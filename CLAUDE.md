# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Solves the CBE (Chemical and Biomolecular Engineering) faculty-to-course teaching assignment problem for Cornell using a **minimum-cost maximum-flow** linear programming formulation. The optimization covers a full academic year (Fall 2026 + Spring 2027) in a single LP solve.

## Architecture

The problem is modeled as a **directed graph** with gateway nodes for per-semester control:

```
BOS → Faculty_i → FallGW_i  (cap=U_fall)  → Fall Courses  → Fall Completions  → EOS
                → SpringGW_i (cap=U_spring) → Spring Courses → Spring Completions → EOS
```

Node layout (233 nodes total, all indices computed by `src/BuildGraph.jl`):

| Layer | Count | Purpose |
|---|---|---|
| BOS | 1 | Super-source |
| Faculty | 31 | One per faculty member |
| Fall Gateways | 31 | Enforce fall semester cap per faculty |
| Spring Gateways | 31 | Enforce spring semester cap per faculty |
| Fall Courses | 37 | Fall 2026 course offerings |
| Spring Courses | 32 | Spring 2027 course offerings |
| Fall Completions | 37 | Flow drain per fall course |
| Spring Completions | 32 | Flow drain per spring course |
| EOS | 1 | Super-sink |

BOS→Faculty capacity = yearly total (U_fall + U_spring). Gateway capacities enforce per-semester limits. Setting a gateway cap to 0 blocks teaching for that semester (leave, admin roles).

### Key types (from VLDataScienceMachineLearningPackage)
- `MyDirectedBipartiteGraphModel` — holds the graph structure, edge weights, and capacities
- `MyLinearProgrammingProblemModel` — LP formulation (c, A, b, lb, ub)
- `MyConstrainedGraphEdgeModels` — parses the edgelist file into edge model objects

### File layout
- `FacultyMatching-LP-MinCostMaxFlow-Primal-AY-2026-2027.ipynb` — **main notebook**: two-semester optimization
- `FacultyMatching-LP-MinCostMaxFlow-Primal-Fall-2026.ipynb` — legacy fall-only notebook (kept for reference)
- `Include.jl` — loads all dependencies, sources `src/Updates.jl` and `src/BuildGraph.jl`
- `src/BuildGraph.jl` — `generate_edgelist()`: programmatically generates the edgelist and all node indices from CSV inputs. Returns metadata dict used by the notebook.
- `src/Updates.jl` — helper functions: `update_cost_array!`, `update_capacity_array!`, `update_edge_capacity!`, `extract_matching`
- `data/Faculty.csv` — faculty list with per-semester caps (`U_fall`, `U_spring`)
- `data/Courses-Fall-2026.csv` — fall course list (course, credits, title)
- `data/Courses-Spring-2027.csv` — spring course list (course, credits, title)
- `data/Faculty-Course-Preferences-Fall-2026.csv` — fall preference matrix
- `data/Faculty-Course-Preferences-Spring-2027.csv` — spring preference matrix
- `data/Faculty-Course-Preferences-12-10-25.csv` — master survey data (source for both semester files)
- `data/pref_survey_to_csv.py` — converts Excel bench-depth survey to preferences CSV

## Running

```bash
# Activate Julia environment (from repo root)
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run the notebook
jupyter notebook FacultyMatching-LP-MinCostMaxFlow-Primal-AY-2026-2027.ipynb
```

The notebook calls `generate_edgelist()` which produces `data/Faculty-Courses-Bipartite-AY-2026-2027.edgelist` automatically. No manual edgelist editing needed.

## Preference survey pipeline

Convert a new Excel survey to the preferences CSV:
```bash
python data/pref_survey_to_csv.py data/CBE_Bench_Depth_Survey_12.10.25.xlsx data/Faculty-Course-Preferences-12-10-25.csv
```
Then split into semester-specific files by extracting columns matching each semester's course list. Requires Python 3 with `pandas` and `openpyxl`. See `data/AGENT-PREF-SURVEY-JOB.md` for the full spec.

## Key conventions

- Preference scale: 0=prepared, 1=comfortable, 2=interested in developing, 3=needs support (default for missing data)
- Cost of -1.0 on an edge = strong preferred match (manually set in notebook via `set_override!`)
- Faculty on leave or with admin roles: set U_fall=0 or U_spring=0 in Faculty.csv
- All node indices are computed dynamically by `BuildGraph.jl` — never hardcode node numbers
- Flow value F = sum of all U_fall + U_spring across faculty (computed automatically)
- Results saved as JLD2 with separate `fall_matching` and `spring_matching` dicts
