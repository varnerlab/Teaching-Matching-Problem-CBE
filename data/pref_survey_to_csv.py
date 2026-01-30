#!/usr/bin/env python3
"""
Convert the CBE bench-depth survey Excel file into a clean CSV of
faculty course preferences.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import pandas as pd


PREF_MAP = {
    "I am prepared to teach": 0,
    "I would be comfortable teaching": 1,
    "I would be interested in developing this teaching expertise": 2,
    "I would need significant support or lead time to teach": 3,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert CBE bench-depth survey Excel to CSV preferences."
    )
    parser.add_argument(
        "input",
        type=Path,
        help="Path to the Excel file (e.g., data/CBE_Bench_Depth_Survey_12.10.25.xlsx)",
    )
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        default=Path("data/faculty_course_preferences.csv"),
        help="Output CSV path (default: data/faculty_course_preferences.csv)",
    )
    parser.add_argument(
        "--sheet",
        default="Full Bench Survey",
        help="Excel sheet name (default: Full Bench Survey)",
    )
    return parser.parse_args()


def map_pref(val):
    if not isinstance(val, str):
        return pd.NA
    return PREF_MAP.get(val.strip(), pd.NA)


def extract_course_columns(header_row):
    course_info = []
    for idx, label in header_row.items():
        if not isinstance(label, str):
            continue
        if "Ranking" in label or "Comments" in label:
            continue
        if label.strip() == "Faculty Name":
            continue
        match = re.search(r"([A-Z]{4,5})\s*([0-9]{4}|[0-9]xxx)", label)
        if match:
            code = f"{match.group(1)}-{match.group(2)}"
            course_info.append((idx, code))
    return course_info


def keep_best_duplicate(df, lastname, course_cols):
    subset = df[df["lastname"] == lastname]
    if len(subset) <= 1:
        return df
    non_null_counts = subset[course_cols].notna().sum(axis=1)
    keep_idx = non_null_counts.idxmax()
    df = pd.concat(
        [df[df["lastname"] != lastname], df.loc[[keep_idx]]],
        ignore_index=True,
    )
    return df


def main() -> None:
    args = parse_args()
    if not args.input.exists():
        raise FileNotFoundError(f"Input file not found: {args.input}")

    raw = pd.read_excel(args.input, sheet_name=args.sheet, header=None)
    header = raw.iloc[1]
    data = raw.iloc[2:].copy()

    course_info = extract_course_columns(header)
    course_cols = [code for _, code in course_info]

    names = data[0]
    lastnames = names.where(names.notna(), pd.NA)
    lastnames = lastnames.astype(str).str.split(",").str[0].str.strip()
    lastnames = lastnames.str.replace(" ", "-", regex=False)
    mask = lastnames.notna() & (lastnames.str.lower() != "nan") & (
        lastnames.str.strip() != ""
    )

    masked = data.loc[mask]
    out = pd.DataFrame(index=masked.index)
    out["lastname"] = lastnames[mask]

    for idx, code in course_info:
        out[code] = masked[idx].map(map_pref).astype("Int64")

    # Drop duplicate Coso-Strong rows, keep the one with more values.
    out = keep_best_duplicate(out, "Coso-Strong", course_cols)

    # Fill missing values with default 3 for all faculty.
    out[course_cols] = out[course_cols].fillna(3)

    # Add default faculty who did not respond (do not overwrite existing rows).
    default_faculty = ["DeLisa", "Abbott", "Joo", "Putnam", "Yang"]
    existing = set(out["lastname"].astype(str))
    rows = []
    for name in default_faculty:
        if name not in existing:
            row = {"lastname": name}
            row.update({c: 3 for c in course_cols})
            rows.append(row)
    if rows:
        out = pd.concat([out, pd.DataFrame(rows)], ignore_index=True)

    # Ensure integer output.
    for col in course_cols:
        out[col] = out[col].astype(int)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    out.to_csv(args.output, index=False)
    print(f"Wrote {args.output} ({len(out)} rows, {len(out.columns)} columns)")


if __name__ == "__main__":
    main()
