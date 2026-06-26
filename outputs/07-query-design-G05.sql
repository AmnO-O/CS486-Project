-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 07: Query Design
-- Target: SQL Server 2019+ (T-SQL)
-- ============================================================

-- ============================================================
-- Query 1: Upcoming Approved Bookings
-- ============================================================
-- Business question:
--   What approved or checked-in bookings are coming up in the
--   next lookahead period, and what space do they occupy?
--
-- Target user(s):
--   Facility Staff, Facility Manager, Department Administrator
--
-- Why useful:
--   Enables staff to prepare rooms in advance, identify
--   scheduling conflicts early, and plan facility readiness.
-- ============================================================

DECLARE @from_date DATETIME2 = '2026-07-01 00:00:00';
DECLARE @to_date   DATETIME2 = '2026-07-31 23:59:59';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    u.full_name                          AS requester_name,
    u.email                              AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.status
FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s
        ON b.space_id = s.space_id
    INNER JOIN [dbo].[users] u
        ON b.requester_id = u.user_id
WHERE b.requested_start_time >= @from_date
  AND b.requested_start_time <= @to_date
  AND b.is_deleted = 0
  AND b.status IN ('approved', 'checked_in')
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 2: Booking History for a Space
-- ============================================================
-- Business question:
--   What is the complete booking history (past sessions) for a
--   given space, including who used it and who approved it?
--
-- Target user(s):
--   Facility Staff, Department Administrator, Facility Manager
--
-- Why useful:
--   Provides an audit trail of past usage for reporting on
--   space utilization, identifying frequent requesters, and
--   reviewing approval decisions.
-- ============================================================

DECLARE @space_code NVARCHAR(50) = N'T06-CL-201';

SELECT
    b.booking_id,
    u.full_name                          AS requester_name,
    u.email                              AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.status,
    b.actual_start_time,
    b.actual_end_time,
    a.full_name                          AS approver_name,
    b.decision_note
FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s
        ON b.space_id = s.space_id
    INNER JOIN [dbo].[users] u
        ON b.requester_id = u.user_id
    LEFT JOIN [dbo].[users] a
        ON b.approver_id = a.user_id
WHERE s.space_code = @space_code
  AND b.requested_end_time < GETDATE()
  AND b.is_deleted = 0
ORDER BY b.requested_start_time DESC;
GO

-- ============================================================
-- Query 3: Active Maintenance Tickets
-- ============================================================
-- Business question:
--   Which spaces currently have unresolved maintenance issues,
--   what is the problem, and who is assigned to resolve it?
--
-- Target user(s):
--   Facility Staff, Facility Manager
--
-- Why useful:
--   Provides a real-time view of all open and in-progress
--   maintenance tickets so staff can prioritise repairs and
--   identify spaces that cannot be booked.
-- ============================================================

DECLARE @status VARCHAR(50) = 'open';

SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    u.full_name                          AS reporter_name,
    st.full_name                         AS assigned_staff_name,
    m.problem_description,
    m.start_time,
    m.status
FROM [dbo].[maintenances] m
    INNER JOIN [dbo].[spaces] s
        ON m.space_id = s.space_id
    INNER JOIN [dbo].[users] u
        ON m.reporter_id = u.user_id
    LEFT JOIN [dbo].[users] st
        ON m.assigned_staff_id = st.user_id
WHERE m.status = @status
  AND m.is_deleted = 0
ORDER BY m.start_time;
GO

-- ============================================================
-- Query 4: No-Show Bookings
-- ============================================================
-- Business question:
--   Which bookings in a given date range resulted in no-shows
--   (requester did not check in)?
--
-- Target user(s):
--   Facility Staff, Facility Manager
--
-- Why useful:
--   Tracks wasted space allocations due to no-shows, enabling
--   staff to follow up with frequent no-show users and adjust
--   overbooking policies.
-- ============================================================

DECLARE @start_date DATETIME2 = '2026-06-01 00:00:00';
DECLARE @end_date   DATETIME2 = '2026-06-30 23:59:59';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name                          AS requester_name,
    u.email                              AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants
FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s
        ON b.space_id = s.space_id
    INNER JOIN [dbo].[users] u
        ON b.requester_id = u.user_id
WHERE b.status = 'no_show'
  AND b.is_deleted = 0
  AND b.requested_start_time >= @start_date
  AND b.requested_end_time <= @end_date
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 5: Available Space Finder
-- ============================================================
-- Business question:
--   Which spaces are available during a given time slot, have
--   sufficient capacity for the expected participants, and are
--   not blocked by unresolved maintenance?
--
-- Target user(s):
--   Lecturer, Teaching Assistant, Student, Facility Staff
--
-- Why useful:
--   Helps requesters quickly identify suitable rooms without
--   manually checking overlapping bookings or maintenance
--   schedules, streamlining the booking process.
-- ============================================================

DECLARE @slot_start    DATETIME2 = '2026-07-15 10:00:00';
DECLARE @slot_end      DATETIME2 = '2026-07-15 12:00:00';
DECLARE @min_capacity  INT       = 20;

SELECT
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.usage_policy
FROM [dbo].[spaces] s
WHERE s.current_status = 'available'
  AND s.capacity >= @min_capacity
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[bookings] b
      WHERE b.space_id = s.space_id
        AND b.status IN ('approved', 'checked_in')
        AND b.is_deleted = 0
        AND @slot_start < b.requested_end_time
        AND @slot_end > b.requested_start_time
  )
  AND NOT EXISTS (
      SELECT 1
      FROM [dbo].[maintenances] m
      WHERE m.space_id = s.space_id
        AND m.status IN ('open', 'in_progress')
        AND m.is_deleted = 0
        AND @slot_start < COALESCE(m.completion_time, '9999-12-31')
        AND @slot_end > m.start_time
  )
ORDER BY s.capacity, s.space_code;
GO

-- ============================================================
-- Query 6: Space Utilization Report
-- ============================================================
-- Business question:
--   How many completed bookings and total usage hours did each
--   space accumulate in a given period, broken down by space
--   type?
--
-- Target user(s):
--   Facility Manager, Department Administrator
--
-- Why useful:
--   Enables data-driven decisions about space allocation,
--   identifies under-utilised rooms that could be repurposed,
--   and supports capacity planning reports.
-- ============================================================

DECLARE @report_start DATETIME2 = '2026-06-01 00:00:00';
DECLARE @report_end   DATETIME2 = '2026-06-30 23:59:59';

SELECT
    s.space_type,
    s.space_code,
    s.space_name,
    s.capacity,
    COUNT(b.booking_id)                                        AS total_completed_bookings,
    COALESCE(SUM(DATEDIFF(MINUTE, b.actual_start_time, b.actual_end_time) / 60.0), 0)
                                                               AS total_hours_used,
    AVG(b.expected_participants * 1.0)                         AS avg_expected_participants
FROM [dbo].[spaces] s
    LEFT JOIN [dbo].[bookings] b
        ON s.space_id = b.space_id
        AND b.status = 'completed'
        AND b.is_deleted = 0
        AND b.actual_start_time >= @report_start
        AND b.actual_end_time <= @report_end
GROUP BY s.space_type, s.space_code, s.space_name, s.capacity
ORDER BY s.space_type, total_completed_bookings DESC;
GO

-- ============================================================
-- Query 7: Rejection Audit Trail
-- ============================================================
-- Business question:
--   Which booking requests were rejected in a given period,
--   by whom, and for what reason?
--
-- Target user(s):
--   Facility Manager, Department Administrator
--
-- Why useful:
--   Ensures accountability in the approval workflow by
--   providing a transparent audit trail of all rejection
--   decisions, helping managers identify patterns of
--   unfair or inconsistent rejections.
-- ============================================================

DECLARE @audit_start DATETIME2 = '2026-06-01 00:00:00';
DECLARE @audit_end   DATETIME2 = '2026-06-30 23:59:59';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    req.full_name                        AS requester_name,
    req.email                            AS requester_email,
    rej.full_name                        AS rejected_by,
    b.decision_time                      AS rejection_time,
    b.rejection_reason,
    b.decision_note,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time
FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s
        ON b.space_id = s.space_id
    INNER JOIN [dbo].[users] req
        ON b.requester_id = req.user_id
    INNER JOIN [dbo].[users] rej
        ON b.approver_id = rej.user_id
WHERE b.status = 'rejected'
  AND b.is_deleted = 0
  AND b.decision_time >= @audit_start
  AND b.decision_time <= @audit_end
ORDER BY b.decision_time DESC;
GO
