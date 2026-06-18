# Trajectory: Task 04 Re-validation (2026-06-18)

## Trigger
User requested evaluate lại Task 04 after Task 02 conceptual revision.

## Analysis
Task 02 revision changed:
1. **Attribute counts** — audit columns (`created_at`, `updated_at`) and `is_deleted` removed from ERD entity blocks
2. **Data types** — SQL Server types (`NVARCHAR`, `DATETIME2`, `BIT`) replaced with conceptual types (`string`, `datetime`, `boolean`)

## Changes Applied

### §1.2 Attribute Coverage
- Old: All 7 tables showed ✅ perfect match (ERD count = logical count)
- New: 6 of 7 tables show ⚠️ with explanation:
  - departments: 2/4, users: 7/9, spaces: 10/12, facilities: 2/4, bookings: 18/21, maintenance: 9/12
  - space_facilities: 3/3 ✅ (no audit columns)
- Added note explaining the intentional delta per conceptual ERD convention

### §1.3 Data Type Consistency
- Old: `INT → INT`, `NVARCHAR → NVARCHAR(n)`, etc. (SQL→SQL)
- New: `int → INT`, `string → NVARCHAR(n)/VARCHAR(50)`, `datetime → DATETIME2`, `boolean → BIT` (conceptual→SQL)

### §13 Validation Checklist
- Updated item wording to clarify "conceptual attributes" with intentional delta note

## Structural Impact
**None.** The schema itself is unchanged. All findings (D1–D6), recommendations, and the freeze recommendation remain identical.
