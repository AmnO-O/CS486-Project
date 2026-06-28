# Task 07 — Query 15 Trajectory (Cao Quang Hung)

## Timestamp
2026-06-28 15:30

## Action
Appended Query 15 to `outputs/07-query-design-G05.sql`

## Query 15: Department admin — upcoming approved bookings by department members

### Business Question
What are the upcoming approved bookings made by users in my department for the next two weeks?

### Target User
Department Administrator

### Why Useful
Department Administrators can monitor all approved upcoming bookings made by members of their department — seeing who booked which space, for what purpose, and when. This helps them plan around department events, identify scheduling conflicts, and ensure fair resource allocation within the department.

### SQL Approach
- `@admin_email` parameter to identify the department admin (default: t06.deptadmin1@university.edu)
- `@lookahead_days` parameter set to 14 (next two weeks)
- CTE `admin_dept` resolves the admin's department_id
- Main query joins `bookings` → `spaces` → `users`, filtered by:
  - `department_id` matching the admin's department
  - `is_deleted = 0`
  - `status = 'approved'`
  - `requested_start_time` between GETDATE() and GETDATE() + @lookahead_days
- `days_until_start` computed column for planning
- Ordered by `requested_start_time` ascending

### Seed Data Verification
- Admin: Sarah Williams (t06.deptadmin1@university.edu) → Math department
- Math department users: Sarah Williams (admin1)
- Her approved future bookings: Booking 9 (July 3, admin_event) and Booking 7 (July 10, meeting)
- Both within `@lookahead_days = 14` from today (June 28)
- Expected output: 2 rows

### Design Decisions
- Department scope: the query resolves the admin's own department automatically, so no hardcoded department_id
- Status filter: `approved` only (not checked_in/completed) since the question is about upcoming reservations
- Time horizon: 14 days is a practical planning window for department admins
