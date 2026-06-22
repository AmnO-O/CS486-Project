SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 06: Sample Data Preparation
-- Dependencies: Must run after outputs/05-db-definition-G05.sql
-- Target: SQL Server 2019+
-- ============================================================

-- ============================================================
-- Assumptions and Design Decisions
-- ============================================================
-- 1. Date-range rationale:
--    - Past dates (2026-06-01 ~ 2026-06-15): completed, no-show,
--      rejected, soft-deleted records.
--    - Current date (2026-06-22): checked-in session (in-progress
--      today).
--    - Future dates (2026-07-01 ~ 2026-07-20): pending, approved,
--      cancelled bookings; future maintenance records.
-- 2. Space-status coverage: all five statuses represented across
--    nine spaces. Spaces 5 (under_maintenance), 7 (temporarily_closed),
--    8 (retired) cannot accept valid bookings.
-- 3. Maintenance concurrency: spaces 5 and 9 have open maintenance;
--    space 6 has in_progress maintenance (starting 2026-07-20);
--    space 3 has resolved maintenance.
-- 4. Soft-delete: booking 10 and maintenance 5 use is_deleted = 1.
-- 5. FK-safe ordering: data inserted in dependency order
--    (departments → users → spaces → facilities → space_facilities →
--    maintenances → bookings).
-- 6. Idempotence strategy: Cleanup-and-reseed. All T06-owned rows
--    are identified by space_code prefix 'T06-' or email prefix
--    't06.' and are deleted in reverse FK order before reseeding.
-- 7. Expected-error tests: each isolated with BEGIN TRY/CATCH,
--    prerequisite lookups validated before the failing statement.
-- ============================================================

-- ============================================================
-- SECTION 0: Idempotent Cleanup (reverse FK order)
-- ============================================================
PRINT 'SECTION 0: Cleanup previous T06 sample data';
GO

DELETE FROM [dbo].[bookings]
WHERE [space_id] IN (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%');

DELETE FROM [dbo].[maintenances]
WHERE [space_id] IN (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%');

DELETE FROM [dbo].[space_facilities]
WHERE [space_id] IN (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%');

DELETE FROM [dbo].[spaces]
WHERE [space_code] LIKE 'T06-%';

DELETE FROM [dbo].[users]
WHERE [email] LIKE 't06.%';

GO

-- ============================================================
-- SECTION 1: Departments
-- ============================================================
PRINT 'SECTION 1: Departments';
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School of Computer Science')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School of Computer Science');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Mathematics');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Physics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Physics');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Faculty of Engineering');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Business Administration')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Business Administration');

GO

-- Lookup variables
DECLARE @cs_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @math_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @physics_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Physics');
DECLARE @eng_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering');
DECLARE @biz_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Business Administration');

IF @cs_dept_id IS NULL OR @math_dept_id IS NULL OR @physics_dept_id IS NULL OR @eng_dept_id IS NULL OR @biz_dept_id IS NULL
    THROW 51000, 'Setup failed: department lookup returned NULL.', 1;

GO

-- ============================================================
-- SECTION 2: Users (all roles, mixed account statuses)
-- ============================================================
PRINT 'SECTION 2: Users';
GO

DECLARE @cs_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @math_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @physics_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Physics');
DECLARE @eng_dept_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.student1@university.edu', N'Alice Johnson', N'123-456-7890', 'student', @cs_dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.lecturer1@university.edu', N'Prof. Robert Chen', N'123-456-7891', 'lecturer', @cs_dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.ta1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.ta1@university.edu', N'Maria Santos', NULL, 'teaching_assistant', @cs_dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.facilitystaff1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.facilitystaff1@university.edu', N'David Kim', N'123-456-7892', 'facility_staff', @cs_dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.deptadmin1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.deptadmin1@university.edu', N'Sarah Williams', N'123-456-7893', 'department_admin', @math_dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.facilitymgr1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.facilitymgr1@university.edu', N'James Taylor', N'123-456-7894', 'facility_manager', @cs_dept_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.student2@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.student2@university.edu', N'Emily Davis', NULL, 'student', @physics_dept_id, 'inactive');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06.student3@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.student3@university.edu', N'Michael Brown', N'123-456-7895', 'student', @eng_dept_id, 'suspended');

GO

-- Lookup variables
DECLARE @student1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu');
DECLARE @lecturer1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu');
DECLARE @ta1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.ta1@university.edu');
DECLARE @staff1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitystaff1@university.edu');
DECLARE @admin1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.deptadmin1@university.edu');
DECLARE @mgr1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitymgr1@university.edu');
DECLARE @student2_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student2@university.edu');
DECLARE @student3_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student3@university.edu');

IF @student1_id IS NULL OR @lecturer1_id IS NULL OR @ta1_id IS NULL OR @staff1_id IS NULL OR @admin1_id IS NULL OR @mgr1_id IS NULL OR @student2_id IS NULL OR @student3_id IS NULL
    THROW 51001, 'Setup failed: user lookup returned NULL.', 1;

GO

-- ============================================================
-- SECTION 3: Spaces (all types, all statuses)
-- ============================================================
PRINT 'SECTION 3: Spaces';
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-AUD-101', N'Main Auditorium', 'auditorium', N'Building A', N'1', N'101', 200, 'available', N'Priority given to lectures and examinations. No food or drinks.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-201', N'Classroom 201', 'classroom', N'Building A', N'2', N'201', 40, 'available', N'Standard classroom. Whiteboard available.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-202', N'Classroom 202', 'classroom', N'Building B', N'2', N'202', 35, 'temporarily_closed', N'Under renovation. Not available for booking.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-301')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-301', N'Classroom 301', 'classroom', N'Building A', N'3', N'301', 50, 'retired', N'Decommissioned. Not available for booking.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-101', N'Classroom 101', 'classroom', N'Building B', N'1', N'101', 25, 'available', N'Small classroom. Suitable for tutorials and seminars.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-001')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-LAB-001', N'Computer Lab A', 'computer_lab', N'Building B', N'1', N'001', 30, 'available', N'Contains 20 workstations. ID required for access.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-002')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-LAB-002', N'Project Lab B', 'project_lab', N'Building B', N'2', N'002', 20, 'in_use', N'Project-based lab. Contains workstations and workbenches.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-MTG-001')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-MTG-001', N'Meeting Room 1', 'meeting_room', N'Building A', N'1', N'001', 10, 'under_maintenance', N'Small meeting room. Currently under maintenance.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-SW-001', N'Student Workspace', 'student_workspace', N'Building C', N'1', N'001', 15, 'available', N'Open student workspace. First-come-first-served policy for unbooked slots.');

GO

-- Lookup variables
DECLARE @space1_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @space2_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');
DECLARE @space3_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202');
DECLARE @space4_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-301');
DECLARE @space5_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
DECLARE @space6_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-001');
DECLARE @space7_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-002');
DECLARE @space8_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MTG-001');
DECLARE @space9_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001');

IF @space1_id IS NULL OR @space2_id IS NULL OR @space5_id IS NULL OR @space6_id IS NULL OR @space7_id IS NULL OR @space9_id IS NULL
    THROW 51002, 'Setup failed: space lookup returned NULL.', 1;

GO

-- ============================================================
-- SECTION 4: Facilities
-- ============================================================
PRINT 'SECTION 4: Facilities';
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

-- Lookup variables
DECLARE @fac_projector INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Projector');
DECLARE @fac_whiteboard INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Whiteboard');
DECLARE @fac_microphone INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Microphone');
DECLARE @fac_computer INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Computer');
DECLARE @fac_livestream INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Livestreaming Equipment');
DECLARE @fac_ac INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Air Conditioner');

IF @fac_projector IS NULL OR @fac_whiteboard IS NULL OR @fac_microphone IS NULL OR @fac_computer IS NULL OR @fac_livestream IS NULL OR @fac_ac IS NULL
    THROW 51003, 'Setup failed: facility lookup returned NULL.', 1;

GO

-- ============================================================
-- SECTION 5: Space Facilities
-- ============================================================
PRINT 'SECTION 5: Space Facilities';
GO

DECLARE @fac_projector INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Projector');
DECLARE @fac_whiteboard INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Whiteboard');
DECLARE @fac_microphone INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Microphone');
DECLARE @fac_computer INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Computer');
DECLARE @fac_livestream INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Livestreaming Equipment');
DECLARE @fac_ac INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Air Conditioner');

IF @fac_projector IS NULL OR @fac_whiteboard IS NULL OR @fac_microphone IS NULL OR @fac_computer IS NULL OR @fac_livestream IS NULL OR @fac_ac IS NULL
    THROW 51003, 'Setup failed: facility lookup returned NULL.', 1;

DECLARE @space1_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @space2_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');
DECLARE @space3_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202');
DECLARE @space4_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-301');
DECLARE @space5_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
DECLARE @space6_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-001');
DECLARE @space7_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-002');
DECLARE @space8_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MTG-001');
DECLARE @space9_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001');

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space1_id AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space1_id, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space1_id AND [facility_id] = @fac_microphone)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space1_id, @fac_microphone, 2);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space1_id AND [facility_id] = @fac_ac)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space1_id, @fac_ac, 2);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space1_id AND [facility_id] = @fac_livestream)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space1_id, @fac_livestream, 1);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space2_id AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space2_id, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space2_id AND [facility_id] = @fac_whiteboard)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space2_id, @fac_whiteboard, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space2_id AND [facility_id] = @fac_ac)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space2_id, @fac_ac, 1);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space5_id AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space5_id, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space5_id AND [facility_id] = @fac_whiteboard)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space5_id, @fac_whiteboard, 1);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space6_id AND [facility_id] = @fac_computer)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space6_id, @fac_computer, 20);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space6_id AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space6_id, @fac_projector, 1);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space7_id AND [facility_id] = @fac_computer)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space7_id, @fac_computer, 10);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space7_id AND [facility_id] = @fac_whiteboard)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space7_id, @fac_whiteboard, 1);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space8_id AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space8_id, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space8_id AND [facility_id] = @fac_whiteboard)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space8_id, @fac_whiteboard, 1);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space9_id AND [facility_id] = @fac_whiteboard)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space9_id, @fac_whiteboard, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space9_id AND [facility_id] = @fac_computer)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space9_id, @fac_computer, 5);

IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space3_id AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space3_id, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space3_id AND [facility_id] = @fac_whiteboard)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space3_id, @fac_whiteboard, 1);

GO

-- ============================================================
-- SECTION 6: Maintenances
-- ============================================================
PRINT 'SECTION 6: Maintenances';
GO

DECLARE @staff1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitystaff1@university.edu');
DECLARE @mgr1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitymgr1@university.edu');
DECLARE @lecturer1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu');

DECLARE @space8_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MTG-001');
DECLARE @space5_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
DECLARE @space6_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-001');
DECLARE @space9_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001');
DECLARE @space2_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');

-- Maintenance 1: Open maintenance on space 8 (meeting_room, under_maintenance)
-- Broken projector and damaged furniture
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @space8_id AND [problem_description] = N'Broken projector and damaged furniture' AND [status] = 'open')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@space8_id, @lecturer1_id, @staff1_id, N'Broken projector and damaged furniture', '2026-06-20 10:00:00', 'open');

-- Maintenance 2: Open maintenance on space 5 (classroom, available)
-- Air conditioning failure
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @space5_id AND [problem_description] = N'Air conditioning failure' AND [status] = 'open')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@space5_id, @lecturer1_id, @staff1_id, N'Air conditioning failure', '2026-07-01 08:00:00', 'open');

-- Maintenance 3: Resolved maintenance on space 6 (computer_lab)
-- Network connectivity issues
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @space6_id AND [problem_description] = N'Network connectivity issues' AND [status] = 'resolved')
BEGIN
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@space6_id, @lecturer1_id, @staff1_id, N'Network connectivity issues', '2026-06-05 09:00:00', 'open');

    UPDATE [dbo].[maintenances]
    SET [status] = 'resolved',
        [completion_time] = '2026-06-06 16:00:00',
        [result_note] = N'Router replaced and connectivity restored. All workstations tested.'
    WHERE [space_id] = @space6_id AND [problem_description] = N'Network connectivity issues';
END

-- Maintenance 4: In-progress maintenance on space 9 (student_workspace)
-- Damaged furniture (future start, so bookings before it are safe)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @space9_id AND [problem_description] = N'Damaged furniture' AND [status] = 'in_progress')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@space9_id, @lecturer1_id, @staff1_id, N'Damaged furniture', '2026-07-20 08:00:00', 'in_progress');

-- Maintenance 5: Soft-deleted resolved maintenance on space 2 (classroom)
-- Cleaning issues
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @space2_id AND [problem_description] = N'Cleaning issues' AND [is_deleted] = 1)
BEGIN
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@space2_id, @lecturer1_id, @staff1_id, N'Cleaning issues', '2026-06-01 08:00:00', 'open');

    UPDATE [dbo].[maintenances]
    SET [status] = 'resolved',
        [completion_time] = '2026-06-02 10:00:00',
        [result_note] = N'Space cleaned and sanitized.',
        [is_deleted] = 1
    WHERE [space_id] = @space2_id AND [problem_description] = N'Cleaning issues';
END

GO

-- ============================================================
-- SECTION 7: Valid Bookings (normal workflow scenarios)
-- ============================================================
PRINT 'SECTION 7: Valid Bookings';
GO

DECLARE @student1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu');
DECLARE @lecturer1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu');
DECLARE @ta1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.ta1@university.edu');
DECLARE @staff1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitystaff1@university.edu');
DECLARE @admin1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.deptadmin1@university.edu');
DECLARE @mgr1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitymgr1@university.edu');

DECLARE @space1_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @space2_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');
DECLARE @space6_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-001');
DECLARE @space7_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-002');
DECLARE @space9_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001');

-- Booking 1: Future approved booking — lecture (upcoming bookings report)
-- Space 1 (auditorium), 2026-07-01 08:00-10:00
PRINT '  Booking 1: Future approved lecture';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space1_id AND [requested_start_time] = '2026-07-01 08:00:00' AND [requester_id] = @lecturer1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space1_id, @lecturer1_id, '2026-07-01 08:00:00', '2026-07-01 10:00:00', 'lecture', 150, 'pending');

    DECLARE @b1_id INT = SCOPE_IDENTITY();
    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-06-20 14:00:00',
        [decision_note] = N'Approved for CS486 lecture series.'
    WHERE [booking_id] = @b1_id;
END

-- Booking 2: Future approved booking — examination (same space, different time slot)
-- Space 1 (auditorium), 2026-07-01 10:00-12:00 (no overlap with booking 1)
PRINT '  Booking 2: Future approved examination';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space1_id AND [requested_start_time] = '2026-07-01 10:00:00' AND [requester_id] = @lecturer1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space1_id, @lecturer1_id, '2026-07-01 10:00:00', '2026-07-01 12:00:00', 'examination', 180, 'pending');

    DECLARE @b2_id INT = SCOPE_IDENTITY();
    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-06-20 14:30:00',
        [decision_note] = N'Approved for final examination.'
    WHERE [booking_id] = @b2_id;
END

-- Booking 3: Past completed booking — examination (full lifecycle)
-- Space 2 (classroom), 2026-06-10 09:00-11:00
PRINT '  Booking 3: Past completed examination';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space2_id AND [requested_start_time] = '2026-06-10 09:00:00' AND [requester_id] = @student1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space2_id, @student1_id, '2026-06-10 09:00:00', '2026-06-10 11:00:00', 'examination', 35, 'pending');

    DECLARE @b3_id INT = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @staff1_id,
        [decision_time] = '2026-06-08 10:00:00',
        [decision_note] = N'Approved for midterm examination.'
    WHERE [booking_id] = @b3_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in',
        [actual_start_time] = '2026-06-10 09:05:00',
        [checked_in_by] = @staff1_id,
        [initial_condition] = N'Room clean, desks arranged, whiteboard clean.'
    WHERE [booking_id] = @b3_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'completed',
        [actual_end_time] = '2026-06-10 11:10:00',
        [final_condition] = N'Desks rearranged, minor chalk dust, whiteboard needs cleaning.',
        [usage_notes] = N'Midterm examination completed. 35 students attended.'
    WHERE [booking_id] = @b3_id;
END

-- Booking 4: Past no-show booking (for no-show reports)
-- Space 2 (classroom), 2026-06-12 14:00-16:00
PRINT '  Booking 4: Past no-show';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space2_id AND [requested_start_time] = '2026-06-12 14:00:00' AND [requester_id] = @student1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space2_id, @student1_id, '2026-06-12 14:00:00', '2026-06-12 16:00:00', 'meeting', 10, 'pending');

    DECLARE @b4_id INT = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @staff1_id,
        [decision_time] = '2026-06-11 09:00:00',
        [decision_note] = N'Approved for student club meeting.'
    WHERE [booking_id] = @b4_id;

    -- Transition to no_show (no trigger validation for no_show)
    UPDATE [dbo].[bookings]
    SET [status] = 'no_show'
    WHERE [booking_id] = @b4_id;
END

-- Booking 5: Future pending booking — workshop
-- Space 6 (computer_lab), 2026-07-05 09:00-12:00
PRINT '  Booking 5: Future pending workshop';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space6_id AND [requested_start_time] = '2026-07-05 09:00:00' AND [requester_id] = @ta1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space6_id, @ta1_id, '2026-07-05 09:00:00', '2026-07-05 12:00:00', 'workshop', 25, 'pending');
END

-- Booking 6: Checked-in booking (ongoing today)
-- Space 7 (project_lab), 2026-06-22 09:00-12:00
PRINT '  Booking 6: Checked-in student activity';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space7_id AND [requested_start_time] = '2026-06-22 09:00:00' AND [requester_id] = @student1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space7_id, @student1_id, '2026-06-22 09:00:00', '2026-06-22 12:00:00', 'student_activity', 15, 'pending');

    DECLARE @b6_id INT = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @staff1_id,
        [decision_time] = '2026-06-20 10:00:00',
        [decision_note] = N'Approved for student project work.'
    WHERE [booking_id] = @b6_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in',
        [actual_start_time] = '2026-06-22 09:00:00',
        [checked_in_by] = @staff1_id,
        [initial_condition] = N'All workstations functional, lab clean.'
    WHERE [booking_id] = @b6_id;
END

-- Booking 7: Future approved booking — meeting
-- Space 7 (project_lab), 2026-07-10 14:00-15:00 (no overlap with booking 6 which is on 06-22)
PRINT '  Booking 7: Future approved meeting';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space7_id AND [requested_start_time] = '2026-07-10 14:00:00' AND [requester_id] = @admin1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space7_id, @admin1_id, '2026-07-10 14:00:00', '2026-07-10 15:00:00', 'meeting', 10, 'pending');

    DECLARE @b7_id INT = SCOPE_IDENTITY();
    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-07-01 08:00:00',
        [decision_note] = N'Approved for department meeting.'
    WHERE [booking_id] = @b7_id;
END

-- Booking 8: Past rejected booking with full decision metadata
-- Space 6 (computer_lab), 2026-06-08 10:00-12:00
PRINT '  Booking 8: Past rejected seminar';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space6_id AND [requested_start_time] = '2026-06-08 10:00:00' AND [requester_id] = @lecturer1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space6_id, @lecturer1_id, '2026-06-08 10:00:00', '2026-06-08 12:00:00', 'seminar', 28, 'pending');

    DECLARE @b8_id INT = SCOPE_IDENTITY();
    UPDATE [dbo].[bookings]
    SET [status] = 'rejected',
        [approver_id] = @staff1_id,
        [decision_time] = '2026-06-07 16:00:00',
        [decision_note] = N'Computer lab is reserved for system maintenance that week.',
        [rejection_reason] = N'Lab reserved for system updates on the requested date.'
    WHERE [booking_id] = @b8_id;
END

-- Booking 9: Future approved booking — administrative_event
-- Space 2 (classroom), 2026-07-03 08:00-10:00
PRINT '  Booking 9: Future approved administrative event';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space2_id AND [requested_start_time] = '2026-07-03 08:00:00' AND [requester_id] = @admin1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space2_id, @admin1_id, '2026-07-03 08:00:00', '2026-07-03 10:00:00', 'administrative_event', 20, 'pending');

    DECLARE @b9_id INT = SCOPE_IDENTITY();
    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-06-25 09:00:00',
        [decision_note] = N'Approved for faculty orientation session.'
    WHERE [booking_id] = @b9_id;
END

-- Booking 10: Soft-deleted booking (historical preservation proof)
-- Space 1 (auditorium), 2026-06-05 08:00-10:00
PRINT '  Booking 10: Soft-deleted booking';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space1_id AND [requested_start_time] = '2026-06-05 08:00:00' AND [requester_id] = @lecturer1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space1_id, @lecturer1_id, '2026-06-05 08:00:00', '2026-06-05 10:00:00', 'lecture', 100, 'pending');

    DECLARE @b10_id INT = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-06-03 10:00:00',
        [decision_note] = N'Approved for guest lecture.'
    WHERE [booking_id] = @b10_id;

    -- Soft-delete the booking
    UPDATE [dbo].[bookings]
    SET [is_deleted] = 1
    WHERE [booking_id] = @b10_id;
END

-- Booking 11: Cancelled booking
-- Space 9 (student_workspace), 2026-07-12 10:00-12:00 (before maintenance on space 9 starts 2026-07-20)
PRINT '  Booking 11: Cancelled booking';
IF NOT EXISTS (SELECT 1 FROM [dbo].[bookings] WHERE [space_id] = @space9_id AND [requested_start_time] = '2026-07-12 10:00:00' AND [requester_id] = @student1_id)
BEGIN
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space9_id, @student1_id, '2026-07-12 10:00:00', '2026-07-12 12:00:00', 'student_activity', 10, 'cancelled');
END

GO

-- ============================================================
-- SECTION 8: Expected-Error Test Cases
-- ============================================================
PRINT 'SECTION 8: Expected-Error Test Cases';
GO

-- ============================================================
-- ECASE 1: BR1 — Overlap prevention
-- Attempt to insert a booking on space 1 that overlaps approved
-- booking 1 (2026-07-01 08:00-10:00). Start time is unique so the
-- filtered unique index does not block it; the overlap trigger must.
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 1: BR1 overlap prevention';
GO

DECLARE @space1_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space1_id, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu'),
            '2026-07-01 09:30:00', '2026-07-01 11:30:00', 'seminar', 50, 'approved');
    PRINT '  UNEXPECTED: BR1 overlap test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR1 overlap): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 2: BR2 — Unavailable space (under_maintenance)
-- Attempt to create a booking on space 8 (meeting_room, under_maintenance)
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 2: BR2 under_maintenance space';
GO

DECLARE @space8_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MTG-001');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space8_id, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu'),
            '2026-07-15 10:00:00', '2026-07-15 12:00:00', 'meeting', 5, 'pending');
    PRINT '  UNEXPECTED: BR2 under_maintenance test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR2 under_maintenance): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 3: BR2 — Unavailable space (retired)
-- Attempt to create a booking on space 4 (classroom, retired)
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 3: BR2 retired space';
GO

DECLARE @space4_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-301');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space4_id, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu'),
            '2026-07-20 08:00:00', '2026-07-20 10:00:00', 'lecture', 30, 'pending');
    PRINT '  UNEXPECTED: BR2 retired test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR2 retired): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 4: BR2 — Unavailable space (temporarily_closed)
-- Attempt to create a booking on space 3 (classroom, temporarily_closed)
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 4: BR2 temporarily_closed space';
GO

DECLARE @space3_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space3_id, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu'),
            '2026-08-01 09:00:00', '2026-08-01 11:00:00', 'workshop', 20, 'pending');
    PRINT '  UNEXPECTED: BR2 temporarily_closed test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR2 temporarily_closed): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 5: BR3 — Capacity prevention
-- Attempt to create a booking on space 2 (classroom, capacity 40)
-- with expected_participants = 50
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 5: BR3 capacity violation';
GO

DECLARE @space2_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space2_id, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu'),
            '2026-08-10 08:00:00', '2026-08-10 10:00:00', 'lecture', 50, 'pending');
    PRINT '  UNEXPECTED: BR3 capacity test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR3 capacity): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 6: BR4 — Unresolved maintenance blocks booking
-- Space 5 (classroom, available) has open maintenance starting
-- 2026-07-01. Attempt to book 2026-07-02 09:00-11:00 (overlaps).
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 6: BR4 maintenance overlap';
GO

DECLARE @space5_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space5_id, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu'),
            '2026-07-02 09:00:00', '2026-07-02 11:00:00', 'lecture', 20, 'pending');
    PRINT '  UNEXPECTED: BR4 maintenance overlap test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR4 maintenance overlap): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 7: BR6 — Approval metadata missing
-- Insert a pending booking, then update to approved without
-- setting required approver_id, decision_time, decision_note
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 7: BR6 approval metadata missing';
GO

DECLARE @space6_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-001');
DECLARE @student1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space6_id, @student1_id, '2026-08-15 10:00:00', '2026-08-15 12:00:00', 'workshop', 20, 'pending');

    DECLARE @ec7_id INT = SCOPE_IDENTITY();

    -- Try to approve without approver_id, decision_time, decision_note
    UPDATE [dbo].[bookings]
    SET [status] = 'approved'
    WHERE [booking_id] = @ec7_id;

    PRINT '  UNEXPECTED: BR6 approval metadata test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR6 approval metadata): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 8: BR7 — Rejection reason missing
-- Insert a pending booking, then update to rejected without
-- rejection_reason
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 8: BR7 rejection reason missing';
GO

DECLARE @space7_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-LAB-002');
DECLARE @student1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space7_id, @student1_id, '2026-08-20 14:00:00', '2026-08-20 16:00:00', 'student_activity', 10, 'pending');

    DECLARE @ec8_id INT = SCOPE_IDENTITY();

    -- Try to reject without rejection_reason
    UPDATE [dbo].[bookings]
    SET [status] = 'rejected',
        [approver_id] = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitystaff1@university.edu'),
        [decision_time] = GETDATE(),
        [decision_note] = N'Cannot accommodate request.'
    WHERE [booking_id] = @ec8_id;

    PRINT '  UNEXPECTED: BR7 rejection reason test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR7 rejection reason): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 9: BR8/BR9 — Check-in missing fields
-- Approve a booking first, then update to checked_in without
-- actual_start_time
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 9: BR8/BR9 check-in missing fields';
GO

DECLARE @ec9_space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @lecturer1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu');
DECLARE @mgr1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitymgr1@university.edu');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@ec9_space, @lecturer1_id, '2026-08-25 09:00:00', '2026-08-25 11:00:00', 'seminar', 10, 'pending');

    DECLARE @ec9_id INT = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-08-20 10:00:00',
        [decision_note] = N'Approved for research seminar.'
    WHERE [booking_id] = @ec9_id;

    -- Try to check in without actual_start_time
    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in',
        [checked_in_by] = @mgr1_id,
        [initial_condition] = N'Workspace tidy.'
    WHERE [booking_id] = @ec9_id;

    PRINT '  UNEXPECTED: BR8/BR9 check-in test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR8/BR9 check-in): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 10: BR8/BR9 — Completion missing fields
-- Approve, check in, then complete without actual_end_time
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 10: BR8/BR9 completion missing fields';
GO

DECLARE @ec10_space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @lecturer1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu');
DECLARE @mgr1_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.facilitymgr1@university.edu');

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@ec10_space, @lecturer1_id, '2026-08-30 09:00:00', '2026-08-30 11:00:00', 'seminar', 10, 'pending');

    DECLARE @ec10_id INT = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @mgr1_id,
        [decision_time] = '2026-08-25 10:00:00',
        [decision_note] = N'Approved.'
    WHERE [booking_id] = @ec10_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in',
        [actual_start_time] = '2026-08-30 09:00:00',
        [checked_in_by] = @mgr1_id,
        [initial_condition] = N'Clean and ready.'
    WHERE [booking_id] = @ec10_id;

    -- Try to complete without actual_end_time
    UPDATE [dbo].[bookings]
    SET [status] = 'completed',
        [final_condition] = N'Good condition.',
        [usage_notes] = N'Seminar completed.'
    WHERE [booking_id] = @ec10_id;

    PRINT '  UNEXPECTED: BR8/BR9 completion test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (BR8/BR9 completion): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 11: Duplicate email (BR10 unique identification)
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 11: Duplicate email';
GO

BEGIN TRY
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06.student1@university.edu', N'Duplicate User', NULL, 'student',
            (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science'), 'active');
    PRINT '  UNEXPECTED: Duplicate email test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (duplicate email): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 12: Invalid enum value for booking status
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 12: Invalid booking status';
GO

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES ((SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001'),
            (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu'),
            '2026-09-01 10:00:00', '2026-09-01 12:00:00', 'meeting', 5, 'invalid_status');
    PRINT '  UNEXPECTED: Invalid enum test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (invalid enum): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- ECASE 13: Invalid time range (end <= start)
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE 13: Invalid time range';
GO

BEGIN TRY
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES ((SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-001'),
            (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.student1@university.edu'),
            '2026-09-01 14:00:00', '2026-09-01 13:00:00', 'meeting', 5, 'pending');
    PRINT '  UNEXPECTED: Invalid time range test did not raise an error.';
END TRY
BEGIN CATCH
    PRINT '  Expected error (invalid time range): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- SECTION 9: Verification Queries
-- ============================================================
PRINT 'SECTION 9: Verification Queries';
GO

PRINT '--- Row counts ---';
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
SELECT 'maintenances', COUNT(*) FROM [dbo].[maintenances]
UNION ALL
SELECT 'bookings', COUNT(*) FROM [dbo].[bookings]
ORDER BY [table];

GO

PRINT '--- All booking statuses ---';
SELECT DISTINCT [status] FROM [dbo].[bookings] ORDER BY [status];

GO

PRINT '--- All booking purposes ---';
SELECT DISTINCT [purpose] FROM [dbo].[bookings] ORDER BY [purpose];

GO

PRINT '--- All space types ---';
SELECT DISTINCT [space_type] FROM [dbo].[spaces] ORDER BY [space_type];

GO

PRINT '--- All space statuses ---';
SELECT DISTINCT [current_status] FROM [dbo].[spaces] ORDER BY [current_status];

GO

PRINT '--- All maintenance statuses ---';
SELECT DISTINCT [status] FROM [dbo].[maintenances] ORDER BY [status];

GO

PRINT '--- All user roles ---';
SELECT DISTINCT [role] FROM [dbo].[users] WHERE [email] LIKE 't06.%' ORDER BY [role];

GO

PRINT '--- All account statuses ---';
SELECT DISTINCT [account_status] FROM [dbo].[users] WHERE [email] LIKE 't06.%' ORDER BY [account_status];

GO

PRINT '--- Audit: created_at and updated_at are populated (no NULLs) ---';
SELECT 'departments' AS [table], COUNT(*) AS [total], SUM(CASE WHEN [created_at] IS NULL THEN 1 ELSE 0 END) AS [null_created], SUM(CASE WHEN [updated_at] IS NULL THEN 1 ELSE 0 END) AS [null_updated] FROM [dbo].[departments]
UNION ALL
SELECT 'users', COUNT(*), SUM(CASE WHEN [created_at] IS NULL THEN 1 ELSE 0 END), SUM(CASE WHEN [updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[users]
UNION ALL
SELECT 'spaces', COUNT(*), SUM(CASE WHEN [created_at] IS NULL THEN 1 ELSE 0 END), SUM(CASE WHEN [updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[spaces]
UNION ALL
SELECT 'facilities', COUNT(*), SUM(CASE WHEN [created_at] IS NULL THEN 1 ELSE 0 END), SUM(CASE WHEN [updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[facilities]
UNION ALL
SELECT 'bookings', COUNT(*), SUM(CASE WHEN [created_at] IS NULL THEN 1 ELSE 0 END), SUM(CASE WHEN [updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[bookings]
UNION ALL
SELECT 'maintenances', COUNT(*), SUM(CASE WHEN [created_at] IS NULL THEN 1 ELSE 0 END), SUM(CASE WHEN [updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[maintenances];

GO

PRINT '--- Soft-deleted bookings (is_deleted = 1) ---';
SELECT [booking_id], [space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [status], [is_deleted]
FROM [dbo].[bookings]
WHERE [is_deleted] = 1;

GO

PRINT '--- Soft-deleted maintenances (is_deleted = 1) ---';
SELECT [maintenance_id], [space_id], [problem_description], [status], [is_deleted]
FROM [dbo].[maintenances]
WHERE [is_deleted] = 1;

GO

PRINT '--- Upcoming future approved bookings ---';
SELECT b.[booking_id], s.[space_code], s.[space_name], b.[requested_start_time], b.[requested_end_time], b.[purpose], b.[expected_participants]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
WHERE b.[status] = 'approved' AND b.[requested_start_time] > GETDATE() AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];

GO

PRINT '--- Spaces currently under maintenance ---';
SELECT s.[space_code], s.[space_name], s.[building], s.[room_number], m.[maintenance_id], m.[problem_description], m.[status], m.[start_time]
FROM [dbo].[spaces] s
INNER JOIN [dbo].[maintenances] m ON s.[space_id] = m.[space_id]
WHERE s.[current_status] = 'under_maintenance' AND m.[is_deleted] = 0;

GO

PRINT '--- No-show bookings ---';
SELECT b.[booking_id], s.[space_code], b.[requested_start_time], b.[requested_end_time], u.[full_name] AS [requester]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE b.[status] = 'no_show' AND b.[is_deleted] = 0;

GO

PRINT '--- Booking history for T06 lecturer (past bookings) ---';
SELECT b.[booking_id], s.[space_code], b.[requested_start_time], b.[requested_end_time], b.[purpose], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
WHERE b.[requester_id] = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06.lecturer1@university.edu')
  AND b.[requested_end_time] < GETDATE()
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];

GO

PRINT '--- Maintenance with assigned staff ---';
SELECT m.[maintenance_id], s.[space_code], m.[problem_description], m.[status], u.[full_name] AS [assigned_staff]
FROM [dbo].[maintenances] m
INNER JOIN [dbo].[spaces] s ON m.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON m.[assigned_staff_id] = u.[user_id]
WHERE m.[assigned_staff_id] IS NOT NULL AND m.[is_deleted] = 0;

GO

PRINT '=== SAMPLE DATA GENERATION COMPLETE ===';
GO
