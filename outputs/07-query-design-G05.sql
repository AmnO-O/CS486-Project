
-- ============================================================
-- Query 6: Booking Rejection Audit Trail for a Lecturer
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question: Professor submitted consecutive booking
--   requests that were all rejected. Need complete audit trail
--   including refusal reasons, timestamps, and staff who
--   processed them.
--
-- Business question (full):
--   A professor submitted consecutive booking requests that were
--   all rejected. Need a complete audit trail including refusal
--   reasons, timestamps, and staff who processed them.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Facility Managers can review rejection patterns to identify
--   systemic issues (e.g., recurring room conflicts, policy gaps)
--   and follow up with staff who handled the decisions, ensuring
--   consistent and fair approval practices.
-- ============================================================

DECLARE @lecturer_email NVARCHAR(255) = N't06.lecturer1@university.edu';

SELECT
    b.booking_id,
    s.space_code,
    s.space_name,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    ba.decision_time          AS rejection_time,
    ba.rejection_reason,
    ba.decision_note,
    approver.full_name        AS processed_by_staff,
    approver.role             AS staff_role
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s
    ON s.space_id = b.space_id
INNER JOIN [dbo].[users] requester
    ON requester.user_id = b.requester_id
INNER JOIN [dbo].[booking_approvals] ba
    ON ba.booking_id = b.booking_id
INNER JOIN [dbo].[users] approver
    ON approver.user_id = ba.approver_id
WHERE requester.email = @lecturer_email
  AND ba.decision = 'rejected'
  AND b.is_deleted = 0
ORDER BY b.requested_start_time ASC;
GO

-- Note: returns zero rows for the sample data because lecturer1 has no rejected
-- bookings (the only rejected booking belongs to a TA). The SQL logic is correct;
-- seed additional rejected bookings for a lecturer to exercise this query.
GO

-- ============================================================
-- Query 7: Space Maintenance Risk Profile with Upcoming Bookings
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question: Which spaces have encountered resolved
--   maintenance issues within the past six months, and what are
--   their upcoming approved bookings for the next seven days?
--
-- Business question (full):
--   Which spaces have encountered resolved maintenance issues
--   within the past six months, and what are their upcoming
--   approved bookings for the next seven days? The facility
--   manager needs this comprehensive risk profile to identify
--   rooms with a history of failure and leverage their available
--   gap times (or empty slots) for preventive maintenance before
--   new schedules are disrupted.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Surfaces every space with a recent maintenance history
--   alongside its immediate booking pipeline, so the Facility
--   Manager can proactively schedule preventive maintenance
--   during unused time windows before new disruptions occur.
-- ============================================================

DECLARE @six_months_ago    DATETIME2 = DATEADD(MONTH, -6, GETDATE());
DECLARE @seven_days_ahead  DATETIME2 = DATEADD(DAY, 7, GETDATE());

SELECT
    s.space_id,
    s.space_code,
    s.space_name,
    s.building,
    s.floor,
    s.current_status,
    m.maintenance_id         AS resolved_maint_id,
    m.problem_description,
    m.completion_time        AS maint_completion_time,
    m.result_note,
    b.booking_id             AS upcoming_booking_id,
    b.requested_start_time   AS booking_start,
    b.requested_end_time     AS booking_end,
    b.purpose                AS booking_purpose,
    b.expected_participants
FROM [dbo].[spaces] s
LEFT JOIN [dbo].[maintenance] m
    ON m.space_id = s.space_id
   AND m.status = 'resolved'
   AND m.completion_time >= @six_months_ago
   AND m.is_deleted = 0
LEFT JOIN [dbo].[bookings] b
    ON b.space_id = s.space_id
   AND b.status = 'approved'
   AND b.requested_start_time >= GETDATE()
   AND b.requested_start_time <= @seven_days_ahead
   AND b.is_deleted = 0
WHERE (m.maintenance_id IS NOT NULL OR b.booking_id IS NOT NULL)
ORDER BY s.space_code, m.completion_time, b.requested_start_time;
GO

-- Note: sample data has resolved maintenance records for T06-CLS-201,
-- T06-PROJ-110, T06-SW-020, and T06-MTG-012 within the past 6 months,
-- but no approved bookings starting within the 7-day window (only one
-- approved booking exists on July 20, outside the range). The query
-- correctly returns maintenance history rows with NULL booking columns;
-- seed additional approved bookings for a complete joined result.
GO

-- ============================================================
-- Query 8: Department No-Show Rate Report for the Semester
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question: During high-demand weeks, certain departments
--   have a habit of booking multiple spaces "just in case" but
--   failing to check in, creating artificial room shortages.
--
-- Business question (full):
--   During high-demand weeks, certain departments have a habit
--   of booking multiple spaces "just in case" but failing to
--   check in, creating artificial room shortages. The Facility
--   Manager needs a report identifying departments with the
--   highest No-Show rates this semester to enforce strict
--   reservation penalties.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Quantifies no-show behaviour by department so the Facility
--   Manager can target enforcement actions (booking caps,
--   penalties) at the worst offenders, freeing artificially
--   reserved spaces for legitimate users.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-06-01T00:00:00';

SELECT
    d.department_id,
    d.name                         AS department_name,
    COUNT(*)                       AS total_approved_bookings,
    SUM(CASE WHEN b.status = 'no_show' THEN 1 ELSE 0 END)
                                   AS no_show_count,
    ROUND(
        SUM(CASE WHEN b.status = 'no_show' THEN 1.0 ELSE 0.0 END)
        / NULLIF(COUNT(*), 0) * 100,
        1
    )                              AS no_show_rate_pct
FROM [dbo].[bookings] b
INNER JOIN [dbo].[users] u
    ON u.user_id = b.requester_id
INNER JOIN [dbo].[departments] d
    ON d.department_id = u.department_id
INNER JOIN [dbo].[booking_approvals] ba
    ON ba.booking_id = b.booking_id
   AND ba.decision = 'approved'
WHERE b.requested_end_time >= @semester_start
  AND b.requested_end_time < GETDATE()
  AND b.is_deleted = 0
GROUP BY d.department_id, d.name
ORDER BY no_show_rate_pct DESC;
GO

-- Note: with sample data (semester_start = 2026-06-01), two departments
-- appear: School of Computer Science (1 no-show out of 2 approved past
-- bookings = 50.0%) and Department of Physics (1 no-show out of 1 = 100.0%).
-- Physics ranks first; seed more data to see a richer distribution.
GO

-- ============================================================
-- Query 9: Cumulative Space Usage Hours Per Requester This Month
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question: When multiple students submit competing
--   booking requests for the same meeting room and time slot,
--   how many cumulative hours has each requester actually used
--   university shared spaces during the current month?
--
-- Business question (full):
--   When multiple students submit competing booking requests for
--   the same meeting room and time slot, how many cumulative
--   hours has each requester actually used university shared
--   spaces during the current month? The facility manager needs
--   this information to support fair allocation by prioritizing
--   users who have received less access to shared facilities.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Enables evidence-based allocation when multiple requesters
--   compete for the same room — users with fewer actual hours
--   get priority, preventing well-connected users from
--   monopolising shared spaces.
-- ============================================================

DECLARE @month_start DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
DECLARE @month_end   DATETIME2 = DATEADD(MONTH, 1, @month_start);

SELECT
    u.user_id,
    u.full_name                          AS requester_name,
    u.email                              AS requester_email,
    d.name                               AS department_name,
    COUNT(DISTINCT bs.session_id)        AS completed_sessions,
    ROUND(
        SUM(
            DATEDIFF(SECOND, bs.actual_start_time, bs.actual_end_time)
        ) / 3600.0,
        2
    )                                    AS cumulative_hours
FROM [dbo].[bookings] b
INNER JOIN [dbo].[users] u
    ON u.user_id = b.requester_id
INNER JOIN [dbo].[departments] d
    ON d.department_id = u.department_id
INNER JOIN [dbo].[booking_sessions] bs
    ON bs.booking_id = b.booking_id
WHERE bs.actual_end_time IS NOT NULL
  AND bs.actual_end_time >= @month_start
  AND bs.actual_end_time < @month_end
  AND b.is_deleted = 0
GROUP BY u.user_id, u.full_name, u.email, d.name
ORDER BY cumulative_hours ASC;
GO

-- Note: with sample data (June 2026), only one completed session exists:
-- T06-COMP-301 seminar by Dr. Linh Pham (lecturer1, CS) on 2026-06-10,
-- lasting 1.83 hours (08:05 → 09:55). Returns 1 row. Seed more completed
-- sessions for a richer distribution.
GO

-- ============================================================
-- Query 10: Semester Room-Type Demand & Approval Summary
-- ============================================================
-- student-name: Pham Huu Nam
-- target-users: facility_manager
-- business-question: Provide a summary of the past semester
--   regarding which room type was most frequently requested,
--   including its successful approval rate and the number of
--   unique users attracted.
--
-- Business question (full):
--   Provide a summary of the past semester regarding which room
--   type (classroom, laboratory, meeting_room) was most
--   frequently requested, including its successful approval rate
--   and the number of unique users attracted, in order to
--   evaluate potential expansion or consolidation.
--
-- Target user(s):
--   Facility Manager
--
-- Why useful:
--   Reveals which space types carry the heaviest demand and
--   which are under-utilised, guiding capital decisions about
--   which room types to expand, consolidate, or re-purpose for
--   the next academic year.
-- ============================================================

DECLARE @semester_start DATETIME2 = '2026-06-01T00:00:00';
DECLARE @semester_end   DATETIME2 = '2026-08-01T00:00:00';

SELECT
    s.space_type,
    COUNT(*)                                            AS total_requests,
    COUNT(DISTINCT b.requester_id)                      AS unique_requesters,
    COUNT(DISTINCT CASE WHEN ba.decision = 'approved'
                        THEN b.booking_id END)          AS approved_count,
    ROUND(
        COUNT(DISTINCT CASE WHEN ba.decision = 'approved'
                            THEN b.booking_id END) * 100.0
        / NULLIF(COUNT(*), 0),
        1
    )                                                   AS approval_rate_pct
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s
    ON s.space_id = b.space_id
LEFT JOIN [dbo].[booking_approvals] ba
    ON ba.booking_id = b.booking_id
WHERE b.requested_start_time >= @semester_start
  AND b.requested_start_time < @semester_end
  AND b.is_deleted = 0
GROUP BY s.space_type
ORDER BY total_requests DESC;
GO

-- Note: with sample data (Jun–Aug 2026 semester), auditorium leads with
-- 3 requests (2 approved = 66.7%, 2 unique requesters), followed by
-- classroom (2 requests, 0 approved) and computer_lab (2, 100%). Project_lab
-- and student_workspace each have 1 request. Seed more data to see fuller
-- ranking across all 6 room types.
