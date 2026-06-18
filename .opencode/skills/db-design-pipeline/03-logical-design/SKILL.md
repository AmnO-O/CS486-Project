# Skill: db-design-pipeline:03-logical-design

## Title
Logical Design from ERD and Entity Registry

## Purpose
Produce the logical schema design prompt and expected behavior for Task 03, generating `outputs/03-logical-design-G05.md` from `docs/entity-registry.md`, `outputs/02-erd-design-G05.md`, and `outputs/01-business-req-analysis-G05.md`.

## Inputs
- docs/entity-registry.md (required)
- outputs/02-erd-design-G05.md (required for reference)
- outputs/01-business-req-analysis-G05.md (required for business rules)
- --group (optional, default: G05)

## Outputs
- outputs/03-logical-design-G{{group}}.md
- docs/schema-registry.md (updated with table and column definitions)
- docs/entity-registry.md (updated with finalized names/types/constraints)

## Behavior / Steps

1. Read `docs/entity-registry.md`, `outputs/02-erd-design-G05.md`, and `outputs/01-business-req-analysis-G05.md`.
2. For each entity in the entity registry, map it to a logical table.
3. For each attribute in the entity registry, define a column with:
   - Name (apply naming conventions)
   - Data type (SQL Server compatible: INT, NVARCHAR, DATETIME2, DECIMAL, BIT, etc.)
   - Nullable/NOT NULL based on entity requirements
   - Default values where appropriate
   - Unique constraints for candidate keys
4. For each relationship in the entity registry:
   - Map to a foreign key constraint in the child table
   - Use appropriate referential integrity rules (ON DELETE CASCADE, ON DELETE SET NULL, etc.)
   - If M:N, create a junction/associative table with composite PK
5. Implement business rule constraints as CHECK constraints, UNIQUE constraints, and (where appropriate) INSTEAD OF / AFTER triggers for cross-row, cross-table, or status-transition validation.
6. Define indexes on:
   - Primary keys
   - Foreign keys
   - High-cardinality search columns (e.g., email, booking dates)
7. Prove normalization to at least 3NF:
   - 1NF: All values are atomic; no repeating groups
   - 2NF: No partial dependencies on composite keys
   - 3NF: No transitive dependencies; all non-key attributes depend solely on the PK
8. Document naming conventions applied (e.g., plural table names, snake_case columns, FK_Source_Target format).
9. Record constraint implementation details (how business rules are enforced).
10. Note any deviations from the ERD with justification.
11. Format the result as a final markdown deliverable and update the schema registry.

## Cognitive Rules / Guidelines

- **Role**: Act as a logical database design engineer and SQL schema architect.
- **Input sources only**: `docs/entity-registry.md`, `outputs/02-erd-design-G05.md`, `outputs/01-business-req-analysis-G05.md`.
- **Output intent**: Produce a detailed, reviewer-ready logical design that bridges the ERD and SQL DDL.
- **Do NOT embed hardcoded templates** — templates/responses are provided by the runtime when needed.

### Design Priorities (in order)
1. Preserve all entities from the ERD as tables
2. Preserve all relationships as FKs or junction tables
3. Implement explicit business rules as CHECK/UNIQUE constraints
4. Choose SQL Server-compatible data types
5. Optimize for 3NF normalization
6. Define supporting indexes

### Formatting Expectations
- Well-labelled Markdown sections for each table
- Column definitions in structured tables (name, type, nullable, constraints)
- Relationship mapping matrix showing ERD → logical design
- Normalization proofs with 1NF/2NF/3NF rationale
- Constraint commentary explaining business rule mapping
- Naming convention documentation

### Guardrails and Prohibitions
- Do **not** invent entities, columns, or relationships not in the entity registry.
- Do **not** output runtime instructions or shell commands.
- Do **not** make assumptions about statuses, enums, or constraint values beyond what the business requirement and entity registry explicitly state.
- Do **not** modify prior artifacts (outputs/01 or 02); only read them.
- Do **not** use SQL Server 2008 or deprecated features without compatibility notes.
- Do **not** create tables without explicit justification (especially junction tables).
- **Add triggers for status-driven column enforcement**: For columns that are nullable at table level but must be NOT NULL when a status column transitions to a specific value (e.g., `actual_start_time` must be set when `status = 'checked_in'`), define AFTER UPDATE triggers. This provides defense-in-depth beyond application-level enforcement.

### Interoperability
- The runtime may provide a template for table definitions if a specific visual format is required.
- The skill must update `docs/schema-registry.md` with the finalized table and column metadata.
- The skill must add finalization markers to `docs/entity-registry.md` for names/types that have been locked.

## Validation Checks (post-generation)

- Verify all entities from the entity registry are represented as tables.
- Verify all relationships are mapped (as FKs or junction tables).
- Verify column data types are SQL Server-compatible.
- Verify business rules are implemented as constraints (CHECK, UNIQUE, FK).
- Verify normalization proof is present and justified.
- Verify naming conventions are documented and applied consistently.
- Verify no forbidden writes have occurred (outputs/01 or 02).

## Idempotency
- Overwrite `outputs/03-logical-design-G{{group}}.md` if it exists.
- Update (not overwrite) `docs/schema-registry.md` and `docs/entity-registry.md` with finalized metadata.

## Notes
- The skill should be prompt-focused and not include runtime shell behavior.
- Emphasis on traceability: each table/column should be traceable back to the entity registry and business rules.
- SQL Server compatibility is required; document any deviations from standard ANSI SQL.
- The logical design is the bridge between conceptual (ERD) and physical (DDL); precision here reduces downstream issues in Tasks 04–07.
