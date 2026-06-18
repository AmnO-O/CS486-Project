# Trajectory: Task 03 Logical Design Update (2026-06-18)

## Trigger
User requested defense-in-depth triggers for BR8/BR9 based on recommendation in the validation report.

## Changes Made

### SKILL.md
- Step 5 expanded: "CHECK constraints **and UNIQUE constraints, and (where appropriate) INSTEAD OF / AFTER triggers**"
- New guardrail added: "Add triggers for status-driven column enforcement"

### outputs/03-logical-design-G05.md

**§7 Constraint Implementation:**
- BR8: `Application` → `Database (trigger)` — enforcement via `trg_bookings_checkin_enforcement`, `trg_bookings_completion_enforcement`
- BR9: `Application` → `Database (trigger)` — same triggers cover initial_condition/final_condition

**§7 Trigger table — 2 triggers added:**

| Trigger | Logic |
|---|---|
| `trg_bookings_checkin_enforcement` | When status → 'checked_in', enforce: actual_start_time, checked_in_by, initial_condition NOT NULL |
| `trg_bookings_completion_enforcement` | When status → 'completed', enforce: actual_end_time, final_condition NOT NULL |

**§8 Deviations — D7 added:**
- Deviation: Triggers added beyond ERD scope
- Justification: Defense-in-depth for BR8/BR9 — nullable columns enforced NOT NULL on status transition

**§9 Revision Log — v1.2 added**

### outputs/04-design-validation-G05.md

**§2 Business Rule Coverage:**
- BR8: `⚠️ Partial / Application` → `✅ Enforced / Database`
- BR9: `⚠️ Partial / Application` → `✅ Enforced / Database`
- Coverage: `14/14 fully enforced at database level`
- Removed BR8/BR9 note about application-layer delegation

**§9 Discrepancy Log:**
- Removed D6 (weak enforcement of BR8/BR9 — resolved by new triggers)

**§10 Recommendations:**
- Removed "Low — Consider triggers..." (now implemented)

**§11 Schema Freeze:**
- Updated: `12 database-level enforced` → `14 database-level enforced`
