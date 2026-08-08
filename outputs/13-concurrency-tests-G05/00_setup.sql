-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 13: Concurrency Tests — 00_setup.sql (shared fixture)
-- Target: SQL Server 2019+ (T-SQL); run via sqlcmd -d <db> -i 00_setup.sql
--
-- Creates a small deterministic TEST-13 world used by BOTH the
-- baseline/ (no concurrency control) and controlled/ (Task 12 entry
-- points) scenario scripts:
--
--   1 department, 2 users (RQ requester / ST staff), 9 meeting_rooms,
--   1 advisory maintenance (M3, escalation target), 1 advisory
--   maintenance (M9, ack-repair target), 5 pending bookings (PB2a,
--   PB2b, PB3, PB10a, PB10b, PB13).
--
-- All scenario windows are placed >= +600 days from SYSDATETIME() so
-- they never collide with the 06 sample data or the Task 12 smoke
-- windows (+340..+400 days).
--
-- Idempotent: re-running never duplicates (guarded inserts).
-- ============================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ------------------------------------------------------------------
-- 1. Preflight: Task 12 entry points must exist (they are the object
--    under test); the Phase 2 schema (Task 10) is assumed applied.
-- ------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'usp_booking_instant_submit')
    OR NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'usp_booking_approve')
    OR NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'usp_maintenance_set_impact_level')
    OR NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = N'usp_maintenance_report')
BEGIN
    THROW 53001, N'Task 13 setup: Task 12 entry points missing. Run outputs/12-concurrency-implementation-G05.sql first.', 1;
END

-- ------------------------------------------------------------------
-- 2. Department
-- ------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.departments WHERE name = N'TEST-13-Dept')
    INSERT INTO dbo.departments (name) VALUES (N'TEST-13-Dept');

DECLARE @dept_id INT = (SELECT department_id FROM dbo.departments WHERE name = N'TEST-13-Dept');

-- ------------------------------------------------------------------
-- 3. Users: RQ (lecturer, requester side) and ST (facility_manager,
--    staff/approver side). Emails are unique business keys.
-- ------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE email = N'test13.requester@campus.edu')
    INSERT INTO dbo.users (email, full_name, phone_number, role, department_id, account_status)
    VALUES (N'test13.requester@campus.edu', N'TEST-13 Requester', NULL, 'lecturer', @dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM dbo.users WHERE email = N'test13.staff@campus.edu')
    INSERT INTO dbo.users (email, full_name, phone_number, role, department_id, account_status)
    VALUES (N'test13.staff@campus.edu', N'TEST-13 Staff', NULL, 'facility_manager', @dept_id, 'active');

DECLARE @rq INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.requester@campus.edu');
DECLARE @st INT = (SELECT user_id FROM dbo.users WHERE email = N'test13.staff@campus.edu');

IF @rq IS NULL OR @st IS NULL
    THROW 53002, N'Task 13 setup: fixture users missing.', 1;

-- ------------------------------------------------------------------
-- 4. Spaces: 9 meeting_rooms (capacity 30). meeting_room's allowed
--    purposes per Task 10 seed: meeting, seminar, administrative_event,
--    workshop, student_activity (lecture/examination are NOT allowed —
--    used by c11/c12 soft-gate fallback).
-- ------------------------------------------------------------------
DECLARE @space_codes TABLE (n INT PRIMARY KEY, code NVARCHAR(50));
INSERT INTO @space_codes (n, code) VALUES
    (1, N'TEST-13-01-MR'), (2, N'TEST-13-02-MR'), (3, N'TEST-13-03-MR'),
    (4, N'TEST-13-04-MR'), (5, N'TEST-13-05-MR'), (6, N'TEST-13-06-MR'),
    (7, N'TEST-13-07-MR'), (8, N'TEST-13-08-MR'), (9, N'TEST-13-09-MR');

DECLARE @n INT, @code NVARCHAR(50);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT n, code FROM @space_codes;
OPEN cur;
FETCH NEXT FROM cur INTO @n, @code;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.spaces WHERE space_code = @code)
        INSERT INTO dbo.spaces
            (space_code, space_name, space_type, building, floor, room_number, capacity, current_status)
        VALUES
            (@code, N'TEST-13 Space ' + CAST(@n AS NVARCHAR(3)), 'meeting_room',
             N'TEST-B', N'F1', CAST(@n AS NVARCHAR(3)), 30, 'available');
    FETCH NEXT FROM cur INTO @n, @code;
END
CLOSE cur;
DEALLOCATE cur;

-- Space ids
DECLARE @s1 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-01-MR');
DECLARE @s2 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-02-MR');
DECLARE @s3 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-03-MR');
DECLARE @s4 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-04-MR');
DECLARE @s5 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-05-MR');
DECLARE @s6 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-06-MR');
DECLARE @s7 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-07-MR');
DECLARE @s8 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-08-MR');
DECLARE @s9 INT = (SELECT space_id FROM dbo.spaces WHERE space_code = N'TEST-13-09-MR');

-- ------------------------------------------------------------------
-- 5. Scenario windows (offsets from now; all >= +600 days)
-- ------------------------------------------------------------------
DECLARE @w1  DATETIME2 = DATEADD(day, 600, SYSDATETIME());  -- b01/c01 instant vs instant
DECLARE @w2a DATETIME2 = DATEADD(day, 620, SYSDATETIME());  -- b02/c02 order-1 (approve first)
DECLARE @w2b DATETIME2 = DATEADD(day, 621, SYSDATETIME());  -- b02/c02 order-2 (submit first)
DECLARE @w3  DATETIME2 = DATEADD(day, 640, SYSDATETIME());  -- b03/c03 escalation
DECLARE @w4  DATETIME2 = DATEADD(day, 660, SYSDATETIME());  -- b05/c05 lock timeout
DECLARE @w5  DATETIME2 = DATEADD(day, 680, SYSDATETIME());  -- b09/c09 ticket vs submit
DECLARE @w6  DATETIME2 = DATEADD(day, 700, SYSDATETIME());  -- c11 soft gate
DECLARE @w7  DATETIME2 = DATEADD(day, 720, SYSDATETIME());  -- c12 fallback vs instant
DECLARE @w8  DATETIME2 = DATEADD(day, 740, SYSDATETIME());  -- b10/c10 staff vs staff
DECLARE @w9  DATETIME2 = DATEADD(day, 760, SYSDATETIME());  -- c13 ack repair

-- ------------------------------------------------------------------
-- 6. Advisory maintenance tickets (seeded; escalation/ack targets)
--    M3: on S3, overlaps W3 (advisory -> escalated to OOS in b03/c03)
--    M9: on S9, overlaps W9 (advisory; acks deliberately NOT inserted)
-- ------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.maintenance m
               WHERE m.space_id = @s3 AND m.problem_description = N'TEST-13 advisory M3')
    INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
    VALUES (@s3, @rq, N'TEST-13 advisory M3', DATEADD(hour, -1, @w3), 'open', 'advisory');

IF NOT EXISTS (SELECT 1 FROM dbo.maintenance m
               WHERE m.space_id = @s9 AND m.problem_description = N'TEST-13 advisory M9')
    INSERT INTO dbo.maintenance (space_id, reporter_id, problem_description, start_time, status, impact_level)
    VALUES (@s9, @rq, N'TEST-13 advisory M9', DATEADD(hour, -1, @w9), 'open', 'advisory');

-- ------------------------------------------------------------------
-- 7. Pending bookings (seeded via RAW INSERT — pending rows pass all
--    defense triggers). Used by baseline and controlled scenarios.
-- ------------------------------------------------------------------
-- PB2a: S2 window W2a (c02 order-1: staff approves first)
IF NOT EXISTS (SELECT 1 FROM dbo.bookings b WHERE b.space_id = @s2 AND b.requested_start_time = @w2a)
    INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status)
    VALUES (@s2, @rq, @w2a, DATEADD(hour, 2, @w2a), 'meeting', 10, 'pending');

-- PB2b: S2 window W2b (c02 order-2: instant submit first)
IF NOT EXISTS (SELECT 1 FROM dbo.bookings b WHERE b.space_id = @s2 AND b.requested_start_time = @w2b)
    INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status)
    VALUES (@s2, @rq, @w2b, DATEADD(hour, 2, @w2b), 'meeting', 10, 'pending');

-- PB3: S3 window W3 (T4: escalation leaves pending untouched)
IF NOT EXISTS (SELECT 1 FROM dbo.bookings b WHERE b.space_id = @s3 AND b.requested_start_time = @w3)
    INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status)
    VALUES (@s3, @rq, @w3, DATEADD(hour, 2, @w3), 'meeting', 10, 'pending');

-- PB10a / PB10b: S8 windows W8 and W8+30min (b10/c10 staff-vs-staff,
-- overlapping each other)
IF NOT EXISTS (SELECT 1 FROM dbo.bookings b WHERE b.space_id = @s8 AND b.requested_start_time = @w8)
    INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status)
    VALUES (@s8, @rq, @w8, DATEADD(hour, 2, @w8), 'meeting', 10, 'pending');

DECLARE @w8b DATETIME2 = DATEADD(minute, 30, @w8);
IF NOT EXISTS (SELECT 1 FROM dbo.bookings b WHERE b.space_id = @s8 AND b.requested_start_time = @w8b)
    INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status)
    VALUES (@s8, @rq, @w8b, DATEADD(hour, 2, @w8b), 'meeting', 10, 'pending');

-- PB13: S9 window W9 (c13 ack repair; advisory M9 overlaps, acks missing)
IF NOT EXISTS (SELECT 1 FROM dbo.bookings b WHERE b.space_id = @s9 AND b.requested_start_time = @w9)
    INSERT INTO dbo.bookings (space_id, requester_id, requested_start_time, requested_end_time, purpose, expected_participants, status)
    VALUES (@s9, @rq, @w9, DATEADD(hour, 2, @w9), 'meeting', 10, 'pending');

PRINT 'T13-SETUP-OK: TEST-13 fixture ready (1 dept, 2 users, 9 spaces, 2 advisories, 6 pending bookings).';
