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

-- ============================================================
-- Query 11: Lab Availability with Equipment and Conflict Checks
-- ============================================================
-- student-name: Tran Dinh Quoc Thang
-- target-users: lecturer, teaching_assistant
-- business-question:
--   Which computer or project labs can host a requested tutorial slot
--   with enough capacity, enough workstations, optional projector support,
--   no live unavailable-room status, no confirmed booking overlap, and no
--   unresolved maintenance conflict?
--
-- Target user(s):
--   Lecturer, Teaching Assistant
--
-- Why useful:
--   Helps teaching users and facility staff choose a lab that is not only
--   large enough, but also operationally safe for approval before the
--   request is submitted.
-- ============================================================

DECLARE @tutorial_date DATE = DATEADD(DAY, 12, CAST(GETDATE() AS DATE));
DECLARE @slot_start_hour INT = 9;
DECLARE @slot_duration_minutes INT = 120;
DECLARE @slot_start DATETIME2 = DATEADD(HOUR, @slot_start_hour, CAST(@tutorial_date AS DATETIME2));
DECLARE @slot_end DATETIME2 = DATEADD(MINUTE, @slot_duration_minutes, @slot_start);
DECLARE @minimum_capacity INT = 30;
DECLARE @minimum_workstation_count INT = 30;
DECLARE @requires_projector BIT = 1;
DECLARE @minimum_projector_count INT = 1;
DECLARE @space_type_computer_lab VARCHAR(50) = 'computer_lab';
DECLARE @space_type_project_lab VARCHAR(50) = 'project_lab';
DECLARE @space_status_available VARCHAR(50) = 'available';
DECLARE @status_approved VARCHAR(50) = 'approved';
DECLARE @status_checked_in VARCHAR(50) = 'checked_in';
DECLARE @status_completed VARCHAR(50) = 'completed';
DECLARE @maintenance_status_open VARCHAR(50) = 'open';
DECLARE @maintenance_status_in_progress VARCHAR(50) = 'in_progress';
DECLARE @computer_facility_name NVARCHAR(255) = N'T06 Computer';
DECLARE @projector_facility_name NVARCHAR(255) = N'T06 Projector';

WITH lab_inventory AS (
    SELECT
        s.space_id,
        s.space_code,
        s.space_name,
        s.space_type,
        s.building,
        s.floor,
        s.room_number,
        s.capacity,
        s.current_status,
        SUM(CASE WHEN f.name = @computer_facility_name THEN COALESCE(sf.quantity, 0) ELSE 0 END) AS workstation_count,
        SUM(CASE WHEN f.name = @projector_facility_name THEN COALESCE(sf.quantity, 0) ELSE 0 END) AS projector_count
    FROM spaces s
    LEFT JOIN space_facilities sf
        ON sf.space_id = s.space_id
    LEFT JOIN facilities f
        ON f.facility_id = sf.facility_id
    WHERE s.space_type IN (@space_type_computer_lab, @space_type_project_lab)
    GROUP BY
        s.space_id,
        s.space_code,
        s.space_name,
        s.space_type,
        s.building,
        s.floor,
        s.room_number,
        s.capacity,
        s.current_status
),
booking_conflicts AS (
    SELECT
        b.space_id,
        COUNT(*) AS confirmed_overlap_count
    FROM bookings b
    WHERE b.is_deleted = 0
      AND b.status IN (@status_approved, @status_checked_in, @status_completed)
      AND @slot_start < b.requested_end_time
      AND @slot_end > b.requested_start_time
    GROUP BY b.space_id
),
maintenance_conflicts AS (
    SELECT
        m.space_id,
        COUNT(*) AS unresolved_maintenance_count
    FROM maintenance m
    WHERE m.is_deleted = 0
      AND m.status IN (@maintenance_status_open, @maintenance_status_in_progress)
      AND m.start_time < @slot_end
      AND (m.completion_time IS NULL OR m.completion_time > @slot_start)
    GROUP BY m.space_id
)
SELECT
    li.space_code,
    li.space_name,
    li.space_type,
    li.building,
    li.floor,
    li.room_number,
    li.capacity,
    li.workstation_count,
    li.projector_count,
    li.current_status,
    @slot_start AS requested_start_time,
    @slot_end AS requested_end_time,
    COALESCE(bc.confirmed_overlap_count, 0) AS confirmed_overlap_count,
    COALESCE(mc.unresolved_maintenance_count, 0) AS unresolved_maintenance_count
FROM lab_inventory li
LEFT JOIN booking_conflicts bc
    ON bc.space_id = li.space_id
LEFT JOIN maintenance_conflicts mc
    ON mc.space_id = li.space_id
WHERE li.current_status = @space_status_available
  AND li.capacity >= @minimum_capacity
  AND li.workstation_count >= @minimum_workstation_count
  AND (@requires_projector = 0 OR li.projector_count >= @minimum_projector_count)
  AND COALESCE(bc.confirmed_overlap_count, 0) = 0
  AND COALESCE(mc.unresolved_maintenance_count, 0) = 0
ORDER BY li.capacity ASC, li.workstation_count DESC, li.space_code;
GO

-- ============================================================
-- Query 12: Lecturer Personal Booking Timeline
-- ============================================================
-- student-name: Tran Dinh Quoc Thang
-- target-users: lecturer
-- business-question:
--   What is a lecturer's semester booking timeline across active
--   lifecycle statuses, including room details, decision notes,
--   rejection reasons, approver information, and actual session times?
--
-- Target user(s):
--   Lecturer
--
-- Why useful:
--   Gives a lecturer a single audit-friendly view of pending, approved,
--   rejected, checked-in, completed, and no-show bookings without losing
--   the decision or session context stored in child tables.
-- ============================================================

DECLARE @lecturer_email_for_timeline NVARCHAR(255) = N't06.lecturer1@university.edu';
DECLARE @lecturer_role VARCHAR(50) = 'lecturer';
-- email is UNIQUE in users; this lookup converts human input to the surrogate key used below.
DECLARE @lecturer_user_id INT = (
    SELECT u.user_id
    FROM users u
    WHERE u.email = @lecturer_email_for_timeline
      AND u.role = @lecturer_role
);
DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';
DECLARE @semester_end DATETIME2 = '2027-01-01 00:00:00';
DECLARE @status_pending VARCHAR(50) = 'pending';
DECLARE @status_approved VARCHAR(50) = 'approved';
DECLARE @status_rejected VARCHAR(50) = 'rejected';
DECLARE @status_checked_in VARCHAR(50) = 'checked_in';
DECLARE @status_completed VARCHAR(50) = 'completed';
DECLARE @status_no_show VARCHAR(50) = 'no_show';

SELECT
    b.booking_id,
    b.status AS booking_status,
    b.purpose,
    b.expected_participants,
    b.requested_start_time,
    b.requested_end_time,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    ba.decision,
    ba.decision_time,
    ba.decision_note,
    ba.rejection_reason,
    approver.full_name AS approver_name,
    approver.email AS approver_email,
    approver.role AS approver_role,
    bs.actual_start_time,
    bs.actual_end_time,
    bs.initial_condition,
    bs.final_condition,
    bs.usage_notes
FROM bookings b
INNER JOIN spaces s
    ON s.space_id = b.space_id
LEFT JOIN booking_approvals ba
    ON ba.booking_id = b.booking_id
LEFT JOIN users approver
    ON approver.user_id = ba.approver_id
LEFT JOIN booking_sessions bs
    ON bs.booking_id = b.booking_id
WHERE b.requester_id = @lecturer_user_id
  AND b.is_deleted = 0
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
  AND b.status IN (
      @status_pending,
      @status_approved,
      @status_rejected,
      @status_checked_in,
      @status_completed,
      @status_no_show
  )
ORDER BY b.requested_start_time DESC, b.booking_id DESC;
GO

-- ============================================================
-- Query 13: Completed TA Lab Session History
-- ============================================================
-- student-name: Tran Dinh Quoc Thang
-- target-users: teaching_assistant
-- business-question:
--   Which completed computer or project lab sessions belong to a teaching
--   assistant, and what were the actual duration, condition notes,
--   check-in staff, usage notes, and facilities available in the room?
--
-- Target user(s):
--   Teaching Assistant
--
-- Why useful:
--   Lets a teaching assistant review completed lab usage and handover notes,
--   while preserving a compact facility summary for later teaching or
--   equipment follow-up.
--
-- Note: returns zero rows if the sample data has no completed lab session
--   requested by the selected teaching assistant.
-- ============================================================

DECLARE @ta_email_for_completed_labs NVARCHAR(255) = N't06.ta1@university.edu';
DECLARE @ta_role VARCHAR(50) = 'teaching_assistant';
-- email is UNIQUE in users; this lookup converts human input to the surrogate key used below.
DECLARE @ta_user_id INT = (
    SELECT u.user_id
    FROM users u
    WHERE u.email = @ta_email_for_completed_labs
      AND u.role = @ta_role
);
DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';
DECLARE @semester_end DATETIME2 = '2027-01-01 00:00:00';
DECLARE @space_type_computer_lab VARCHAR(50) = 'computer_lab';
DECLARE @space_type_project_lab VARCHAR(50) = 'project_lab';
DECLARE @status_completed VARCHAR(50) = 'completed';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    b.purpose,
    b.expected_participants,
    bs.actual_start_time,
    bs.actual_end_time,
    DATEDIFF(MINUTE, bs.actual_start_time, bs.actual_end_time) AS actual_duration_minutes,
    ROUND(DATEDIFF(MINUTE, bs.actual_start_time, bs.actual_end_time) / 60.0, 2) AS actual_duration_hours,
    bs.initial_condition,
    bs.final_condition,
    bs.usage_notes,
    checker.full_name AS checked_in_by_name,
    checker.email AS checked_in_by_email,
    STRING_AGG(CONCAT(f.name, N' x', COALESCE(CONVERT(NVARCHAR(20), sf.quantity), N'?')), N', ') AS facility_summary
FROM bookings b
INNER JOIN spaces s
    ON s.space_id = b.space_id
INNER JOIN booking_sessions bs
    ON bs.booking_id = b.booking_id
INNER JOIN users checker
    ON checker.user_id = bs.checked_in_by
LEFT JOIN space_facilities sf
    ON sf.space_id = s.space_id
LEFT JOIN facilities f
    ON f.facility_id = sf.facility_id
WHERE b.requester_id = @ta_user_id
  AND b.is_deleted = 0
  AND b.status = @status_completed
  AND bs.actual_end_time IS NOT NULL
  AND s.space_type IN (@space_type_computer_lab, @space_type_project_lab)
  AND bs.actual_start_time >= @semester_start
  AND bs.actual_start_time < @semester_end
GROUP BY
    b.booking_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    b.purpose,
    b.expected_participants,
    bs.actual_start_time,
    bs.actual_end_time,
    bs.initial_condition,
    bs.final_condition,
    bs.usage_notes,
    checker.full_name,
    checker.email
ORDER BY bs.actual_start_time DESC, b.booking_id DESC;
GO

-- ============================================================
-- Query 14: Approval Lead-Time Analysis
-- ============================================================
-- student-name: Tran Dinh Quoc Thang
-- target-users: facility_manager, department_admin
-- business-question:
--   How long do approved and rejected lecturer bookings take to receive
--   a decision when grouped by purpose, space type, and decision status?
--
-- Target user(s):
--   Facility Manager, Department Administrator
--
-- Why useful:
--   Summarizes minimum, average, and maximum decision lead time so lecturers
--   and administrators can plan future submissions with realistic approval
--   windows.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-01-01 00:00:00';
DECLARE @semester_end DATETIME2 = '2027-01-01 00:00:00';
DECLARE @requester_role VARCHAR(50) = 'lecturer';
DECLARE @decision_approved VARCHAR(50) = 'approved';
DECLARE @decision_rejected VARCHAR(50) = 'rejected';

SELECT
    b.purpose,
    s.space_type,
    ba.decision AS decision_status,
    COUNT(*) AS decided_booking_count,
    MIN(DATEDIFF(MINUTE, b.created_at, ba.decision_time)) AS min_decision_lead_minutes,
    ROUND(AVG(CAST(DATEDIFF(MINUTE, b.created_at, ba.decision_time) AS DECIMAL(10, 2))), 2) AS avg_decision_lead_minutes,
    MAX(DATEDIFF(MINUTE, b.created_at, ba.decision_time)) AS max_decision_lead_minutes
FROM booking_approvals ba
INNER JOIN bookings b
    ON b.booking_id = ba.booking_id
INNER JOIN spaces s
    ON s.space_id = b.space_id
INNER JOIN users requester
    ON requester.user_id = b.requester_id
WHERE b.is_deleted = 0
  AND requester.role = @requester_role
  AND ba.decision IN (@decision_approved, @decision_rejected)
  AND b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
GROUP BY
    b.purpose,
    s.space_type,
    ba.decision
ORDER BY avg_decision_lead_minutes DESC, decided_booking_count DESC, b.purpose, s.space_type;
GO

-- ============================================================
-- Query 15: Upcoming Lab Readiness Alert
-- ============================================================
-- student-name: Tran Dinh Quoc Thang
-- target-users: teaching_assistant
-- business-question:
--   Which approved upcoming teaching-assistant lab bookings may be
--   disrupted by non-available space status or overlapping unresolved
--   maintenance?
--
-- Target user(s):
--   Teaching Assistant
--
-- Why useful:
--   Flags at-risk TA lab sessions early enough for staff to prepare a
--   backup room or resolve maintenance before the tutorial begins.
--
-- Note: returns zero rows if the sample data has no approved upcoming TA
--   lab booking with a readiness issue.
-- ============================================================

DECLARE @lookahead_days INT = 30;
DECLARE @now DATETIME2 = GETDATE();
DECLARE @window_end DATETIME2 = DATEADD(DAY, @lookahead_days, @now);
DECLARE @requester_role VARCHAR(50) = 'teaching_assistant';
DECLARE @status_approved VARCHAR(50) = 'approved';
DECLARE @space_status_available VARCHAR(50) = 'available';
DECLARE @space_type_computer_lab VARCHAR(50) = 'computer_lab';
DECLARE @space_type_project_lab VARCHAR(50) = 'project_lab';
DECLARE @maintenance_status_open VARCHAR(50) = 'open';
DECLARE @maintenance_status_in_progress VARCHAR(50) = 'in_progress';

WITH upcoming_ta_lab_bookings AS (
    SELECT
        b.booking_id,
        b.space_id,
        b.requester_id,
        b.purpose,
        b.expected_participants,
        b.requested_start_time,
        b.requested_end_time,
        s.space_code,
        s.space_name,
        s.space_type,
        s.building,
        s.floor,
        s.room_number,
        s.capacity,
        s.current_status,
        requester.full_name AS ta_name,
        requester.email AS ta_email
    FROM bookings b
    INNER JOIN spaces s
        ON s.space_id = b.space_id
    INNER JOIN users requester
        ON requester.user_id = b.requester_id
    WHERE b.is_deleted = 0
      AND b.status = @status_approved
      AND requester.role = @requester_role
      AND s.space_type IN (@space_type_computer_lab, @space_type_project_lab)
      AND b.requested_start_time >= @now
      AND b.requested_start_time < @window_end
),
maintenance_overlap AS (
    SELECT
        u.booking_id,
        COUNT(m.maintenance_id) AS unresolved_maintenance_count,
        STRING_AGG(CONCAT(N'#', m.maintenance_id, N' ', m.status, N': ', m.problem_description), N' | ') AS maintenance_summary
    FROM upcoming_ta_lab_bookings u
    INNER JOIN maintenance m
        ON m.space_id = u.space_id
        AND m.is_deleted = 0
        AND m.status IN (@maintenance_status_open, @maintenance_status_in_progress)
        AND m.start_time < u.requested_end_time
        AND (m.completion_time IS NULL OR m.completion_time > u.requested_start_time)
    GROUP BY u.booking_id
)
SELECT
    u.booking_id,
    u.ta_name,
    u.ta_email,
    u.space_code,
    u.space_name,
    u.space_type,
    u.building,
    u.floor,
    u.room_number,
    u.requested_start_time,
    u.requested_end_time,
    u.current_status,
    COALESCE(mo.unresolved_maintenance_count, 0) AS unresolved_maintenance_count,
    CASE
        WHEN u.current_status <> @space_status_available AND COALESCE(mo.unresolved_maintenance_count, 0) > 0
            THEN N'Space status and maintenance conflict'
        WHEN u.current_status <> @space_status_available
            THEN N'Space status not available'
        WHEN COALESCE(mo.unresolved_maintenance_count, 0) > 0
            THEN N'Overlapping unresolved maintenance'
        ELSE N'Ready'
    END AS readiness_alert_reason,
    mo.maintenance_summary
FROM upcoming_ta_lab_bookings u
LEFT JOIN maintenance_overlap mo
    ON mo.booking_id = u.booking_id
WHERE u.current_status <> @space_status_available
   OR COALESCE(mo.unresolved_maintenance_count, 0) > 0
ORDER BY u.requested_start_time ASC, u.space_code;
GO
