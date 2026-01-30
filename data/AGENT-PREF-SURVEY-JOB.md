AGENT-PREF-SURVEY-JOB
======================

Purpose
-------
Turn the CBE bench-depth survey Excel file into a clean CSV of faculty course
preferences, with coded values and consistent column names.

Inputs
------
- Excel file in `data/` (example: `data/CBE_Bench_Depth_Survey_12.10.25.xlsx`)
- Sheet name: `Full Bench Survey`
- The sheet uses:
  - Row 1 (0-based row index = 1) for the course headers
  - Column 0 for faculty name in `Lastname, Firstname` format
  - Course columns contain preference text
  - “Ranking” and “Comments?” columns must be ignored

Output
------
- CSV file saved to `data/faculty_course_preferences.csv`
- Columns:
  - `lastname`
  - One column per course, named `PREFIX-NUMBER` (example: `ENGRI-1120`)
- Rows:
  - One row per faculty
  - All missing preference cells filled with default value `3`

How to Run
----------
Dependencies: Python 3 + `pandas` (and `openpyxl` for `.xlsx` files).

Run:
```
python data/pref_survey_to_csv.py data/NEW_SURVEY_FILE.xlsx data/faculty_course_preferences.csv
```

Optional sheet override:
```
python data/pref_survey_to_csv.py data/NEW_SURVEY_FILE.xlsx data/faculty_course_preferences.csv --sheet "Full Bench Survey"
```

Shell wrapper (optional):
```
bash data/run_pref_survey.sh data/NEW_SURVEY_FILE.xlsx data/faculty_course_preferences.csv
```

Preference Coding
-----------------
Map the survey responses to numeric codes:
- I am prepared to teach = 0
- I would be comfortable teaching = 1
- I would be interested in developing this teaching expertise = 2
- I would need significant support or lead time to teach = 3

Course Column Parsing
---------------------
From each course header cell, extract the course code by regex:
`([A-Z]{4,5})\s*([0-9]{4}|[0-9]xxx)`

Example:
`ENGRI 1120 Introduction to Chemical Engineering` -> `ENGRI-1120`

Do not include any column whose header contains:
- `Ranking`
- `Comments`

Faculty Name Parsing
--------------------
From `Lastname, Firstname`, keep only the last name (left of the comma),
trim whitespace, and replace any spaces in the last name with `-`.

Duplicate Handling (Coso-Strong)
--------------------------------
If there are duplicate last names (specifically `Coso-Strong` in the current file),
keep the row with the most non-empty course values and drop the other(s).

Defaults and Missing Data
-------------------------
1) Fill missing preference values for all faculty with `3`.
2) Ensure these faculty exist even if they did not respond:
   - DeLisa
   - Abbott
   - Joo
   - Putnam
   - Yang (already exists in the current file; do NOT overwrite if present)
   Any missing from the file should be added with `3` for all courses.

Suggested Implementation (Python / pandas)
-----------------------------------------
1) Read the sheet with `header=None`.
2) Use row index 1 as the header row.
3) Identify course columns by regex, skipping Ranking/Comments/Faculty Name.
4) Build a DataFrame with:
   - `lastname` from column 0
   - course columns mapped via the preference coding
5) Keep only non-empty last names.
6) Resolve `Coso-Strong` duplicate by most non-null course values.
7) Fill missing values with `3`.
8) Add default rows for missing faculty.
9) Rename course columns to `PREFIX-NUMBER` (replace space with `-`).
10) Save to `data/faculty_course_preferences.csv`.

Validation Checklist
--------------------
- CSV exists at `data/faculty_course_preferences.csv`
- Column headers use `PREFIX-NUMBER`
- All preference values are integers 0–3
- No missing values remain
- Default faculty rows exist for DeLisa, Abbott, Joo, Putnam
- Yang’s existing row is preserved if present
