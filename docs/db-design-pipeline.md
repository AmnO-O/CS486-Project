# DB Design Pipeline — 7-Task Workflow

## Dependency chain
```
01 Business Req → 02 ERD → 03 Logical Design → 04 Validation
                                                      ↓
07 Query Design ← 06 Sample Data ← 05 DDL  ←─────────┘
```

| Task | Input | Output used by |
|---|---|---|
| 01 Business Req | `req/` docs | 02 |
| 02 ERD | 01 output + entity-registry | 03 |
| 03 Logical Design | 02 output | 04, 05 |
| 04 Validation | 02 + 03 outputs | review only |
| 05 DDL | 03 output + schema-registry | 06 |
| 06 Sample Data | 05 output | 07 |
| 07 Query Design | 05 + 06 outputs | final deliverable |

---

## Task 01 — Business Requirement Analysis
**Command**: `/01-generate-business-req`
**Output**: `outputs/01-business-req-analysis-G05.md`
**Template**: `.opencode/skills/db-design-pipeline/templates/01-business-req-analysis/`

### Before generating
- [ ] Read `req/business-requirement.md` fully
- [ ] Read `req/CS486_Project.pdf` section 1 and 2
- [ ] Read `docs/project-overview.md`

### Checklist
- [ ] Business purpose — 1 paragraph explaining why this system exists
- [ ] Actors — all 6 roles with their permissions
- [ ] Entities — list with description (minimum 6 entities)
- [ ] Attributes — per entity, with data type and constraint notes
- [ ] Relationships — list with cardinality and participation
- [ ] Business rules — explicit numbered list (minimum 10 rules)

### After generating
- [ ] Populate `docs/entity-registry.md` with confirmed entities
- [ ] Run `file-evaluation.md`
- [ ] Update `memory/Progress.md` task 01 → ✅ Done
- [ ] Update `memory/ActiveContext.md` → next task is 02

---

## Task 02 — Conceptual ERD Design
**Command**: `/02-generate-erd`
**Output**: `outputs/02-erd-design-G05.md`
**Template**: `.opencode/skills/db-design-pipeline/templates/02-erd-design/`

### Before generating
- [ ] Read `docs/entity-registry.md` (populated from task 01)
- [ ] Read `docs/project-overview.md` — key business rules section

### Checklist
- [ ] All entities from entity-registry are present
- [ ] Every entity has attributes (underline PK, double-ellipse multi-valued, dashed derived)
- [ ] Every relationship has: name, cardinality (1:1 / 1:N / M:N), participation (partial/total)
- [ ] Weak entities identified with double rectangle
- [ ] Multi-valued attributes handled (e.g., facilities of a space)
- [ ] APPROVAL relationship: shows staff decision, 1:1 with BOOKING
- [ ] USAGE_SESSION: shown as separate entity, 1:1 with BOOKING
- [ ] Conflict note: booking overlap constraint documented

### After generating
- [ ] Run `file-evaluation.md`
- [ ] Update `memory/Progress.md` task 02 → ✅ Done
- [ ] Update `memory/ActiveContext.md`

---

## Task 03 — Logical Database Design
**Command**: `/03-generate-logical-design`
**Output**: `outputs/03-logical-design-G05.md`
**Template**: `.opencode/skills/db-design-pipeline/templates/03-logical-design/`

### Before generating
- [ ] Read `outputs/02-erd-design-G05.md`
- [ ] Read `docs/entity-registry.md`

### Checklist
- [ ] Every entity → one relation (document the mapping explicitly)
- [ ] Every M:N relationship → junction table with composite PK
- [ ] Every 1:N relationship → FK on the N side
- [ ] Every 1:1 relationship → FK with UNIQUE constraint
- [ ] Weak entity → composite PK (weak entity PK + owner PK as FK)
- [ ] Multi-valued attributes → separate relation
- [ ] All candidate keys identified beyond PKs
- [ ] All FK constraints listed explicitly

### After generating
- [ ] Populate `docs/schema-registry.md` with final schema
- [ ] Run `file-evaluation.md`
- [ ] Update `memory/Progress.md` task 03 → ✅ Done
- [ ] Update `memory/ActiveContext.md`

---

## Task 04 — Design Validation
**Command**: `/04-generate-design-validation`
**Output**: `outputs/04-design-validation-G05.md`
**Template**: `.opencode/skills/db-design-pipeline/templates/04-design-validation/`

### Before generating
- [ ] Read `outputs/02-erd-design-G05.md`
- [ ] Read `outputs/03-logical-design-G05.md`
- [ ] Read `docs/design-decisions.md`

### Checklist (validate in this order)
- [ ] **ERD completeness**: every business rule from task 01 is modeled
- [ ] **ERD → Schema mapping**: no entity/attribute lost in conversion
- [ ] **Key correctness**: PKs are minimal, FKs reference correct tables
- [ ] **Candidate keys**: all uniqueness constraints identified
- [ ] **Normalization**: check 1NF, 2NF, 3NF — document any violations
- [ ] **Business rule coverage**: list each rule → which constraint enforces it
- [ ] **Gaps**: explicitly state what is NOT enforced at DB level and why

### After generating
- [ ] Run `file-evaluation.md`
- [ ] Update `memory/Progress.md` task 04 → ✅ Done
- [ ] Update `memory/ActiveContext.md`

---

## Task 05 — Database Implementation (DDL)
**Command**: `/05-generate-ddl`
**Output**: `outputs/05-db-definition-G05.sql`
**Template**: `.opencode/skills/db-design-pipeline/templates/05-ddl/`

### Before generating
- [ ] Read `docs/schema-registry.md`
- [ ] Read `docs/tech-stack.md` — naming conventions
- [ ] Read `docs/design-decisions.md`

### Checklist
- [ ] CREATE TABLE in FK dependency order (see schema-registry)
- [ ] Every column has correct type and nullability
- [ ] Every status column has CHECK constraint with all valid values
- [ ] Every FK has ON DELETE / ON UPDATE rule documented
- [ ] UNIQUE constraint on candidate keys (e.g., `email`, `space_code`)
- [ ] DEFAULT values where appropriate (`created_at DEFAULT NOW()`)
- [ ] Comments on complex constraints

### After generating
- [ ] Run `file-evaluation.md`
- [ ] Update `memory/Progress.md` task 05 → ✅ Done
- [ ] Update `memory/ActiveContext.md`

---

## Task 06 — Sample Data
**Command**: `/06-generate-sample-data`
**Output**: `outputs/06-sample-data-G05.sql`
**Template**: `.opencode/skills/db-design-pipeline/templates/06-sample-data/`

### Before generating
- [ ] Read `outputs/05-db-definition-G05.sql` for exact table/column names

### Checklist — coverage requirements
- [ ] All 6 user roles represented (student, lecturer, TA, facility_staff, dept_admin, facility_manager)
- [ ] All space types represented
- [ ] All booking statuses covered (pending, approved, rejected, cancelled, checked_in, completed, no_show)
- [ ] All space statuses covered (available, in_use, under_maintenance, temporarily_closed, retired)
- [ ] Booking → approval chain: at least 3 approved, 2 rejected (with rejection_reason)
- [ ] Check-in/check-out: at least 3 usage_sessions
- [ ] Maintenance: at least 3 records covering different problem types
- [ ] Edge cases: 1 no-show booking, 1 cancelled booking

### Minimums
- 6+ users, 5+ spaces, 10+ bookings, 3+ maintenance records

### After generating
- [ ] Run `file-evaluation.md`
- [ ] Update `memory/Progress.md` task 06 → ✅ Done
- [ ] Update `memory/ActiveContext.md`

---

## Task 07 — Query Design
**Command**: `/07-generate-query-design`
**Output**: `outputs/07-query-design-G05.sql`
**Template**: `.opencode/skills/db-design-pipeline/templates/07-query-design/`

### Before generating
- [ ] Read `outputs/05-db-definition-G05.sql`
- [ ] Read `outputs/06-sample-data-G05.sql`

### Checklist — per query
- [ ] `-- Business question: <question>`
- [ ] `-- Target user: <role(s)>`
- [ ] `-- Why useful: <explanation>`
- [ ] SQL statement with meaningful aliases

### Checklist — coverage (minimum 5 queries)
- [ ] At least 1 query with JOIN (multi-table)
- [ ] At least 1 query with GROUP BY + aggregate (COUNT, SUM, AVG)
- [ ] At least 1 query with subquery or CTE
- [ ] At least 1 query filtering by date/time range
- [ ] At least 1 query useful for facility manager (utilization, no-shows, maintenance)

### After generating
- [ ] Verify each query runs without error against sample data
- [ ] Run `file-evaluation.md`
- [ ] Run `outputs-evaluation.md` — final overall evaluation
- [ ] Update `memory/Progress.md` ALL tasks → ✅ Done
- [ ] Update `memory/ActiveContext.md` → pipeline complete