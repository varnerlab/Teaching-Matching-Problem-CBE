"""
    run_matching.jl

Solve the two-semester (Fall 2026 + Spring 2027) faculty-course teaching
assignment problem using a min-cost max-flow LP formulation, and write the
optimal assignments to a CSV file.

Usage:
    julia --project=. run_matching.jl

Output:
    results/Faculty-Course-Assignments-AY-2026-2027.csv
"""

# ===== Load packages and project code ========================================
include(joinpath(@__DIR__, "Include.jl"));

# ===== Function definitions ==================================================

"""
    edgerecordparser(record::String, delim::Char=',') -> Tuple | Nothing

Parse a single line from the edgelist file into a 5-tuple:
(source::Int, target::Int, cost::Float64, lb::Float64, ub::Float64).

Returns `nothing` if the line does not contain at least 5 fields
(e.g., blank lines or malformed records).
"""
function edgerecordparser(record::String, delim::Char=',')

    fields = split(record, delim)
    if length(fields) < 5
        return nothing
    end

    source = parse(Int, fields[1])
    target = parse(Int, fields[2])
    cost   = parse(Float64, fields[3])
    lb     = parse(Float64, fields[4])
    ub     = parse(Float64, fields[5])

    return (source, target, cost, lb, ub)
end


"""
    build_capacity_bounds(model::MyDirectedBipartiteGraphModel) -> Array{Float64,2}

Extract the capacity lower and upper bounds from the graph model into an
(N_edges × 2) matrix. Column 1 = lower bound, column 2 = upper bound.
"""
function build_capacity_bounds(model::MyDirectedBipartiteGraphModel)

    capacity = model.capacity
    number_of_edges = length(model.edges)
    bounds = Array{Float64,2}(undef, number_of_edges, 2)

    for (k, v) in model.edgesinverse
        bounds[k, 1] = capacity[v][1]
        bounds[k, 2] = capacity[v][2]
    end

    return bounds
end


"""
    build_cost_vector(model::MyDirectedBipartiteGraphModel) -> Array{Float64,1}

Extract the edge cost (weight) vector from the graph model into a length-N_edges
array, ordered by edge index.
"""
function build_cost_vector(model::MyDirectedBipartiteGraphModel)

    number_of_edges = length(model.edges)
    weights = model.edges
    cost_vector = Array{Float64,1}(undef, number_of_edges)

    for (k, v) in model.edgesinverse
        cost_vector[k] = weights[v]
    end

    return cost_vector
end


"""
    apply_cost_override!(model, cost_vector, graph_info, faculty_df, fall_courses_df, spring_courses_df,
        faculty_name, course_name, semester; wv=-1.0)

Set the cost on a specific (gateway → course) edge to `wv`. This is used to
encode strong faculty-course preferences that go beyond the survey data.

# Arguments
- `faculty_name::String`: faculty last name (must match Faculty.csv)
- `course_name::String`: course code, e.g. "CHEME-3130"
- `semester::Symbol`: `:fall` or `:spring`
- `wv::Float64`: cost value to assign (default -100.0 = hard constraint)
"""
function apply_cost_override!(model::MyDirectedBipartiteGraphModel,
    cost_vector::Array{Float64,1}, graph_info::Dict{String,Any},
    faculty_df::DataFrame, fall_courses_df::DataFrame, spring_courses_df::DataFrame,
    faculty_name::String, course_name::String, semester::Symbol; wv::Float64 = -100.0)

    idx = findfirst(==(faculty_name), faculty_df[!, :name])
    if isnothing(idx)
        @warn "Faculty not found: $faculty_name"
        return
    end

    if semester == :fall
        gateway_node = graph_info["fall_gateway_nodes"][idx]
        ci = findfirst(==(course_name), fall_courses_df[!, :course])
        if isnothing(ci)
            @warn "Fall course not found: $course_name"
            return
        end
        course_node = graph_info["fall_course_nodes"][ci]
    else
        gateway_node = graph_info["spring_gateway_nodes"][idx]
        ci = findfirst(==(course_name), spring_courses_df[!, :course])
        if isnothing(ci)
            @warn "Spring course not found: $course_name"
            return
        end
        course_node = graph_info["spring_course_nodes"][ci]
    end

    update_cost_array!(model, cost_vector, wv=wv, faculty=gateway_node, course=course_node)
end


"""
    build_incidence_matrix(model::MyDirectedBipartiteGraphModel) -> Array{Float64,2}

Build the (N_nodes × N_edges) node-edge incidence matrix for the flow
conservation constraints. Entry A[s, e] = -1 if edge e leaves node s,
A[t, e] = +1 if edge e enters node t.
"""
function build_incidence_matrix(model::MyDirectedBipartiteGraphModel)

    n_nodes = length(model.nodes)
    n_edges = length(model.edges)
    A = zeros(n_nodes, n_edges)

    for (k, v) in model.edgesinverse
        A[v[1], k] = -1.0  # outgoing
        A[v[2], k] =  1.0  # incoming
    end

    return A
end


"""
    build_flow_balance(model::MyDirectedBipartiteGraphModel, F::Float64) -> Array{Float64,1}

Build the right-hand-side vector b for flow conservation. The source node
supplies F units of flow (b[source] = -F), the sink absorbs them (b[sink] = F),
and all other nodes are balanced (b[i] = 0).
"""
function build_flow_balance(model::MyDirectedBipartiteGraphModel, F::Float64)

    n_nodes = length(model.nodes)
    b = zeros(n_nodes)
    b[model.source] = -F
    b[model.sink]   =  F

    return b
end


"""
    extract_flow(model::MyDirectedBipartiteGraphModel, solution::Dict) -> Dict{Tuple{Int,Int}, Float64}

Convert the LP solution vector into a dictionary mapping (source, target) node
pairs to their flow values.
"""
function extract_flow(model::MyDirectedBipartiteGraphModel, solution::Dict)

    flow = Dict{Tuple{Int,Int}, Float64}()
    flow_vector = solution["argmax"]

    for (k, v) in model.edgesinverse
        flow[(v[1], v[2])] = flow_vector[k]
    end

    return flow
end


"""
    build_assignments_dataframe(graph_info, faculty_df, fall_courses_df, spring_courses_df,
        fall_matching, spring_matching) -> DataFrame

Build a tidy DataFrame of faculty assignments across both semesters, sorted
alphabetically by faculty name. Columns: Faculty, Fall_Course, Fall_Title,
Spring_Course, Spring_Title, Fall_Load, Spring_Load, Total_Load.
"""
function build_assignments_dataframe(graph_info::Dict{String,Any},
    faculty_df::DataFrame, fall_courses_df::DataFrame, spring_courses_df::DataFrame,
    fall_matching::Dict{String, Vector{String}}, spring_matching::Dict{String, Vector{String}})

    # Count how many faculty are assigned to each course
    fall_course_count = Dict{String,Int}()
    for courses in values(fall_matching)
        for c in courses
            fall_course_count[c] = get(fall_course_count, c, 0) + 1
        end
    end
    spring_course_count = Dict{String,Int}()
    for courses in values(spring_matching)
        for c in courses
            spring_course_count[c] = get(spring_course_count, c, 0) + 1
        end
    end

    rows = NamedTuple[]
    for i in 1:graph_info["N_faculty"]
        name = String(faculty_df[i, :name])
        fc = get(fall_matching, name, String[])
        sc = get(spring_matching, name, String[])

        fall_titles = [String(fall_courses_df[fall_courses_df.course .== c, :title][1]) for c in fc]
        spring_titles = [String(spring_courses_df[spring_courses_df.course .== c, :title][1]) for c in sc]

        # Credit hours: divide course credits by number of faculty assigned
        fall_credits = sum(
            Float64(fall_courses_df[fall_courses_df.course .== c, :credits][1]) / fall_course_count[c]
            for c in fc; init=0.0)
        spring_credits = sum(
            Float64(spring_courses_df[spring_courses_df.course .== c, :credits][1]) / spring_course_count[c]
            for c in sc; init=0.0)

        # Undiluted credit hours: full course credits regardless of team size
        fall_credits_full = sum(
            Float64(fall_courses_df[fall_courses_df.course .== c, :credits][1])
            for c in fc; init=0.0)
        spring_credits_full = sum(
            Float64(spring_courses_df[spring_courses_df.course .== c, :credits][1])
            for c in sc; init=0.0)

        push!(rows, (
            Faculty        = name,
            Fall_Course    = join(fc, "; "),
            Fall_Title     = join(fall_titles, "; "),
            Spring_Course  = join(sc, "; "),
            Spring_Title   = join(spring_titles, "; "),
            Fall_Load      = length(fc),
            Spring_Load    = length(sc),
            Total_Load     = length(fc) + length(sc),
            Fall_Credits   = fall_credits,
            Spring_Credits = spring_credits,
            Total_Credits  = fall_credits + spring_credits,
            Total_Credits_Undiluted = fall_credits_full + spring_credits_full,
        ))
    end

    df = DataFrame(rows)
    sort!(df, :Faculty)

    return df
end


"""
    load_cost_overrides(filepath::String) -> Vector{Tuple{String, String, Symbol}}

Load cost overrides from a CSV file with columns: faculty, course, semester.
Each row becomes a (faculty_name, course_code, :fall/:spring) tuple that will
have its edge cost set to -1.0 during optimization.
"""
function load_cost_overrides(filepath::String)
    df = CSV.read(filepath, DataFrame, comment="#")
    return [(String(row.faculty), String(row.course), Symbol(row.semester)) for row in eachrow(df)]
end


# ===== Main computation ======================================================

function main()

    # Step 1: Generate the graph edgelist from CSV inputs
    println("Generating graph...")
    graph_info = generate_edgelist(
        faculty_csv            = joinpath(_PATH_TO_CONFIG, "Faculty.csv"),
        fall_courses_csv       = joinpath(_PATH_TO_CONFIG, "Courses-Fall-2026.csv"),
        spring_courses_csv     = joinpath(_PATH_TO_CONFIG, "Courses-Spring-2027.csv"),
        fall_preferences_csv   = joinpath(_PATH_TO_DATA, "Faculty-Course-Preferences-Fall-2026.csv"),
        spring_preferences_csv = joinpath(_PATH_TO_DATA, "Faculty-Course-Preferences-Spring-2027.csv"),
        output_edgelist        = joinpath(_PATH_TO_DATA, "Faculty-Courses-Bipartite-AY-2026-2027.edgelist"),
    )

    faculty_df        = graph_info["faculty_df"]
    fall_courses_df   = graph_info["fall_courses_df"]
    spring_courses_df = graph_info["spring_courses_df"]

    println("  $(graph_info["N_nodes"]) nodes | $(graph_info["N_faculty"]) faculty | " *
            "$(graph_info["N_fall_courses"]) fall courses | $(graph_info["N_spring_courses"]) spring courses")
    println("  Total flow F = $(graph_info["F"])")

    # Step 2: Parse the edgelist and build the directed graph model
    println("Building graph model...")
    edge_file = joinpath(_PATH_TO_DATA, "Faculty-Courses-Bipartite-AY-2026-2027.edgelist")
    edge_models = MyConstrainedGraphEdgeModels(edge_file, edgerecordparser, delim=',', comment='#')
    model = build(MyDirectedBipartiteGraphModel, (
        s = graph_info["BOS"], t = graph_info["EOS"], edges = edge_models,
    ))

    # Step 3: Extract capacity bounds and cost vector from graph
    bounds = build_capacity_bounds(model)
    cost_vector = build_cost_vector(model)

    # Step 4: Apply manual cost overrides from CSV
    cost_overrides = load_cost_overrides(joinpath(_PATH_TO_CONFIG, "Cost-Overrides-AY-2026-2027.csv"))
    println("  Loaded $(length(cost_overrides)) cost overrides")
    for (faculty_name, course_name, semester) in cost_overrides
        apply_cost_override!(model, cost_vector, graph_info,
            faculty_df, fall_courses_df, spring_courses_df,
            faculty_name, course_name, semester)
    end

    # Step 5: Build LP components and solve
    println("Solving LP...")
    A = build_incidence_matrix(model)
    b = build_flow_balance(model, graph_info["F"])

    problem = build(MyLinearProgrammingProblemModel, (
        c = -cost_vector, A = A, b = b,
        lb = bounds[:, 1], ub = bounds[:, 2],
    ))

    solution = solve(problem, constraints = :eq)
    println("  Objective = $(solution["objective_value"])")

    # Step 6: Extract flow and faculty-course assignments
    flow = extract_flow(model, solution)

    fall_matching = extract_matching(flow,
        graph_info["fall_gateway_nodes"], graph_info["fall_course_nodes"],
        faculty_df, fall_courses_df,
    )
    spring_matching = extract_matching(flow,
        graph_info["spring_gateway_nodes"], graph_info["spring_course_nodes"],
        faculty_df, spring_courses_df,
    )

    # Step 7: Build output DataFrame and write CSV
    output_df = build_assignments_dataframe(graph_info,
        faculty_df, fall_courses_df, spring_courses_df,
        fall_matching, spring_matching,
    )

    output_path = joinpath(_PATH_TO_RESULTS, "Faculty-Course-Assignments-AY-2026-2027.csv")
    CSV.write(output_path, output_df)

    # Step 8: Print summary
    println("\n" * "="^90)
    println("  Faculty Teaching Assignments — AY 2026-2027")
    println("="^90)
    pretty_table(
        output_df[:, [:Faculty, :Fall_Course, :Spring_Course, :Fall_Load, :Spring_Load, :Total_Load, :Fall_Credits, :Spring_Credits, :Total_Credits, :Total_Credits_Undiluted]];
        backend = :text,
        table_format = TextTableFormat(borders = text_table_borders__compact),
        alignment = [:l, :l, :l, :c, :c, :c, :c, :c, :c, :c],
        fit_table_in_display_horizontally = false,
        fit_table_in_display_vertically = false,
    )

    n_fall = sum(output_df.Fall_Load)
    n_spring = sum(output_df.Spring_Load)
    fall_slots = hasproperty(fall_courses_df, :max_faculty) ? sum(fall_courses_df.max_faculty) : graph_info["N_fall_courses"]
    spring_slots = hasproperty(spring_courses_df, :max_faculty) ? sum(spring_courses_df.max_faculty) : graph_info["N_spring_courses"]
    println("Fall:   $n_fall / $fall_slots slots assigned ($(graph_info["N_fall_courses"]) courses)")
    println("Spring: $n_spring / $spring_slots slots assigned ($(graph_info["N_spring_courses"]) courses)")
    println("Total:  $(n_fall + n_spring) assignments across $(graph_info["N_faculty"]) faculty")
    println("\nResults written to: $output_path")
end

# Run
main()
