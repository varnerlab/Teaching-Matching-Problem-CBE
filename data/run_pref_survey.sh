#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input_excel> [output_csv]" >&2
  echo "Example: $0 data/CBE_Bench_Depth_Survey_12.10.25.xlsx data/faculty_course_preferences.csv" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-data/faculty_course_preferences.csv}"

python data/pref_survey_to_csv.py "$INPUT" "$OUTPUT"
