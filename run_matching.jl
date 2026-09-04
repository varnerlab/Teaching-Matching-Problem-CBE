"""
Solve and validate the AY 2026-2027 teaching match.

Usage:
    julia --project=. run_matching.jl
    julia --project=. run_matching.jl --no-save
    julia --project=. run_matching.jl --save-as NAME [--replace]
    julia --project=. run_matching.jl --compare NAME [--no-save]
"""

include(joinpath(@__DIR__, "Include.jl"))


function usage(io::IO = stdout)
    println(io, """
Usage: julia --project=. run_matching.jl [options]

Options:
  --no-save          Solve and validate without writing result files.
  --save-as NAME     Save a reproducible named scenario under results/scenarios/NAME.
  --replace          Allow --save-as to replace an existing scenario of the same name.
  --compare NAME     Compare the current solve with a saved scenario.
  -h, --help         Show this help.

Without --no-save or --save-as, the validated result replaces results/latest.
""")
end


function parse_cli(args)
    no_save = false
    save_as = nothing
    replace = false
    compare = nothing
    help = false
    index = 1

    while index <= length(args)
        argument = args[index]
        if argument == "--no-save"
            no_save = true
        elseif argument == "--replace"
            replace = true
        elseif argument in ("-h", "--help")
            help = true
        elseif argument in ("--save-as", "--compare")
            index == length(args) && throw(ArgumentError("$argument requires a name."))
            value = args[index + 1]
            startswith(value, "-") && throw(ArgumentError("$argument requires a name."))
            argument == "--save-as" ? (save_as = value) : (compare = value)
            index += 1
        else
            throw(ArgumentError("Unknown option '$argument'. Use --help for usage."))
        end
        index += 1
    end

    no_save && !isnothing(save_as) &&
        throw(ArgumentError("--no-save and --save-as cannot be used together."))
    replace && isnothing(save_as) &&
        throw(ArgumentError("--replace is only valid with --save-as."))

    return (; no_save, save_as, replace, compare, help)
end


function print_result(result)
    println("\nTeaching assignments — AY 2026-2027")
    pretty_table(
        result.assignments[:, [
            :Faculty, :Fall_Course, :Spring_Course,
            :Fall_Load, :Fall_Obligation, :Spring_Load, :Spring_Obligation,
            :Total_Credits,
        ]];
        backend = :text,
        table_format = TextTableFormat(borders = text_table_borders__compact),
        alignment = [:l, :l, :l, :c, :c, :c, :c, :c],
        fit_table_in_display_horizontally = false,
        fit_table_in_display_vertically = false,
    )

    fall_assignments = sum(result.assignments.Fall_Load)
    spring_assignments = sum(result.assignments.Spring_Load)
    fixed, preferred = _selected_assignment_counts(result)
    println("\nValidated: $fall_assignments Fall + $spring_assignments Spring = $(fall_assignments + spring_assignments) assignments")
    println("Selected decisions: $fixed fixed, $preferred preferred")
    println("Solver status: $(result.solution["status"]) | objective: $(result.solution["objective_value"])")

    if !isempty(result.warnings)
        println("\nConfiguration warnings:")
        for warning in result.warnings
            println("  - ", warning)
        end
    end
end


function print_comparison(comparison, scenario::String)
    println("\nComparison with saved scenario '$scenario'")
    println("Objective: $(comparison.saved_objective) -> $(comparison.current_objective)")

    if nrow(comparison.assignment_changes) == 0
        println("No faculty assignment changes.")
    else
        println("\nFaculty assignment changes:")
        pretty_table(comparison.assignment_changes;
            backend = :text, fit_table_in_display_horizontally = false)
    end

    if nrow(comparison.staffing_changes) == 0
        println("No course staffing changes.")
    else
        println("\nCourse staffing changes:")
        pretty_table(comparison.staffing_changes;
            backend = :text, fit_table_in_display_horizontally = false)
    end
end


function main(args = ARGS)
    try
        options = parse_cli(args)
        if options.help
            usage()
            return 0
        end

        println("Reading and validating configuration...")
        result = solve_matching()
        print_result(result)

        if !isnothing(options.compare)
            comparison = compare_matching_result(result, options.compare)
            print_comparison(comparison, options.compare)
        end

        if options.no_save
            println("\nNo files written (--no-save).")
        else
            output = save_matching_result(result;
                save_as = options.save_as, replace = options.replace)
            println("\nValidated results written to: $output")
        end
        return 0
    catch error
        if error isa MatchingValidationError || error isa ArgumentError
            showerror(stderr, error)
            println(stderr)
            return 2
        end
        rethrow()
    end
end


if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
