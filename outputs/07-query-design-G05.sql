-- ============================================================
-- Query 1: Pending Bookings Awaiting My Approval Today
-- ============================================================
-- student-name: Nguyen Huu Phuoc
-- target-users: facility_staff
-- business-question:
--   What bookings are waiting for my approval today?
--
-- Why useful:
--   Provides facility staff with a consolidated queue of all
--   pending booking requests that have not yet been processed.
--   This enables efficient, timely review and decision-making
--   on approval or rejection without hunting through emails
--   or spreadsheets.
-- ============================================================

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.space_type,
    requester.full_name          AS requester_name,
    requester.email              AS requester_email,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    DATEDIFF(MINUTE, b.requested_start_time, b.requested_end_time) AS duration_minutes,
    s.capacity
FROM bookings b
INNER JOIN spaces s
    ON s.space_id = b.space_id
INNER JOIN users requester
    ON requester.user_id = b.requester_id
WHERE b.status = 'pending'
  AND b.is_deleted = 0
  AND NOT EXISTS (
      SELECT 1
      FROM booking_approvals ba
      WHERE ba.booking_id = b.booking_id
  )
ORDER BY b.requested_start_time ASC, b.created_at ASC;
GO

-- ============================================================
-- Query 2: Currently Occupied Spaces and Their Occupants
-- ============================================================
-- student-name: Nguyen Huu Phuoc
-- target-users: facility_staff
-- business-question:
--   Which spaces are currently occupied and by whom?
--
-- Why useful:
--   Enables facility staff to quickly see which spaces are in use,
--   who is occupying them, and since when. Useful for responding
--   to inquiries, coordinating maintenance, and managing walk-in
--   requests.
-- ============================================================

DECLARE @now DATETIME2 = GETDATE();

SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.space_type,
    requester.full_name          AS occupant_name,
    requester.email              AS occupant_email,
    b.purpose,
    b.requested_start_time,
    b.requested_end_time,
    bs.actual_start_time,
    DATEDIFF(MINUTE, bs.actual_start_time, @now) AS minutes_elapsed
FROM bookings b
INNER JOIN spaces s
    ON s.space_id = b.space_id
INNER JOIN users requester
    ON requester.user_id = b.requester_id
INNER JOIN booking_sessions bs
    ON bs.booking_id = b.booking_id
    AND bs.actual_end_time IS NULL
WHERE b.status = 'checked_in'
  AND b.is_deleted = 0
  AND s.current_status = 'in_use'
ORDER BY s.building, s.floor, s.room_number;
GO

-- ============================================================
-- Query 3: Active Maintenance Issues Report
-- ============================================================
-- student-name: Nguyen Huu Phuoc
-- target-users: facility_staff
-- business-question:
--   What maintenance issues are open or in progress across
--   all spaces?
--
-- Why useful:
--   Enables facility staff to see all active maintenance tickets
--   at a glance — including which space is affected, who reported
--   it, who is assigned, how long it has been open, and the
--   problem description — so they can prioritize and track
--   resolution progress.
-- ============================================================

DECLARE @target_status_open        VARCHAR(50) = 'open';
DECLARE @target_status_in_progress VARCHAR(50) = 'in_progress';

SELECT
    m.maintenance_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    s.space_type,
    m.problem_description,
    m.status,
    reporter.full_name       AS reporter_name,
    reporter.email           AS reporter_email,
    assignee.full_name       AS assigned_staff_name,
    assignee.email           AS assigned_staff_email,
    m.start_time,
    DATEDIFF(DAY, m.start_time, GETDATE()) AS days_since_reported
FROM maintenance m
INNER JOIN spaces s
    ON s.space_id = m.space_id
INNER JOIN users reporter
    ON reporter.user_id = m.reporter_id
LEFT JOIN users assignee
    ON assignee.user_id = m.assigned_staff_id
WHERE m.status IN (@target_status_open, @target_status_in_progress)
  AND m.is_deleted = 0
ORDER BY
    m.status,
    m.start_time ASC;
GO

-- ============================================================
-- Query 4: Approved Bookings Past Their Start Time Without Check-In
-- ============================================================
-- student-name: Nguyen Huu Phuoc
-- target-users: facility_staff
-- business-question:
--   Which approved bookings have a start time in the past but no
--   actual check-in recorded yet?
--
-- Why useful:
--   Enables facility staff to proactively identify bookings that
--   were approved but have not been checked in past their start
--   time — allowing staff to contact the requester, free up the
--   space for others, or mark the booking as no-show.
--
-- Note: Returns zero rows if all approved bookings are either in
--   the future or already have a check-in recorded. Seed data in
--   Task 06 does not cover this gap scenario.
-- ============================================================

DECLARE @now DATETIME2 = GETDATE();

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    requester.full_name          AS requester_name,
    requester.email              AS requester_email,
    requester.phone_number       AS requester_phone,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    DATEDIFF(MINUTE, b.requested_start_time, @now) AS minutes_past_start
FROM bookings b
INNER JOIN spaces s
    ON s.space_id = b.space_id
INNER JOIN users requester
    ON requester.user_id = b.requester_id
WHERE b.status = 'approved'
  AND b.is_deleted = 0
  AND b.requested_start_time < @now
  AND NOT EXISTS (
      SELECT 1
      FROM booking_sessions bs
      WHERE bs.booking_id = b.booking_id
  )
ORDER BY b.requested_start_time ASC;
GO

-- ============================================================
-- Query 5: Today's Completed Sessions with Final Condition Report
-- ============================================================
-- student-name: Nguyen Huu Phuoc
-- target-users: facility_staff
-- business-question:
--   Which sessions were completed today, and what was the final
--   condition of each space?
--
-- Why useful:
--   Gives facility staff a daily summary of all sessions that
--   finished today, including final condition and usage notes.
--   This supports end-of-day reconciliation, identifying spaces
--   that need cleaning or repairs before the next booking, and
--   maintaining an audit trail of space handover.
--
-- Note: Returns zero rows if no sessions were completed today.
--   Seed data completed session is 6 days in the past, so this
--   scenario is not covered by Task 06 data.
-- ============================================================

DECLARE @today_start DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), DAY(GETDATE()));
DECLARE @today_end   DATETIME2 = DATEADD(DAY, 1, @today_start);

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    requester.full_name          AS requester_name,
    requester.email              AS requester_email,
    b.purpose,
    b.expected_participants,
    bs.actual_start_time,
    bs.actual_end_time,
    DATEDIFF(MINUTE, bs.actual_start_time, bs.actual_end_time) AS duration_minutes,
    bs.initial_condition,
    bs.final_condition,
    bs.usage_notes,
    checker.full_name            AS checked_in_by_name
FROM bookings b
INNER JOIN spaces s
    ON s.space_id = b.space_id
INNER JOIN users requester
    ON requester.user_id = b.requester_id
INNER JOIN booking_sessions bs
    ON bs.booking_id = b.booking_id
    AND bs.actual_end_time IS NOT NULL
LEFT JOIN users checker
    ON checker.user_id = bs.checked_in_by
WHERE b.status = 'completed'
  AND b.is_deleted = 0
  AND bs.actual_end_time >= @today_start
  AND bs.actual_end_time < @today_end
ORDER BY bs.actual_end_time DESC;
GO

-- ============================================================
-- Query 6: Rejected Booking Audit Trail for a Lecturer
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question:
--   Professor submitted consecutive booking requests that were all
--   rejected. Need complete audit trail including refusal reasons,
--   timestamps, and staff who processed them.
--
-- Why useful:
--   Enables the facility manager to investigate possible bias or
--   procedural issues in booking handling, review staff
--   decision-making, and identify rejection patterns targeting a
--   specific requester — supporting fairness and accountability.
-- ============================================================

DECLARE @lecturer_email NVARCHAR(255) = N't06.lecturer1@university.edu';
-- Note: email is the natural unique key for users per BR10; using
--       user_id would require a lookup step. Email is UNIQUE.

SELECT
    b.booking_id,
    b.purpose,
    b.requested_start_time,
    b.requested_end_time,
    b.expected_participants,
    b.status             AS booking_status,
    ba.decision_time,
    ba.decision          AS approval_decision,
    ba.rejection_reason,
    ba.decision_note,
    approver.full_name   AS processed_by_staff,
    approver.role        AS staff_role
FROM bookings b
INNER JOIN users requester
    ON requester.user_id = b.requester_id
LEFT JOIN booking_approvals ba
    ON ba.booking_id = b.booking_id
    AND ba.decision = 'rejected'
LEFT JOIN users approver
    ON approver.user_id = ba.approver_id
WHERE requester.email = @lecturer_email
  AND requester.role = 'lecturer'
  AND b.is_deleted = 0
  AND b.status = 'rejected'
ORDER BY b.requested_start_time DESC;
GO

-- ============================================================
-- Query 7: Spaces with Upcoming Bookings but No Recent Maintenance
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question:
--   Which spaces have approved bookings scheduled within the
--   next 10 days but have NOT undergone any maintenance or
--   quality inspection within the past 1 months? The facility
--   manager needs this list to dispatch technicians for urgent
--   pre-use checks on long-neglected rooms.
--
-- Why useful:
--   Proactively identifying high-risk spaces (upcoming use + no
--   recent inspection) lets the facility manager prioritize
--   technician dispatch before events begin, reducing the chance
--   of equipment failure or safety issues during booked sessions.
-- ============================================================

DECLARE @lookahead_days       INT = 10;
DECLARE @maintenance_months   INT = 1;

SELECT
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    s.space_type,
    s.capacity,
    COUNT(b.booking_id) AS upcoming_booking_count,
    STRING_AGG(
        FORMAT(b.requested_start_time, 'yyyy-MM-dd HH:mm') + N' - ' +
        FORMAT(b.requested_end_time, 'HH:mm'),
        N'; '
    ) AS upcoming_slots
FROM spaces s
INNER JOIN bookings b
    ON b.space_id = s.space_id
    AND b.is_deleted = 0
    AND b.status IN ('approved', 'checked_in')
    AND b.requested_start_time >= GETDATE()
    AND b.requested_start_time < DATEADD(DAY, @lookahead_days, GETDATE())
WHERE NOT EXISTS (
    SELECT 1
    FROM maintenance m
    WHERE m.space_id = s.space_id
      AND m.is_deleted = 0
      AND (
            (m.status = 'resolved' AND m.completion_time >= DATEADD(MONTH, -@maintenance_months, GETDATE()))
            OR 
            (m.status = 'under_maintenance' AND m.completion_time IS NULL)
          )
)
GROUP BY
    s.space_code,
    s.space_name,
    s.building,
    s.room_number,
    s.space_type,
    s.capacity
ORDER BY upcoming_booking_count DESC, s.building, s.room_number;
GO


-- ============================================================
-- Query 8: Department No-Show Rate Analysis for Semester
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question:
--   During high-demand weeks, certain departments have a habit of
--   booking multiple spaces "just in case" but failing to check in,
--   creating artificial room shortages. The Facility Manager needs
--   a report identifying departments with the highest No-Show rates
--   this semester to enforce strict reservation penalties.
--
-- Why useful:
--   Highlights departments that over-reserve and under-utilize
--   spaces, enabling the facility manager to implement targeted
--   booking policies (e.g., deposit requirements, reduced
--   concurrent-booking limits) and recover real capacity during
--   peak periods.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';
DECLARE @semester_end   DATETIME2 = '2026-06-30 23:59:59';

WITH confirmed_bookings AS (
    SELECT
        b.booking_id,
        b.requester_id,
        b.status
    FROM bookings b
    WHERE b.is_deleted = 0
      AND b.status IN ('approved', 'checked_in', 'completed', 'no_show')
      AND b.requested_start_time >= @semester_start
      AND b.requested_start_time < @semester_end
)
SELECT
    d.name          AS department_name,
    COUNT(cb.booking_id)                                                        AS total_confirmed_bookings,
    SUM(CASE WHEN cb.status = 'no_show' THEN 1 ELSE 0 END)                       AS no_show_count,
    ROUND(100.0 * SUM(CASE WHEN cb.status = 'no_show' THEN 1 ELSE 0 END)
          / NULLIF(COUNT(cb.booking_id), 0), 2)                                  AS no_show_rate_pct
FROM confirmed_bookings cb
INNER JOIN users u        ON u.user_id = cb.requester_id
INNER JOIN departments d  ON d.department_id = u.department_id
GROUP BY d.department_id, d.name
HAVING COUNT(cb.booking_id) >= 1
ORDER BY no_show_rate_pct DESC, total_confirmed_bookings DESC;
GO

-- ============================================================
-- Query 9: Cumulative Monthly Usage Hours for Competing Students
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question:
--   When multiple students submit competing booking requests for the
--   same meeting room and time slot, how many cumulative hours has
--   each requester actually used university shared spaces during the
--   current month? The department administrator needs this information
--   to support fair allocation by prioritizing users who have received
--   less access to shared facilities.
--
-- Why useful:
--   Enables the facility manager to make data-driven approval decisions
--   when multiple students compete for the same room and slot. By
--   prioritizing under-served requesters (low cumulative hours this
--   month), the system supports equitable access and prevents
--   high-frequency users from dominating shared spaces.
-- ============================================================

DECLARE @target_space_code NVARCHAR(50) = N'T06-MR-401';
-- space_code is UNIQUE — acts as stable identifier for human input
DECLARE @slot_start     DATETIME2 = DATEADD(DAY,   9, GETDATE());
DECLARE @slot_end       DATETIME2 = DATEADD(HOUR,  2, @slot_start);
DECLARE @month_start    DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
DECLARE @month_end      DATETIME2 = DATEADD(MONTH, 1, @month_start);

WITH competing_requesters AS (
    SELECT DISTINCT b.requester_id
    FROM bookings b
    INNER JOIN spaces s ON s.space_id = b.space_id
    WHERE s.space_code = @target_space_code
      AND b.is_deleted = 0
      AND b.status IN ('pending', 'approved')
      AND b.requested_start_time < @slot_end
      AND b.requested_end_time   > @slot_start
),
user_monthly_hours AS (
    SELECT
        b.requester_id,
        ROUND(SUM(DATEDIFF(SECOND, bs.actual_start_time, bs.actual_end_time)) / 3600.0, 2) AS cumulative_hours
    FROM bookings b
    INNER JOIN booking_sessions bs
        ON bs.booking_id = b.booking_id
        AND bs.actual_end_time IS NOT NULL
    WHERE b.is_deleted = 0
      AND b.requester_id IN (SELECT requester_id FROM competing_requesters)
      AND bs.actual_start_time >= @month_start
      AND bs.actual_start_time <  @month_end
    GROUP BY b.requester_id
)
SELECT
    u.user_id,
    u.full_name,
    u.email,
    d.name                          AS department_name,
    COALESCE(umh.cumulative_hours, 0) AS cumulative_hours_this_month
FROM competing_requesters cr
INNER JOIN users u            ON u.user_id = cr.requester_id
INNER JOIN departments d      ON d.department_id = u.department_id
LEFT  JOIN user_monthly_hours umh ON umh.requester_id = u.user_id
WHERE u.role = 'student'
  AND u.account_status = 'active'
ORDER BY cumulative_hours_this_month ASC, u.full_name;
GO

-- ============================================================
-- Query 10: Semester Room-Type Request Summary for Expansion Analysis
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question:
--   Provide a summary of the past semester regarding which room type
--   (classroom, laboratory, meeting_room) was most frequently
--   requested, including its successful approval rate and the number
--   of unique users attracted, in order to evaluate potential
--   expansion or consolidation.
--
-- Why useful:
--   Enables the facility manager to make data-driven decisions about
--   space expansion (which room types need more capacity) and
--   consolidation (which room types are underutilized), based on
--   actual request volumes, approval success rates, and user reach.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';
DECLARE @semester_end   DATETIME2 = '2026-07-01 00:00:00';

WITH categorized_requests AS (
    SELECT
        b.booking_id,
        CASE
            WHEN s.space_type IN ('computer_lab', 'project_lab') THEN N'laboratory'
            ELSE s.space_type
        END AS room_category,
        b.status,
        b.requester_id
    FROM bookings b
    INNER JOIN spaces s
        ON s.space_id = b.space_id
    WHERE b.is_deleted = 0
      AND b.requested_start_time >= @semester_start
      AND b.requested_start_time < @semester_end
      AND s.space_type IN ('classroom', 'computer_lab', 'project_lab', 'meeting_room', 'auditorium')
)
SELECT
    room_category,
    COUNT(*)                                                                  AS total_requests,
    SUM(CASE WHEN status IN ('approved', 'checked_in', 'completed', 'no_show') THEN 1 ELSE 0 END) AS approved_count,
    ROUND(
        100.0 * SUM(CASE WHEN status IN ('approved', 'checked_in', 'completed', 'no_show') THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    )                                                                         AS approval_rate_pct,
    COUNT(DISTINCT requester_id)                                              AS unique_users
FROM categorized_requests
GROUP BY room_category
ORDER BY total_requests DESC;
GO