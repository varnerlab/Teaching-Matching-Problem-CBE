# Teaching Matching Repair Plan

Status: the seven approved repairs below were implemented on 2026-09-04. The separate end-to-end preference-data pipeline remains a follow-up design topic.

## Context

The current minimum-cost flow mechanics are generally sound, but configuration semantics, silent fallbacks, duplicated notebook logic, and stale result artifacts make the system difficult to use without expert knowledge.

The original production configuration contained one concrete conflict: Celik had an exact Fall obligation of 3 but four override rows (`CHEME-4320`, `CHEME-5020`, `CHEME-5650`, and `CHEME-5990`). The migration classifies `Celik -> CHEME-5650` as `preferred`; the other three are `fixed`. This preserves the prior selected result while making the negotiable decision explicit.

## Agreed repairs

### 1. Separate fixed assignments from preferences

Replace ambiguous cost overrides with two explicit assignment kinds:

- `fixed`: the assignment must occur. Implement the faculty-to-course edge with `lb = 1` and `ub = 1`.
- `preferred`: the assignment is desirable but negotiable. Represent it through an objective cost or bonus.

An illustrative schema is:

```csv
faculty,course,semester,kind
Celik,CHEME-4320,fall,fixed
Celik,CHEME-5020,fall,fixed
Celik,CHEME-5650,fall,preferred
Celik,CHEME-5990,fall,fixed
```

Preflight validation must reject fixed assignments that exceed a faculty obligation or a course maximum. It must also reject unknown faculty, courses, semesters, duplicate rows, disabled courses, and other invalid references.

The current assignment data is classified as `fixed` or `preferred`. All prior overrides are fixed except `Celik -> CHEME-5650`, which is preferred because Celik's three other Fall assignments consume the exact obligation.

### 2. Keep faculty obligations exact

The current faculty loads are exact teaching obligations, not upper bounds. Preserve that behavior.

Rename or clearly document `U_fall` and `U_spring` so users understand that every nonzero unit must be assigned. Candidate names include `load_fall` and `load_spring`, or `required_load_fall` and `required_load_spring`.

Validation and result reports must state each faculty member's exact obligation and assigned load explicitly.

### 3. Specify both minimum and maximum course staffing

Replace the ambiguous combination of `required` and `max_faculty` with explicit numeric bounds:

```csv
course,credits,min_faculty,max_faculty,title
CHEME-4320,4,5,5,...
CHEME-4620,4,6,6,...
CHEME-5650,1,0,3,...
```

Interpretation:

- `min_faculty == max_faculty`: exact team size.
- `min_faculty > 0`: the course must run with at least that many faculty.
- `min_faculty == 0`: optional course.
- `max_faculty == 0`: disabled course.

Remove the stored `required` field because it is derivable as `min_faculty > 0` and could otherwise contradict the numeric bounds.

Validate that both values are nonnegative integers and `min_faculty <= max_faculty`. Fixed assignments may not exceed the maximum, and enough eligible faculty must remain to satisfy the minimum.

### 4. Use one implementation for scripts and notebooks

The script is the primary user interface and should remain canonical. Move reusable orchestration into a shared source file, for example `src/TeachingMatching.jl`, with an API such as:

```julia
result = solve_matching(
    faculty_csv = ...,
    fall_courses_csv = ...,
    spring_courses_csv = ...,
    preferences = ...,
    assignments = ...,
)
```

Make `run_matching.jl` a thin command-line entry point. Update the notebook to call the same function. Remove duplicated LP construction and manual notebook overrides so the two interfaces cannot silently solve different problems.

The returned result should expose assignments, flow, objective value, validation results, and effective source data for notebook exploration and exports.

### 5. Add pre-solve validation, post-solve verification, and tests

Pre-solve validation should provide actionable domain-language errors for:

- Missing columns and invalid data types.
- Duplicate faculty or course identifiers.
- Unknown assignment references or invalid semesters.
- Invalid preference values.
- Invalid course staffing bounds.
- Fixed assignments exceeding faculty obligations or course maxima.
- Faculty obligations incompatible with course staffing capacity.
- Missing or insufficient preference information.

For example:

> Celik has 4 fixed Fall assignments but an exact Fall obligation of 3. Change one assignment to `preferred`, remove it, or increase the obligation.

Post-solve verification should confirm:

- Every faculty member receives the exact semester obligation.
- Every fixed assignment appears.
- Every course is within its minimum and maximum staffing.
- A faculty member is assigned at most once to a course.
- All assignment flows are integral within a numerical tolerance.
- Exported assignment counts agree with the solved flow.

Add small synthetic automated tests covering a basic feasible match, competing preferences, fixed assignments, conflicting fixed assignments, multi-instructor courses, infeasible total loads, and malformed configuration. Also validate the production configuration in the test suite.

### 6. Distinguish missing preference data from score 3

Use these semantics:

```text
0 = prepared
1 = comfortable
2 = interested in developing
3 = needs significant support
blank = unknown/no data
```

Do not silently convert missing rows, missing columns, or blank cells to 3.

By default, exclude unknown edges from automatic matching. A `fixed` assignment may still use an unknown edge because the administrative decision confirms that assignment. Provide an explicit configuration option if unknown automatic matches ever need to be permitted.

Validation should explain the consequence of missing data, for example:

> Murtagh has no preference survey data, but both Fall obligations are covered by fixed assignments.

or:

> Faculty X has an exact obligation of 2, only 1 fixed assignment, and no eligible preference data for another assignment.

### 7. Support scratch what-if runs and explicitly saved scenarios

Do not create timestamped output folders automatically.

Default scratch run:

```bash
julia --project=. run_matching.jl
```

This overwrites one `results/latest/` directory containing the current assignments, validation report, and metadata.

No-write exploratory run:

```bash
julia --project=. run_matching.jl --no-save
```

Explicitly save an important scenario:

```bash
julia --project=. run_matching.jl --save-as celik-5650
```

This creates `results/scenarios/celik-5650/` containing assignments, validation, metadata, and the effective configuration needed to reproduce the solve. Reusing a scenario name should require `--replace`.

Support scenario comparison where practical:

```bash
julia --project=. run_matching.jl --compare celik-5650
```

The comparison should summarize changed faculty assignments, course staffing, objective values, and validation differences.

Each saved result set should record:

- Run timestamp and optional scenario label.
- Git commit when available.
- Hashes of all effective input files.
- Solver status and objective value.
- Faculty and course counts.
- Fall and Spring assignment totals.
- Validation outcome.

Only replace saved result files after solving and post-solve validation succeed. Failed exploratory runs must not destroy the previous valid output.

## Original audit facts preserved in tests

- Current configuration: 34 faculty, 42 Fall courses, and 38 Spring courses.
- Exact obligations: 53 Fall assignments and 31 Spring assignments, for 84 total.
- The legacy root assignment file contained 33 faculty and 80 assignments; the canonical `results/latest` output now contains 34 faculty and 84 assignments.
- The legacy root audit report describes an older configuration; canonical validation is now generated with each successful result.
- There are 82 assignment-decision rows: 81 fixed and one preferred. The current solution selects all 81 fixed decisions and does not select the conflicting preferred Celik decision.
- Multi-faculty course requirements are now enforced through `min_faculty` and `max_faculty`.
- Synthetic nonrespondent preference rows were removed, and missing preference edges are unavailable for automatic assignment.
- The two-semester notebook now calls the same `solve_matching()` implementation as the script.

## Next discussion

Design a reproducible preference-data pipeline. The supplied survey workbook, committed master preference CSV, semester-specific files, manual course additions, and duplicate Coso-Strong responses do not currently have a single documented transformation path.

Likely topics:

- Whether the workbook or a cleaned master table is the authoritative source.
- How to represent intentional manual preference additions and corrections.
- How to generate semester-specific preferences from course configuration.
- How duplicate survey responses should be resolved or flagged.
- How to preserve provenance without making ordinary what-if work cumbersome.

## Implementation status

Implemented:

- Fixed and preferred assignment semantics.
- Explicit exact faculty-load names.
- Explicit course minimum and maximum staffing.
- Shared script/notebook solver implementation.
- Pre-solve validation, post-solve verification, and synthetic/production tests.
- Blank/unknown preference semantics and removal of synthetic nonrespondent rows.
- Scratch, no-save, named-scenario, replacement, and comparison workflows.

Verified production result: 34 faculty, 53 Fall assignments, 31 Spring assignments, 84 total assignments, 81 fixed decisions selected, all exact obligations met, and all course staffing bounds satisfied.
