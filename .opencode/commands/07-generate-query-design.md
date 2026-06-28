---
description: >
  Generate meaningful SQL queries for Task 07 Query Design.
  Each query answers a real business question derived from the Campus Space
  Management System requirements. Queries are assigned to specific students
  with role-based perspectives.
---

Command: generate-query-design

Description:
Run the `db-design-pipeline:07-generate-query-design` skill to generate
`outputs/07-query-design-G05.sql` from the approved schema and sample data.
Each student is assigned a role and must produce queries that match their
role's perspective.

Usage:
```bash
# Generate queries for one student (defaults to 5 queries, overwrite mode)
generate-query-design --group G05 \
  --student-name "Nguyen Huu Phuoc" \
  --target-users facility_staff

# Specify number of queries and append mode
generate-query-design --group G05 \
  --student-name "Nguyen Van A" \
  --target-users lecturer \
  --num-queries 4 \
  --mode append

# Multiple students
generate-query-design --group G05 \
  --student-name "Nguyen Van A" --target-users lecturer --num-queries 5 \
  --student-name "Tran Thi B" --target-users facility_staff --num-queries 5

# Explicit overwrite with custom query count
generate-query-design --group G05 \
  --student-name "Le Van C" \
  --target-users facility_manager \
  --num-queries 8 \
  --mode overwrite
```

Arguments:
  --group G05               Group identifier (default: G05)
  --student-name <name>     Assign queries to a specific student.
                            Repeat for each student (e.g., 4 students = 4 flags).
  --target-users <roles>    Comma-separated list of valid user roles from
                            req/business-requirement.md that this student's
                            queries must target. Must be a subset of:
                            student, lecturer, teaching_assistant,
                            facility_staff, department_admin, facility_manager.
  --num-queries <n>         Number of queries to generate per student.
                            Minimum: 1. Maximum: 20. Default: 5.
  --mode <mode>             Write mode: overwrite or append.
                            - overwrite: replace the entire output file
                            - append: add new queries to the end of the
                              existing file, preserving prior queries
                            If omitted, the agent MUST prompt the user:
                            "Output file exists. Append to existing queries
                            or overwrite everything?"

Interaction rule:
  When --student-name is provided but --mode is not specified, and the output
  file `outputs/07-query-design-G05.sql` already exists, the agent MUST stop
  and ask the user:
    "Output file exists. Append new queries for [student name] to the
    existing file, or overwrite the entire file?"
  Only proceed after the user answers. This ensures prior students' work
  is never silently lost.

Input sources:
- outputs/05-db-definition-G05.sql — understand the database definition
- outputs/06-sample-data-G05.sql — understand what data exists
- outputs/01-business-req-analysis-G05.md — business context and BRs
- req/business-requirement.md — derive business questions from real use cases

Output: `outputs/07-query-design-G05.sql`

Requirements:
1. Each student generates at least --num-queries meaningful SQL queries.
2. Every query's Target User(s) must be a subset of the student's
   --target-users argument.
3. Each query must follow the 4-field template with these additional metadata
   annotations in the comment header:
   --student-name: <student name>
   --target-users: <role list>
   --business-question: <which business question this query answers>
4. All queries must be valid T-SQL and executable against `CS486_G05`.
5. Use parameterized DECLARE blocks — no hardcoded literals in logic.
6. Separate each query with GO.
7. Do not modify prior artifacts.

Query distribution (per student):
- Each student's role determines the types of queries they should produce:
  - Lecturer: availability search, schedule view, past bookings
  - Facility Staff: approvals, occupancy, check-in, maintenance, session reports
  - Facility Manager: utilization analytics, no-show analysis, maintenance backlog
  - Department Admin: department summaries, audit trails, inter-dept comparison
  - Student: personal booking history, available rooms, booking submission

Notes:
- Use --group G05 as default.
- Task behavior is defined in the skill.
- When --mode is omitted and file exists, ALWAYS ask before proceeding.
