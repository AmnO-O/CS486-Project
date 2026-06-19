SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Task 06 — Sample Data Preparation
-- Database: CS486_G05
-- Depends on: outputs/05-db-definition-G05.sql (Task 05 DDL)
-- Idempotence strategy: cleanup-and-reseed using stable Task 06
--   natural keys (space_code LIKE 'T06-%', email LIKE 't06_%',
--   facility names are standard, departments use IF NOT EXISTS).
-- ============================================================

USE [CS486_G05];
GO

-- ============================================================
-- SECTION 1: IDEMPOTENCE — CLEANUP TASK 06 ROWS
-- Reverse FK order: space_facilities, bookings, maintenances,
-- spaces, facilities, users, departments.
-- ============================================================
PRINT 'SECTION 1: CLEANUP — removing prior Task 06 sample rows';
GO

-- Delete space_facilities for T06 spaces
DELETE [sf]
FROM [dbo].[space_facilities] [sf]
INNER JOIN [dbo].[spaces] [s] ON [sf].[space_id] = [s].[space_id]
WHERE [s].[space_code] LIKE 'T06-%';

-- Delete bookings created by T06 users
DELETE [b]
FROM [dbo].[bookings] [b]
INNER JOIN [dbo].[users] [u] ON [b].[requester_id] = [u].[user_id]
WHERE [u].[email] LIKE 't06_%';

-- Delete maintenances reported by T06 users
DELETE [m]
FROM [dbo].[maintenances] [m]
INNER JOIN [dbo].[users] [u] ON [m].[reporter_id] = [u].[user_id]
WHERE [u].[email] LIKE 't06_%';

-- Delete remaining bookings on T06 spaces (orphaned if any)
DELETE [b]
FROM [dbo].[bookings] [b]
INNER JOIN [dbo].[spaces] [s] ON [b].[space_id] = [s].[space_id]
WHERE [s].[space_code] LIKE 'T06-%';

-- Delete remaining maintenances on T06 spaces
DELETE [m]
FROM [dbo].[maintenances] [m]
INNER JOIN [dbo].[spaces] [s] ON [m].[space_id] = [s].[space_id]
WHERE [s].[space_code] LIKE 'T06-%';

-- Delete T06 facilities (standard facility names only)
DELETE FROM [dbo].[facilities] WHERE [name] IN (
    N'Projector', N'Whiteboard', N'Microphone',
    N'Computer', N'Livestreaming Equipment', N'Air Conditioner'
);

-- Delete T06 spaces
DELETE FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%';

-- Delete T06 users
DELETE FROM [dbo].[users] WHERE [email] LIKE 't06_%';

-- Departments: keep (they are not T06-owned), just ensure they exist
GO

-- ============================================================
-- SECTION 2: VALID SEED DATA
-- ============================================================
PRINT 'SECTION 2: VALID SEED DATA';
GO

-- ============================================================
-- 2.1 DEPARTMENTS
-- ============================================================
PRINT '--- 2.1 Departments';
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School of Computer Science')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School of Computer Science');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Faculty of Engineering');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Mathematics');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School of Business')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School of Business');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Physics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Physics');

-- Lookup variables for departments
DECLARE @dept_cs_id  INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @dept_eng_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering');
DECLARE @dept_math_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @dept_bus_id  INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Business');
DECLARE @dept_phy_id  INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Physics');

IF @dept_cs_id IS NULL OR @dept_eng_id IS NULL OR @dept_math_id IS NULL OR @dept_bus_id IS NULL OR @dept_phy_id IS NULL
    THROW 51001, 'Task 06 setup failed: one or more required departments were not found.', 1;

GO

-- ============================================================
-- 2.2 USERS (all roles, mixed account_statuses)
-- ============================================================
PRINT '--- 2.2 Users';
GO

DECLARE @dept_cs_id  INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @dept_eng_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering');
DECLARE @dept_math_id INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @dept_bus_id  INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Business');

-- Insert users only if they don't exist
IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_student_1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_student_1@university.edu', N'Alice Johnson', N'0901000001', 'student', @dept_cs_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_student_2@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_student_2@university.edu', N'Bob Lee', N'0901000002', 'student', @dept_math_id, 'inactive');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_student_3@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_student_3@university.edu', N'Charlie Park', N'0901000003', 'student', @dept_eng_id, 'suspended');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_lecturer_1@university.edu', N'Dr. Diana Chen', N'0901000004', 'lecturer', @dept_cs_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_lecturer_2@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_lecturer_2@university.edu', N'Dr. Edward Kim', N'0901000005', 'lecturer', @dept_math_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_ta_1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_ta_1@university.edu', N'Fiona Wang', NULL, 'teaching_assistant', @dept_cs_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_facility_staff_1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_facility_staff_1@university.edu', N'George Liu', N'0901000007', 'facility_staff', @dept_cs_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_facility_staff_2@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_facility_staff_2@university.edu', N'Helen Zhang', N'0901000008', 'facility_staff', @dept_eng_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_admin_1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_admin_1@university.edu', N'Ian Wu', N'0901000009', 'department_admin', @dept_bus_id, 'active');

IF NOT EXISTS (SELECT 1 FROM [dbo].[users] WHERE [email] = 't06_manager_1@university.edu')
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_manager_1@university.edu', N'Jane Miller', N'0901000010', 'facility_manager', @dept_cs_id, 'active');

GO

-- ============================================================
-- 2.3 SPACES (all 6 space types, all 5 space statuses)
-- ============================================================
PRINT '--- 2.3 Spaces';
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-AUD-101', N'Main Auditorium', 'auditorium', N'Building A', N'1st Floor', N'A101', 200, 'available', N'Priority to large lectures and examinations. Max 200 persons.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-101', N'Classroom 101', 'classroom', N'Building A', N'1st Floor', N'A102', 40, 'available', N'Standard classroom. Whiteboard and projector available.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-102')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-102', N'Classroom 102', 'classroom', N'Building A', N'1st Floor', N'A103', 30, 'available', N'Standard classroom. Suitable for small groups.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-201', N'Classroom 201', 'classroom', N'Building B', N'2nd Floor', N'B201', 50, 'in_use', N'Currently active semester. Capacity 50.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-202', N'Classroom 202', 'classroom', N'Building B', N'2nd Floor', N'B202', 35, 'under_maintenance', N'Under maintenance — multiple active tickets.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-203')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-203', N'Classroom 203', 'classroom', N'Building B', N'2nd Floor', N'B203', 25, 'temporarily_closed', N'Temporarily closed for renovation.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-204')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-204', N'Classroom 204', 'classroom', N'Building B', N'2nd Floor', N'B204', 20, 'retired', N'Retired — no longer in service.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-205')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-205', N'Classroom 205', 'classroom', N'Building B', N'2nd Floor', N'B205', 45, 'available', N'Standard classroom. Good for medium-sized lectures.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-206')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-206', N'Classroom 206', 'classroom', N'Building B', N'2nd Floor', N'B206', 10, 'available', N'Small classroom. Suitable for tutorials and meetings.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CL-207', N'Classroom 207', 'classroom', N'Building B', N'2nd Floor', N'B207', 60, 'available', N'Large classroom. Capacity 60 with projector.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-CS-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-CS-101', N'Computer Lab Alpha', 'computer_lab', N'Building C', N'1st Floor', N'C101', 30, 'available', N'Computer lab with 30 workstations. IDLE required.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-PL-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-PL-101', N'Project Lab Beta', 'project_lab', N'Building C', N'1st Floor', N'C102', 20, 'available', N'Project lab for team-based projects.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-MR-101', N'Meeting Room A', 'meeting_room', N'Building A', N'3rd Floor', N'A301', 10, 'available', N'Small meeting room. Capacity 10.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-102')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-MR-102', N'Meeting Room B', 'meeting_room', N'Building A', N'3rd Floor', N'A302', 8, 'available', N'Small meeting room. Capacity 8.');

IF NOT EXISTS (SELECT 1 FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-101')
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
    VALUES ('T06-SW-101', N'Student Workspace Alpha', 'student_workspace', N'Building D', N'1st Floor', N'D101', 15, 'available', N'Open student workspace. First-come first-served for study groups.');

GO

-- ============================================================
-- 2.4 FACILITIES
-- ============================================================
PRINT '--- 2.4 Facilities';
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
-- 2.5 SPACE_FACILITIES (junction)
-- ============================================================
PRINT '--- 2.5 Space Facilities';
GO

-- Lookups
DECLARE @space_aud_101  INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @space_cl_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
DECLARE @space_cl_102   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-102');
DECLARE @space_cl_201   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-201');
DECLARE @space_cl_202   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202');
DECLARE @space_cl_203   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-203');
DECLARE @space_cl_204   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-204');
DECLARE @space_cl_205   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-205');
DECLARE @space_cl_206   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-206');
DECLARE @space_cl_207   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
DECLARE @space_cs_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CS-101');
DECLARE @space_pl_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-PL-101');
DECLARE @space_mr_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101');
DECLARE @space_mr_102   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-102');
DECLARE @space_sw_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-101');

DECLARE @fac_projector INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Projector');
DECLARE @fac_wb       INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Whiteboard');
DECLARE @fac_mic      INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Microphone');
DECLARE @fac_pc       INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Computer');
DECLARE @fac_ls       INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Livestreaming Equipment');
DECLARE @fac_ac       INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'Air Conditioner');

-- Validate lookups
IF (@space_aud_101 IS NULL OR @space_cl_101 IS NULL OR @space_cl_102 IS NULL OR @space_cl_201 IS NULL
    OR @space_cl_202 IS NULL OR @space_cl_203 IS NULL OR @space_cl_204 IS NULL OR @space_cl_205 IS NULL
    OR @space_cl_206 IS NULL OR @space_cl_207 IS NULL OR @space_cs_101 IS NULL OR @space_pl_101 IS NULL
    OR @space_mr_101 IS NULL OR @space_mr_102 IS NULL OR @space_sw_101 IS NULL)
    THROW 51002, 'Task 06 setup failed: one or more required spaces were not found.', 1;

IF (@fac_projector IS NULL OR @fac_wb IS NULL OR @fac_mic IS NULL OR @fac_pc IS NULL OR @fac_ls IS NULL OR @fac_ac IS NULL)
    THROW 51003, 'Task 06 setup failed: one or more required facilities were not found.', 1;

-- Insert space_facilities (use IF NOT EXISTS on composite key)
-- Auditorium: projector(2), microphone(4), livestreaming(1), AC(2)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_aud_101 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_aud_101, @fac_projector, 2);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_aud_101 AND [facility_id] = @fac_mic)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_aud_101, @fac_mic, 4);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_aud_101 AND [facility_id] = @fac_ls)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_aud_101, @fac_ls, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_aud_101 AND [facility_id] = @fac_ac)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_aud_101, @fac_ac, 2);

-- Classroom 101: projector(1), whiteboard(1), computer(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_101 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_101, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_101 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_101, @fac_wb, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_101 AND [facility_id] = @fac_pc)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_101, @fac_pc, 1);

-- Classroom 102: projector(1), whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_102 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_102, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_102 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_102, @fac_wb, 1);

-- Classroom 201: projector(1), whiteboard(1), computer(15)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_201 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_201, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_201 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_201, @fac_wb, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_201 AND [facility_id] = @fac_pc)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_201, @fac_pc, 15);

-- Classroom 202 (under_maintenance): projector(1), whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_202 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_202, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_202 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_202, @fac_wb, 1);

-- Classroom 203 (temporarily_closed): projector(1), whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_203 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_203, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_203 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_203, @fac_wb, 1);

-- Classroom 204 (retired): whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_204 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_204, @fac_wb, 1);

-- Classroom 205: projector(1), whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_205 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_205, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_205 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_205, @fac_wb, 1);

-- Classroom 206: whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_206 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_206, @fac_wb, 1);

-- Classroom 207: projector(1), whiteboard(1), microphone(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_207 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_207, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_207 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_207, @fac_wb, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cl_207 AND [facility_id] = @fac_mic)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cl_207, @fac_mic, 1);

-- Computer Lab: computer(30), projector(1), whiteboard(1), AC(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cs_101 AND [facility_id] = @fac_pc)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cs_101, @fac_pc, 30);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cs_101 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cs_101, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cs_101 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cs_101, @fac_wb, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_cs_101 AND [facility_id] = @fac_ac)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_cs_101, @fac_ac, 1);

-- Project Lab: computer(20), projector(1), whiteboard(1), AC(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_pl_101 AND [facility_id] = @fac_pc)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_pl_101, @fac_pc, 20);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_pl_101 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_pl_101, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_pl_101 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_pl_101, @fac_wb, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_pl_101 AND [facility_id] = @fac_ac)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_pl_101, @fac_ac, 1);

-- Meeting Room A: projector(1), whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_mr_101 AND [facility_id] = @fac_projector)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_mr_101, @fac_projector, 1);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_mr_101 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_mr_101, @fac_wb, 1);

-- Meeting Room B: whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_mr_102 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_mr_102, @fac_wb, 1);

-- Student Workspace: computer(15), whiteboard(1)
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_sw_101 AND [facility_id] = @fac_pc)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_sw_101, @fac_pc, 15);
IF NOT EXISTS (SELECT 1 FROM [dbo].[space_facilities] WHERE [space_id] = @space_sw_101 AND [facility_id] = @fac_wb)
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@space_sw_101, @fac_wb, 1);

GO

-- ============================================================
-- 2.6 MAINTENANCES (open, in_progress, resolved, soft-deleted)
-- ============================================================
PRINT '--- 2.6 Maintenances';
GO

-- User and space lookups (repopulate from stable keys)
DECLARE @u_student_1    INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_student_1@university.edu');
DECLARE @u_lecturer_1   INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');
DECLARE @u_staff_1      INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_facility_staff_1@university.edu');
DECLARE @u_staff_2      INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_facility_staff_2@university.edu');
DECLARE @u_manager_1    INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_manager_1@university.edu');

DECLARE @s_cl_202       INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202');
DECLARE @s_cl_205       INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-205');
DECLARE @s_cl_101       INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');

IF (@u_student_1 IS NULL OR @u_lecturer_1 IS NULL OR @u_staff_1 IS NULL OR @u_staff_2 IS NULL OR @u_manager_1 IS NULL)
    THROW 51004, 'Task 06 setup failed: required users not found for maintenances.', 1;
IF (@s_cl_202 IS NULL OR @s_cl_205 IS NULL OR @s_cl_101 IS NULL)
    THROW 51005, 'Task 06 setup failed: required spaces not found for maintenances.', 1;

-- M1: open — broken projector on T06-CL-202 (under_maintenance)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @s_cl_202 AND [problem_description] = N'T06-Broken projector — image not displaying' AND [status] = 'open')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@s_cl_202, @u_lecturer_1, @u_staff_1, N'T06-Broken projector — image not displaying', '2026-06-18 08:00:00', 'open');

-- M2: in_progress — AC failure on T06-CL-202
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @s_cl_202 AND [problem_description] = N'T06-Air conditioning failure — no cooling' AND [status] = 'in_progress')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@s_cl_202, @u_student_1, @u_staff_2, N'T06-Air conditioning failure — no cooling', '2026-06-19 09:00:00', 'in_progress');

-- M3: resolved — cleaning issue on T06-CL-205
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @s_cl_205 AND [problem_description] = N'T06-Cleaning issue — spillage on floor' AND [status] = 'resolved')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
    VALUES (@s_cl_205, @u_student_1, @u_staff_1, N'T06-Cleaning issue — spillage on floor', '2026-06-15 14:00:00', '2026-06-16 10:00:00', 'resolved', N'Floor cleaned and sanitized.');

-- M4: open — network problem on T06-CL-205 (for BR4 test, starts June 20)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @s_cl_205 AND [problem_description] = N'T06-Network problem — intermittent connectivity' AND [status] = 'open')
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@s_cl_205, @u_lecturer_1, @u_staff_1, N'T06-Network problem — intermittent connectivity', '2026-06-20 08:00:00', 'open');

-- M5: soft-deleted — damaged furniture on T06-CL-101 (is_deleted = 1, resolved)
IF NOT EXISTS (SELECT 1 FROM [dbo].[maintenances] WHERE [space_id] = @s_cl_101 AND [problem_description] = N'T06-Damaged furniture — broken chair' AND [is_deleted] = 1)
    INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note], [is_deleted])
    VALUES (@s_cl_101, @u_student_1, @u_staff_1, N'T06-Damaged furniture — broken chair', '2026-06-14 10:00:00', '2026-06-14 16:00:00', 'resolved', N'Chair replaced.', 1);

GO

-- ============================================================
-- 2.7 BOOKINGS (all statuses, all purposes)
-- ============================================================
PRINT '--- 2.7 Bookings';
GO

DECLARE @u_student_1   INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_student_1@university.edu');
DECLARE @u_lecturer_1  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');
DECLARE @u_lecturer_2  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_2@university.edu');
DECLARE @u_ta_1        INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_ta_1@university.edu');
DECLARE @u_staff_1     INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_facility_staff_1@university.edu');
DECLARE @u_staff_2     INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_facility_staff_2@university.edu');
DECLARE @u_manager_1   INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_manager_1@university.edu');
DECLARE @u_admin_1     INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_admin_1@university.edu');

DECLARE @s_aud_101  INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-AUD-101');
DECLARE @s_cl_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
DECLARE @s_cl_102   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-102');
DECLARE @s_cl_205   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-205');
DECLARE @s_cl_206   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-206');
DECLARE @s_cl_207   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
DECLARE @s_cs_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CS-101');
DECLARE @s_pl_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-PL-101');
DECLARE @s_mr_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-101');
DECLARE @s_mr_102   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-MR-102');
DECLARE @s_sw_101   INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-SW-101');

-- Validate all lookups
IF (@u_student_1 IS NULL OR @u_lecturer_1 IS NULL OR @u_lecturer_2 IS NULL OR @u_ta_1 IS NULL
    OR @u_staff_1 IS NULL OR @u_staff_2 IS NULL OR @u_manager_1 IS NULL OR @u_admin_1 IS NULL)
    THROW 51006, 'Task 06 setup failed: required users not found for bookings.', 1;

IF (@s_aud_101 IS NULL OR @s_cl_101 IS NULL OR @s_cl_102 IS NULL OR @s_cl_205 IS NULL
    OR @s_cl_206 IS NULL OR @s_cl_207 IS NULL OR @s_cs_101 IS NULL OR @s_pl_101 IS NULL
    OR @s_mr_101 IS NULL OR @s_mr_102 IS NULL OR @s_sw_101 IS NULL)
    THROW 51007, 'Task 06 setup failed: required spaces not found for bookings.', 1;

-- ============================================================
-- B1: Completed — T06-CL-101, June 15 08:00-10:00, lecture, 30pax
-- Transition: pending → approved → checked_in → completed
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_101, @u_lecturer_1, '2026-06-15 08:00:00', '2026-06-15 10:00:00', 'lecture', 30, 'pending');

DECLARE @b1_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-14 09:00:00', [decision_note] = N'Approved for CS101 lecture.'
WHERE [booking_id] = @b1_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-15 08:05:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'Clean and tidy, all equipment functional.'
WHERE [booking_id] = @b1_id;

UPDATE [dbo].[bookings]
SET [status] = 'completed', [actual_end_time] = '2026-06-15 10:00:00', [final_condition] = N'Good, chairs slightly disorganised.', [usage_notes] = N'Lecture delivered successfully. Students used projector.'
WHERE [booking_id] = @b1_id;

-- ============================================================
-- B2: Approved (no check-in) — T06-CL-101, June 16 09:00-11:00, examination, 35pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_101, @u_lecturer_1, '2026-06-16 09:00:00', '2026-06-16 11:00:00', 'examination', 35, 'pending');

DECLARE @b2_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-15 10:00:00', [decision_note] = N'Approved for midterm exam.'
WHERE [booking_id] = @b2_id;

-- ============================================================
-- B3: Future approved — T06-CL-101, June 22 08:00-10:00, lecture, 25pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_101, @u_lecturer_1, '2026-06-22 08:00:00', '2026-06-22 10:00:00', 'lecture', 25, 'pending');

DECLARE @b3_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-20 09:00:00', [decision_note] = N'Approved for regular lecture.'
WHERE [booking_id] = @b3_id;

-- ============================================================
-- B4: Pending — T06-CL-101, June 25 14:00-16:00, meeting, 10pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_101, @u_admin_1, '2026-06-25 14:00:00', '2026-06-25 16:00:00', 'meeting', 10, 'pending');

-- ============================================================
-- B5: Completed — T06-CL-102, June 14 10:00-12:00, workshop, 20pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_102, @u_ta_1, '2026-06-14 10:00:00', '2026-06-14 12:00:00', 'workshop', 20, 'pending');

DECLARE @b5_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-13 14:00:00', [decision_note] = N'Approved for TA workshop.'
WHERE [booking_id] = @b5_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-14 10:00:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'Clean, whiteboard empty.'
WHERE [booking_id] = @b5_id;

UPDATE [dbo].[bookings]
SET [status] = 'completed', [actual_end_time] = '2026-06-14 12:05:00', [final_condition] = N'Good, whiteboard used and cleaned.', [usage_notes] = N'Workshop on database design completed.'
WHERE [booking_id] = @b5_id;

-- ============================================================
-- B6: Completed — T06-CL-102, June 14 14:00-16:00, seminar, 15pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_102, @u_lecturer_2, '2026-06-14 14:00:00', '2026-06-14 16:00:00', 'seminar', 15, 'pending');

DECLARE @b6_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-13 15:00:00', [decision_note] = N'Approved for research seminar.'
WHERE [booking_id] = @b6_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-14 14:00:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'Tidy and ready.'
WHERE [booking_id] = @b6_id;

UPDATE [dbo].[bookings]
SET [status] = 'completed', [actual_end_time] = '2026-06-14 16:00:00', [final_condition] = N'Good condition.', [usage_notes] = N'Seminar delivered, projector used.'
WHERE [booking_id] = @b6_id;

-- ============================================================
-- B7: Future approved — T06-CL-102, June 23 09:00-11:00, lecture, 30pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_102, @u_lecturer_2, '2026-06-23 09:00:00', '2026-06-23 11:00:00', 'lecture', 30, 'pending');

DECLARE @b7_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_manager_1, [decision_time] = '2026-06-22 10:00:00', [decision_note] = N'Approved for math lecture.'
WHERE [booking_id] = @b7_id;

-- ============================================================
-- B8: No-show — T06-CL-102, June 18 08:00-10:00, lecture, 25pax
-- Transition: pending → approved → no_show
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_102, @u_lecturer_1, '2026-06-18 08:00:00', '2026-06-18 10:00:00', 'lecture', 25, 'pending');

DECLARE @b8_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-17 09:00:00', [decision_note] = N'Approved.'
WHERE [booking_id] = @b8_id;

UPDATE [dbo].[bookings]
SET [status] = 'no_show'
WHERE [booking_id] = @b8_id;

-- ============================================================
-- B9: Approved — T06-CL-205, June 17 13:00-15:00, administrative_event, 5pax
-- (before M4 maintenance starts June 20)
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_205, @u_admin_1, '2026-06-17 13:00:00', '2026-06-17 15:00:00', 'administrative_event', 5, 'pending');

DECLARE @b9_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-16 14:00:00', [decision_note] = N'Approved for department meeting.'
WHERE [booking_id] = @b9_id;

-- ============================================================
-- B10: Checked-in — T06-CL-205, June 19 09:00-11:00, seminar, 20pax
-- (before M4 maintenance starts June 20)
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_205, @u_lecturer_1, '2026-06-19 09:00:00', '2026-06-19 11:00:00', 'seminar', 20, 'pending');

DECLARE @b10_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-18 10:00:00', [decision_note] = N'Approved for research seminar.'
WHERE [booking_id] = @b10_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-19 09:00:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'Clean and well-prepared.'
WHERE [booking_id] = @b10_id;

-- ============================================================
-- B11: Cancelled — T06-CL-206, June 12 10:00-11:00, meeting, 5pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_206, @u_student_1, '2026-06-12 10:00:00', '2026-06-12 11:00:00', 'meeting', 5, 'pending');

DECLARE @b11_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings] SET [status] = 'cancelled' WHERE [booking_id] = @b11_id;

-- ============================================================
-- B12: Pending — T06-CL-207, June 28 08:00-10:00, examination, 50pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_207, @u_lecturer_2, '2026-06-28 08:00:00', '2026-06-28 10:00:00', 'examination', 50, 'pending');

-- ============================================================
-- B13: Future approved — T06-CL-207, June 24 08:00-12:00, examination, 50pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cl_207, @u_lecturer_1, '2026-06-24 08:00:00', '2026-06-24 12:00:00', 'examination', 50, 'pending');

DECLARE @b13_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_manager_1, [decision_time] = '2026-06-23 09:00:00', [decision_note] = N'Approved for final exam.'
WHERE [booking_id] = @b13_id;

-- ============================================================
-- B14: Future approved — T06-CS-101, June 26 09:00-11:00, lecture, 30pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_cs_101, @u_lecturer_1, '2026-06-26 09:00:00', '2026-06-26 11:00:00', 'lecture', 30, 'pending');

DECLARE @b14_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-25 10:00:00', [decision_note] = N'Approved for computer lab lecture.'
WHERE [booking_id] = @b14_id;

-- ============================================================
-- B15: Completed — T06-PL-101, June 11 14:00-17:00, workshop, 15pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_pl_101, @u_ta_1, '2026-06-11 14:00:00', '2026-06-11 17:00:00', 'workshop', 15, 'pending');

DECLARE @b15_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-10 15:00:00', [decision_note] = N'Approved for project lab workshop.'
WHERE [booking_id] = @b15_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-11 14:00:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'All computers functional, clean.'
WHERE [booking_id] = @b15_id;

UPDATE [dbo].[bookings]
SET [status] = 'completed', [actual_end_time] = '2026-06-11 17:10:00', [final_condition] = N'Good, computers shut down properly.', [usage_notes] = N'Robotics workshop completed successfully.'
WHERE [booking_id] = @b15_id;

-- ============================================================
-- B16: Future approved — T06-MR-101, June 21 10:00-12:00, meeting, 8pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_mr_101, @u_admin_1, '2026-06-21 10:00:00', '2026-06-21 12:00:00', 'meeting', 8, 'pending');

DECLARE @b16_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_manager_1, [decision_time] = '2026-06-20 10:00:00', [decision_note] = N'Approved for staff meeting.'
WHERE [booking_id] = @b16_id;

-- ============================================================
-- B17: Rejected — T06-MR-102, June 10 09:00-10:00, meeting, 5pax
-- Transition: pending → rejected (with rejection_reason)
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_mr_102, @u_student_1, '2026-06-10 09:00:00', '2026-06-10 10:00:00', 'meeting', 5, 'pending');

DECLARE @b17_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'rejected', [approver_id] = @u_staff_1, [decision_time] = '2026-06-09 14:00:00', [decision_note] = N'Request denied due to scheduling conflict with faculty meeting.', [rejection_reason] = N'Room reserved for faculty meeting.'
WHERE [booking_id] = @b17_id;

-- ============================================================
-- B18: Checked-in — T06-SW-101, June 19 10:00-12:00, student_activity, 12pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_sw_101, @u_student_1, '2026-06-19 10:00:00', '2026-06-19 12:00:00', 'student_activity', 12, 'pending');

DECLARE @b18_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_staff_1, [decision_time] = '2026-06-18 15:00:00', [decision_note] = N'Approved for student club activity.'
WHERE [booking_id] = @b18_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-19 10:00:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'Clean workspace, computers available.'
WHERE [booking_id] = @b18_id;

-- ============================================================
-- B19: Completed — T06-AUD-101, June 13 08:00-17:00, lecture, 150pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_aud_101, @u_lecturer_1, '2026-06-13 08:00:00', '2026-06-13 17:00:00', 'lecture', 150, 'pending');

DECLARE @b19_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_manager_1, [decision_time] = '2026-06-12 09:00:00', [decision_note] = N'Approved for all-day seminar.'
WHERE [booking_id] = @b19_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in', [actual_start_time] = '2026-06-13 08:10:00', [checked_in_by] = @u_staff_1, [initial_condition] = N'Spacious, all microphones working, AC functional.'
WHERE [booking_id] = @b19_id;

UPDATE [dbo].[bookings]
SET [status] = 'completed', [actual_end_time] = '2026-06-13 17:00:00', [final_condition] = N'Good, some litter on floor.', [usage_notes] = N'Full-day guest lecture. Livestreaming equipment used.'
WHERE [booking_id] = @b19_id;

-- ============================================================
-- B20: Future approved — T06-AUD-101, June 30 08:00-12:00, examination, 180pax
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@s_aud_101, @u_lecturer_2, '2026-06-30 08:00:00', '2026-06-30 12:00:00', 'examination', 180, 'pending');

DECLARE @b20_id INT = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved', [approver_id] = @u_manager_1, [decision_time] = '2026-06-28 10:00:00', [decision_note] = N'Approved for large-scale final exam.'
WHERE [booking_id] = @b20_id;

-- ============================================================
-- B21: Soft-deleted — T06-MR-102, June 9 10:00-11:00, meeting, 5pax
-- Historical preservation: is_deleted = 1
-- ============================================================
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [is_deleted])
VALUES (@s_mr_102, @u_student_1, '2026-06-09 10:00:00', '2026-06-09 11:00:00', 'meeting', 5, 'cancelled', 1);

GO

-- ============================================================
-- SECTION 3: EXPECTED-ERROR TEST CASES
-- All wrapped in TRY/CATCH so the script continues.
-- ============================================================
PRINT 'SECTION 3: EXPECTED-ERROR TEST CASES';
GO

-- ============================================================
-- 3.1 BR1 — Overlap Prevention
-- Attempt to insert an approved booking that overlaps an existing
-- approved booking on the same space.
-- Target: trg_bookings_prevent_overlap
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR1 — overlap prevention';
GO

BEGIN TRY
    DECLARE @br1_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-101');
    DECLARE @br1_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br1_space_id IS NULL OR @br1_user_id IS NULL
        THROW 51010, 'BR1 setup: required lookup ID is NULL.', 1;

    -- B3 exists: June 22 08:00-10:00 on T06-CL-101, approved
    -- This new booking June 22 09:00-11:00 on same space overlaps
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br1_space_id, @br1_user_id, '2026-06-22 09:00:00', '2026-06-22 11:00:00', 'lecture', 20, 'approved');

    PRINT 'ERROR: BR1 test — expected an overlap error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR1 overlap prevention]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.2 BR2 — Unavailable-Space Prevention
-- Attempt to insert a booking against unavailable spaces.
-- Target: trg_bookings_check_space_status
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR2 — under_maintenance space';
GO

BEGIN TRY
    DECLARE @br2a_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-202');
    DECLARE @br2_user_id   INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br2a_space_id IS NULL OR @br2_user_id IS NULL
        THROW 51011, 'BR2a setup: required lookup ID is NULL.', 1;

    -- T06-CL-202 is under_maintenance
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br2a_space_id, @br2_user_id, '2026-06-25 08:00:00', '2026-06-25 10:00:00', 'lecture', 20, 'pending');

    PRINT 'ERROR: BR2a test — expected space-status error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR2 under_maintenance]: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: BR2 — retired space';
GO

BEGIN TRY
    DECLARE @br2b_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-204');
    DECLARE @br2b_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br2b_space_id IS NULL OR @br2b_user_id IS NULL
        THROW 51012, 'BR2b setup: required lookup ID is NULL.', 1;

    -- T06-CL-204 is retired
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br2b_space_id, @br2b_user_id, '2026-06-25 10:00:00', '2026-06-25 12:00:00', 'lecture', 10, 'pending');

    PRINT 'ERROR: BR2b test — expected space-status error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR2 retired space]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.3 BR3 — Capacity Prevention
-- Attempt to create a booking where expected_participants exceeds
-- the space capacity.
-- Target: trg_bookings_check_capacity
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR3 — capacity exceeded';
GO

BEGIN TRY
    DECLARE @br3_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-206');
    DECLARE @br3_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br3_space_id IS NULL OR @br3_user_id IS NULL
        THROW 51013, 'BR3 setup: required lookup ID is NULL.', 1;

    -- T06-CL-206 has capacity 10
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br3_space_id, @br3_user_id, '2026-07-01 08:00:00', '2026-07-01 10:00:00', 'lecture', 15, 'pending');

    PRINT 'ERROR: BR3 test — expected capacity error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR3 capacity]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.4 BR4 — Unresolved Maintenance Prevention
-- Attempt to create a booking that overlaps an unresolved
-- (open/in_progress) maintenance window.
-- Target: trg_bookings_check_maintenance
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR4 — maintenance overlap';
GO

BEGIN TRY
    DECLARE @br4_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-205');
    DECLARE @br4_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br4_space_id IS NULL OR @br4_user_id IS NULL
        THROW 51014, 'BR4 setup: required lookup ID is NULL.', 1;

    -- M4 exists: T06-CL-205 open maintenance starting June 20
    -- This booking June 21 09:00-10:00 on same space overlaps
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br4_space_id, @br4_user_id, '2026-06-21 09:00:00', '2026-06-21 10:00:00', 'lecture', 20, 'pending');

    PRINT 'ERROR: BR4 test — expected maintenance-block error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR4 maintenance overlap]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.5 BR6 — Approval Metadata Validation
-- Attempt to approve a pending booking without required metadata.
-- Target: trg_bookings_approval_validation
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR6 — approval metadata missing';
GO

BEGIN TRY
    DECLARE @br6_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
    DECLARE @br6_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br6_space_id IS NULL OR @br6_user_id IS NULL
        THROW 51015, 'BR6 setup: required lookup ID is NULL.', 1;

    -- Insert a pending booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br6_space_id, @br6_user_id, '2026-07-05 08:00:00', '2026-07-05 10:00:00', 'lecture', 30, 'pending');

    DECLARE @br6_booking_id INT = SCOPE_IDENTITY();

    -- Try to approve without approver_id, decision_time, decision_note
    UPDATE [dbo].[bookings]
    SET [status] = 'approved'
    WHERE [booking_id] = @br6_booking_id;

    PRINT 'ERROR: BR6 test — expected approval metadata error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR6 approval validation]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.6 BR7 — Rejection Reason Validation
-- Attempt to reject a booking without a rejection_reason.
-- Target: trg_bookings_rejection_reason
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR7 — rejection reason missing';
GO

BEGIN TRY
    DECLARE @br7_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
    DECLARE @br7_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @br7_space_id IS NULL OR @br7_user_id IS NULL
        THROW 51016, 'BR7 setup: required lookup ID is NULL.', 1;

    -- Insert a pending booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br7_space_id, @br7_user_id, '2026-07-06 08:00:00', '2026-07-06 10:00:00', 'lecture', 30, 'pending');

    DECLARE @br7_booking_id INT = SCOPE_IDENTITY();

    -- Try to reject without rejection_reason
    UPDATE [dbo].[bookings]
    SET [status] = 'rejected', [approver_id] = @br7_user_id, [decision_time] = GETDATE(), [decision_note] = N'Rejected.'
    WHERE [booking_id] = @br7_booking_id;

    PRINT 'ERROR: BR7 test — expected rejection reason error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR7 rejection reason]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.7 BR8/BR9 — Check-in and Completion Validation
-- Attempt to check in without required fields, and complete
-- without required fields.
-- Target: trg_bookings_checkin_enforcement,
--         trg_bookings_completion_enforcement
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: BR8/BR9 — check-in missing required fields';
GO

BEGIN TRY
    DECLARE @br8_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
    DECLARE @br8_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');
    DECLARE @br8_staff_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_facility_staff_1@university.edu');

    IF @br8_space_id IS NULL OR @br8_user_id IS NULL OR @br8_staff_id IS NULL
        THROW 51017, 'BR8 setup: required lookup ID is NULL.', 1;

    -- Insert a pending booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br8_space_id, @br8_user_id, '2026-07-07 08:00:00', '2026-07-07 10:00:00', 'lecture', 30, 'pending');

    DECLARE @br8_booking_id INT = SCOPE_IDENTITY();

    -- Approve it first
    UPDATE [dbo].[bookings]
    SET [status] = 'approved', [approver_id] = @br8_staff_id, [decision_time] = GETDATE(), [decision_note] = N'Approved for test.'
    WHERE [booking_id] = @br8_booking_id;

    -- Try to check in without actual_start_time, checked_in_by, initial_condition
    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in'
    WHERE [booking_id] = @br8_booking_id;

    PRINT 'ERROR: BR8/BR9 check-in test — expected check-in error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR8/BR9 check-in validation]: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: BR8/BR9 — completion missing required fields';
GO

BEGIN TRY
    DECLARE @br9_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
    DECLARE @br9_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');
    DECLARE @br9_staff_id INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_facility_staff_1@university.edu');

    IF @br9_space_id IS NULL OR @br9_user_id IS NULL OR @br9_staff_id IS NULL
        THROW 51018, 'BR9 setup: required lookup ID is NULL.', 1;

    -- Insert a pending booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@br9_space_id, @br9_user_id, '2026-07-08 08:00:00', '2026-07-08 10:00:00', 'lecture', 30, 'pending');

    DECLARE @br9_booking_id INT = SCOPE_IDENTITY();

    -- Approve it
    UPDATE [dbo].[bookings]
    SET [status] = 'approved', [approver_id] = @br9_staff_id, [decision_time] = GETDATE(), [decision_note] = N'Approved.'
    WHERE [booking_id] = @br9_booking_id;

    -- Check in properly
    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in', [actual_start_time] = GETDATE(), [checked_in_by] = @br9_staff_id, [initial_condition] = N'Clean.'
    WHERE [booking_id] = @br9_booking_id;

    -- Try to complete without actual_end_time and final_condition
    UPDATE [dbo].[bookings]
    SET [status] = 'completed'
    WHERE [booking_id] = @br9_booking_id;

    PRINT 'ERROR: BR8/BR9 completion test — expected completion error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [BR8/BR9 completion validation]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- 3.8 Declarative Constraint Tests
-- ============================================================
PRINT 'EXPECTED_ERROR_CASE: Invalid booking purpose enum';
GO

BEGIN TRY
    DECLARE @dc_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
    DECLARE @dc_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @dc_space_id IS NULL OR @dc_user_id IS NULL
        THROW 51019, 'Declarative constraint setup: required lookup ID is NULL.', 1;

    -- Invalid purpose 'party' not in CHECK constraint
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@dc_space_id, @dc_user_id, '2026-07-10 08:00:00', '2026-07-10 10:00:00', 'party', 10, 'pending');

    PRINT 'ERROR: Invalid enum test — expected CHECK constraint error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [invalid purpose enum]: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: Invalid time range (end <= start)';
GO

BEGIN TRY
    DECLARE @dc2_space_id INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = 'T06-CL-207');
    DECLARE @dc2_user_id  INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = 't06_lecturer_1@university.edu');

    IF @dc2_space_id IS NULL OR @dc2_user_id IS NULL
        THROW 51020, 'Declarative constraint setup: required lookup ID is NULL.', 1;

    -- requested_end_time = requested_start_time, violates CK_bookings_requested_end_time
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@dc2_space_id, @dc2_user_id, '2026-07-10 08:00:00', '2026-07-10 08:00:00', 'lecture', 10, 'pending');

    PRINT 'ERROR: Invalid time range test — expected CHECK error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [invalid time range]: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: Duplicate user email';
GO

BEGIN TRY
    -- Attempt to insert a user with an existing email
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES ('t06_student_1@university.edu', N'Duplicate User', NULL, 'student',
        (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science'),
        'active');

    PRINT 'ERROR: Duplicate email test — expected UNIQUE constraint error but none was raised.';
END TRY
BEGIN CATCH
    PRINT 'CAUGHT [duplicate email]: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ============================================================
-- SECTION 4: VERIFICATION QUERIES
-- ============================================================
PRINT 'SECTION 4: VERIFICATION QUERIES';
GO

-- 4.1 Row counts per table
PRINT '--- 4.1 Row counts';
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
SELECT 'bookings', COUNT(*) FROM [dbo].[bookings];
GO

-- 4.2 Status coverage — bookings
PRINT '--- 4.2 Booking status coverage';
SELECT [status], COUNT(*) AS [count] FROM [dbo].[bookings] GROUP BY [status] ORDER BY [status];
GO

-- 4.3 Status coverage — maintenances
PRINT '--- 4.3 Maintenance status coverage';
SELECT [status], COUNT(*) AS [count] FROM [dbo].[maintenances] GROUP BY [status] ORDER BY [status];
GO

-- 4.4 Status coverage — spaces
PRINT '--- 4.4 Space current_status coverage';
SELECT [current_status], COUNT(*) AS [count] FROM [dbo].[spaces] WHERE [space_code] LIKE 'T06-%' GROUP BY [current_status] ORDER BY [current_status];
GO

-- 4.5 Role coverage — users
PRINT '--- 4.5 User role coverage (T06)';
SELECT [role], COUNT(*) AS [count] FROM [dbo].[users] WHERE [email] LIKE 't06_%' GROUP BY [role] ORDER BY [role];
GO

-- 4.6 Audit timestamps (BR12) — created_at and updated_at are populated
PRINT '--- 4.6 Audit timestamp check (BR12)';
SELECT 'bookings' AS [table], MIN([created_at]) AS [min_created], MIN([updated_at]) AS [min_updated], COUNT(*) AS [rows_with_audit]
FROM [dbo].[bookings] WHERE [created_at] IS NOT NULL AND [updated_at] IS NOT NULL
UNION ALL
SELECT 'maintenances', MIN([created_at]), MIN([updated_at]), COUNT(*)
FROM [dbo].[maintenances] WHERE [created_at] IS NOT NULL AND [updated_at] IS NOT NULL
UNION ALL
SELECT 'users', MIN([created_at]), MIN([updated_at]), COUNT(*)
FROM [dbo].[users] WHERE [created_at] IS NOT NULL AND [updated_at] IS NOT NULL;
GO

-- 4.7 Soft-delete evidence (BR11/BR13)
PRINT '--- 4.7 Soft-delete evidence (BR11/BR13)';
SELECT 'bookings' AS [table], COUNT(*) AS [soft_deleted_rows]
FROM [dbo].[bookings] WHERE [is_deleted] = 1
UNION ALL
SELECT 'maintenances', COUNT(*)
FROM [dbo].[maintenances] WHERE [is_deleted] = 1;
GO

-- 4.8 Reporting: Booking history (past completed)
PRINT '--- 4.8 Reporting: Completed booking history';
SELECT [b].[booking_id], [s].[space_code], [u].[full_name] AS [requester], [b].[requested_start_time], [b].[requested_end_time], [b].[purpose], [b].[status]
FROM [dbo].[bookings] [b]
INNER JOIN [dbo].[spaces] [s] ON [b].[space_id] = [s].[space_id]
INNER JOIN [dbo].[users] [u] ON [b].[requester_id] = [u].[user_id]
WHERE [b].[status] = 'completed' AND [b].[is_deleted] = 0
ORDER BY [b].[requested_start_time] DESC;
GO

-- 4.9 Reporting: Upcoming approved bookings
PRINT '--- 4.9 Reporting: Upcoming approved bookings';
SELECT [b].[booking_id], [s].[space_code], [u].[full_name] AS [requester], [b].[requested_start_time], [b].[requested_end_time], [b].[purpose]
FROM [dbo].[bookings] [b]
INNER JOIN [dbo].[spaces] [s] ON [b].[space_id] = [s].[space_id]
INNER JOIN [dbo].[users] [u] ON [b].[requester_id] = [u].[user_id]
WHERE [b].[status] = 'approved' AND [b].[is_deleted] = 0 AND [b].[requested_start_time] > GETDATE()
ORDER BY [b].[requested_start_time];
GO

-- 4.10 Reporting: Spaces under maintenance
PRINT '--- 4.10 Reporting: Spaces under maintenance';
SELECT [s].[space_code], [s].[space_name], [s].[building], [s].[room_number], [m].[maintenance_id], [m].[problem_description], [m].[status], [m].[start_time]
FROM [dbo].[spaces] [s]
INNER JOIN [dbo].[maintenances] [m] ON [s].[space_id] = [m].[space_id]
WHERE [m].[status] IN ('open', 'in_progress') AND [m].[is_deleted] = 0
ORDER BY [m].[start_time] DESC;
GO

-- 4.11 Reporting: No-show bookings
PRINT '--- 4.11 Reporting: No-show bookings';
SELECT [b].[booking_id], [s].[space_code], [u].[full_name] AS [requester], [b].[requested_start_time], [b].[requested_end_time], [b].[purpose]
FROM [dbo].[bookings] [b]
INNER JOIN [dbo].[spaces] [s] ON [b].[space_id] = [s].[space_id]
INNER JOIN [dbo].[users] [u] ON [b].[requester_id] = [u].[user_id]
WHERE [b].[status] = 'no_show' AND [b].[is_deleted] = 0
ORDER BY [b].[requested_start_time];
GO

-- 4.12 Reporting: Space facility inventory
PRINT '--- 4.12 Reporting: Space facility inventory';
SELECT [s].[space_code], [s].[space_name], [f].[name] AS [facility], [sf].[quantity]
FROM [dbo].[space_facilities] [sf]
INNER JOIN [dbo].[spaces] [s] ON [sf].[space_id] = [s].[space_id]
INNER JOIN [dbo].[facilities] [f] ON [sf].[facility_id] = [f].[facility_id]
WHERE [s].[space_code] LIKE 'T06-%'
ORDER BY [s].[space_code], [f].[name];
GO

-- 4.13 Reporting: Active maintenance with assigned staff
PRINT '--- 4.13 Reporting: Active maintenance with assigned staff';
SELECT [m].[maintenance_id], [s].[space_code], [m].[problem_description], [u].[full_name] AS [assigned_staff], [m].[status], [m].[start_time]
FROM [dbo].[maintenances] [m]
INNER JOIN [dbo].[spaces] [s] ON [m].[space_id] = [s].[space_id]
LEFT JOIN [dbo].[users] [u] ON [m].[assigned_staff_id] = [u].[user_id]
WHERE [m].[status] IN ('open', 'in_progress') AND [m].[is_deleted] = 0
ORDER BY [m].[start_time];
GO

PRINT '=== END OF TASK 06 SAMPLE DATA SCRIPT ===';
GO
