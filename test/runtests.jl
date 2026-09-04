using Test

include(joinpath(@__DIR__, "..", "Include.jl"))


function write_test_inputs(directory;
    faculty,
    fall_courses,
    spring_courses = "course,credits,min_faculty,max_faculty,title\nSPRING-OFF,0,0,0,Disabled\n",
    fall_preferences,
    spring_preferences = "lastname,SPRING-OFF\n",
    assignments = "faculty,course,semester,kind\n",
)
    files = (
        faculty = "faculty.csv",
        fall_courses = "fall-courses.csv",
        spring_courses = "spring-courses.csv",
        fall_preferences = "fall-preferences.csv",
        spring_preferences = "spring-preferences.csv",
        assignments = "assignments.csv",
    )
    contents = (; faculty, fall_courses, spring_courses, fall_preferences,
        spring_preferences, assignments)
    for key in keys(files)
        write(joinpath(directory, files[key]), contents[key])
    end
    return NamedTuple{keys(files)}(Tuple(joinpath(directory, files[key]) for key in keys(files)))
end


@testset "Production configuration" begin
    result = solve_matching()
    @test nrow(result.assignments) == 34
    @test sum(result.assignments.Fall_Load) == 53
    @test sum(result.assignments.Spring_Load) == 31
    @test sum(result.assignments.Total_Load) == 84
    @test all(result.assignments.Fall_Load .== result.assignments.Fall_Obligation)
    @test all(result.assignments.Spring_Load .== result.assignments.Spring_Obligation)
    @test all(result.staffing.Status .== "OK")
    @test _selected_assignment_counts(result) == (81, 0)
    @test !("CHEME-5650" in result.fall_matching["Celik"])
end


@testset "Preference optimization" begin
    mktempdir() do directory
        paths = write_test_inputs(directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\nBob,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,1,1,X\nY,3,1,1,Y\n",
            fall_preferences = "lastname,X,Y\nAlice,0,2\nBob,2,0\n",
        )
        result = solve_matching(paths = paths)
        @test result.fall_matching["Alice"] == ["X"]
        @test result.fall_matching["Bob"] == ["Y"]
    end
end


@testset "Preferred remains negotiable" begin
    mktempdir() do directory
        paths = write_test_inputs(directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,0,1,X\nY,3,0,1,Y\n",
            fall_preferences = "lastname,X,Y\nAlice,0,0\n",
            assignments = "faculty,course,semester,kind\nAlice,Y,fall,preferred\n",
        )
        result = solve_matching(paths = paths)
        @test result.fall_matching["Alice"] == ["Y"]
        @test _selected_assignment_counts(result) == (0, 1)
    end
end


@testset "Multi-faculty course minimum" begin
    mktempdir() do directory
        paths = write_test_inputs(directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\nBob,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,2,2,X\n",
            fall_preferences = "lastname,X\nAlice,0\nBob,0\n",
        )
        result = solve_matching(paths = paths)
        row = only(eachrow(result.staffing[result.staffing.Course .== "X", :]))
        @test row.Assigned_Count == 2
        @test row.Min_Faculty == 2
        @test row.Max_Faculty == 2
    end
end


@testset "Named scenario save and comparison" begin
    mktempdir() do directory
        input_directory = joinpath(directory, "inputs")
        mkdir(input_directory)
        paths = write_test_inputs(input_directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,1,1,X\n",
            fall_preferences = "lastname,X\nAlice,0\n",
        )
        result = solve_matching(paths = paths)
        results_directory = joinpath(directory, "results")
        target = save_matching_result(result;
            results_root = results_directory, save_as = "baseline")

        @test isfile(joinpath(target, "assignments.csv"))
        @test isfile(joinpath(target, "course-staffing.csv"))
        @test isfile(joinpath(target, "validation-report.md"))
        @test isfile(joinpath(target, "run-metadata.json"))
        @test isdir(joinpath(target, "inputs"))
        @test_throws ArgumentError save_matching_result(result;
            results_root = results_directory, save_as = "baseline")

        comparison = compare_matching_result(result, "baseline";
            results_root = results_directory)
        @test nrow(comparison.assignment_changes) == 0
        @test nrow(comparison.staffing_changes) == 0
        @test save_matching_result(result; results_root = results_directory,
            save_as = "baseline", replace = true) == target
    end
end


@testset "Actionable validation failures" begin
    mktempdir() do directory
        paths = write_test_inputs(directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,0,1,X\nY,3,0,1,Y\n",
            fall_preferences = "lastname,X,Y\n",
            assignments = "faculty,course,semester,kind\nAlice,X,fall,fixed\nAlice,Y,fall,fixed\n",
        )
        @test_throws MatchingValidationError validate_matching_inputs(read_matching_inputs(paths))
    end

    mktempdir() do directory
        paths = write_test_inputs(directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,2,1,X\n",
            fall_preferences = "lastname,X\nAlice,0\n",
        )
        @test_throws MatchingValidationError validate_matching_inputs(read_matching_inputs(paths))
    end

    mktempdir() do directory
        paths = write_test_inputs(directory,
            faculty = "name,load_fall,load_spring\nAlice,1,0\n",
            fall_courses = "course,credits,min_faculty,max_faculty,title\nX,3,0,1,X\n",
            fall_preferences = "lastname,X\n",
        )
        @test_throws MatchingValidationError validate_matching_inputs(read_matching_inputs(paths))
    end
end
