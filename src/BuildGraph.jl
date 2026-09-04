"""
    generate_edgelist(; faculty_df, fall_courses_df, spring_courses_df,
        fall_preferences_df, spring_preferences_df, assignments_df,
        output_edgelist, preferred_cost=-100.0) -> Dict

Generate the two-semester teaching-assignment flow network.

Faculty `load_fall` and `load_spring` values are exact obligations because the
total source flow equals their sum. Course `min_faculty` and `max_faculty`
values become lower and upper flow bounds. Missing preferences do not create
eligible automatic matches. A `fixed` assignment has flow bounds `[1, 1]`; a
`preferred` assignment remains optional but receives `preferred_cost`.
"""
function generate_edgelist(;
    faculty_df::DataFrame,
    fall_courses_df::DataFrame,
    spring_courses_df::DataFrame,
    fall_preferences_df::DataFrame,
    spring_preferences_df::DataFrame,
    assignments_df::DataFrame,
    output_edgelist::String,
    preferred_cost::Float64 = -100.0,
)
    N_f = nrow(faculty_df)
    N_cF = nrow(fall_courses_df)
    N_cS = nrow(spring_courses_df)

    bos = 1
    faculty_nodes = collect(2:(N_f + 1))
    fall_gw_nodes = collect((faculty_nodes[end] + 1):(faculty_nodes[end] + N_f))
    spring_gw_nodes = collect((fall_gw_nodes[end] + 1):(fall_gw_nodes[end] + N_f))
    fall_course_nodes = collect((spring_gw_nodes[end] + 1):(spring_gw_nodes[end] + N_cF))
    spring_course_nodes = collect((fall_course_nodes[end] + 1):(fall_course_nodes[end] + N_cS))
    fall_comp_nodes = collect((spring_course_nodes[end] + 1):(spring_course_nodes[end] + N_cF))
    spring_comp_nodes = collect((fall_comp_nodes[end] + 1):(fall_comp_nodes[end] + N_cS))
    eos = spring_comp_nodes[end] + 1

    fall_pref = _build_pref_lookup(fall_preferences_df)
    spring_pref = _build_pref_lookup(spring_preferences_df)
    assignment_kinds = _build_assignment_lookup(assignments_df)

    edges = String[
        "# Two-semester faculty-course matching edgelist (auto-generated)",
        "# Format: source,target,cost,lb,ub",
        "# Missing preference edges have ub=0; fixed assignments have lb=ub=1",
        "#",
        "# BOS -> Faculty (exact yearly obligations through total-flow balance)",
    ]

    for i in 1:N_f
        yearly_load = faculty_df[i, :load_fall] + faculty_df[i, :load_spring]
        push!(edges, "$bos,$(faculty_nodes[i]),0.0,0.0,$(Float64(yearly_load))")
    end

    push!(edges, "# Faculty -> Fall Gateway (exact after flow balance)")
    for i in 1:N_f
        load = faculty_df[i, :load_fall]
        push!(edges, "$(faculty_nodes[i]),$(fall_gw_nodes[i]),0.0,0.0,$(Float64(load))")
    end

    push!(edges, "# Faculty -> Spring Gateway (exact after flow balance)")
    for i in 1:N_f
        load = faculty_df[i, :load_spring]
        push!(edges, "$(faculty_nodes[i]),$(spring_gw_nodes[i]),0.0,0.0,$(Float64(load))")
    end

    push!(edges, "# Fall Gateway -> Fall Courses")
    _append_assignment_edges!(edges, faculty_df, fall_courses_df, fall_gw_nodes,
        fall_course_nodes, fall_pref, assignment_kinds, :fall, preferred_cost)

    push!(edges, "# Spring Gateway -> Spring Courses")
    _append_assignment_edges!(edges, faculty_df, spring_courses_df, spring_gw_nodes,
        spring_course_nodes, spring_pref, assignment_kinds, :spring, preferred_cost)

    push!(edges, "# Fall Course -> Fall Completion (explicit staffing bounds)")
    for j in 1:N_cF
        lb = Float64(fall_courses_df[j, :min_faculty])
        ub = Float64(fall_courses_df[j, :max_faculty])
        push!(edges, "$(fall_course_nodes[j]),$(fall_comp_nodes[j]),0.0,$lb,$ub")
    end

    push!(edges, "# Spring Course -> Spring Completion (explicit staffing bounds)")
    for j in 1:N_cS
        lb = Float64(spring_courses_df[j, :min_faculty])
        ub = Float64(spring_courses_df[j, :max_faculty])
        push!(edges, "$(spring_course_nodes[j]),$(spring_comp_nodes[j]),0.0,$lb,$ub")
    end

    push!(edges, "# Fall Completion -> EOS")
    for j in 1:N_cF
        ub = Float64(fall_courses_df[j, :max_faculty])
        push!(edges, "$(fall_comp_nodes[j]),$eos,0.0,0.0,$ub")
    end

    push!(edges, "# Spring Completion -> EOS")
    for j in 1:N_cS
        ub = Float64(spring_courses_df[j, :max_faculty])
        push!(edges, "$(spring_comp_nodes[j]),$eos,0.0,0.0,$ub")
    end

    mkpath(dirname(output_edgelist))
    open(output_edgelist, "w") do io
        foreach(line -> println(io, line), edges)
    end

    F = sum(faculty_df[!, :load_fall]) + sum(faculty_df[!, :load_spring])

    fall_courses_with_nodes = copy(fall_courses_df)
    spring_courses_with_nodes = copy(spring_courses_df)
    fall_courses_with_nodes[!, :coursenodeindex] = fall_course_nodes
    fall_courses_with_nodes[!, :coursecompletionnode] = fall_comp_nodes
    spring_courses_with_nodes[!, :coursenodeindex] = spring_course_nodes
    spring_courses_with_nodes[!, :coursecompletionnode] = spring_comp_nodes

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
        "faculty_df" => copy(faculty_df),
        "fall_courses_df" => fall_courses_with_nodes,
        "spring_courses_df" => spring_courses_with_nodes,
        "assignments_df" => copy(assignments_df),
    )
end


function _append_assignment_edges!(
    edges::Vector{String}, faculty_df::DataFrame, courses_df::DataFrame,
    gateway_nodes::Vector{Int}, course_nodes::Vector{Int},
    preferences::Dict{String,Dict{String,Float64}},
    assignment_kinds::Dict{Tuple{String,String,Symbol},Symbol},
    semester::Symbol, preferred_cost::Float64,
)
    for i in 1:nrow(faculty_df)
        faculty = String(faculty_df[i, :name])
        faculty_preferences = get(preferences, faculty, Dict{String,Float64}())
        for j in 1:nrow(courses_df)
            course = String(courses_df[j, :course])
            kind = get(assignment_kinds, (faculty, course, semester), :automatic)

            if kind == :fixed
                cost, lb, ub = 0.0, 1.0, 1.0
            elseif kind == :preferred
                cost, lb, ub = preferred_cost, 0.0, 1.0
            elseif haskey(faculty_preferences, course)
                cost, lb, ub = faculty_preferences[course], 0.0, 1.0
            else
                cost, lb, ub = 0.0, 0.0, 0.0
            end

            push!(edges, "$(gateway_nodes[i]),$(course_nodes[j]),$cost,$lb,$ub")
        end
    end
    return edges
end


"""Build `faculty => course => preference` without filling missing values."""
function _build_pref_lookup(pref_df::DataFrame)
    lookup = Dict{String,Dict{String,Float64}}()
    course_cols = [String(c) for c in names(pref_df) if c != "lastname"]

    for row in eachrow(pref_df)
        faculty = String(row[:lastname])
        values = Dict{String,Float64}()
        for course in course_cols
            value = row[Symbol(course)]
            if !ismissing(value)
                values[course] = Float64(value)
            end
        end
        lookup[faculty] = values
    end
    return lookup
end


function _build_assignment_lookup(assignments_df::DataFrame)
    lookup = Dict{Tuple{String,String,Symbol},Symbol}()
    for row in eachrow(assignments_df)
        key = (String(row.faculty), String(row.course), Symbol(row.semester))
        lookup[key] = Symbol(row.kind)
    end
    return lookup
end
