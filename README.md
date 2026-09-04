# Teaching Matching Problem — CBE

This project assigns faculty to Fall and Spring courses with a validated
minimum-cost flow model. Faculty teaching loads are exact obligations. Courses
have explicit minimum and maximum staffing, and administrative decisions are
classified as either fixed or preferred.

## Run the current configuration

Instantiate the Julia environment once after cloning:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Then run:

```bash
julia --project=. run_matching.jl
```

The default run validates, solves, verifies, and replaces `results/latest`.
It never creates timestamped result directories.

Useful what-if commands:

```bash
# Solve and display without writing files
julia --project=. run_matching.jl --no-save

# Preserve a meaningful scenario and its effective inputs
julia --project=. run_matching.jl --save-as baseline

# Replace a previously saved scenario deliberately
julia --project=. run_matching.jl --save-as baseline --replace

# Compare current configuration with a saved scenario
julia --project=. run_matching.jl --compare baseline --no-save
```

## Configuration

### Faculty obligations

Edit `data/config/Faculty.csv`:

```csv
name,load_fall,load_spring
Celik,3,3
```

The loads are exact, not upper bounds. A load of three requires exactly three
assignments in that semester.

### Course staffing

Edit the Fall and Spring course CSVs:

```csv
course,credits,min_faculty,max_faculty,title
CHEME-4320,4,5,5,Chemical Engineering Capstone Design I
CHEME-5650,1,0,3,Design Project
```

- `min_faculty == max_faculty` requires an exact team size.
- `min_faculty > 0` means the course must be staffed.
- `min_faculty == 0` means the course is optional.
- `max_faculty == 0` disables the course.

### Assignment decisions

Edit `data/config/Assignments-AY-2026-2027.csv`:

```csv
faculty,course,semester,kind
Bauer,CHEME-4320,fall,fixed
Celik,CHEME-5650,fall,preferred
```

- `fixed` is a mathematical requirement and must appear in the result.
- `preferred` is a strong but negotiable objective preference.

The validator rejects conflicts such as more fixed assignments than a
faculty member's exact obligation.

### Preference data

Preference values have these meanings:

```text
0 = prepared
1 = comfortable
2 = interested in developing
3 = needs significant support
blank = unknown/no data
```

Unknown matches are not eligible for automatic assignment. A fixed or
preferred administrative decision can explicitly enable an otherwise unknown
faculty-course pair.

## Results

`results/latest` contains:

- `assignments.csv`
- `course-staffing.csv`
- `validation-report.md`
- `run-metadata.json`

Named scenarios under `results/scenarios/` also contain copies of all effective
input files. Metadata records input hashes, Git commit, solver status, counts,
and validation status.

Result files are replaced only after the solve passes post-solve verification.

## Notebook

`FacultyMatching-LP-MinCostMaxFlow-Primal-AY-2026-2027.ipynb` calls the same
`solve_matching()` implementation as the command-line script. It is an
interactive view of the canonical solver rather than a separate formulation.

## Tests

```bash
julia --project=. test/runtests.jl
```

The tests cover the production configuration, preference optimization,
preferred and fixed decisions, multi-faculty minima, scenario persistence, and
actionable validation failures.
