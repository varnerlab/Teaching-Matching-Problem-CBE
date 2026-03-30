"""
    generate_edgelist(; faculty_csv, fall_courses_csv, spring_courses_csv,
        fall_preferences_csv, spring_preferences_csv, output_edgelist) -> Dict

Programmatically generate the directed bipartite graph edgelist for the
two-semester faculty-course matching problem.

Graph architecture:
    BOS → Faculty_i → FallGW_i  → FallCourses  → FallCompletions  → EOS
                    → SpringGW_i → SpringCourses → SpringCompletions → EOS

Returns a metadata dictionary with all computed node indices and graph info.
"""
function generate_edgelist(;
    faculty_csv::String,
    fall_courses_csv::String,
    spring_courses_csv::String,
    fall_preferences_csv::String,
    spring_preferences_csv::String,
    output_edgelist::String,
    default_preference_cost::Float64 = 3.0
)

    # --- Read input data ---
    faculty_df = CSV.read(faculty_csv, DataFrame)
    fall_courses_df = CSV.read(fall_courses_csv, DataFrame)
    spring_courses_df = CSV.read(spring_courses_csv, DataFrame)
    fall_pref_df = CSV.read(fall_preferences_csv, DataFrame)
    spring_pref_df = CSV.read(spring_preferences_csv, DataFrame)

    N_f = nrow(faculty_df)
    N_cF = nrow(fall_courses_df)
    N_cS = nrow(spring_courses_df)

    # --- Compute node indices ---
    # Layout: BOS | Faculty | FallGW | SpringGW | FallCourses | SpringCourses | FallCompletions | SpringCompletions | EOS
    bos = 1

    faculty_start = 2
    faculty_nodes = collect(faculty_start : faculty_start + N_f - 1)

    fall_gw_start = faculty_start + N_f
    fall_gw_nodes = collect(fall_gw_start : fall_gw_start + N_f - 1)

    spring_gw_start = fall_gw_start + N_f
    spring_gw_nodes = collect(spring_gw_start : spring_gw_start + N_f - 1)

    fall_course_start = spring_gw_start + N_f
    fall_course_nodes = collect(fall_course_start : fall_course_start + N_cF - 1)

    spring_course_start = fall_course_start + N_cF
    spring_course_nodes = collect(spring_course_start : spring_course_start + N_cS - 1)

    fall_comp_start = spring_course_start + N_cS
    fall_comp_nodes = collect(fall_comp_start : fall_comp_start + N_cF - 1)

    spring_comp_start = fall_comp_start + N_cF
    spring_comp_nodes = collect(spring_comp_start : spring_comp_start + N_cS - 1)

    eos = spring_comp_start + N_cS

    # --- Build preference lookup ---
    fall_pref = _build_pref_lookup(fall_pref_df, default_preference_cost)
    spring_pref = _build_pref_lookup(spring_pref_df, default_preference_cost)

    # --- Generate edges ---
    edges = String[]

    # Header
    push!(edges, "# Two-semester faculty-course matching edgelist (auto-generated)")
    push!(edges, "# Format: source,target,cost,lb,ub")
    push!(edges, "# Nodes: BOS=$bos, Faculty=$(faculty_nodes[1])-$(faculty_nodes[end]), FallGW=$(fall_gw_nodes[1])-$(fall_gw_nodes[end]), SpringGW=$(spring_gw_nodes[1])-$(spring_gw_nodes[end])")
    push!(edges, "# FallCourses=$(fall_course_nodes[1])-$(fall_course_nodes[end]), SpringCourses=$(spring_course_nodes[1])-$(spring_course_nodes[end])")
    push!(edges, "# FallComp=$(fall_comp_nodes[1])-$(fall_comp_nodes[end]), SpringComp=$(spring_comp_nodes[1])-$(spring_comp_nodes[end]), EOS=$eos")
    push!(edges, "#")

    # 1. BOS → Faculty (yearly capacity)
    push!(edges, "# BOS -> Faculty (yearly teaching capacity)")
    for i in 1:N_f
        u_fall = faculty_df[i, :U_fall]
        u_spring = faculty_df[i, :U_spring]
        yearly = u_fall + u_spring
        push!(edges, "$bos,$(faculty_nodes[i]),0.0,0.0,$(Float64(yearly))")
    end

    # 2. Faculty → Fall Gateway
    push!(edges, "# Faculty -> Fall Gateway (fall semester cap)")
    for i in 1:N_f
        u_fall = faculty_df[i, :U_fall]
        push!(edges, "$(faculty_nodes[i]),$(fall_gw_nodes[i]),0.0,0.0,$(Float64(u_fall))")
    end

    # 3. Faculty → Spring Gateway
    push!(edges, "# Faculty -> Spring Gateway (spring semester cap)")
    for i in 1:N_f
        u_spring = faculty_df[i, :U_spring]
        push!(edges, "$(faculty_nodes[i]),$(spring_gw_nodes[i]),0.0,0.0,$(Float64(u_spring))")
    end

    # 4. Fall Gateway → Fall Courses (with preference costs)
    push!(edges, "# Fall Gateway -> Fall Courses (preference costs)")
    for i in 1:N_f
        name = faculty_df[i, :name]
        for j in 1:N_cF
            course = fall_courses_df[j, :course]
            cost = get(get(fall_pref, name, Dict{String,Float64}()), course, default_preference_cost)
            push!(edges, "$(fall_gw_nodes[i]),$(fall_course_nodes[j]),$(cost),0.0,1.0")
        end
    end

    # 5. Spring Gateway → Spring Courses (with preference costs)
    push!(edges, "# Spring Gateway -> Spring Courses (preference costs)")
    for i in 1:N_f
        name = faculty_df[i, :name]
        for j in 1:N_cS
            course = spring_courses_df[j, :course]
            cost = get(get(spring_pref, name, Dict{String,Float64}()), course, default_preference_cost)
            push!(edges, "$(spring_gw_nodes[i]),$(spring_course_nodes[j]),$(cost),0.0,1.0")
        end
    end

    # 6. Fall Course → Fall Completion (lb=1 for required courses)
    push!(edges, "# Fall Course -> Fall Completion (lb=1 if required)")
    for j in 1:N_cF
        lb = _is_required(fall_courses_df, j) ? 1.0 : 0.0
        push!(edges, "$(fall_course_nodes[j]),$(fall_comp_nodes[j]),0.0,$(lb),1.0")
    end

    # 7. Spring Course → Spring Completion (lb=1 for required courses)
    push!(edges, "# Spring Course -> Spring Completion (lb=1 if required)")
    for j in 1:N_cS
        lb = _is_required(spring_courses_df, j) ? 1.0 : 0.0
        push!(edges, "$(spring_course_nodes[j]),$(spring_comp_nodes[j]),0.0,$(lb),1.0")
    end

    # 8. Fall Completion → EOS
    push!(edges, "# Fall Completion -> EOS")
    for j in 1:N_cF
        push!(edges, "$(fall_comp_nodes[j]),$eos,0.0,0.0,1.0")
    end

    # 9. Spring Completion → EOS
    push!(edges, "# Spring Completion -> EOS")
    for j in 1:N_cS
        push!(edges, "$(spring_comp_nodes[j]),$eos,0.0,0.0,1.0")
    end

    # --- Write edgelist ---
    open(output_edgelist, "w") do io
        for line in edges
            println(io, line)
        end
    end

    # --- Compute total flow ---
    F = sum(faculty_df[!, :U_fall]) + sum(faculty_df[!, :U_spring])

    # --- Add computed node indices to course DataFrames ---
    fall_courses_df[!, :coursenodeindex] = fall_course_nodes
    fall_courses_df[!, :coursecompletionnode] = fall_comp_nodes
    spring_courses_df[!, :coursenodeindex] = spring_course_nodes
    spring_courses_df[!, :coursecompletionnode] = spring_comp_nodes

    # --- Return metadata ---
    return Dict{String,Any}(
        "BOS" => bos,
        "EOS" => eos,
        "N_nodes" => eos,
        "N_faculty" => N_f,
        "N_fall_courses" => N_cF,
        "N_spring_courses" => N_cS,
        "faculty_nodes" => faculty_nodes,
        "fall_gateway_nodes" => fall_gw_nodes,
        "spring_gateway_nodes" => spring_gw_nodes,
        "fall_course_nodes" => fall_course_nodes,
        "spring_course_nodes" => spring_course_nodes,
        "fall_completion_nodes" => fall_comp_nodes,
        "spring_completion_nodes" => spring_comp_nodes,
        "F" => Float64(F),
        "faculty_df" => faculty_df,
        "fall_courses_df" => fall_courses_df,
        "spring_courses_df" => spring_courses_df,
    )
end


"""
    _is_required(courses_df, row_index) -> Bool

Check if a course is marked as required. Returns `false` if the `required`
column is missing from the DataFrame.
"""
function _is_required(courses_df::DataFrame, j::Int)
    if hasproperty(courses_df, :required)
        val = courses_df[j, :required]
        return val === true || val == "true" || val == 1
    end
    return false
end


"""
    _build_pref_lookup(pref_df, default) -> Dict{String, Dict{String, Float64}}

Build a nested lookup: faculty_name -> course_name -> preference_cost.
"""
function _build_pref_lookup(pref_df::DataFrame, default::Float64)
    lookup = Dict{String, Dict{String, Float64}}()
    course_cols = [String(c) for c in names(pref_df) if c != "lastname"]

    for row in eachrow(pref_df)
        name = String(row[:lastname])
        inner = Dict{String, Float64}()
        for col in course_cols
            val = row[Symbol(col)]
            if !ismissing(val)
                inner[col] = Float64(val)
            else
                inner[col] = default
            end
        end
        lookup[name] = inner
    end

    return lookup
end
