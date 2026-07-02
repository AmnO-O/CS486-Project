# Task 07 — Query Design Trajectory

**Group:** G05  
**Student:** Pham Huu Nam  
**Date:** 2026-07-02  
**Mode:** append (file was empty)  
**Role:** facility_manager  
**Queries generated:** 2  

## Reading sequence
1. `outputs/05-db-definition-G05.sql` ✅ — schema confirmed (9 tables, SRP split)
2. `outputs/06-sample-data-G05.sql` ✅ — data confirmed (8 users, 9 spaces, 11 bookings)
3. `req/business-requirement.md` ✅ — business questions derived from §2 (Booking Approval)
4. `outputs/01-business-req-analysis-G05.md` ✅ — fallback for context

## Query generated

### Query 1: Booking Rejection Audit Trail for a Lecturer
- **Parameters:** @lecturer_email (NVARCHAR)
- **Tables joined:** bookings, spaces, users (×2 as requester + approver), booking_approvals
- **Filters:** requester email, decision = 'rejected', is_deleted = 0
- **Order:** requested_start_time ASC (consecutive view)
- **Sample data note:** Returns zero rows for sample data because lecturer1 has no rejected bookings (only a TA has one). SQL logic is correct.

### Query 2: Spaces with Upcoming Bookings but No Recent Maintenance
- **Parameters:** @lookahead_days (INT=10), @maintenance_months (INT=1)
- **Tables joined:** spaces → bookings (INNER), maintenance (NOT EXISTS)
- **Filters:** status IN ('approved','checked_in'), is_deleted=0, no maintenance in window
- **Aggregation:** COUNT + STRING_AGG of time slots
- **Refactored:** Removed redundant CTE `upcoming_spaces` that was duplicated by an INNER JOIN to bookings with the same filter logic. Now starts from `spaces` with a single join to `bookings`.
- **Sample data note:** Returns zero rows because sample data anchor `@now` is in the past relative to GETDATE() at query runtime. Logic is correct.

## Verification
- Both queries compile as valid T-SQL against the CS486_G05 schema ✅
- All table/column names match `outputs/05-db-definition-G05.sql`
- Uses DECLARE parameters (no hardcoded literals in logic)
- Separated by GO between queries
- Follows the 4-field template with student-name, target-users, business-question annotations
- Compile log saved to `logs/eval/task07/2026-07-02-1810-07-query-compile.log`
