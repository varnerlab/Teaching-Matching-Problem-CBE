struct MatchingValidationError <: Exception
    messages::Vector{String}
end

function Base.showerror(io::IO, error::MatchingValidationError)
    println(io, "Teaching-matching configuration is invalid:")
    for message in error.messages
        println(io, "  - ", message)
    end
end


"""Return the production input paths used by the script and notebook."""
function default_matching_paths(root::String = _ROOT)
    return (
        faculty = joinpath(root, "data", "config", "Faculty.csv"),
        fall_courses = joinpath(root, "data", "config", "Courses-Fall-2026.csv"),
        spring_courses = joinpath(root, "data", "config", "Courses-Spring-2027.csv"),
        fall_preferences = joinpath(root, "data", "Faculty-Course-Preferences-Fall-2026.csv"),
        spring_preferences = joinpath(root, "data", "Faculty-Course-Preferences-Spring-2027.csv"),
        assignments = joinpath(root, "data", "config", "Assignments-AY-2026-2027.csv"),
    )
end


"""Read and normalize all matching inputs without filling missing preferences."""
function read_matching_inputs(paths = default_matching_paths())
    for path in values(paths)
        isfile(path) || throw(MatchingValidationError(["Input file not found: $path"]))
    end

    faculty = CSV.read(paths.faculty, DataFrame)
    fall_courses = CSV.read(paths.fall_courses, DataFrame)
    spring_courses = CSV.read(paths.spring_courses, DataFrame)
    fall_preferences = CSV.read(paths.fall_preferences, DataFrame)
    spring_preferences = CSV.read(paths.spring_preferences, DataFrame)
    assignments = CSV.read(paths.assignments, DataFrame, comment = "#")

    _normalize_string_column!(faculty, :name)
    for courses in (fall_courses, spring_courses)
        _normalize_string_column!(courses, :course)
        _normalize_string_column!(courses, :title)
    end
    for preferences in (fall_preferences, spring_preferences)
        _normalize_string_column!(preferences, :lastname)
    end
    for column in (:faculty, :course, :semester, :kind)
        _normalize_string_column!(assignments, column)
    end

    return (
        faculty = faculty,
        fall_courses = fall_courses,
        spring_courses = spring_courses,
        fall_preferences = fall_preferences,
        spring_preferences = spring_preferences,
        assignments = assignments,
    )
end


function _normalize_string_column!(df::DataFrame, column::Symbol)
    if column in propertynames(df)
        df[!, column] = [ismissing(value) ? "" : strip(String(value)) for value in df[!, column]]
    end
    return df
end


function _require_columns!(errors::Vector{String}, df::DataFrame, required, label::String)
    missing_columns = setdiff(String.(required), names(df))
    if !isempty(missing_columns)
        push!(errors, "$label is missing column(s): $(join(missing_columns, ", ")).")
    end
end


_is_nonnegative_integer(value) =
    !ismissing(value) && value isa Real && isfinite(value) && isinteger(value) && value >= 0

function _duplicate_values(values)
    counts = Dict{eltype(values),Int}()
    for value in values
        counts[value] = get(counts, value, 0) + 1
    end
    return [value for (value, count) in counts if count > 1]
end


"""
    validate_matching_inputs(inputs) -> Vector{String}

Validate schemas, references, bounds, exact-load feasibility, fixed assignments,
and preference coverage. Returns non-fatal warnings or throws a
`MatchingValidationError` containing actionable messages.
"""
function validate_matching_inputs(inputs)
    errors = String[]
    warnings = String[]

    _require_columns!(errors, inputs.faculty, [:name, :load_fall, :load_spring], "Faculty.csv")
    for (semester, courses) in ((:fall, inputs.fall_courses), (:spring, inputs.spring_courses))
        _require_columns!(errors, courses,
            [:course, :credits, :min_faculty, :max_faculty, :title],
            "$(uppercasefirst(String(semester))) courses CSV")
    end
    _require_columns!(errors, inputs.fall_preferences, [:lastname], "Fall preferences CSV")
    _require_columns!(errors, inputs.spring_preferences, [:lastname], "Spring preferences CSV")
    _require_columns!(errors, inputs.assignments,
        [:faculty, :course, :semester, :kind], "Assignments CSV")
    isempty(errors) || throw(MatchingValidationError(errors))

    faculty_names = String.(inputs.faculty.name)
    if any(isempty, faculty_names)
        push!(errors, "Faculty.csv contains a blank faculty name.")
    end
    for name in sort(_duplicate_values(faculty_names))
        push!(errors, "Faculty.csv contains duplicate faculty '$name'.")
    end
    for row in eachrow(inputs.faculty)
        for (semester, column) in (("Fall", :load_fall), ("Spring", :load_spring))
            _is_nonnegative_integer(row[column]) ||
                push!(errors, "$(row.name) has invalid $semester exact load '$(row[column])'; use a nonnegative integer.")
        end
    end

    courses_by_semester = Dict(:fall => inputs.fall_courses, :spring => inputs.spring_courses)
    course_names = Dict{Symbol,Vector{String}}()
    for semester in (:fall, :spring)
        courses = courses_by_semester[semester]
        names_for_semester = String.(courses.course)
        course_names[semester] = names_for_semester
        if any(isempty, names_for_semester)
            push!(errors, "$(uppercasefirst(String(semester))) courses CSV contains a blank course code.")
        end
        for course in sort(_duplicate_values(names_for_semester))
            push!(errors, "$(uppercasefirst(String(semester))) courses CSV contains duplicate course '$course'.")
        end
        for row in eachrow(courses)
            if !_is_nonnegative_integer(row.min_faculty) || !_is_nonnegative_integer(row.max_faculty)
                push!(errors, "$(uppercasefirst(String(semester))) $(row.course) staffing bounds must be nonnegative integers.")
            elseif row.min_faculty > row.max_faculty
                push!(errors, "$(uppercasefirst(String(semester))) $(row.course) has min_faculty=$(row.min_faculty) greater than max_faculty=$(row.max_faculty).")
            end
            if ismissing(row.credits) || !(row.credits isa Real) || !isfinite(row.credits) || row.credits < 0
                push!(errors, "$(uppercasefirst(String(semester))) $(row.course) has invalid credits '$(row.credits)'.")
            end
        end
    end

    faculty_set = Set(faculty_names)
    for (semester, preferences) in ((:fall, inputs.fall_preferences), (:spring, inputs.spring_preferences))
        preference_names = String.(preferences.lastname)
        for name in sort(_duplicate_values(preference_names))
            push!(errors, "$(uppercasefirst(String(semester))) preferences contain duplicate faculty '$name'.")
        end
        for name in sort(collect(setdiff(Set(preference_names), faculty_set)))
            push!(errors, "$(uppercasefirst(String(semester))) preferences reference unknown faculty '$name'.")
        end

        configured_courses = Set(course_names[semester])
        preference_courses = Set(String.(names(preferences)[2:end]))
        extra_courses = sort(collect(setdiff(preference_courses, configured_courses)))
        missing_courses = sort(collect(setdiff(configured_courses, preference_courses)))
        !isempty(extra_courses) && push!(warnings,
            "$(uppercasefirst(String(semester))) preferences contain unused course column(s): $(join(extra_courses, ", ")).")
        !isempty(missing_courses) && push!(warnings,
            "$(uppercasefirst(String(semester))) preferences have no column for: $(join(missing_courses, ", ")); those automatic matches are unknown.")

        for row in eachrow(preferences)
            for course in preference_courses
                value = row[Symbol(course)]
                if !ismissing(value) && (!(value isa Real) || !isfinite(value) || !isinteger(value) || !(0 <= value <= 3))
                    push!(errors, "$(uppercasefirst(String(semester))) preference for $(row.lastname)/$course is '$value'; use 0, 1, 2, 3, or blank.")
                end
            end
        end
    end

    assignment_keys = Tuple{String,String,String}[]
    for row in eachrow(inputs.assignments)
        key = (row.faculty, row.course, row.semester)
        push!(assignment_keys, key)
        if !(row.semester in ("fall", "spring"))
            push!(errors, "Assignment $(row.faculty)/$(row.course) has invalid semester '$(row.semester)'; use fall or spring.")
            continue
        end
        if !(row.kind in ("fixed", "preferred"))
            push!(errors, "Assignment $(row.faculty)/$(row.course)/$(row.semester) has invalid kind '$(row.kind)'; use fixed or preferred.")
        end
        if !(row.faculty in faculty_set)
            push!(errors, "Assignment references unknown faculty '$(row.faculty)'.")
        end
        semester = Symbol(row.semester)
        if !(row.course in Set(course_names[semester]))
            push!(errors, "Assignment references unknown $(row.semester) course '$(row.course)'.")
        end
    end
    for key in sort(_duplicate_values(assignment_keys))
        push!(errors, "Assignments CSV contains duplicate assignment $(join(key, "/")).")
    end

    isempty(errors) || throw(MatchingValidationError(errors))

    faculty_load = Dict{Tuple{String,Symbol},Int}()
    for row in eachrow(inputs.faculty)
        faculty_load[(row.name, :fall)] = Int(row.load_fall)
        faculty_load[(row.name, :spring)] = Int(row.load_spring)
    end
    course_bounds = Dict{Tuple{String,Symbol},Tuple{Int,Int}}()
    for semester in (:fall, :spring), row in eachrow(courses_by_semester[semester])
        course_bounds[(row.course, semester)] = (Int(row.min_faculty), Int(row.max_faculty))
    end
    kinds = _build_assignment_lookup(inputs.assignments)
    preferences = Dict(
        :fall => _build_pref_lookup(inputs.fall_preferences),
        :spring => _build_pref_lookup(inputs.spring_preferences),
    )

    for row in eachrow(inputs.assignments)
        semester = Symbol(row.semester)
        _, maximum = course_bounds[(row.course, semester)]
        maximum == 0 && push!(errors,
            "$(uppercasefirst(row.semester)) $(row.course) is disabled (max_faculty=0) but has a $(row.kind) assignment for $(row.faculty).")
    end

    for faculty in faculty_names, semester in (:fall, :spring)
        obligation = faculty_load[(faculty, semester)]
        fixed_courses = [course for ((name, course, sem), kind) in kinds
            if name == faculty && sem == semester && kind == :fixed]
        if length(fixed_courses) > obligation
            push!(errors, "$faculty has $(length(fixed_courses)) fixed $(uppercasefirst(String(semester))) assignments but an exact $(uppercasefirst(String(semester))) obligation of $obligation. Change one assignment to preferred, remove it, or increase the obligation.")
        end

        available_courses = [course for course in course_names[semester]
            if course_bounds[(course, semester)][2] > 0 &&
               _edge_is_available(faculty, course, semester, preferences, kinds)]
        if length(available_courses) < obligation
            push!(errors, "$faculty has an exact $(uppercasefirst(String(semester))) obligation of $obligation but only $(length(available_courses)) eligible fixed, preferred, or rated course(s). Add preference data or an assignment decision.")
        end

        has_preference_row = haskey(preferences[semester], faculty)
        if obligation > 0 && !has_preference_row && length(fixed_courses) == obligation
            push!(warnings, "$faculty has no $(uppercasefirst(String(semester))) preference row, but all $obligation obligation(s) are covered by fixed assignments.")
        elseif obligation > 0 && !has_preference_row
            push!(warnings, "$faculty has no $(uppercasefirst(String(semester))) preference row; non-fixed assignments rely only on explicit preferred decisions.")
        end
    end

    for semester in (:fall, :spring), course in course_names[semester]
        minimum, maximum = course_bounds[(course, semester)]
        fixed_faculty = [faculty for ((faculty, c, sem), kind) in kinds
            if c == course && sem == semester && kind == :fixed]
        if length(fixed_faculty) > maximum
            push!(errors, "$(uppercasefirst(String(semester))) $course has $(length(fixed_faculty)) fixed faculty but max_faculty=$maximum.")
        end
        available_faculty = [faculty for faculty in faculty_names
            if faculty_load[(faculty, semester)] > 0 &&
               _edge_is_available(faculty, course, semester, preferences, kinds)]
        if length(available_faculty) < minimum
            push!(errors, "$(uppercasefirst(String(semester))) $course requires at least $minimum faculty but only $(length(available_faculty)) are eligible through a fixed, preferred, or rated edge.")
        end
    end

    for semester in (:fall, :spring)
        exact_load = sum(faculty_load[(faculty, semester)] for faculty in faculty_names)
        total_minimum = sum(course_bounds[(course, semester)][1] for course in course_names[semester])
        total_maximum = sum(course_bounds[(course, semester)][2] for course in course_names[semester])
        if !(total_minimum <= exact_load <= total_maximum)
            push!(errors, "$(uppercasefirst(String(semester))) exact faculty load is $exact_load, outside total course staffing capacity $total_minimum-$total_maximum.")
        end
    end

    isempty(errors) || throw(MatchingValidationError(errors))
    return warnings
end


function _edge_is_available(faculty::String, course::String, semester::Symbol,
    preferences, kinds)
    kind = get(kinds, (faculty, course, semester), :automatic)
    return kind in (:fixed, :preferred) || haskey(get(preferences[semester], faculty, Dict{String,Float64}()), course)
end


function edgerecordparser(record::String, delim::Char = ',')
    fields = split(record, delim)
    length(fields) == 5 || return nothing
    return (
        parse(Int, fields[1]), parse(Int, fields[2]), parse(Float64, fields[3]),
        parse(Float64, fields[4]), parse(Float64, fields[5]),
    )
end


function build_capacity_bounds(model::MyDirectedBipartiteGraphModel)
    bounds = Array{Float64,2}(undef, length(model.edges), 2)
    for (index, edge) in model.edgesinverse
        bounds[index, 1] = model.capacity[edge][1]
        bounds[index, 2] = model.capacity[edge][2]
    end
    return bounds
end


function build_cost_vector(model::MyDirectedBipartiteGraphModel)
    costs = Array{Float64,1}(undef, length(model.edges))
    for (index, edge) in model.edgesinverse
        costs[index] = model.edges[edge]
    end
    return costs
end


function build_incidence_matrix(model::MyDirectedBipartiteGraphModel)
    A = zeros(length(model.nodes), length(model.edges))
    for (index, edge) in model.edgesinverse
        A[edge[1], index] = -1.0
        A[edge[2], index] = 1.0
    end
    return A
end


function build_flow_balance(model::MyDirectedBipartiteGraphModel, flow_value::Float64)
    b = zeros(length(model.nodes))
    b[model.source] = -flow_value
    b[model.sink] = flow_value
    return b
end


function extract_flow(model::MyDirectedBipartiteGraphModel, solution::Dict)
    flow = Dict{Tuple{Int,Int},Float64}()
    for (index, edge) in model.edgesinverse
        flow[(edge[1], edge[2])] = solution["argmax"][index]
    end
    return flow
end


function build_assignments_dataframe(graph_info, faculty_df, fall_courses_df,
    spring_courses_df, fall_matching, spring_matching)
    fall_count = _course_assignment_counts(fall_matching)
    spring_count = _course_assignment_counts(spring_matching)
    rows = NamedTuple[]

    for row in eachrow(faculty_df)
        faculty = String(row.name)
        fall = get(fall_matching, faculty, String[])
        spring = get(spring_matching, faculty, String[])
        fall_titles = [_course_value(fall_courses_df, course, :title, String) for course in fall]
        spring_titles = [_course_value(spring_courses_df, course, :title, String) for course in spring]
        fall_credits = sum(_course_value(fall_courses_df, course, :credits, Float64) / fall_count[course]
            for course in fall; init = 0.0)
        spring_credits = sum(_course_value(spring_courses_df, course, :credits, Float64) / spring_count[course]
            for course in spring; init = 0.0)
        full_credits = sum(_course_value(fall_courses_df, course, :credits, Float64)
            for course in fall; init = 0.0) +
            sum(_course_value(spring_courses_df, course, :credits, Float64)
            for course in spring; init = 0.0)

        push!(rows, (
            Faculty = faculty,
            Fall_Course = join(fall, "; "),
            Fall_Title = join(fall_titles, "; "),
            Spring_Course = join(spring, "; "),
            Spring_Title = join(spring_titles, "; "),
            Fall_Load = length(fall),
            Fall_Obligation = Int(row.load_fall),
            Spring_Load = length(spring),
            Spring_Obligation = Int(row.load_spring),
            Total_Load = length(fall) + length(spring),
            Fall_Credits = fall_credits,
            Spring_Credits = spring_credits,
            Total_Credits = fall_credits + spring_credits,
            Total_Credits_Undiluted = full_credits,
        ))
    end

    result = DataFrame(rows)
    sort!(result, :Faculty)
    return result
end


function _course_assignment_counts(matching)
    counts = Dict{String,Int}()
    for courses in values(matching), course in courses
        counts[course] = get(counts, course, 0) + 1
    end
    return counts
end


function _course_value(courses::DataFrame, course::String, column::Symbol, type)
    index = findfirst(==(course), courses.course)
    isnothing(index) && error("Course '$course' missing during result construction.")
    return type(courses[index, column])
end


function build_course_staffing_dataframe(fall_courses, spring_courses,
    fall_matching, spring_matching)
    rows = NamedTuple[]
    for (semester, courses, matching) in (
        ("fall", fall_courses, fall_matching),
        ("spring", spring_courses, spring_matching),
    )
        assigned = Dict{String,Vector{String}}(course => String[] for course in String.(courses.course))
        for (faculty, faculty_courses) in matching, course in faculty_courses
            push!(assigned[course], faculty)
        end
        for row in eachrow(courses)
            faculty = sort(assigned[row.course])
            push!(rows, (
                Semester = semester,
                Course = String(row.course),
                Title = String(row.title),
                Min_Faculty = Int(row.min_faculty),
                Max_Faculty = Int(row.max_faculty),
                Assigned_Count = length(faculty),
                Assigned_Faculty = join(faculty, "; "),
                Status = row.min_faculty <= length(faculty) <= row.max_faculty ? "OK" : "INVALID",
            ))
        end
    end
    return DataFrame(rows)
end


"""Solve one validated teaching-matching scenario without writing result files."""
function solve_matching(; paths = default_matching_paths(), preferred_cost::Float64 = -100.0)
    inputs = read_matching_inputs(paths)
    warnings = validate_matching_inputs(inputs)

    return mktempdir() do directory
        edge_file = joinpath(directory, "teaching-matching.edgelist")
        graph_info = generate_edgelist(
            faculty_df = inputs.faculty,
            fall_courses_df = inputs.fall_courses,
            spring_courses_df = inputs.spring_courses,
            fall_preferences_df = inputs.fall_preferences,
            spring_preferences_df = inputs.spring_preferences,
            assignments_df = inputs.assignments,
            output_edgelist = edge_file,
            preferred_cost = preferred_cost,
        )

        edge_models = MyConstrainedGraphEdgeModels(edge_file, edgerecordparser,
            delim = ',', comment = '#')
        model = build(MyDirectedBipartiteGraphModel, (
            s = graph_info["BOS"], t = graph_info["EOS"], edges = edge_models,
        ))
        bounds = build_capacity_bounds(model)
        cost_vector = build_cost_vector(model)
        A = build_incidence_matrix(model)
        b = build_flow_balance(model, graph_info["F"])
        problem = build(MyLinearProgrammingProblemModel, (
            c = -cost_vector,
            A = A,
            b = b,
            lb = bounds[:, 1],
            ub = bounds[:, 2],
        ))

        solution = try
            solve(problem, constraints = :eq)
        catch error
            throw(MatchingValidationError([
                "The validated configuration still has no feasible matching. Review how fixed assignments and eligible preference edges interact. Solver detail: $(sprint(showerror, error))",
            ]))
        end
        flow = extract_flow(model, solution)
        fall_matching = extract_matching(flow, graph_info["fall_gateway_nodes"],
            graph_info["fall_course_nodes"], inputs.faculty, inputs.fall_courses)
        spring_matching = extract_matching(flow, graph_info["spring_gateway_nodes"],
            graph_info["spring_course_nodes"], inputs.faculty, inputs.spring_courses)
        assignments = build_assignments_dataframe(graph_info, inputs.faculty,
            inputs.fall_courses, inputs.spring_courses, fall_matching, spring_matching)
        staffing = build_course_staffing_dataframe(inputs.fall_courses,
            inputs.spring_courses, fall_matching, spring_matching)

        verification = verify_matching_solution(inputs, graph_info, model, solution,
            fall_matching, spring_matching, assignments, staffing)

        return (
            inputs = inputs,
            paths = paths,
            graph_info = graph_info,
            model = model,
            problem = problem,
            solution = solution,
            flow = flow,
            fall_matching = fall_matching,
            spring_matching = spring_matching,
            assignments = assignments,
            staffing = staffing,
            warnings = warnings,
            verification = verification,
            preferred_cost = preferred_cost,
        )
    end
end


function verify_matching_solution(inputs, graph_info, model, solution,
    fall_matching, spring_matching, assignments, staffing; tolerance = 1e-7)
    errors = String[]
    checks = String[]

    maximum_fraction = maximum(abs(value - round(value)) for value in solution["argmax"])
    maximum_fraction <= tolerance ||
        push!(errors, "Solved flow is not integral within tolerance $tolerance (maximum deviation $maximum_fraction).")
    push!(checks, "All solved flows are integral within tolerance $tolerance.")

    for row in eachrow(inputs.faculty)
        fall_count = length(get(fall_matching, row.name, String[]))
        spring_count = length(get(spring_matching, row.name, String[]))
        fall_count == row.load_fall || push!(errors,
            "$(row.name) received $fall_count Fall assignments but has an exact obligation of $(row.load_fall).")
        spring_count == row.load_spring || push!(errors,
            "$(row.name) received $spring_count Spring assignments but has an exact obligation of $(row.load_spring).")
    end
    push!(checks, "Every faculty member meets the exact Fall and Spring obligations.")

    assignment_set = Set{Tuple{String,String,Symbol}}()
    for (faculty, courses) in fall_matching, course in courses
        push!(assignment_set, (faculty, course, :fall))
    end
    for (faculty, courses) in spring_matching, course in courses
        push!(assignment_set, (faculty, course, :spring))
    end
    for row in eachrow(inputs.assignments)
        if row.kind == "fixed" && !((row.faculty, row.course, Symbol(row.semester)) in assignment_set)
            push!(errors, "Fixed assignment $(row.faculty)/$(row.course)/$(row.semester) is absent from the solution.")
        end
    end
    push!(checks, "Every fixed assignment appears in the solution.")

    for row in eachrow(staffing)
        row.Min_Faculty <= row.Assigned_Count <= row.Max_Faculty || push!(errors,
            "$(uppercasefirst(row.Semester)) $(row.Course) has $(row.Assigned_Count) faculty; required range is $(row.Min_Faculty)-$(row.Max_Faculty).")
    end
    push!(checks, "Every course is within its minimum and maximum staffing bounds.")

    expected_total = Int(graph_info["F"])
    actual_total = sum(assignments.Total_Load)
    actual_total == expected_total || push!(errors,
        "Export contains $actual_total assignments but solved exact load is $expected_total.")
    push!(checks, "Exported assignments agree with the solved total flow ($expected_total).")

    isempty(errors) || throw(MatchingValidationError(errors))
    return checks
end


function _scenario_name(name::String)
    occursin(r"^[A-Za-z0-9][A-Za-z0-9._-]*$", name) ||
        throw(ArgumentError("Scenario names may contain letters, numbers, '.', '_' and '-' only."))
    return name
end


function _input_hashes(paths)
    return Dict(String(key) => bytes2hex(sha256(read(path))) for (key, path) in pairs(paths))
end


function _git_commit(root::String)
    try
        return readchomp(Cmd(`git rev-parse HEAD`; dir = root))
    catch
        return "unavailable"
    end
end


function _git_dirty(root::String)
    try
        return !isempty(readchomp(Cmd(`git status --porcelain`; dir = root)))
    catch
        return nothing
    end
end


function _selected_assignment_counts(result)
    selected = Set{Tuple{String,String,Symbol}}()
    for (faculty, courses) in result.fall_matching, course in courses
        push!(selected, (faculty, course, :fall))
    end
    for (faculty, courses) in result.spring_matching, course in courses
        push!(selected, (faculty, course, :spring))
    end
    fixed = preferred = 0
    for row in eachrow(result.inputs.assignments)
        key = (row.faculty, row.course, Symbol(row.semester))
        if key in selected
            row.kind == "fixed" && (fixed += 1)
            row.kind == "preferred" && (preferred += 1)
        end
    end
    return fixed, preferred
end


function _result_metadata(result; scenario = "latest")
    fixed, preferred = _selected_assignment_counts(result)
    return Dict{String,Any}(
        "scenario" => scenario,
        "created_at" => Dates.format(Dates.now(), dateformat"yyyy-mm-ddTHH:MM:SS"),
        "git_commit" => _git_commit(_ROOT),
        "git_dirty" => _git_dirty(_ROOT),
        "solver_status" => string(result.solution["status"]),
        "objective_value" => result.solution["objective_value"],
        "preferred_cost" => result.preferred_cost,
        "faculty_count" => nrow(result.inputs.faculty),
        "fall_course_count" => nrow(result.inputs.fall_courses),
        "spring_course_count" => nrow(result.inputs.spring_courses),
        "fall_assignments" => sum(result.assignments.Fall_Load),
        "spring_assignments" => sum(result.assignments.Spring_Load),
        "total_assignments" => sum(result.assignments.Total_Load),
        "fixed_assignments_selected" => fixed,
        "preferred_assignments_selected" => preferred,
        "validation_status" => "passed",
        "warning_count" => length(result.warnings),
        "input_hashes" => _input_hashes(result.paths),
    )
end


function _write_validation_report(path::String, result, metadata)
    open(path, "w") do io
        println(io, "# Teaching Matching Validation Report\n")
        println(io, "- Status: **PASSED**")
        println(io, "- Scenario: `$(metadata["scenario"])`")
        println(io, "- Generated: $(metadata["created_at"])")
        println(io, "- Solver status: `$(metadata["solver_status"])`")
        println(io, "- Assignments: $(metadata["fall_assignments"]) Fall + $(metadata["spring_assignments"]) Spring = $(metadata["total_assignments"]) total")
        println(io, "- Fixed assignments selected: $(metadata["fixed_assignments_selected"])\n")
        println(io, "## Verified invariants\n")
        for check in result.verification
            println(io, "- ", check)
        end
        println(io, "\n## Warnings\n")
        if isempty(result.warnings)
            println(io, "None.")
        else
            for warning in result.warnings
                println(io, "- ", warning)
            end
        end
        println(io, "\n## Input hashes\n")
        for (name, hash) in sort(collect(metadata["input_hashes"]), by = first)
            println(io, "- `$name`: `$hash`")
        end
    end
end


"""Save a validated scratch result or an explicitly named scenario."""
function save_matching_result(result; results_root::String = _PATH_TO_RESULTS,
    save_as::Union{Nothing,String} = nothing, replace::Bool = false)
    scenario = isnothing(save_as) ? "latest" : _scenario_name(save_as)
    parent = isnothing(save_as) ? results_root : joinpath(results_root, "scenarios")
    target = joinpath(parent, scenario)
    mkpath(parent)

    if !isnothing(save_as) && ispath(target) && !replace
        throw(ArgumentError("Saved scenario '$scenario' already exists. Use --replace to overwrite it."))
    end

    staging = mktempdir(parent; prefix = ".staging-")
    try
        metadata = _result_metadata(result; scenario = scenario)
        CSV.write(joinpath(staging, "assignments.csv"), result.assignments)
        CSV.write(joinpath(staging, "course-staffing.csv"), result.staffing)
        _write_validation_report(joinpath(staging, "validation-report.md"), result, metadata)
        open(joinpath(staging, "run-metadata.json"), "w") do io
            JSON.print(io, metadata, 2)
            println(io)
        end

        if !isnothing(save_as)
            input_directory = joinpath(staging, "inputs")
            mkpath(input_directory)
            for (name, source) in pairs(result.paths)
                extension = splitext(source)[2]
                cp(source, joinpath(input_directory, "$(name)$(extension)"), force = true)
            end
        end

        _replace_result_directory!(staging, target)
    catch
        ispath(staging) && rm(staging; recursive = true, force = true)
        rethrow()
    end
    return target
end


function _replace_result_directory!(staging::String, target::String)
    backup = target * ".previous"
    ispath(backup) && rm(backup; recursive = true, force = true)
    if ispath(target)
        mv(target, backup)
    end
    try
        mv(staging, target)
        ispath(backup) && rm(backup; recursive = true, force = true)
    catch
        ispath(target) && rm(target; recursive = true, force = true)
        ispath(backup) && mv(backup, target)
        rethrow()
    end
end


"""Compare the current in-memory result with a named saved scenario."""
function compare_matching_result(result, scenario::String;
    results_root::String = _PATH_TO_RESULTS)
    scenario = _scenario_name(scenario)
    directory = joinpath(results_root, "scenarios", scenario)
    assignment_path = joinpath(directory, "assignments.csv")
    staffing_path = joinpath(directory, "course-staffing.csv")
    metadata_path = joinpath(directory, "run-metadata.json")
    isfile(assignment_path) || throw(ArgumentError("Saved scenario '$scenario' was not found."))

    old_assignments = CSV.read(assignment_path, DataFrame)
    old_staffing = CSV.read(staffing_path, DataFrame)
    old_metadata = JSON.parsefile(metadata_path)

    assignment_changes = NamedTuple[]
    old_by_faculty = Dict(row.Faculty => row for row in eachrow(old_assignments))
    new_by_faculty = Dict(row.Faculty => row for row in eachrow(result.assignments))
    for faculty in sort(collect(union(keys(old_by_faculty), keys(new_by_faculty))))
        old = get(old_by_faculty, faculty, nothing)
        new = get(new_by_faculty, faculty, nothing)
        old_fall = isnothing(old) ? "" : _cell_string(old.Fall_Course)
        new_fall = isnothing(new) ? "" : _cell_string(new.Fall_Course)
        old_spring = isnothing(old) ? "" : _cell_string(old.Spring_Course)
        new_spring = isnothing(new) ? "" : _cell_string(new.Spring_Course)
        if old_fall != new_fall || old_spring != new_spring
            push!(assignment_changes, (
                Faculty = faculty,
                Saved_Fall = old_fall,
                Current_Fall = new_fall,
                Saved_Spring = old_spring,
                Current_Spring = new_spring,
            ))
        end
    end

    staffing_changes = NamedTuple[]
    old_by_course = Dict((row.Semester, row.Course) => row for row in eachrow(old_staffing))
    new_by_course = Dict((row.Semester, row.Course) => row for row in eachrow(result.staffing))
    for key in sort(collect(union(keys(old_by_course), keys(new_by_course))))
        old = get(old_by_course, key, nothing)
        new = get(new_by_course, key, nothing)
        old_count = isnothing(old) ? 0 : Int(old.Assigned_Count)
        new_count = isnothing(new) ? 0 : Int(new.Assigned_Count)
        old_faculty = isnothing(old) ? "" : _cell_string(old.Assigned_Faculty)
        new_faculty = isnothing(new) ? "" : _cell_string(new.Assigned_Faculty)
        if old_count != new_count || old_faculty != new_faculty
            push!(staffing_changes, (
                Semester = key[1], Course = key[2],
                Saved_Count = old_count, Current_Count = new_count,
                Saved_Faculty = old_faculty, Current_Faculty = new_faculty,
            ))
        end
    end

    return (
        assignment_changes = DataFrame(assignment_changes),
        staffing_changes = DataFrame(staffing_changes),
        saved_objective = old_metadata["objective_value"],
        current_objective = result.solution["objective_value"],
    )
end


_cell_string(value) = ismissing(value) ? "" : String(value)
