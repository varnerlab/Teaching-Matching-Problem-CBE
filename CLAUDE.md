# Repository Guidance

## Purpose

This repository solves the CBE faculty-to-course teaching assignment problem
for Fall 2026 and Spring 2027 with a validated minimum-cost flow model.

## Canonical implementation

- `src/TeachingMatching.jl`: input validation, solve orchestration, result
  verification, persistence, and scenario comparison.
- `src/BuildGraph.jl`: graph and edge-bound construction.
- `src/Updates.jl`: low-level graph helpers.
- `run_matching.jl`: thin command-line interface and primary user workflow.
- `FacultyMatching-LP-MinCostMaxFlow-Primal-AY-2026-2027.ipynb`: interactive
  view that calls `solve_matching()`; do not duplicate the formulation here.

## Model semantics

- `load_fall` and `load_spring` are exact faculty obligations.
- Courses use explicit `min_faculty` and `max_faculty` bounds.
- `fixed` assignments are enforced with lower and upper flow bounds of one.
- `preferred` assignments are negotiable and represented in the objective.
- Preference values are 0–3; missing means unknown, not 3.
- Unknown edges are unavailable for automatic matching but may be enabled by
  an explicit fixed or preferred decision.

## Commands

```bash
julia --project=. run_matching.jl                 # replace results/latest
julia --project=. run_matching.jl --no-save       # scratch solve
julia --project=. run_matching.jl --save-as NAME  # reproducible scenario
julia --project=. run_matching.jl --compare NAME --no-save
julia --project=. test/runtests.jl
```

## Editing rules

- Keep script and notebook behavior centralized in `solve_matching()`.
- Add user-facing validation whenever a new configuration rule is introduced.
- Never silently coerce missing preference information to a numeric score.
- Never describe an objective bonus as a hard constraint.
- Do not write result artifacts until all post-solve invariants pass.
- Add or update a synthetic test for every formulation change.

## Configuration

- `data/config/Faculty.csv`
- `data/config/Courses-Fall-2026.csv`
- `data/config/Courses-Spring-2027.csv`
- `data/config/Assignments-AY-2026-2027.csv`
- `data/Faculty-Course-Preferences-Fall-2026.csv`
- `data/Faculty-Course-Preferences-Spring-2027.csv`

See `README.md` for field definitions and scenario workflow.
