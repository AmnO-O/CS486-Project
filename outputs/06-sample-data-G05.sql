SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Sample Data Script (Task 06)
-- Dependency: Must run AFTER outputs/05-db-definition-G05.sql
-- Target: SQL Server 2019+
-- Idempotency: Cleanup-and-reseed using T06- / t06_ markers
--             + IF NOT EXISTS for shared lookup tables
-- ============================================================

-- ============================================================
-- SECTION 1: IDEMPOTENT CLEANUP
-- Remove prior Task 06 rows in reverse FK order
-- ============================================================
PRINT '=== SECTION 1: IDEMPOTENT CLEANUP ===';
GO

DELETE FROM [dbo].[space_facilities]
WHERE [space_id] IN (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%');

DELETE FROM [dbo].[maintenances]
WHERE [space_id] IN (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%');

DELETE FROM [dbo].[bookings]
WHERE [space_id] IN (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%');

DELETE FROM [dbo].[spaces]
WHERE [space_code] LIKE 'T06-%';

DELETE FROM [dbo].[users]
WHERE [email] LIKE 't06_%';
GO

-- ============================================================
-- SECTION 2: DEPARTMENTS (guarded insert by natural key)
-- ============================================================
PRINT '=== SECTION 2: DEPARTMENTS ===';
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School of Computer Science')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School of Computer Science');

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Mathematics');

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Physics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Physics');

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Faculty Administration')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Faculty Administration');
GO

-- ============================================================
-- SECTION 3: USERS (all 6 roles, mixed account_status)
-- ============================================================
PRINT '=== SECTION 3: USERS ===';
GO

DECLARE @dept_cs INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @dept_math INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @dept_phys INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Physics');
DECLARE @dept_admin INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty Administration');

IF @dept_cs IS NULL OR @dept_math IS NULL OR @dept_phys IS NULL OR @dept_admin IS NULL
    THROW 51000, 'Setup failed: one or more departments not found.', 1;

-- Note: Active users for normal workflows
IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_alice.wang@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_alice.wang@university.edu', N'Alice Wang', N'+84-912-345-001', 'lecturer', @dept_cs, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_bob.chen@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_bob.chen@university.edu', N'Bob Chen', N'+84-912-345-002', 'student', @dept_cs, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_carol.liu@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_carol.liu@university.edu', N'Carol Liu', N'+84-912-345-003', 'teaching_assistant', @dept_cs, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_david.smith@university.edu', N'David Smith', N'+84-912-345-004', 'facility_staff', @dept_admin, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_eve.johnson@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_eve.johnson@university.edu', N'Eve Johnson', N'+84-912-345-005', 'department_admin', @dept_math, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_frank.brown@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_frank.brown@university.edu', N'Frank Brown', N'+84-912-345-006', 'facility_manager', @dept_cs, 'active');

-- Non-active users for status coverage
IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_grace.lee@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_grace.lee@university.edu', N'Grace Lee', N'+84-912-345-007', 'lecturer', @dept_phys, 'inactive');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_henry.kim@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_henry.kim@university.edu', N'Henry Kim', N'+84-912-345-008', 'student', @dept_cs, 'suspended');
GO

-- ============================================================
-- SECTION 4: SPACES (all 6 space_types, all 5 current_statuses)
-- ============================================================
PRINT '=== SECTION 4: SPACES ===';
GO

-- Main Auditorium (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-001')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-AUD-001', N'Main Auditorium', 'auditorium', N'Building A', N'Floor 1', N'101', 200, 'available', N'Maximum 200 persons. Food and drinks prohibited. AV equipment must be operated by authorized staff.');

-- Lecture Room 1 (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-101', N'Lecture Room 1', 'classroom', N'Building A', N'Floor 1', N'102', 50, 'available', N'Standard lecture room. Whiteboard available. No food.');

-- Lecture Room 2 (under_maintenance)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-102')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-102', N'Lecture Room 2', 'classroom', N'Building A', N'Floor 2', N'201', 45, 'under_maintenance', N'Under maintenance — AC and furniture repairs in progress.');

-- Computer Lab 1 (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-201', N'Computer Lab 1', 'computer_lab', N'Building B', N'Floor 2', N'201', 30, 'available', N'30 workstations. No food or drinks. Software must be pre-approved.');

-- Computer Lab 2 (temporarily_closed)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-202', N'Computer Lab 2', 'computer_lab', N'Building A', N'Floor 2', N'202', 25, 'temporarily_closed', N'Temporarily closed for renovation.');

-- Project Lab Alpha (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-PL-001')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-PL-001', N'Project Lab Alpha', 'project_lab', N'Building B', N'Floor 2', N'210', 20, 'available', N'Project lab for group work. Livestreaming equipment available.');

-- Meeting Room 1 (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-MR-101', N'Meeting Room 1', 'meeting_room', N'Building C', N'Floor 1', N'101', 12, 'available', N'Small meeting room. Whiteboard and projector available.');

-- Meeting Room 2 (retired)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-102')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-MR-102', N'Meeting Room 2', 'meeting_room', N'Building B', N'Floor 1', N'102', 8, 'retired', N'This room is no longer available for booking.');

-- Student Hub (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-SW-001', N'Student Hub', 'student_workspace', N'Building D', N'Floor 1', N'001', 40, 'available', N'Open student workspace. Group work encouraged. No loud music.');

-- Small Auditorium (available)
IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-002')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-AUD-002', N'Small Auditorium', 'auditorium', N'Building C', N'Floor 1', N'001', 100, 'available', N'Small auditorium seating 100. Suitable for seminars and workshops.');
GO

-- ============================================================
-- SECTION 5: FACILITIES (guarded insert by natural key)
-- ============================================================
PRINT '=== SECTION 5: FACILITIES ===';
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[facilities] WHERE [name] = N'Projector')
    INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Projector');

IF NOT EXISTS (SELECT 1 FROM [dbo].[facilities] WHERE [name] = N'Whiteboard')
    INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Whiteboard');

IF NOT EXISTS (SELECT 1 FROM [dbo].[facilities] WHERE [name] = N'Microphone')
    INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Microphone');

IF NOT EXISTS (SELECT 1 FROM [dbo].[facilities] WHERE [name] = N'Computer')
    INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Computer');

IF NOT EXISTS (SELECT 1 FROM [dbo].[facilities] WHERE [name] = N'Livestreaming Equipment')
    INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Livestreaming Equipment');

IF NOT EXISTS (SELECT 1 FROM [dbo].[facilities] WHERE [name] = N'Air Conditioner')
    INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Air Conditioner');
GO

-- ============================================================
-- SECTION 6: SPACE FACILITIES (junction table)
-- ============================================================
PRINT '=== SECTION 6: SPACE FACILITIES ===';
GO

-- Map Main Auditorium
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 2
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-AUD-001' AND f.[name] = N'Projector'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 4
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-AUD-001' AND f.[name] = N'Microphone'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 2
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-AUD-001' AND f.[name] = N'Air Conditioner'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

-- Map Lecture Room 1
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-CL-101' AND f.[name] = N'Projector'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-CL-101' AND f.[name] = N'Whiteboard'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-CL-101' AND f.[name] = N'Air Conditioner'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

-- Map Computer Lab 1
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 30
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-CL-201' AND f.[name] = N'Computer'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-CL-201' AND f.[name] = N'Projector'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-CL-201' AND f.[name] = N'Whiteboard'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

-- Map Project Lab Alpha
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 10
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-PL-001' AND f.[name] = N'Computer'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-PL-001' AND f.[name] = N'Whiteboard'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-PL-001' AND f.[name] = N'Livestreaming Equipment'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

-- Map Meeting Room 1
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-MR-101' AND f.[name] = N'Projector'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 1
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-MR-101' AND f.[name] = N'Whiteboard'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

-- Map Student Hub
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 5
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-SW-001' AND f.[name] = N'Computer'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
SELECT s.[space_id], f.[facility_id], 2
FROM [dbo].[spaces] s, [dbo].[facilities] f
WHERE s.[space_code] = 'T06-SW-001' AND f.[name] = N'Whiteboard'
AND NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] x WHERE x.[space_id] = s.[space_id] AND x.[facility_id] = f.[facility_id]);
GO

-- ============================================================
-- SECTION 7: MAINTENANCES
-- ============================================================
PRINT '=== SECTION 7: MAINTENANCES ===';
GO

DECLARE @m_space_aud1 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-001');
DECLARE @m_space_cl102 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-102');
DECLARE @m_space_sw001 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001');
DECLARE @m_user_david INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');
DECLARE @m_user_frank INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_frank.brown@university.edu');
DECLARE @m_user_alice INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_alice.wang@university.edu');

IF @m_space_aud1 IS NULL OR @m_space_cl102 IS NULL OR @m_space_sw001 IS NULL
    THROW 51000, 'Setup failed: required space(s) not found for maintenance seed.', 1;
IF @m_user_david IS NULL OR @m_user_frank IS NULL OR @m_user_alice IS NULL
    THROW 51000, 'Setup failed: required user(s) not found for maintenance seed.', 1;

-- Maintenance 1: Resolved — broken projector on Main Auditorium (past)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @m_space_aud1 AND [start_time] = '2026-06-16 08:00' AND [problem_description] LIKE N'%projector%')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
    VALUES (@m_space_aud1, @m_user_alice, @m_user_david, N'Projector displaying distorted colors — likely bulb or lens issue', '2026-06-16 08:00', '2026-06-16 17:00', 'resolved', N'Replaced projector bulb and calibrated lens. Tested successfully.');

-- Maintenance 2: Open — AC failure on Lecture Room 2 (ongoing, space = under_maintenance)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @m_space_cl102 AND [start_time] = '2026-06-19 10:00' AND [problem_description] LIKE N'%AC%')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
    VALUES (@m_space_cl102, @m_user_alice, @m_user_frank, N'Air conditioning not cooling — temperature exceeds 30°C in the room', '2026-06-19 10:00', NULL, 'open', NULL);

-- Maintenance 3: In-progress — damaged furniture on Lecture Room 2 (concurrent with #2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @m_space_cl102 AND [start_time] = '2026-06-19 14:00' AND [problem_description] LIKE N'%furniture%')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
    VALUES (@m_space_cl102, @m_user_frank, @m_user_david, N'Three desks have broken legs and five chairs are unstable — risk of injury', '2026-06-19 14:00', NULL, 'in_progress', NULL);

-- Maintenance 4: Resolved — cleaning issue on Student Hub (past, soft-deleted)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @m_space_sw001 AND [start_time] = '2026-06-14 09:00' AND [problem_description] LIKE N'%cleaning%')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note], [is_deleted])
    VALUES (@m_space_sw001, @m_user_alice, NULL, N'Student Hub floor and tables need urgent cleaning after weekend event', '2026-06-14 09:00', '2026-06-14 11:00', 'resolved', N'Cleaning completed. All surfaces sanitized and trash removed.', 1);

-- Maintenance 5: In-progress — network problem on Main Auditorium (ongoing, space = available)
-- Used for BR4 expected-error test (overlapping unresolved maintenance)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @m_space_aud1 AND [start_time] = '2026-06-20 08:00' AND [problem_description] LIKE N'%network%')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
    VALUES (@m_space_aud1, @m_user_frank, @m_user_david, N'Network connectivity issues — WiFi and wired connections dropping intermittently', '2026-06-20 08:00', NULL, 'in_progress', NULL);
GO

-- ============================================================
-- SECTION 8: BOOKINGS (all 7 statuses, all 7 purposes)
-- ============================================================
PRINT '=== SECTION 8: BOOKINGS ===';
GO

DECLARE @b_space_aud1 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-001');
DECLARE @b_space_cl101 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
DECLARE @b_space_cl201 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');
DECLARE @b_space_mr101 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101');
DECLARE @b_space_sw001 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001');
DECLARE @b_space_pl001 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-PL-001');
DECLARE @b_space_aud2 INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-002');

DECLARE @b_user_alice INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_alice.wang@university.edu');
DECLARE @b_user_bob INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_bob.chen@university.edu');
DECLARE @b_user_carol INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_carol.liu@university.edu');
DECLARE @b_user_david INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');
DECLARE @b_user_eve INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_eve.johnson@university.edu');
DECLARE @b_user_frank INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_frank.brown@university.edu');
DECLARE @b_user_grace INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_grace.lee@university.edu');

IF @b_space_aud1 IS NULL OR @b_space_cl101 IS NULL OR @b_space_cl201 IS NULL
    OR @b_space_mr101 IS NULL OR @b_space_sw001 IS NULL OR @b_space_pl001 IS NULL OR @b_space_aud2 IS NULL
    THROW 51000, 'Setup failed: required space(s) not found for booking seed.', 1;

IF @b_user_alice IS NULL OR @b_user_bob IS NULL OR @b_user_carol IS NULL
    OR @b_user_david IS NULL OR @b_user_eve IS NULL OR @b_user_frank IS NULL OR @b_user_grace IS NULL
    THROW 51000, 'Setup failed: required user(s) not found for booking seed.', 1;

-- Booking 1: Completed — lecture on Main Auditorium (past)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note], [checked_in_by], [actual_start_time], [initial_condition], [actual_end_time], [final_condition], [usage_notes])
VALUES (@b_space_aud1, @b_user_alice, '2026-06-18 09:00', '2026-06-18 11:00', 'lecture', 150, 'completed',
        @b_user_david, '2026-06-16 10:00', N'Approved for CS101 lecture.',
        @b_user_david, '2026-06-18 09:05', N'Clean and tidy, all seats arranged properly.',
        '2026-06-18 11:10', N'Minor mess, projector left on. Some papers on floor.', N'Lecture went well — students participated actively.');

-- Booking 2: Pending — examination on Computer Lab 1 (future)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@b_space_cl201, @b_user_bob, '2026-07-01 09:00', '2026-07-01 12:00', 'examination', 25, 'pending');

-- Booking 3: Approved — lecture on Lecture Room 1 (future)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note])
VALUES (@b_space_cl101, @b_user_carol, '2026-06-25 08:00', '2026-06-25 10:00', 'lecture', 40, 'approved',
        @b_user_david, '2026-06-23 14:00', N'Approved for CS201 tutorial session.');

-- Booking 4: Pending — workshop on Lecture Room 1 (future, no overlap with #3)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@b_space_cl101, @b_user_alice, '2026-07-02 10:00', '2026-07-02 12:00', 'workshop', 20, 'pending');

-- Booking 5: No-show — seminar on Computer Lab 1 (past, requester never arrived)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@b_space_cl201, @b_user_bob, '2026-06-18 13:00', '2026-06-18 15:00', 'seminar', 20, 'no_show');

-- Booking 6: Cancelled — meeting on Meeting Room 1 (past)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@b_space_mr101, @b_user_eve, '2026-06-16 10:00', '2026-06-16 11:00', 'meeting', 5, 'cancelled');

-- Booking 7: Checked-in — student activity on Student Hub (today, ongoing session)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note], [checked_in_by], [actual_start_time], [initial_condition])
VALUES (@b_space_sw001, @b_user_bob, '2026-06-20 14:00', '2026-06-20 17:00', 'student_activity', 30, 'checked_in',
        @b_user_frank, '2026-06-19 09:00', N'Approved for student club weekly meetup.',
        @b_user_david, '2026-06-20 14:10', N'Clean, tables arranged for group work. Whiteboard markers available.');

-- Booking 8: Pending — administrative event on Project Lab Alpha (future)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@b_space_pl001, @b_user_eve, '2026-07-03 10:00', '2026-07-03 12:00', 'administrative_event', 10, 'pending');

-- Booking 9: Rejected — seminar on Small Auditorium (past, with rejection reason)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note], [rejection_reason])
VALUES (@b_space_aud2, @b_user_grace, '2026-06-15 14:00', '2026-06-15 16:00', 'seminar', 60, 'rejected',
        @b_user_david, '2026-06-14 09:00', N'Insufficient staff for coordination.', N'Seminar requires additional AV support not available on that date.');

-- Booking 10: Completed — student activity on Project Lab Alpha (past, soft-deleted)
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note], [checked_in_by], [actual_start_time], [initial_condition], [actual_end_time], [final_condition], [usage_notes], [is_deleted])
VALUES (@b_space_pl001, @b_user_bob, '2026-06-10 14:00', '2026-06-10 16:00', 'student_activity', 5, 'completed',
        @b_user_david, '2026-06-09 10:00', N'Approved.',
        @b_user_david, '2026-06-10 14:00', N'Neat and tidy.',
        '2026-06-10 16:00', N'Good condition, no issues.', N'Small group project meeting — all equipment returned.', 1);
GO

-- ============================================================
-- SECTION 9: EXPECTED-ERROR TEST CASES
-- Every test is wrapped in TRY/CATCH so the script continues.
-- Setup is self-contained within each test block.
-- ============================================================
PRINT '=== SECTION 9: EXPECTED-ERROR TEST CASES ===';
GO

-- ============================================================
-- TEST 9.1: BR1 — Overlap prevention
-- Attempt to INSERT an approved booking overlapping an existing
-- approved booking (Booking #3) on the same space (T06-CL-101).
-- ============================================================
PRINT 'EXPECTED_ERROR: BR1 — overlapping approved booking interval';
GO
BEGIN TRY
    DECLARE @br1_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
    DECLARE @br1_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_bob.chen@university.edu');
    DECLARE @br1_approver_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');

    IF @br1_space_id IS NULL OR @br1_user_id IS NULL OR @br1_approver_id IS NULL
        THROW 51001, 'BR1 setup: missing lookup IDs.', 1;

    -- Booking #3 is approved on T06-CL-101 from 2026-06-25 08:00 to 10:00
    -- This new booking overlaps: 09:00 to 11:00 on the same day
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note])
    VALUES (@br1_space_id, @br1_user_id, '2026-06-25 09:00', '2026-06-25 11:00', 'lecture', 30, 'approved',
            @br1_approver_id, '2026-06-24 10:00', N'Intentional overlap test.');

    PRINT '  FAIL: BR1 test did not raise expected overlap error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.2: BR2 — Unavailable space (under_maintenance)
-- Attempt to INSERT a booking on T06-CL-102 (under_maintenance).
-- ============================================================
PRINT 'EXPECTED_ERROR: BR2 — booking on under_maintenance space';
GO
BEGIN TRY
    DECLARE @br2a_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-102');
    DECLARE @br2a_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_alice.wang@university.edu');

    IF @br2a_space_id IS NULL OR @br2a_user_id IS NULL
        THROW 51002, 'BR2a setup: missing lookup IDs.', 1;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br2a_space_id, @br2a_user_id, '2026-07-05 09:00', '2026-07-05 11:00', 'lecture', 20, 'pending');

    PRINT '  FAIL: BR2 test (under_maintenance) did not raise expected error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.3: BR2 — Unavailable space (retired)
-- Attempt to INSERT a booking on T06-MR-102 (retired).
-- ============================================================
PRINT 'EXPECTED_ERROR: BR2 — booking on retired space';
GO
BEGIN TRY
    DECLARE @br2b_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-102');
    DECLARE @br2b_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_bob.chen@university.edu');

    IF @br2b_space_id IS NULL OR @br2b_user_id IS NULL
        THROW 51003, 'BR2b setup: missing lookup IDs.', 1;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br2b_space_id, @br2b_user_id, '2026-07-10 10:00', '2026-07-10 11:00', 'meeting', 5, 'pending');

    PRINT '  FAIL: BR2 test (retired) did not raise expected error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.4: BR3 — Capacity limit
-- Attempt to INSERT a booking with expected_participants > capacity.
-- T06-MR-101 has capacity 12; try with 20 participants.
-- ============================================================
PRINT 'EXPECTED_ERROR: BR3 — expected participants exceed capacity';
GO
BEGIN TRY
    DECLARE @br3_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101');
    DECLARE @br3_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_carol.liu@university.edu');

    IF @br3_space_id IS NULL OR @br3_user_id IS NULL
        THROW 51004, 'BR3 setup: missing lookup IDs.', 1;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br3_space_id, @br3_user_id, '2026-07-15 14:00', '2026-07-15 16:00', 'workshop', 20, 'pending');

    PRINT '  FAIL: BR3 test did not raise expected capacity error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.5: BR4 — Unresolved maintenance blocks booking
-- Attempt to INSERT a booking on T06-AUD-001 that overlaps
-- with an in-progress maintenance (maintenance #5, started
-- 2026-06-20 08:00, still in_progress).
-- ============================================================
PRINT 'EXPECTED_ERROR: BR4 — overlapping unresolved maintenance';
GO
BEGIN TRY
    DECLARE @br4_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-001');
    DECLARE @br4_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_carol.liu@university.edu');
    DECLARE @br4_approver_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');

    IF @br4_space_id IS NULL OR @br4_user_id IS NULL OR @br4_approver_id IS NULL
        THROW 51005, 'BR4 setup: missing lookup IDs.', 1;

    -- Maintenance #5 is in_progress on T06-AUD-001 since 2026-06-20 08:00
    -- This booking (2026-06-20 09:00-11:00) overlaps.
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note])
    VALUES (@br4_space_id, @br4_user_id, '2026-06-20 09:00', '2026-06-20 11:00', 'seminar', 30, 'approved',
            @br4_approver_id, '2026-06-19 15:00', N'BR4 overlap test with active maintenance.');

    PRINT '  FAIL: BR4 test did not raise expected maintenance overlap error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.6: BR6 — Approval metadata missing
-- INSERT a pending booking, then UPDATE to 'approved' WITHOUT
-- approver_id, decision_time, and decision_note.
-- ============================================================
PRINT 'EXPECTED_ERROR: BR6 — missing approval metadata';
GO
BEGIN TRY
    DECLARE @br6_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-002');
    DECLARE @br6_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_alice.wang@university.edu');
    DECLARE @br6_booking_id INT;

    IF @br6_space_id IS NULL OR @br6_user_id IS NULL
        THROW 51006, 'BR6 setup: missing lookup IDs.', 1;

    -- Create a pending booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br6_space_id, @br6_user_id, '2026-08-01 09:00', '2026-08-01 11:00', 'seminar', 40, 'pending');

    SET @br6_booking_id = SCOPE_IDENTITY();

    -- Attempt to approve WITHOUT required metadata
    UPDATE [dbo].[bookings]
    SET [status] = 'approved'
    WHERE [booking_id] = @br6_booking_id;

    PRINT '  FAIL: BR6 test did not raise expected approval metadata error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.7: BR7 — Rejection reason missing
-- INSERT a pending booking, then UPDATE to 'rejected' WITHOUT
-- rejection_reason.
-- ============================================================
PRINT 'EXPECTED_ERROR: BR7 — missing rejection reason';
GO
BEGIN TRY
    DECLARE @br7_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-002');
    DECLARE @br7_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_bob.chen@university.edu');
    DECLARE @br7_approver_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');
    DECLARE @br7_booking_id INT;

    IF @br7_space_id IS NULL OR @br7_user_id IS NULL OR @br7_approver_id IS NULL
        THROW 51007, 'BR7 setup: missing lookup IDs.', 1;

    -- Create a pending booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br7_space_id, @br7_user_id, '2026-08-02 14:00', '2026-08-02 16:00', 'workshop', 20, 'pending');

    SET @br7_booking_id = SCOPE_IDENTITY();

    -- Attempt to reject WITHOUT rejection_reason
    UPDATE [dbo].[bookings]
    SET [status] = 'rejected',
        [approver_id] = @br7_approver_id,
        [decision_time] = '2026-08-01 10:00',
        [decision_note] = N'Rejected due to scheduling conflict.'
    WHERE [booking_id] = @br7_booking_id;

    PRINT '  FAIL: BR7 test did not raise expected rejection reason error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.8: BR8/BR9 — Check-in enforcement
-- INSERT a booking as approved, then UPDATE to 'checked_in'
-- WITHOUT actual_start_time, checked_in_by, and initial_condition.
-- ============================================================
PRINT 'EXPECTED_ERROR: BR8/BR9 — missing check-in fields';
GO
BEGIN TRY
    DECLARE @br8_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-002');
    DECLARE @br8_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_carol.liu@university.edu');
    DECLARE @br8_approver_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');
    DECLARE @br8_booking_id INT;

    IF @br8_space_id IS NULL OR @br8_user_id IS NULL OR @br8_approver_id IS NULL
        THROW 51008, 'BR8 setup: missing lookup IDs.', 1;

    -- Create an approved booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note])
    VALUES (@br8_space_id, @br8_user_id, '2026-08-03 10:00', '2026-08-03 12:00', 'lecture', 30, 'approved',
            @br8_approver_id, '2026-08-02 14:00', N'Approved for BR8 test.');

    SET @br8_booking_id = SCOPE_IDENTITY();

    -- Attempt to check in WITHOUT required fields
    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in'
    WHERE [booking_id] = @br8_booking_id;

    PRINT '  FAIL: BR8/BR9 check-in test did not raise expected error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.9: BR8/BR9 — Completion enforcement
-- INSERT a booking as checked_in with all required fields,
-- then UPDATE to 'completed' WITHOUT actual_end_time and
-- final_condition.
-- ============================================================
PRINT 'EXPECTED_ERROR: BR8/BR9 — missing completion fields';
GO
BEGIN TRY
    DECLARE @br9_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-002');
    DECLARE @br9_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_alice.wang@university.edu');
    DECLARE @br9_approver_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_frank.brown@university.edu');
    DECLARE @br9_checkin_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_david.smith@university.edu');
    DECLARE @br9_booking_id INT;

    IF @br9_space_id IS NULL OR @br9_user_id IS NULL OR @br9_approver_id IS NULL OR @br9_checkin_id IS NULL
        THROW 51009, 'BR9 setup: missing lookup IDs.', 1;

    -- Create a checked_in booking with all required check-in fields
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [approver_id], [decision_time], [decision_note], [checked_in_by], [actual_start_time], [initial_condition])
    VALUES (@br9_space_id, @br9_user_id, '2026-08-04 09:00', '2026-08-04 11:00', 'workshop', 20, 'checked_in',
            @br9_approver_id, '2026-08-03 10:00', N'Approved for BR9 test.',
            @br9_checkin_id, '2026-08-04 09:05', N'All good ready for session.');

    SET @br9_booking_id = SCOPE_IDENTITY();

    -- Attempt to complete WITHOUT actual_end_time and final_condition
    UPDATE [dbo].[bookings]
    SET [status] = 'completed'
    WHERE [booking_id] = @br9_booking_id;

    PRINT '  FAIL: BR8/BR9 completion test did not raise expected error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.10: Declarative constraint — invalid user role
-- Attempt to INSERT a user with role not in the CHECK enum.
-- ============================================================
PRINT 'EXPECTED_ERROR: CK_users_role — invalid role value';
GO
BEGIN TRY
    DECLARE @br10_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');

    IF @br10_dept_id IS NULL
        THROW 51010, 'BR10 setup: missing lookup IDs.', 1;

    INSERT INTO [dbo].[users] ([email], [full_name], [role], [department_id])
    VALUES ('t06_invalid_role@university.edu', N'Invalid Role User', 'admin', @br10_dept_id);

    PRINT '  FAIL: Invalid role test did not raise expected CHECK error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.11: Declarative constraint — invalid time range
-- Attempt to INSERT a booking where requested_end_time <=
-- requested_start_time.
-- ============================================================
PRINT 'EXPECTED_ERROR: CK_bookings_requested_end_time — end <= start';
GO
BEGIN TRY
    DECLARE @br11_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101');
    DECLARE @br11_user_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_eve.johnson@university.edu');

    IF @br11_space_id IS NULL OR @br11_user_id IS NULL
        THROW 51011, 'BR11 setup: missing lookup IDs.', 1;

    -- End time equals start time (should fail)
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br11_space_id, @br11_user_id, '2026-08-10 10:00', '2026-08-10 10:00', 'meeting', 5, 'pending');

    PRINT '  FAIL: Invalid time range test did not raise expected CHECK error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.12: Declarative constraint — duplicate email
-- Attempt to INSERT a user with an email that already exists.
-- ============================================================
PRINT 'EXPECTED_ERROR: UQ_users_email — duplicate email';
GO
BEGIN TRY
    DECLARE @br12_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');

    IF @br12_dept_id IS NULL
        THROW 51012, 'BR12 setup: missing lookup IDs.', 1;

    -- t06_alice.wang@university.edu already exists
    INSERT INTO [dbo].[users] ([email], [full_name], [role], [department_id])
    VALUES ('t06_alice.wang@university.edu', N'Alice Wang Duplicate', 'student', @br12_dept_id);

    PRINT '  FAIL: Duplicate email test did not raise expected UNIQUE error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- TEST 9.13: Declarative constraint — duplicate space code
-- Attempt to INSERT a space with an existing space_code.
-- ============================================================
PRINT 'EXPECTED_ERROR: UQ_spaces_space_code — duplicate space_code';
GO
BEGIN TRY
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status])
    VALUES ('T06-AUD-001', N'Duplicate Auditorium', 'auditorium', N'Building X', N'Floor 1', N'001', 50, 'available');

    PRINT '  FAIL: Duplicate space_code test did not raise expected UNIQUE error.';
END TRY
BEGIN CATCH
    PRINT '  CAUGHT: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- SECTION 10: VERIFICATION QUERIES
-- ============================================================
PRINT '=== SECTION 10: VERIFICATION QUERIES ===';
GO

-- ============================================================
-- VERIFY 10.1: Row counts per table
-- ============================================================
PRINT '--- VERIFY: Row counts ---';
SELECT 'departments' AS [table], COUNT(*) AS [row_count] FROM [dbo].[departments]
UNION ALL
SELECT 'users', COUNT(*) FROM [dbo].[users]
UNION ALL
SELECT 'spaces', COUNT(*) FROM [dbo].[spaces]
UNION ALL
SELECT 'facilities', COUNT(*) FROM [dbo].[facilities]
UNION ALL
SELECT 'space_facilities', COUNT(*) FROM [dbo].[space_facilities]
UNION ALL
SELECT 'bookings', COUNT(*) FROM [dbo].[bookings]
UNION ALL
SELECT 'maintenances', COUNT(*) FROM [dbo].[maintenances]
ORDER BY [table];
GO

-- ============================================================
-- VERIFY 10.2: BR12 — Audit trail populated
-- ============================================================
PRINT '--- VERIFY: BR12 audit timestamps ---';
SELECT TOP 3 'departments' AS [source], [department_id] AS [id], [created_at], [updated_at] FROM [dbo].[departments]
UNION ALL
SELECT TOP 3 'users', [user_id], [created_at], [updated_at] FROM [dbo].[users]
UNION ALL
SELECT TOP 3 'spaces', [space_id], [created_at], [updated_at] FROM [dbo].[spaces]
UNION ALL
SELECT TOP 3 'bookings', [booking_id], [created_at], [updated_at] FROM [dbo].[bookings]
UNION ALL
SELECT TOP 3 'maintenances', [maintenance_id], [created_at], [updated_at] FROM [dbo].[maintenances];
GO

-- ============================================================
-- VERIFY 10.3: BR11/BR13 — Soft-deleted rows (historical preservation)
-- ============================================================
PRINT '--- VERIFY: BR11/BR13 soft-deleted rows ---';
SELECT 'bookings' AS [table], [booking_id] AS [id], [is_deleted], [status], [requested_start_time], [space_id]
FROM [dbo].[bookings] WHERE [is_deleted] = 1
UNION ALL
SELECT 'maintenances', [maintenance_id], [is_deleted], [status], [start_time], [space_id]
FROM [dbo].[maintenances] WHERE [is_deleted] = 1;
GO

-- ============================================================
-- VERIFY 10.4: BR14 — Booking history report
-- Show past completed bookings for space T06-AUD-001
-- ============================================================
PRINT '--- VERIFY: BR14 booking history (Main Auditorium) ---';
SELECT b.[booking_id], u.[full_name] AS [requester], b.[purpose], b.[requested_start_time], b.[requested_end_time], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE b.[space_id] = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-001')
  AND b.[requested_end_time] < GETDATE()
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];
GO

-- ============================================================
-- VERIFY 10.5: BR14 — Upcoming bookings report
-- ============================================================
PRINT '--- VERIFY: BR14 upcoming bookings ---';
SELECT b.[booking_id], s.[space_code], s.[space_name], u.[full_name] AS [requester], b.[purpose], b.[requested_start_time], b.[requested_end_time], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE b.[requested_start_time] > GETDATE()
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];
GO

-- ============================================================
-- VERIFY 10.6: BR14 — Spaces currently under maintenance
-- ============================================================
PRINT '--- VERIFY: BR14 spaces under maintenance ---';
SELECT s.[space_code], s.[space_name], s.[building], s.[room_number], m.[maintenance_id], m.[problem_description], m.[status], m.[start_time]
FROM [dbo].[spaces] s
INNER JOIN [dbo].[maintenances] m ON s.[space_id] = m.[space_id]
WHERE s.[current_status] = 'under_maintenance'
  AND m.[is_deleted] = 0
  AND m.[status] IN ('open', 'in_progress')
ORDER BY s.[space_code], m.[start_time];
GO

-- ============================================================
-- VERIFY 10.7: BR14 — No-show bookings report
-- ============================================================
PRINT '--- VERIFY: BR14 no-show bookings ---';
SELECT b.[booking_id], s.[space_code], u.[full_name] AS [requester], b.[purpose], b.[requested_start_time], b.[requested_end_time]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE b.[status] = 'no_show'
  AND b.[is_deleted] = 0;
GO

-- ============================================================
-- VERIFY 10.8: Status distribution summary
-- ============================================================
PRINT '--- VERIFY: Booking status distribution ---';
SELECT [status], COUNT(*) AS [count] FROM [dbo].[bookings] GROUP BY [status] ORDER BY [status];
GO

PRINT '--- VERIFY: Maintenance status distribution ---';
SELECT [status], COUNT(*) AS [count] FROM [dbo].[maintenances] GROUP BY [status] ORDER BY [status];
GO

-- ============================================================
-- VERIFY 10.9: Constraint counts per table
-- ============================================================
PRINT '--- VERIFY: Space type distribution ---';
SELECT [space_type], COUNT(*) AS [count] FROM [dbo].[spaces] GROUP BY [space_type] ORDER BY [space_type];
GO

PRINT '--- VERIFY: User role distribution ---';
SELECT [role], COUNT(*) AS [count] FROM [dbo].[users] GROUP BY [role] ORDER BY [role];
GO

PRINT '=== TASK 06 SAMPLE DATA GENERATION COMPLETE ===';
GO
