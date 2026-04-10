---
name: audit-assignments
description: Audit faculty-course assignment coverage for both semesters. Checks required courses have overrides, multi-faculty slots are filled, and faculty capacity is consistent with overrides.
argument-hint: ""
allowed-tools: Read Grep Glob Write
---

# Faculty-Course Assignment Audit

Audit the teaching assignment configuration for coverage issues and inconsistencies. Write findings to `results/issues.md`.

## Data sources

Read all six data files before starting analysis:

1. `data/config/Faculty.csv` -- faculty list with `U_fall` and `U_spring` capacity caps
2. `data/config/Courses-Fall-2026.csv` -- fall courses with `required` flag and `max_faculty`
3. `data/config/Courses-Spring-2027.csv` -- spring courses with `required` flag and `max_faculty`
4. `data/config/Cost-Overrides-AY-2026-2027.csv` -- hard faculty-course-semester assignments (lines starting with `#` are commented out and should be ignored)
5. `data/Faculty-Course-Preferences-Fall-2026.csv` -- fall preference matrix (0=prepared, 1=comfortable, 2=interested, 3=needs support)
6. `data/Faculty-Course-Preferences-Spring-2027.csv` -- spring preference matrix

## Checks to perform

### 1. Required course coverage
For each course where `required=true`:
- Count how many **active** (non-commented) overrides exist for that course+semester (excluding faculty whose semester capacity is 0)
- Compare against `max_faculty` for that course
- If a required course has fewer effective overrides than `max_faculty`, check the preference matrix for **available faculty** (those with remaining capacity after their overrides are accounted for, and with semester capacity > 0) who have a low preference cost (0 or 1) for that course
- Flag as **CRITICAL** only if a required course has 0 effective overrides AND no available faculty with preference cost 0 or 1
- Flag as **INFO** (not critical) if a required course has 0 effective overrides BUT there are available faculty with preference cost 0 or 1 -- list those faculty and their costs so the user can see the LP will likely find a good match
- Flag as **WARNING** if a required course has fewer overrides than `max_faculty` -- list available low-cost faculty who could fill the gap

### 2. Faculty capacity vs override count
For each faculty member:
- Count their active fall overrides and spring overrides separately
- Compare fall override count against `U_fall` and spring override count against `U_spring`
- Flag as **CRITICAL** if override count > capacity (overrides will be unsatisfiable)
- Flag as **CRITICAL** if a faculty has overrides in a semester where their capacity is 0 (gateway blocked)
- Flag as **WARNING** if override count equals capacity exactly (no room for LP to assign additional courses)

### 3. Multi-faculty course staffing
For courses with `max_faculty > 1`:
- Count effective overrides (excluding faculty whose semester capacity is 0)
- Flag as **WARNING** if effective overrides > `max_faculty` (some overrides will be dropped)
- Flag as **WARNING** if effective overrides < `max_faculty` and course is required

### 4. Orphaned overrides
- Flag any override that references a course not found in the corresponding semester's course CSV
- Flag any override that references a faculty member not found in Faculty.csv

## Output format

Write the results to `results/issues.md` using this structure:

```markdown
# Teaching Assignment Audit -- AY 2026-2027

> Generated: {today's date}

## Summary

- Critical issues: {count}
- Warnings: {count}
- Info: {count}
- Courses audited: {fall count} fall + {spring count} spring
- Faculty audited: {count}

## Critical Issues

{numbered list of critical issues with course, semester, and explanation}

## Warnings

{numbered list of warnings with course, semester, and explanation}

## Info

{numbered list of info items -- these are courses without overrides where the LP has good candidates from the preference matrix. List the available faculty and their preference costs.}

## Fall 2026 -- Required Course Coverage

| Course | Title | max_faculty | Assigned Faculty | LP Candidates (cost 0-1) | Status |
|---|---|---|---|---|---|

## Spring 2027 -- Required Course Coverage

| Course | Title | max_faculty | Assigned Faculty | LP Candidates (cost 0-1) | Status |
|---|---|---|---|---|---|

## Faculty Override Load

| Faculty | U_fall | Fall Overrides | U_spring | Spring Overrides | Status |
|---|---|---|---|---|---|
```

## Instructions

- Only count non-commented lines in the overrides CSV (skip lines starting with `#`)
- A faculty member with `U_fall=0` or `U_spring=0` effectively cannot teach that semester -- treat their overrides for that semester as unsatisfiable
- When identifying LP candidates for unfilled slots, a faculty member is "available" if they have semester capacity > 0 AND their override count for that semester is strictly less than their semester capacity (i.e., they have remaining capacity the LP can use)
- Preference scale: 0=prepared (best), 1=comfortable, 2=interested in developing, 3=needs support (worst/default). Only list candidates with cost 0 or 1 as likely LP picks.
- Be precise: name the specific courses and faculty in each issue
- Keep the tone factual and actionable
- After writing the file, print a short summary of findings to the user
