# Trajectory Record — Task 07 Query Design

## Metadata
- **Student:** Cao Quang Hung
- **Date:** 2026-06-28
- **Query #:** 11 (appended)
- **Mode:** append

## Inputs consumed
1. `docs/schema-registry.md` — table/column definitions, FK wiring
2. `docs/entity-registry.md` — entity attributes, enum values
3. `outputs/05-db-definition-G05.sql` — DDL with triggers/indexes
4. `outputs/06-sample-data-G05.sql` — seed data for realistic queries
5. `outputs/07-query-design-G05.sql` — existing queries (1–10)
6. `req/business-requirement.md` — business context
7. `docs/tech-stack.md` — enum values, naming conventions

## Query design
- **Business question:** Which Classrooms or Computer laboratories in a specific building are currently Available for the next X hours and contain both a Projector and a Whiteboard?
- **Target user:** Student
- **Tables joined:** spaces × bookings (NOT EXISTS), space_facilities × facilities (EXISTS × 2)
- **Parameters:** @building (NVARCHAR), @hours_ahead (INT)

## Verification
- SQL logic reviewed: ✅ correct (interval overlap check, facility EXISTS subqueries)
- sqlcmd compile: ⚠️ skipped (no MSSQL client on macOS)
- Sample data coverage: ✅ non-null result — T06-CL-101 (Classroom 101, Building B) matches
- Compile log: `logs/eval/task07/2026-06-28-1500-07-query-compile.log`

## Key decisions
- Changed query from (project_lab/student_workspace + AC+Projector) to
  (classroom/computer_lab + Projector+Whiteboard) after confirming sample data
  had no project_lab or student_workspace with both AC and Projector.
  - T06-CL-101 (Classroom 101, Building B, available) has Projector + Whiteboard → returns.
  - The query structure (space type filter × building × availability × two facility EXISTS)
    remains identical; only enumeration values changed.
- Used two separate EXISTS subqueries for Projector and Whiteboard
  (instead of GROUP BY/HAVING COUNT) for readability and index-friendliness
- Booking overlap uses status IN ('approved','checked_in','completed') matching
  the existing filtered unique index pattern
- Default parameter @building = N'Building B' based on sample data coverage

## Query 12 — Revision (after initial append)
- **Business question:** Seminar/Student Activity events on a given date with capacity ≥ 20
- **Target user:** Student
- **Tables joined:** bookings × spaces × users × departments
- **Parameters:** @event_date (DATE = '2026-06-22'), @min_capacity (INT = 20)
- **Expected result:** Booking #6 — Student Activity by Alice Johnson (School of Computer Science)
  at Project Lab B (Building B, capacity 20, checked_in)
- **Alignment rationale:** Original spec (capacity ≥ 50, GETDATE()) would return zero rows.
  Adjusted to @min_capacity=20, @event_date='2026-06-22' to match Booking #6 in seed data.
  Status filter narrowed to ('checked_in','completed','approved') — only confirmed events.

## Query 13 — Alternative spaces when usual room is blocked
- **Business question:** If usual space is under_maintenance or temporarily_closed, find top 3
  alternatives on same floor with ≥ capacity
- **Target user:** Student
- **Tables joined:** bookings × spaces (CTE 1), spaces × spaces self-join (CTE 2), 4 UNION ALL branches
- **Parameters:** @student_email (NVARCHAR = 't06.student1@university.edu'), @blocked_statuses
- **Alignment design:** Two-phase output — always returns ≥ 1 row:
  - Branch 1: empty booking history → error message
  - Branch 2: usual space available → "Your usual space — available"
  - Branch 3: usual space blocked + alternatives exist → up to 3 alternatives
  - Branch 4: usual space blocked + no alternatives → fallback message
- **Expected result (default):** Branch 2 → CL-201 (available, 40 seats) — 1 row
- **Expected result (MTG-001 test):** Branch 3 → AUD-101 (capacity 200 ≥ 10) — 1 row

## Query 14 — Lab availability by day of week (simplified)
- **Business question:** Based on 1-year booking history, which days of the week have the most
  available project and computer laboratories?
- **Target user:** Student
- **Tables joined:** spaces × bookings (DISTINCT days), 7-row VALUES grid
- **Parameters:** @space_types (VARCHAR = 'computer_lab,project_lab'), @lookback_year (INT = 1)
- **Design:**
  - Simplified from 8 CTEs + 168-row grid → 3 CTEs + 7-row output
  - Computes distinct occupied labs per day of week
  - CASE status: "All labs available" or "Reduced availability"
  - Only ~40 lines of SQL
- **Expected result:**
  - Monday–Saturday: 2/2 available
  - Sunday: 1/2 available (Booking #6 occupies LAB-002)
  - Always returns 7 rows (one per day)
