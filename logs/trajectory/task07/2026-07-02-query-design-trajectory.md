# Task 07 — Query Design Trajectory

**Group:** G05  
**Student:** Pham Huu Nam  
**Date:** 2026-07-02  
**Mode:** append (file was empty)  
**Role:** facility_manager  
**Queries generated:** 1  

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

## Verification
- Query compiles valid T-SQL against the CS486_G05 schema
- All table/column names match `outputs/05-db-definition-G05.sql`
- Uses DECLARE parameters (no hardcoded literals in logic)
- Separated by GO at end
- Follows the 4-field template with student-name, target-users, business-question annotations
