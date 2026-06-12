   Command: generate-business-req

Description:
Run the `db-design-pipeline:01-business-req-analysis` skill to generate `outputs/01-business-req-analysis-G05.md` from requirements under `req/`.

Usage:
```
generate-business-req --group G05
# or
generate-business-req req/ --group G05
```

Prompt:
  Generate a complete business requirement analysis for the Campus Space Management System, group G05.

  Input sources:
  - `docs/project-overview.md`
  - all requirement files under `req/*.md`

  Output:
  - A single markdown document suitable for `outputs/01-business-req-analysis-G05.md`

  Include these sections:
  1. Project overview and purpose
  2. Actors / user roles
  3. Core domain objects and managed spaces
  4. Booking request lifecycle
  5. Approval workflow
  6. Maintenance and incident handling
  7. Key business rules and constraints
  8. Assumptions / unresolved ambiguities

  Do not:
  - generate shell commands or wrapper scripts
  - assume the database design is finalized
  - invent unsupported requirements

Notes: 
  - Use `--group G05` as the default group.
  - If a directory is provided, read all requirement files under that directory.
  - This command file defines the invocation interface only; the skill contains the task behavior.
