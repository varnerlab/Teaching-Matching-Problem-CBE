# Matching results

`results/latest/` is the current scratch result. A normal run replaces it, so it
does not accumulate timestamped copies and is intentionally ignored by Git.

Named scenarios created with `--save-as NAME` are stored under
`results/scenarios/NAME/`. Each scenario contains its effective input files,
assignments, course staffing, validation report, and run metadata. Named
scenarios are visible to Git so an important case can be committed deliberately.

The CSV and Markdown files directly in this directory predate the scenario
workflow. Treat them as historical snapshots, not as the current result. The
authoritative output of the latest run is under `results/latest/`.
