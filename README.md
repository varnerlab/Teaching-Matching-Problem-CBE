# Teaching Matching Problem — CBE

This repository assigns CBE faculty to Fall and Spring courses using a
validated minimum-cost flow model. It is designed for both routine production
runs and temporary what-if analysis.

The command-line script is the canonical way to run the model:

```bash
julia --project=. run_matching.jl
```

The academic-year notebook calls the same implementation. It is an interactive
view of the model, not a separate calculation.

## Contents

- [Quick start](#quick-start)
- [Command-line reference](#command-line-reference)
- [Common operating workflows](#common-operating-workflows)
- [Canonical input files](#canonical-input-files)
- [How the optimization works](#how-the-optimization-works)
- [Reading terminal output](#reading-terminal-output)
- [Result files](#result-files)
- [Validation and troubleshooting](#validation-and-troubleshooting)
- [Tests](#tests)
- [Academic-year rollover checklist](#academic-year-rollover-checklist)
- [Handoff checklist](#handoff-checklist)

## Model contract

These rules are fundamental:

- Every faculty `load_fall` and `load_spring` value is an **exact**
  obligation, not a maximum.
- Every course has an explicit minimum and maximum number of faculty.
- A `fixed` assignment is mandatory.
- A `preferred` assignment is strongly favored but remains negotiable.
- An ordinary preference score is a cost from `0` to `3`; lower is better.
- A blank preference is unknown and is not eligible for automatic matching.
- Output is written only after pre-solve validation, optimization, and
  post-solve verification all succeed.

The user-facing objective is always the original minimization objective:

```text
matching cost: lower is better
```

The underlying package maximizes the negated cost internally. Its raw
`solver_objective` is retained only in metadata for debugging.

## Quick start

Run all commands from the repository root—the directory containing
`Project.toml` and `run_matching.jl`.

### 1. Install Julia dependencies

The current workflow has been verified with Julia 1.12.7.

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

This needs to be repeated only when setting up a new checkout or when
`Project.toml` changes.

### 2. Verify the checkout

```bash
julia --project=. test/runtests.jl
```

All test groups should pass before using a new checkout for production work.

### 3. Run the current configuration

```bash
julia --project=. run_matching.jl
```

This command:

1. Reads the six canonical input files.
2. Validates their schemas and logical consistency.
3. Builds and solves the matching model.
4. Verifies exact loads, fixed decisions, integrality, and course bounds.
5. Displays the solution and warnings.
6. Replaces `results/latest/` with the verified result.

It does not create timestamped directories.

## Command-line reference

See the built-in help at any time:

```bash
julia --project=. run_matching.jl --help
```

| Option | Meaning |
|---|---|
| no option | Solve and replace `results/latest/`. |
| `--no-save` | Solve, validate, and display without writing result files. |
| `--save-as NAME` | Save a reproducible named scenario under `results/scenarios/NAME/`. This does not update `results/latest/`. |
| `--replace` | Permit `--save-as NAME` to replace an existing scenario. Valid only with `--save-as`. |
| `--compare NAME` | Compare the current in-memory solution with named scenario `NAME`. |
| `-h`, `--help` | Display usage and exit. |

Scenario names may contain letters, numbers, periods, underscores, and
hyphens. They must begin with a letter or number. Examples:
`baseline`, `load-test-1`, and `2026.09-review`.

### Flag interactions

- `--no-save` and `--save-as` cannot be used together.
- `--replace` without `--save-as` is an error.
- `--compare NAME --no-save` compares without writing anything.
- `--compare NAME` compares and then replaces `results/latest/`.
- `--compare BASE --save-as CANDIDATE` compares with `BASE` and saves the
  current configuration as `CANDIDATE`.
- An existing named scenario is never overwritten unless `--replace` is
  supplied explicitly.

Expected configuration or command-line errors exit with status code `2`.
A successful run or help request exits with status code `0`.

## Common operating workflows

### Routine scratch run

```bash
julia --project=. run_matching.jl
```

Use this while editing inputs and checking the latest answer. Each successful
run replaces the previous `results/latest/`; failed runs leave the previous
verified result intact.

### Inspect a change without writing files

```bash
julia --project=. run_matching.jl --no-save
```

This is the safest first run after editing configuration files.

### Save a baseline, test a change, and compare

First save a meaningful baseline:

```bash
julia --project=. run_matching.jl --save-as baseline
```

Then edit the canonical input files and compare the resulting solution without
creating another saved copy:

```bash
julia --project=. run_matching.jl --compare baseline --no-save
```

If the candidate is worth keeping:

```bash
julia --project=. run_matching.jl --compare baseline --save-as candidate-1
```

The comparison reports:

- faculty whose Fall or Spring course lists changed;
- courses whose assigned count or faculty list changed; and
- saved versus current matching cost.

### Replace a named scenario deliberately

```bash
julia --project=. run_matching.jl --save-as baseline --replace
```

Use this only when the old scenario is no longer needed. Named scenarios are
visible to Git and can be committed when they are important records.

## Canonical input files

The script always reads these paths:

| Purpose | Path |
|---|---|
| Faculty obligations | [`data/config/Faculty.csv`](data/config/Faculty.csv) |
| Fall course definitions | [`data/config/Courses-Fall-2026.csv`](data/config/Courses-Fall-2026.csv) |
| Spring course definitions | [`data/config/Courses-Spring-2027.csv`](data/config/Courses-Spring-2027.csv) |
| Administrative assignment decisions | [`data/config/Assignments-AY-2026-2027.csv`](data/config/Assignments-AY-2026-2027.csv) |
| Fall preference matrix | [`data/Faculty-Course-Preferences-Fall-2026.csv`](data/Faculty-Course-Preferences-Fall-2026.csv) |
| Spring preference matrix | [`data/Faculty-Course-Preferences-Spring-2027.csv`](data/Faculty-Course-Preferences-Spring-2027.csv) |

File names elsewhere in `data/` are historical, source-survey, or legacy
artifacts unless explicitly listed above. In particular, the solver does not
read the combined `Faculty-Course-Preferences-12-10-25.csv` file directly.

Names and course codes are trimmed but otherwise case-sensitive. Use exactly
the same spelling in all related files.

### Where to make a typical change

| Intent | File and field |
|---|---|
| Change one person's required Fall or Spring load | Edit `load_fall` or `load_spring` in `Faculty.csv`. |
| Require a course to run | Set an appropriate positive `min_faculty` in that semester's course file. |
| Change a course team size | Edit `min_faculty` and `max_faculty`. |
| Force a specific faculty-course assignment | Add a `fixed` row to the assignments file. |
| Strongly encourage, but do not force, an assignment | Add a `preferred` row to the assignments file. |
| Record ordinary teaching suitability | Enter `0`, `1`, `2`, `3`, or blank in the semester preference matrix. |
| Disable a course | Set both `min_faculty` and `max_faculty` to `0`. |

Do not place `-100` directly in a preference matrix; those files accept only
`0` through `3` or blank. Use a `preferred` decision to request the documented
negative objective cost.

## Faculty obligations

File: `data/config/Faculty.csv`

```csv
name,load_fall,load_spring
Celik,3,3
```

| Column | Requirements |
|---|---|
| `name` | Unique, nonblank faculty identifier. Must match preference and assignment files. |
| `load_fall` | Nonnegative integer; exact number of Fall assignments. |
| `load_spring` | Nonnegative integer; exact number of Spring assignments. |

A load of `3` requires exactly three assignments in that semester. A load of
`0` prohibits assignments in that semester, including fixed assignments.

## Course configuration

Files:

- `data/config/Courses-Fall-2026.csv`
- `data/config/Courses-Spring-2027.csv`

```csv
course,credits,min_faculty,max_faculty,title
CHEME-4320,4,5,5,Chemical Engineering Capstone Design I
CHEME-5650,1,0,3,Design Project
```

| Column | Requirements |
|---|---|
| `course` | Unique, nonblank course code within that semester. |
| `credits` | Nonnegative number used for reporting faculty credit totals. It does not set assignment capacity. |
| `min_faculty` | Nonnegative integer lower staffing bound. |
| `max_faculty` | Nonnegative integer upper staffing bound; must be at least `min_faculty`. |
| `title` | Human-readable course title. |

Common patterns:

| Bounds | Meaning |
|---|---|
| `min=1, max=1` | Exactly one faculty member is required. |
| `min=5, max=5` | Exactly five faculty members are required. |
| `min=0, max=1` | Optional course with at most one faculty member. |
| `min=0, max=3` | Optional course that may have up to three faculty members. |
| `min=0, max=0` | Disabled course; nobody may be assigned. |

Course credits are divided by the number of assigned faculty when the output
computes each person's total credited teaching. Staffing itself is counted in
whole faculty-course assignments, not credit fractions.

## Administrative assignment decisions

File: `data/config/Assignments-AY-2026-2027.csv`

```csv
faculty,course,semester,kind
Bauer,CHEME-4320,fall,fixed
Celik,CHEME-5650,fall,preferred
```

Lines beginning with `#` are comments and may be used to organize this file.

| Column | Allowed values |
|---|---|
| `faculty` | A name from `Faculty.csv`. |
| `course` | A course configured for the specified semester. |
| `semester` | Exactly `fall` or `spring`, lowercase. |
| `kind` | Exactly `fixed` or `preferred`, lowercase. |

### Fixed

A fixed assignment has lower and upper bounds of one. It must appear in every
feasible solution. Fixed assignments do not depend on survey data.

The validator rejects, among other conflicts:

- more fixed assignments than a faculty member's exact semester obligation;
- more fixed faculty than a course's `max_faculty`;
- a fixed assignment to a disabled course; and
- unknown faculty, courses, semesters, or duplicate decisions.

### Preferred

A preferred assignment is eligible even if the survey value is blank and has a
default matching cost of `-100`. This makes it strongly attractive, but it can
still be omitted when exact faculty loads, fixed assignments, or course
capacity prevent it.

Multiple preferred decisions may compete with one another. Use `fixed` only
when the assignment is truly mandatory.

### Worked fixed-versus-preferred example

In the current configuration, Celik has an exact Fall obligation of `3` and
three fixed Fall assignments: CHEME-4320, CHEME-5020, and CHEME-5990.
CHEME-5650 is preferred. The three fixed decisions consume all three required
assignment slots, so CHEME-5650 is correctly omitted.

Changing CHEME-5650 to fixed while leaving the obligation at `3` creates four
fixed assignments and is rejected before optimization. If the correct
obligation were instead changed to `4`, the fourth fixed assignment could be
selected provided CHEME-5650 still had course capacity. This is the intended
difference between an exact load, a hard decision, and a negotiable preference.

## Preference matrices

Files:

- `data/Faculty-Course-Preferences-Fall-2026.csv`
- `data/Faculty-Course-Preferences-Spring-2027.csv`

The first column must be `lastname`. Remaining headers are course codes:

```csv
lastname,CHEME-2880,CHEME-3130,CHEME-3240
Celik,0,1,
```

| Value | Meaning | Automatically eligible? |
|---:|---|---|
| `0` | Prepared to teach | Yes; best ordinary cost |
| `1` | Comfortable teaching | Yes |
| `2` | Interested in developing expertise | Yes |
| `3` | Needs significant support or lead time | Yes; worst ordinary cost |
| blank | Unknown/no survey data | No |

A value of `3` and a blank are deliberately different. A `3` is a known,
eligible assignment with a high cost. A blank creates no automatic assignment
edge. An explicit fixed or preferred decision can enable a blank pair.

Additional preference columns that do not appear in the semester course file
produce warnings and are ignored. Configured courses missing from the
preference matrix also produce warnings; those pairs are unknown unless an
administrative decision enables them.

## Importing a new preference survey

The optional Python converter reads the bench-depth Excel survey:

```bash
python data/pref_survey_to_csv.py \
  data/NEW_SURVEY_FILE.xlsx \
  data/faculty_course_preferences.csv
```

Requirements:

```bash
python -m pip install pandas openpyxl
```

An optional sheet override is available:

```bash
python data/pref_survey_to_csv.py \
  data/NEW_SURVEY_FILE.xlsx \
  data/faculty_course_preferences.csv \
  --sheet "Full Bench Survey"
```

The shell wrapper is equivalent:

```bash
bash data/run_pref_survey.sh \
  data/NEW_SURVEY_FILE.xlsx \
  data/faculty_course_preferences.csv
```

Important: the converter creates one combined CSV. The solver does **not**
automatically read or split that file. Review the converted data, then update
the canonical Fall and Spring preference matrices listed above with the
appropriate course columns. Preserve blank cells; do not replace them with
`3` and do not add synthetic all-`3` rows for nonrespondents.

More converter-specific details are in
[`data/AGENT-PREF-SURVEY-JOB.md`](data/AGENT-PREF-SURVEY-JOB.md).

## How the optimization works

For each semester, the model creates paths:

```text
source -> faculty -> semester gateway -> course -> completion -> sink
```

The flow on a faculty-course edge is either zero or one in the verified
solution.

1. Total source flow equals the sum of all exact faculty obligations.
2. Faculty and semester-gateway capacities enforce each person's exact Fall
   and Spring loads.
3. Course edges enforce `min_faculty <= assigned <= max_faculty`.
4. Fixed assignment edges are constrained to exactly one.
5. Preferred edges receive cost `-100`.
6. Rated ordinary edges receive their survey cost `0` through `3`.
7. Blank ordinary edges have capacity zero.
8. The model minimizes total matching cost.

The package LP solver exposes only maximization, so the implementation passes
the negative of the cost vector at that boundary. If matching cost is `C`,
the raw package objective is `-C`. User-facing output and comparisons always
report `C`, where lower is better.

Matching costs should be compared only when the scenarios use the same cost
rules and broadly comparable obligations. A change in the number of required
assignments or preferred decisions changes the scale of the objective.

### Ties

Different assignments can have exactly the same minimum total cost. In that
case, the solver may return any optimal solution. A result that looks
surprising is not necessarily incorrect—it may be one of several ties.

Use a named baseline and `--compare` to see exactly what moved. If a stable
tie-breaking policy becomes operationally important, it should be added as a
separate documented objective rather than inferred from row order.

## Reading terminal output

A successful run ends with lines similar to:

```text
Validated: 53 Fall + 31 Spring = 84 assignments
Selected decisions: 81 fixed, 0 preferred
Solver status: OPTIMAL | matching cost: 0.0 (lower is better)
```

- `Validated` confirms the exported assignment count.
- `fixed` and `preferred` count only selected rows from the administrative
  decision file.
- `OPTIMAL` means the solver proved the returned result optimal.
- `matching cost` is the original minimization cost.
- Warnings identify usable but incomplete or stale configuration.

Warnings do not invalidate a solution, but they should be reviewed. Errors stop
the run before any result directory is replaced.

## Result files

### Scratch result

A normal run replaces:

```text
results/latest/
```

This directory is intentionally ignored by Git and contains:

| File | Contents |
|---|---|
| `assignments.csv` | One row per faculty with Fall/Spring course lists, exact loads, and allocated credits. |
| `course-staffing.csv` | One row per semester/course with min, max, assigned count, faculty names, and status. |
| `validation-report.md` | Human-readable verification checks, warnings, and input hashes. |
| `run-metadata.json` | Scenario name, time, Git state, hashes, solver status, matching cost, raw solver objective, and counts. |

### Named scenario

`--save-as NAME` writes:

```text
results/scenarios/NAME/
├── assignments.csv
├── course-staffing.csv
├── validation-report.md
├── run-metadata.json
└── inputs/
    ├── assignments.csv
    ├── faculty.csv
    ├── fall_courses.csv
    ├── fall_preferences.csv
    ├── spring_courses.csv
    └── spring_preferences.csv
```

The copied effective inputs make the scenario understandable without guessing
which later configuration produced it. Metadata also records SHA-256 hashes,
the Git commit, and whether the worktree was dirty.

For an official scenario, commit code and configuration first, confirm
`git_dirty: false`, then save the scenario.

Files directly under `results/` that predate this structure are historical
snapshots. See [`results/README.md`](results/README.md).

## Validation and troubleshooting

The validator is intentionally strict. Common messages include:

### “More fixed assignments than exact obligation”

The configuration is contradictory. Change a decision to `preferred`, remove
it, or increase the exact obligation if the obligation itself is wrong.

### “Only N eligible courses”

The faculty member has insufficient rated, fixed, or preferred courses to meet
an exact load. Add real preference information, add an administrative decision,
or correct the obligation.

### “Course requires at least N faculty but only M are eligible”

The course minimum cannot be reached through existing preference and decision
edges. Add eligible faculty or correct the course minimum.

### “Exact faculty load is outside total course staffing capacity”

The semester-wide sum of faculty obligations does not fit between the sum of
course minima and the sum of course maxima.

### “Validated configuration still has no feasible matching”

Individual checks passed, but the combined network is infeasible. This usually
means a group of faculty can reach too few shared courses, or several fixed and
preferred choices compete for the same capacity. Start from a saved baseline,
make one change at a time, and use `--compare ... --no-save`.

### Preferred assignment was not selected

Check whether:

- the faculty member's exact obligation is already filled by fixed decisions;
- the course is at `max_faculty`;
- another preferred decision competes for the same load or capacity; or
- selecting it would prevent a required course minimum elsewhere.

### Matching changed even though total cost did not

The old and new assignments may be equally optimal. See the tie discussion
above.

## Tests

Run:

```bash
julia --project=. test/runtests.jl
```

The suite covers:

- the current production configuration;
- exact faculty obligations;
- preference-cost minimization and objective signs;
- fixed and preferred decisions;
- multi-faculty course minima and maxima;
- named scenario persistence and comparison;
- missing-preference behavior; and
- actionable validation failures.

Tests use temporary directories and do not overwrite production inputs or
`results/latest/`.

## Notebook and programmatic use

`FacultyMatching-LP-MinCostMaxFlow-Primal-AY-2026-2027.ipynb` uses:

```julia
include("Include.jl")
result = solve_matching()
```

The returned `result` contains inputs, graph information, the LP problem,
solver output, Fall and Spring match dictionaries, assignment and staffing data
frames, warnings, verification checks, and `matching_cost`.

The script remains the preferred production interface because it consistently
prints, saves, and compares verified results.

`FacultyMatching-LP-MinCostMaxFlow-Primal-Fall-2026.ipynb` and the checked-in
`*.edgelist` files are legacy analysis artifacts. The canonical academic-year
solver generates its edge list in a temporary directory for each run.

## Repository layout

```text
run_matching.jl             Command-line entry point
Include.jl                  Shared imports and source includes
src/TeachingMatching.jl     Input validation, solve, verification, save/compare
src/BuildGraph.jl           Flow-network construction
src/Updates.jl              Flow extraction helpers
data/config/                Faculty, course, and decision configuration
data/*Preferences*.csv      Preference inputs and historical source data
results/latest/             Replaceable scratch output; ignored by Git
results/scenarios/          Deliberately named reproducible scenarios
test/runtests.jl            Automated regression tests
```

## Academic-year rollover checklist

Before configuring a new academic year:

1. Commit the final prior-year code, configuration, and any official named
   scenarios.
2. Create the new Fall and Spring course files.
3. Create reviewed semester-specific preference matrices.
4. Create the new administrative assignment file with explicit `fixed` and
   `preferred` kinds.
5. Review every faculty member's exact Fall and Spring obligations.
6. Update `default_matching_paths()` in `src/TeachingMatching.jl` to the new
   canonical filenames.
7. Update the academic-year title/docstring in `run_matching.jl` and the
   canonical notebook filename or heading.
8. Update production-count expectations in `test/runtests.jl`.
9. Run the complete test suite.
10. Save and inspect a named baseline before making what-if changes.

## Handoff checklist

A new maintainer should be able to:

1. Clone the repository and instantiate the Julia project.
2. Run the tests successfully.
3. Identify the six canonical input files.
4. Explain exact faculty loads, course bounds, fixed/preferred decisions, and
   blank preferences.
5. Run a scratch solution with `--no-save`;
6. save a named baseline;
7. change one input and compare it with that baseline; and
8. locate assignments, course staffing, validation, metadata, and saved inputs.

If any of those steps are unclear, update this README alongside the code change
that introduced the ambiguity.
