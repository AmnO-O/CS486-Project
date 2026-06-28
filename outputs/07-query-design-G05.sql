-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 07: Query Design
-- Target: SQL Server 2019+ (T-SQL)
-- Schema: dbo (CS486_G05 database)
-- Dependencies: outputs/05-db-definition-G05.sql, outputs/06-sample-data-G05.sql
-- ============================================================

-- ============================================================
-- Query 1: Pending approvals for today
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: What bookings are waiting for my
--    approval today?
-- ============================================================
-- Business question:
--   Which pending booking requests fall within today or the
--   next 24 hours and need immediate attention?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Facility staff need to review and approve/reject bookings
--   in a timely manner. This query shows the most urgent
--   requests first so that no requester is left waiting.
-- ============================================================

DECLARE @staff_id INT = 5;

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name   AS requester,
    u.email       AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.created_at  AS submitted_at
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
WHERE b.status = 'pending'
  AND b.is_deleted = 0
  AND b.requested_start_time <= DATEADD(DAY, 1, GETDATE())
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 2: Real-time occupancy snapshot
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: Which spaces are currently occupied and
--    by whom?
-- ============================================================
-- Business question:
--   What is happening right now — which spaces are checked in
--   or approved, who booked them, and when do they end?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Provides a live dashboard for facility staff to monitor
--   current occupancy, plan walkthroughs, and respond to
--   issues or emergencies in real time.
-- ============================================================

DECLARE @now DATETIME2 = GETDATE();

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    u.full_name   AS requester,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    b.actual_start_time
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
WHERE b.is_deleted = 0
  AND b.status IN ('approved', 'checked_in')
  AND b.requested_start_time <= @now
  AND b.requested_end_time > @now
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 3: Active maintenance tickets
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: What maintenance issues are open or
--    in progress across all spaces?
-- ============================================================
-- Business question:
--   Which spaces are affected by unresolved maintenance,
--   what is the problem, who is assigned, and how long has
--   it been open?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Gives a single view of all active maintenance across
--   campus so staff can prioritize repairs and track
--   assignment progress.
-- ============================================================

SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    m.problem_description,
    m.status,
    m.start_time,
    u_reporter.full_name      AS reporter,
    u_assigned.full_name      AS assigned_staff,
    DATEDIFF(DAY, m.start_time, GETDATE()) AS days_open
FROM [dbo].[maintenances] m
INNER JOIN [dbo].[spaces] s ON m.space_id = s.space_id
INNER JOIN [dbo].[users] u_reporter ON m.reporter_id = u_reporter.user_id
LEFT JOIN [dbo].[users] u_assigned ON m.assigned_staff_id = u_assigned.user_id
WHERE m.is_deleted = 0
  AND m.status IN ('open', 'in_progress')
ORDER BY m.status, m.start_time;
GO

-- ============================================================
-- Query 4: Eligible check-in bookings
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: Which approved bookings have passed
--    their start time but have not checked in yet?
-- ============================================================
-- Business question:
--   Which approved bookings have a start time in the past
--   but no actual check-in recorded yet?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Enables staff to proactively identify no-shows or
--   perform check-in for late arrivals, reducing idle
--   space time and improving utilization.
-- ============================================================

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name   AS requester,
    u.email       AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
WHERE b.status = 'approved'
  AND b.is_deleted = 0
  AND b.requested_start_time <= GETDATE()
  AND b.actual_start_time IS NULL
ORDER BY b.requested_start_time;
GO

-- ============================================================
-- Query 5: Session completion report for today
-- --student-name: Nguyen Huu Phuoc
-- --target-users: facility_staff
-- --business-question: What sessions ended today and what
--    was the final condition of each space?
-- ============================================================
-- Business question:
--   Which sessions were completed today, what were the actual
--   end times, and what final condition was noted for each
--   space?
--
-- Target user(s):
--   Facility Staff
--
-- Why useful:
--   Enables staff to review end-of-day space conditions,
--   flag damage or cleaning needs, and verify all sessions
--   were properly closed out before the next day.
-- ============================================================

DECLARE @report_date DATE = '2026-07-01';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    u.full_name           AS requester,
    b.actual_start_time,
    b.actual_end_time,
    b.initial_condition,
    b.final_condition,
    b.usage_notes,
    u_staff.full_name     AS checked_in_by_staff
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.space_id = s.space_id
INNER JOIN [dbo].[users] u ON b.requester_id = u.user_id
LEFT JOIN [dbo].[users] u_staff ON b.checked_in_by = u_staff.user_id
WHERE b.status = 'completed'
  AND b.is_deleted = 0
  AND CAST(b.actual_end_time AS DATE) = @report_date
ORDER BY b.actual_end_time;
GO
