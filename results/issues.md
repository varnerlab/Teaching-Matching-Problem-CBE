# Teaching Assignment Audit -- AY 2026-2027

> Generated: 2026-04-10

## Summary

- Critical issues: 4
- Warnings: 3
- Info: 1
- Courses audited: 37 fall + 33 spring
- Faculty audited: 31

## Critical Issues

1. **Tester has U_fall=0 but 2 fall overrides** -- Tester is assigned CHEME-4840 and CHEME-4880 in fall, but has zero fall capacity. The fall gateway blocks all flow; these overrides are unsatisfiable.

2. **Varner has U_fall=2 but 3 fall overrides** -- Varner is assigned CHEME-4800, CHEME-5660, and CHEME-5650 in fall, but only has capacity for 2. One override will be dropped by the LP.

3. **Bauer has U_spring=0 but 4 spring overrides** -- Bauer is assigned CHEME-4620, CHEME-5240, CHEME-5650, and CHEME-5651 in spring, but has zero spring capacity. The spring gateway blocks all flow; none of these overrides can be fulfilled.

4. **CHEME-5240 (Process Safety, spring) is required but effectively uncovered** -- The only override is Bauer, who has U_spring=0. No other faculty member is assigned. The LP will fill from preferences, but all faculty have cost=3 (default) for this course.

## Warnings

1. **CHEME-4320 (ChemE Lab, fall) needs 4 faculty, only 3 assigned** -- Bauer, Escobedo, Li are overridden. The 4th slot will be filled by the LP from preferences. If a specific person is intended, add an override.

2. **CHEME-4620 (ChemE Design, spring) has 5 effective overrides for 4 slots** -- After excluding Bauer (U_spring=0), Kowal, Escobedo, Coso-Strong, DeLisa, and Alabi remain (5 faculty). One override will be unsatisfiable. Decide which 4 should teach.

3. **CHEME-5650 (Design Project, spring) has 2 effective overrides for 3 slots** -- After excluding Bauer (U_spring=0), only Celik and Varner remain (2 of 3 slots). The 3rd slot will be filled by the LP.

## Info

1. **CHEME-6240 (Adv Fluid Mech & Heat Transfer, spring) -- no override, but LP has good candidates** -- No explicit override, but Koch has preference cost 0 and available spring capacity. The LP will likely assign Koch. Other available candidates at cost 1: Hormozi (1).

## Fall 2026 -- Required Course Coverage

| Course | Title | max_faculty | Assigned Faculty | Status |
|---|---|---|---|---|
| ENGRI-1120 | Feast! | 2 | Godwin, DeLisa | 2/2 OK |
| ENGRD-2190 | Process Design & Analysis | 1 | Kowal | 1/1 OK |
| CHEME-2880 | Biomolecular Engineering | 1 | DeLisa | 1/1 OK |
| CHEME-3130 | ChemE Thermodynamics | 1 | Yu | 1/1 OK |
| CHEME-3240 | Heat and Mass Transfer | 1 | Goldfarb | 1/1 OK |
| CHEME-4320 | ChemE Laboratory | 4 | Bauer, Escobedo, Li | 3/4 WARNING |
| CHEME-6110 | Math Methods | 1 | Escobedo | 1/1 OK |
| CHEME-6130 | Advanced Thermo | 1 | Yue | 1/1 OK |
| CHEME-6230 | Transport Phenomena | 1 | Stroock | 1/1 OK |

## Spring 2027 -- Required Course Coverage

| Course | Title | max_faculty | Assigned Faculty | Status |
|---|---|---|---|---|
| CHEME-2200 | Physical Chemistry II | 1 | Stroock | 1/1 OK |
| CHEME-3230 | Fluid Mechanics | 1 | Hormozi | 1/1 OK |
| CHEME-3320 | Separation Processes | 1 | Yue | 1/1 OK |
| CHEME-3720 | Process Dynamics & Control | 1 | Coso-Strong | 1/1 OK |
| CHEME-3900 | Kinetics & Reactor Design | 1 | Cardenas | 1/1 OK |
| CHEME-4620 | ChemE Design | 4 | Kowal, Escobedo, Coso-Strong, DeLisa, Alabi | 5/4 WARNING |
| CHEME-5240 | Process Safety Management | 1 | Bauer (BLOCKED) | 0/1 CRITICAL |
| CHEME-6240 | Adv Fluid Mech & Heat Transfer | 1 | (none -- LP: Koch at cost 0) | 0/1 INFO |
| CHEME-6420 | Chemical Kinetics & Transport | 1 | Engstrom | 1/1 OK |

## Faculty Override Load

| Faculty | U_fall | Fall Overrides | U_spring | Spring Overrides | Status |
|---|---|---|---|---|---|
| Bauer | 4 | 4 (4320, 5020, 5650, 5651) | 0 | 4 (4620, 5240, 5650, 5651) | CRITICAL: spring blocked |
| Celik | 2 | 1 (5020) | 3 | 2 (5460, 5650) | OK |
| Cleary | 1 | 1 (5770) | 0 | 0 | OK |
| Coso-Strong | 1 | 0 | 2 | 2 (3720, 4620) | OK |
| Cardenas | 0 | 0 | 1 | 1 (3900) | OK |
| Daniel | 0 | 0 | 1 | 1 (3010) | OK |
| DeLisa | 2 | 2 (ENGRI-1120, 2880) | 2 | 2 (4620, 5430) | OK |
| Engstrom | 1 | 1 (4840) | 1 | 1 (6420) | OK |
| Escobedo | 2 | 2 (4320, 6110) | 2 | 2 (4620, 5540) | OK |
| Godwin | 1 | 1 (ENGRI-1120) | 1 | 1 (6940) | OK |
| Goldfarb | 1 | 1 (3240) | 1 | 1 (4xxx) | OK |
| Hanrath | 3 | 3 (6660, 6662, 6681) | 0 | 0 | OK |
| Hormozi | 0 | 0 | 1 | 1 (3230) | OK |
| Kalra | 1 | 1 (5310) | 0 | 0 | OK |
| Koch | 1 | 1 (6440) | 1 | 0 | OK |
| Kowal | 3 | 2 (ENGRD-2190, 6920) | 2 | 1 (4620) | OK |
| Li | 1 | 1 (4320) | 1 | 0 | OK |
| Putnam | 1 | 1 (6310) | 0 | 0 | OK |
| Stroock | 1 | 1 (6230) | 1 | 1 (2200) | OK |
| Tester | 0 | 2 (4840, 4880) | 0 | 0 | CRITICAL: fall blocked |
| Varner | 2 | 3 (4800, 5660, 5650) | 2 | 1 (5650) | CRITICAL: fall overloaded |
| Alabi | 0 | 0 | 2 | 2 (4620, 6430) | OK |
| Yang | 1 | 0 | 1 | 0 | OK |
| You | 4 | 4 (6800, 6810, 6830, 6840) | 2 | 2 (6810, 6888) | OK |
| Yu | 1 | 1 (3130) | 0 | 0 | OK |
| Yue | 1 | 1 (6130) | 1 | 1 (3320) | OK |
| Abbott | 0 | 0 | 0 | 0 | OK |
| Archer | 0 | 0 | 0 | 0 | OK |
| Duncan | 0 | 0 | 0 | 0 | OK |
| Harimoto | 0 | 0 | 0 | 0 | OK |
| Joo | 0 | 0 | 0 | 0 | OK |
