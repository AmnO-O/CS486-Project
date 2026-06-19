-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- Sample Data Script (Task 06)
-- Dependency: Must execute AFTER outputs/05-db-definition-G05.sql
-- Target: SQL Server 2019+
-- Generated: 2026-06-19
-- ============================================================

SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

-- ============================================================
-- TEMP TABLES FOR IDENTITY PERSISTENCE ACROSS BATCHES
-- ============================================================
CREATE TABLE #dept_ids ([name] NVARCHAR(255) NOT NULL, [id] INT NOT NULL);
CREATE TABLE #user_ids ([email] NVARCHAR(255) NOT NULL, [id] INT NOT NULL);
CREATE TABLE #space_ids ([code] NVARCHAR(50) NOT NULL, [id] INT NOT NULL);
CREATE TABLE #facility_ids ([name] NVARCHAR(255) NOT NULL, [id] INT NOT NULL);
CREATE TABLE #booking_work ([label] NVARCHAR(100) NOT NULL, [id] INT NOT NULL);
CREATE TABLE #maintenance_ids ([label] NVARCHAR(100) NOT NULL, [id] INT NOT NULL);
GO

-- ============================================================
-- SECTION 1: DEPARTMENTS
-- ============================================================
PRINT 'SECTION: Valid seed data — departments';
GO

INSERT INTO [dbo].[departments] ([name]) VALUES (N'School of Computer Science');
INSERT INTO #dept_ids ([name], [id]) VALUES (N'School of Computer Science', SCOPE_IDENTITY());

INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Mathematics');
INSERT INTO #dept_ids ([name], [id]) VALUES (N'Department of Mathematics', SCOPE_IDENTITY());

INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Physics');
INSERT INTO #dept_ids ([name], [id]) VALUES (N'Department of Physics', SCOPE_IDENTITY());

INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Business Administration');
INSERT INTO #dept_ids ([name], [id]) VALUES (N'Department of Business Administration', SCOPE_IDENTITY());
GO

-- ============================================================
-- SECTION 2: USERS
-- ============================================================
PRINT 'SECTION: Valid seed data — users';
GO

DECLARE @cs INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'School of Computer Science');
DECLARE @math INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'Department of Mathematics');
DECLARE @phys INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'Department of Physics');
DECLARE @bus INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'Department of Business Administration');

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'sarah.chen@university.edu', N'Dr. Sarah Chen', N'+1-555-0101', 'facility_manager', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'sarah.chen@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'james.wilson@university.edu', N'James Wilson', N'+1-555-0102', 'facility_staff', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'james.wilson@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'maria.santos@university.edu', N'Maria Santos', N'+1-555-0103', 'facility_staff', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'maria.santos@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'robert.kim@university.edu', N'Robert Kim', N'+1-555-0104', 'department_admin', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'robert.kim@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'emily.thompson@university.edu', N'Prof. Emily Thompson', N'+1-555-0105', 'lecturer', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'emily.thompson@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'david.park@university.edu', N'Prof. David Park', N'+1-555-0106', 'lecturer', @math, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'david.park@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'lisa.wang@university.edu', N'Lisa Wang', N'+1-555-0107', 'teaching_assistant', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'lisa.wang@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'alex.johnson@university.edu', N'Alex Johnson', N'+1-555-0108', 'student', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'alex.johnson@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'kevin.brown@university.edu', N'Kevin Brown', N'+1-555-0109', 'student', @cs, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'kevin.brown@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'suspended.user@university.edu', N'Suspended User', NULL, 'student', @cs, 'suspended');
INSERT INTO #user_ids ([email], [id]) VALUES (N'suspended.user@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'inactive.user@university.edu', N'Inactive User', NULL, 'student', @cs, 'inactive');
INSERT INTO #user_ids ([email], [id]) VALUES (N'inactive.user@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'linda.chen@university.edu', N'Linda Chen', N'+1-555-0110', 'lecturer', @phys, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'linda.chen@university.edu', SCOPE_IDENTITY());

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
VALUES (N'mike.davis@university.edu', N'Mike Davis', N'+1-555-0111', 'student', @bus, 'active');
INSERT INTO #user_ids ([email], [id]) VALUES (N'mike.davis@university.edu', SCOPE_IDENTITY());
GO

-- ============================================================
-- SECTION 3: SPACES
-- ============================================================
PRINT 'SECTION: Valid seed data — spaces';
GO

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'A101', N'Main Auditorium', 'auditorium', N'Building A', N'1', N'101', 200, 'available', N'Lectures, examinations, seminars. Max 200 persons. No food or drinks.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'A101', SCOPE_IDENTITY());

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'B201', N'Lecture Room B201', 'classroom', N'Building B', N'2', N'201', 40, 'available', N'Standard classroom for lectures and tutorials. Whiteboard available.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'B201', SCOPE_IDENTITY());

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'C301', N'Computer Lab C301', 'computer_lab', N'Building C', N'3', N'301', 30, 'under_maintenance', N'Computer lab with 30 workstations. Booking required 48h in advance.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'C301', SCOPE_IDENTITY());

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'D401', N'Project Lab D401', 'project_lab', N'Building D', N'4', N'401', 20, 'available', N'Project lab for student group work. Booking in 2-hour slots.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'D401', SCOPE_IDENTITY());

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'E501', N'Meeting Room E501', 'meeting_room', N'Building E', N'5', N'501', 10, 'available', N'Small meeting room. Max 10 persons. Whiteboard and projector.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'E501', SCOPE_IDENTITY());

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'F101', N'Student Hub F101', 'student_workspace', N'Building F', N'1', N'101', 8, 'temporarily_closed', N'Student collaborative workspace. First-come first-served.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'F101', SCOPE_IDENTITY());

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy])
VALUES (N'B101', N'Retired Lab B101', 'computer_lab', N'Building B', N'1', N'101', 15, 'retired', N'This lab has been decommissioned.');
INSERT INTO #space_ids ([code], [id]) VALUES (N'B101', SCOPE_IDENTITY());
GO

-- ============================================================
-- SECTION 4: FACILITIES
-- ============================================================
PRINT 'SECTION: Valid seed data — facilities';
GO

INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Projector');
INSERT INTO #facility_ids ([name], [id]) VALUES (N'Projector', SCOPE_IDENTITY());

INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Whiteboard');
INSERT INTO #facility_ids ([name], [id]) VALUES (N'Whiteboard', SCOPE_IDENTITY());

INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Microphone');
INSERT INTO #facility_ids ([name], [id]) VALUES (N'Microphone', SCOPE_IDENTITY());

INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Computer');
INSERT INTO #facility_ids ([name], [id]) VALUES (N'Computer', SCOPE_IDENTITY());

INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Livestreaming Equipment');
INSERT INTO #facility_ids ([name], [id]) VALUES (N'Livestreaming Equipment', SCOPE_IDENTITY());

INSERT INTO [dbo].[facilities] ([name]) VALUES (N'Air Conditioner');
INSERT INTO #facility_ids ([name], [id]) VALUES (N'Air Conditioner', SCOPE_IDENTITY());
GO

-- ============================================================
-- SECTION 5: SPACE_FACILITIES
-- ============================================================
PRINT 'SECTION: Valid seed data — space_facilities';
GO

DECLARE @aid INT = (SELECT [id] FROM #space_ids WHERE [code] = N'A101');
DECLARE @bid INT = (SELECT [id] FROM #space_ids WHERE [code] = N'B201');
DECLARE @cid INT = (SELECT [id] FROM #space_ids WHERE [code] = N'C301');
DECLARE @did INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
DECLARE @eid INT = (SELECT [id] FROM #space_ids WHERE [code] = N'E501');
DECLARE @fid INT = (SELECT [id] FROM #space_ids WHERE [code] = N'F101');

DECLARE @proj INT = (SELECT [id] FROM #facility_ids WHERE [name] = N'Projector');
DECLARE @wb INT = (SELECT [id] FROM #facility_ids WHERE [name] = N'Whiteboard');
DECLARE @mic INT = (SELECT [id] FROM #facility_ids WHERE [name] = N'Microphone');
DECLARE @comp INT = (SELECT [id] FROM #facility_ids WHERE [name] = N'Computer');
DECLARE @live INT = (SELECT [id] FROM #facility_ids WHERE [name] = N'Livestreaming Equipment');
DECLARE @ac INT = (SELECT [id] FROM #facility_ids WHERE [name] = N'Air Conditioner');

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@aid, @proj, 2);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@aid, @wb, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@aid, @mic, 4);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@aid, @live, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@aid, @ac, 4);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@bid, @proj, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@bid, @wb, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@bid, @ac, 2);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@cid, @comp, 30);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@cid, @proj, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@cid, @ac, 2);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@did, @comp, 10);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@did, @wb, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@did, @ac, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@eid, @proj, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@eid, @wb, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@eid, @ac, 1);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@fid, @comp, 4);
INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES (@fid, @wb, 1);
GO

-- ============================================================
-- SECTION 6: MAINTENANCES
-- ============================================================
PRINT 'SECTION: Valid seed data — maintenances';
GO

-- Maintenance 1: in_progress on meeting room (for BR4 test later)
DECLARE @eid_m INT = (SELECT [id] FROM #space_ids WHERE [code] = N'E501');
DECLARE @l1id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');
DECLARE @fs1id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');

INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
VALUES (@eid_m, @l1id_m, @fs1id_m, N'Projector lamp malfunction — image flickers and then shuts off after 15 minutes.', '2026-06-27 08:00:00', '2026-06-27 18:00:00', 'in_progress', N'Technician assigned. Replacement bulb ordered.');
INSERT INTO #maintenance_ids ([label], [id]) VALUES (N'BR4_test_maint', SCOPE_IDENTITY());
GO

-- Maintenance 2: in_progress on computer lab (under_maintenance)
DECLARE @cid_m INT = (SELECT [id] FROM #space_ids WHERE [code] = N'C301');
DECLARE @taid_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'lisa.wang@university.edu');
DECLARE @fs2id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'maria.santos@university.edu');

INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
VALUES (@cid_m, @taid_m, @fs2id_m, N'Air conditioning failure — room temperature exceeds 35°C. Computers at risk of overheating.', '2026-06-18 14:00:00', 'in_progress');
GO

-- Maintenance 3: resolved on auditorium (past)
DECLARE @aid_m INT = (SELECT [id] FROM #space_ids WHERE [code] = N'A101');
DECLARE @l2id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'david.park@university.edu');
DECLARE @fs1id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');

INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note])
VALUES (@aid_m, @l2id_m, @fs1id_m, N'Cleaning issue — spilled liquid on stage area. Stains on floor.', '2026-06-05 09:00:00', '2026-06-05 11:30:00', 'resolved', N'Professional cleaning completed. Floor sanitized and dried.');
GO

-- Maintenance 4: soft-deleted resolved on project lab (historical preservation)
DECLARE @did_m INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
DECLARE @s1id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'alex.johnson@university.edu');
DECLARE @fs2id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'maria.santos@university.edu');

INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note], [is_deleted])
VALUES (@did_m, @s1id_m, @fs2id_m, N'Damaged furniture — desk leg is broken and work surface is unstable.', '2026-06-01 10:00:00', '2026-06-02 16:00:00', 'resolved', N'Desk replaced. Area inspected.', 1);
GO

-- Maintenance 5: open on temporarily_closed space (no assigned staff)
DECLARE @fid_m INT = (SELECT [id] FROM #space_ids WHERE [code] = N'F101');
DECLARE @l1id_m INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');

INSERT INTO [dbo].[maintenances] ([space_id], [reporter_id], [problem_description], [start_time], [status])
VALUES (@fid_m, @l1id_m, N'Network problem — Wi-Fi access point not working. Students cannot connect.', '2026-06-19 08:00:00', 'open');
GO

-- ============================================================
-- SECTION 7: VALID BOOKINGS
-- ============================================================
PRINT 'SECTION: Valid seed data — bookings';
GO

-- BOOKING 1: Completed lecture in Auditorium A101 (past)
DECLARE @aid_b INT = (SELECT [id] FROM #space_ids WHERE [code] = N'A101');
DECLARE @l1_b INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');
DECLARE @fs1_b INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
DECLARE @b1_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@aid_b, @l1_b, '2026-06-10 09:00:00', '2026-06-10 11:00:00', 'lecture', 150, 'pending');
SET @b1_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved',
    [approver_id] = @fs1_b,
    [decision_time] = '2026-06-08 14:00:00',
    [decision_note] = N'Approved for CS101 lecture.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b1_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in',
    [actual_start_time] = '2026-06-10 09:05:00',
    [checked_in_by] = @fs1_b,
    [initial_condition] = N'Clean and tidy. Projector working. All lights functional.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b1_id;

UPDATE [dbo].[bookings]
SET [status] = 'completed',
    [actual_end_time] = '2026-06-10 11:10:00',
    [final_condition] = N'Minor chalk dust on desk. Whiteboard partially erased. Overall acceptable.',
    [usage_notes] = N'Lecture finished 10 minutes late due to Q&A session.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b1_id;
GO

-- BOOKING 2: No-show administrative event in Auditorium A101 (past)
DECLARE @aid_b2 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'A101');
DECLARE @da_b2 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'robert.kim@university.edu');
DECLARE @fm_b2 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'sarah.chen@university.edu');
DECLARE @b2_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@aid_b2, @da_b2, '2026-06-11 09:00:00', '2026-06-11 10:00:00', 'administrative_event', 50, 'pending');
SET @b2_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved',
    [approver_id] = @fm_b2,
    [decision_time] = '2026-06-09 10:00:00',
    [decision_note] = N'Approved for department admin event.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b2_id;

UPDATE [dbo].[bookings]
SET [status] = 'no_show',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b2_id;
GO

-- BOOKING 3: Approved examination in Auditorium A101 (future)
DECLARE @aid_b3 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'A101');
DECLARE @l1_b3 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');
DECLARE @fs2_b3 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'maria.santos@university.edu');
DECLARE @b3_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@aid_b3, @l1_b3, '2026-06-25 09:00:00', '2026-06-25 11:00:00', 'examination', 180, 'pending');
SET @b3_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved',
    [approver_id] = @fs2_b3,
    [decision_time] = '2026-06-20 09:00:00',
    [decision_note] = N'Approved for final examination. Ensure 180 seating capacity.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b3_id;
GO

-- BOOKING 4: Checked-in seminar in Classroom B201 (current)
DECLARE @bid_b4 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'B201');
DECLARE @l2_b4 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'david.park@university.edu');
DECLARE @fs1_b4 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
DECLARE @fs2_b4 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'maria.santos@university.edu');
DECLARE @b4_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@bid_b4, @l2_b4, '2026-06-19 08:00:00', '2026-06-19 10:00:00', 'seminar', 30, 'pending');
SET @b4_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved',
    [approver_id] = @fs1_b4,
    [decision_time] = '2026-06-18 11:00:00',
    [decision_note] = N'Approved for math seminar.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b4_id;

UPDATE [dbo].[bookings]
SET [status] = 'checked_in',
    [actual_start_time] = '2026-06-19 08:10:00',
    [checked_in_by] = @fs2_b4,
    [initial_condition] = N'Room clean. Whiteboard clean. Projector functional. AC working.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b4_id;
GO

-- BOOKING 5: Approved lecture in Classroom B201 (future — different time slot)
DECLARE @bid_b5 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'B201');
DECLARE @l1_b5 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');
DECLARE @fs1_b5 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
DECLARE @b5_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@bid_b5, @l1_b5, '2026-06-25 13:00:00', '2026-06-25 15:00:00', 'lecture', 35, 'pending');
SET @b5_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'approved',
    [approver_id] = @fs1_b5,
    [decision_time] = '2026-06-23 09:00:00',
    [decision_note] = N'Approved for CS202 lecture.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b5_id;
GO

-- BOOKING 6: Pending workshop in Project Lab D401 (future)
DECLARE @did_b6 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
DECLARE @ta_b6 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'lisa.wang@university.edu');

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@did_b6, @ta_b6, '2026-06-26 14:00:00', '2026-06-26 16:00:00', 'workshop', 15, 'pending');
GO

-- BOOKING 7: Soft-deleted completed student activity in Project Lab D401 (past — historical preservation)
DECLARE @did_b7 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
DECLARE @s1_b7 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'alex.johnson@university.edu');
DECLARE @fs1_b7 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
DECLARE @b7_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [is_deleted])
VALUES (@did_b7, @s1_b7, '2026-06-09 10:00:00', '2026-06-09 12:00:00', 'student_activity', 10, 'completed', 1);
SET @b7_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [actual_start_time] = '2026-06-09 10:05:00',
    [checked_in_by] = @fs1_b7,
    [initial_condition] = N'Lab was tidy. Computers functional.',
    [actual_end_time] = '2026-06-09 12:10:00',
    [final_condition] = N'All computers shut down properly. Workspace clean.',
    [usage_notes] = N'Student group project session.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b7_id;
GO

-- BOOKING 8: Rejected meeting in Meeting Room E501 (past)
DECLARE @eid_b8 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'E501');
DECLARE @s2_b8 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'kevin.brown@university.edu');
DECLARE @fs2_b8 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'maria.santos@university.edu');
DECLARE @b8_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@eid_b8, @s2_b8, '2026-06-12 14:00:00', '2026-06-12 15:00:00', 'meeting', 5, 'pending');
SET @b8_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'rejected',
    [approver_id] = @fs2_b8,
    [decision_time] = '2026-06-11 16:00:00',
    [decision_note] = N'Meeting request rejected due to scheduling conflict with faculty training.',
    [rejection_reason] = N'Room already reserved for mandatory faculty training session.',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b8_id;
GO

-- BOOKING 9: Cancelled meeting in Meeting Room E501 (past)
DECLARE @eid_b9 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'E501');
DECLARE @l2_b9 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'david.park@university.edu');
DECLARE @b9_id INT;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
VALUES (@eid_b9, @l2_b9, '2026-06-13 10:00:00', '2026-06-13 11:00:00', 'meeting', 4, 'pending');
SET @b9_id = SCOPE_IDENTITY();

UPDATE [dbo].[bookings]
SET [status] = 'cancelled',
    [updated_at] = GETDATE()
WHERE [booking_id] = @b9_id;
GO

-- ============================================================
-- SECTION 8: EXPECTED-ERROR TEST CASES
-- ============================================================
PRINT 'SECTION: Expected-error test cases';
GO

-- -------------------------------------------------------
-- Expected error: BR1 — Overlap prevention
-- Insert a pending booking on A101 that overlaps the existing
-- approved booking (2026-06-25 09:00–11:00). Then try to UPDATE
-- it to approved, which should trigger trg_bookings_prevent_overlap.
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR1 overlap prevention';
GO

BEGIN TRY
    DECLARE @aid_e1 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'A101');
    DECLARE @s1_e1 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'alex.johnson@university.edu');
    DECLARE @fs1_e1 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
    DECLARE @e1_id INT;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@aid_e1, @s1_e1, '2026-06-25 10:00:00', '2026-06-25 12:00:00', 'student_activity', 20, 'pending');
    SET @e1_id = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @fs1_e1,
        [decision_time] = '2026-06-24 10:00:00',
        [decision_note] = N'Attempt to approve overlapping booking.',
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e1_id;

    PRINT 'ERROR: BR1 test did not raise an error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR2 — Unavailable space (under_maintenance)
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR2 unavailable space — under_maintenance';
GO

BEGIN TRY
    DECLARE @cid_e2 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'C301');
    DECLARE @l1_e2 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@cid_e2, @l1_e2, '2026-06-28 09:00:00', '2026-06-28 11:00:00', 'lecture', 20, 'pending');
    PRINT 'ERROR: BR2 under_maintenance test did not raise error on INSERT — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR2 — Unavailable space (retired)
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR2 unavailable space — retired';
GO

BEGIN TRY
    DECLARE @rid_e2b INT = (SELECT [id] FROM #space_ids WHERE [code] = N'B101');
    DECLARE @l1_e2b INT = (SELECT [id] FROM #user_ids WHERE [email] = N'emily.thompson@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@rid_e2b, @l1_e2b, '2026-06-28 09:00:00', '2026-06-28 11:00:00', 'lecture', 10, 'pending');
    PRINT 'ERROR: BR2 retired test did not raise error on INSERT — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR2 — Unavailable space (temporarily_closed)
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR2 unavailable space — temporarily_closed';
GO

BEGIN TRY
    DECLARE @fid_e2c INT = (SELECT [id] FROM #space_ids WHERE [code] = N'F101');
    DECLARE @s2_e2c INT = (SELECT [id] FROM #user_ids WHERE [email] = N'kevin.brown@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@fid_e2c, @s2_e2c, '2026-06-28 10:00:00', '2026-06-28 12:00:00', 'student_activity', 5, 'pending');
    PRINT 'ERROR: BR2 temporarily_closed test did not raise error on INSERT — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR3 — Capacity limit exceeded
-- E501 capacity is 10. Try booking with 20 participants.
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR3 capacity limit exceeded';
GO

BEGIN TRY
    DECLARE @eid_e3 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'E501');
    DECLARE @s2_e3 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'kevin.brown@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@eid_e3, @s2_e3, '2026-06-28 09:00:00', '2026-06-28 10:00:00', 'meeting', 20, 'pending');
    PRINT 'ERROR: BR3 test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR4 — Overlapping unresolved maintenance
-- Meeting Room E501 has an in_progress maintenance from
-- 2026-06-27 08:00 to 2026-06-27 18:00. Try to create a booking
-- that overlaps this window.
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR4 overlapping unresolved maintenance';
GO

BEGIN TRY
    DECLARE @eid_e4 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'E501');
    DECLARE @l2_e4 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'david.park@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@eid_e4, @l2_e4, '2026-06-27 09:00:00', '2026-06-27 10:00:00', 'meeting', 5, 'pending');
    PRINT 'ERROR: BR4 test did not raise error on INSERT — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR6 — Missing approval metadata (no decision_note)
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR6 missing approval metadata';
GO

BEGIN TRY
    DECLARE @did_e6 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @ta_e6 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'lisa.wang@university.edu');
    DECLARE @fs1_e6 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
    DECLARE @e6_id INT;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_e6, @ta_e6, '2026-06-28 14:00:00', '2026-06-28 16:00:00', 'workshop', 10, 'pending');
    SET @e6_id = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @fs1_e6,
        [decision_time] = '2026-06-27 10:00:00',
        -- decision_note is deliberately NULL
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e6_id;

    PRINT 'ERROR: BR6 test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR7 — Rejection missing rejection_reason
-- Try to reject a pending booking without rejection_reason.
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR7 missing rejection reason';
GO

BEGIN TRY
    DECLARE @did_e7 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @s1_e7 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'alex.johnson@university.edu');
    DECLARE @fs1_e7 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
    DECLARE @e7_id INT;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_e7, @s1_e7, '2026-06-28 09:00:00', '2026-06-28 11:00:00', 'student_activity', 8, 'pending');
    SET @e7_id = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'rejected',
        [approver_id] = @fs1_e7,
        [decision_time] = '2026-06-27 10:00:00',
        [decision_note] = N'Rejected.',
        -- rejection_reason is deliberately NULL
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e7_id;

    PRINT 'ERROR: BR7 test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR8/BR9 — Check-in missing actual_start_time
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR8/BR9 check-in without actual_start_time';
GO

BEGIN TRY
    DECLARE @did_e8 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @ta_e8 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'lisa.wang@university.edu');
    DECLARE @fs1_e8 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
    DECLARE @e8_id INT;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_e8, @ta_e8, '2026-06-30 10:00:00', '2026-06-30 12:00:00', 'workshop', 10, 'pending');
    SET @e8_id = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @fs1_e8,
        [decision_time] = '2026-06-29 10:00:00',
        [decision_note] = N'Approved for test.',
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e8_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in',
        [checked_in_by] = @fs1_e8,
        [initial_condition] = N'Room is clean.',
        -- actual_start_time is deliberately NULL
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e8_id;

    PRINT 'ERROR: BR8/BR9 check-in test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: BR8/BR9 — Completion missing actual_end_time
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: BR8/BR9 completion without actual_end_time';
GO

BEGIN TRY
    DECLARE @did_e9 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @s2_e9 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'kevin.brown@university.edu');
    DECLARE @fm_e9 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'sarah.chen@university.edu');
    DECLARE @fs1_e9 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'james.wilson@university.edu');
    DECLARE @e9_id INT;

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_e9, @s2_e9, '2026-06-28 10:00:00', '2026-06-28 12:00:00', 'student_activity', 8, 'pending');
    SET @e9_id = SCOPE_IDENTITY();

    UPDATE [dbo].[bookings]
    SET [status] = 'approved',
        [approver_id] = @fm_e9,
        [decision_time] = '2026-06-27 10:00:00',
        [decision_note] = N'Approved for test.',
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e9_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'checked_in',
        [actual_start_time] = '2026-06-28 10:05:00',
        [checked_in_by] = @fs1_e9,
        [initial_condition] = N'Clean.',
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e9_id;

    UPDATE [dbo].[bookings]
    SET [status] = 'completed',
        [final_condition] = N'Good.',
        -- actual_end_time is deliberately NULL
        [updated_at] = GETDATE()
    WHERE [booking_id] = @e9_id;

    PRINT 'ERROR: BR8/BR9 completion test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Invalid booking status enum
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Invalid booking status enum value';
GO

BEGIN TRY
    DECLARE @did_d1 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @s1_d1 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'alex.johnson@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_d1, @s1_d1, '2026-07-01 09:00:00', '2026-07-01 10:00:00', 'meeting', 5, 'invalid_status');
    PRINT 'ERROR: Invalid enum test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Invalid time range (end <= start)
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Invalid time range (end <= start)';
GO

BEGIN TRY
    DECLARE @did_d2 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @s2_d2 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'kevin.brown@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_d2, @s2_d2, '2026-07-01 10:00:00', '2026-07-01 09:00:00', 'meeting', 5, 'pending');
    PRINT 'ERROR: Invalid time range test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Duplicate email
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Duplicate user email';
GO

BEGIN TRY
    DECLARE @cs_d3 INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'School of Computer Science');

    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES (N'sarah.chen@university.edu', N'Duplicate User', NULL, 'student', @cs_d3, 'active');
    PRINT 'ERROR: Duplicate email test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Duplicate space code
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Duplicate space code';
GO

BEGIN TRY
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status])
    VALUES (N'A101', N'Duplicate Auditorium', 'auditorium', N'Building X', N'1', N'999', 100, 'available');
    PRINT 'ERROR: Duplicate space code test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Invalid space type
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Invalid space type enum';
GO

BEGIN TRY
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status])
    VALUES (N'Z999', N'Invalid Type Space', 'laboratory', N'Building Z', N'1', N'001', 10, 'available');
    PRINT 'ERROR: Invalid space type test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Invalid user role
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Invalid user role enum';
GO

BEGIN TRY
    DECLARE @cs_d5 INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'School of Computer Science');

    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES (N'invalid.role@university.edu', N'Invalid Role User', NULL, 'admin', @cs_d5, 'active');
    PRINT 'ERROR: Invalid user role test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Invalid account status
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Invalid account status enum';
GO

BEGIN TRY
    DECLARE @cs_d6 INT = (SELECT [id] FROM #dept_ids WHERE [name] = N'School of Computer Science');

    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES (N'invalid.status@university.edu', N'Invalid Status User', NULL, 'student', @cs_d6, 'banned');
    PRINT 'ERROR: Invalid account status test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Negative/zero capacity
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Non-positive space capacity';
GO

BEGIN TRY
    INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status])
    VALUES (N'Z000', N'Zero Capacity', 'meeting_room', N'Building Z', N'0', N'000', 0, 'available');
    PRINT 'ERROR: Zero capacity test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — FK violation (invalid department_id)
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: FK violation — invalid department_id';
GO

BEGIN TRY
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES (N'nonexistent.dept@university.edu', N'No Dept User', NULL, 'student', 99999, 'active');
    PRINT 'ERROR: FK violation test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- -------------------------------------------------------
-- Expected error: Declarative — Expected participants = 0
-- -------------------------------------------------------
PRINT 'EXPECTED_ERROR_CASE: Non-positive expected participants';
GO

BEGIN TRY
    DECLARE @did_d9 INT = (SELECT [id] FROM #space_ids WHERE [code] = N'D401');
    DECLARE @s1_d9 INT = (SELECT [id] FROM #user_ids WHERE [email] = N'alex.johnson@university.edu');

    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@did_d9, @s1_d9, '2026-07-01 09:00:00', '2026-07-01 10:00:00', 'meeting', 0, 'pending');
    PRINT 'ERROR: Zero expected participants test did not raise error — unexpected pass.';
END TRY
BEGIN CATCH
    PRINT 'Expected error captured: ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- SECTION 9: VERIFICATION QUERIES
-- ============================================================
PRINT 'SECTION: Verification queries';
GO

PRINT 'VERIFICATION: Row counts per table';
GO
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

PRINT 'VERIFICATION: Booking status distribution';
GO
SELECT [status], COUNT(*) AS [count]
FROM [dbo].[bookings]
GROUP BY [status]
ORDER BY [status];
GO

PRINT 'VERIFICATION: Booking purpose distribution';
GO
SELECT [purpose], COUNT(*) AS [count]
FROM [dbo].[bookings]
GROUP BY [purpose]
ORDER BY [purpose];
GO

PRINT 'VERIFICATION: User role distribution';
GO
SELECT [role], COUNT(*) AS [count]
FROM [dbo].[users]
GROUP BY [role]
ORDER BY [role];
GO

PRINT 'VERIFICATION: Space type distribution';
GO
SELECT [space_type], COUNT(*) AS [count]
FROM [dbo].[spaces]
GROUP BY [space_type]
ORDER BY [space_type];
GO

PRINT 'VERIFICATION: Space status distribution';
GO
SELECT [current_status], COUNT(*) AS [count]
FROM [dbo].[spaces]
GROUP BY [current_status]
ORDER BY [current_status];
GO

PRINT 'VERIFICATION: Maintenance status distribution';
GO
SELECT [status], COUNT(*) AS [count]
FROM [dbo].[maintenances]
GROUP BY [status]
ORDER BY [status];
GO

PRINT 'VERIFICATION: BR12 — Audit trail evidence (created_at and updated_at populated)';
GO
SELECT 'departments' AS [table],
       COUNT(*) AS [total_rows],
       SUM(CASE WHEN [created_at] IS NOT NULL THEN 1 ELSE 0 END) AS [created_filled],
       SUM(CASE WHEN [updated_at] IS NOT NULL THEN 1 ELSE 0 END) AS [updated_filled]
FROM [dbo].[departments]
UNION ALL
SELECT 'users',
       COUNT(*),
       SUM(CASE WHEN [created_at] IS NOT NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN [updated_at] IS NOT NULL THEN 1 ELSE 0 END)
FROM [dbo].[users]
UNION ALL
SELECT 'spaces',
       COUNT(*),
       SUM(CASE WHEN [created_at] IS NOT NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN [updated_at] IS NOT NULL THEN 1 ELSE 0 END)
FROM [dbo].[spaces]
UNION ALL
SELECT 'facilities',
       COUNT(*),
       SUM(CASE WHEN [created_at] IS NOT NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN [updated_at] IS NOT NULL THEN 1 ELSE 0 END)
FROM [dbo].[facilities]
UNION ALL
SELECT 'maintenances',
       COUNT(*),
       SUM(CASE WHEN [created_at] IS NOT NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN [updated_at] IS NOT NULL THEN 1 ELSE 0 END)
FROM [dbo].[maintenances]
UNION ALL
SELECT 'bookings',
       COUNT(*),
       SUM(CASE WHEN [created_at] IS NOT NULL THEN 1 ELSE 0 END),
       SUM(CASE WHEN [updated_at] IS NOT NULL THEN 1 ELSE 0 END)
FROM [dbo].[bookings];
GO

PRINT 'VERIFICATION: BR11/BR13 — Soft-delete preservation evidence';
GO
SELECT 'soft_deleted_maintenances' AS [record_type], COUNT(*) AS [count]
FROM [dbo].[maintenances]
WHERE [is_deleted] = 1;
SELECT 'soft_deleted_bookings' AS [record_type], COUNT(*) AS [count]
FROM [dbo].[bookings]
WHERE [is_deleted] = 1;
GO

PRINT 'VERIFICATION: BR14 — Reporting — Booking history for Auditorium A101';
GO
SELECT b.[booking_id], s.[space_code], u.[full_name] AS [requester],
       b.[requested_start_time], b.[requested_end_time], b.[purpose], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE s.[space_code] = N'A101'
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time] DESC;
GO

PRINT 'VERIFICATION: BR14 — Reporting — Upcoming bookings';
GO
SELECT b.[booking_id], s.[space_code], u.[full_name] AS [requester],
       b.[requested_start_time], b.[requested_end_time], b.[purpose], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE b.[requested_start_time] > GETDATE()
  AND b.[status] IN ('pending', 'approved')
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time] ASC;
GO

PRINT 'VERIFICATION: BR14 — Reporting — Spaces under maintenance';
GO
SELECT s.[space_code], s.[space_name], m.[maintenance_id],
       m.[problem_description], m.[status], u.[full_name] AS [assigned_staff]
FROM [dbo].[spaces] s
INNER JOIN [dbo].[maintenances] m ON s.[space_id] = m.[space_id]
LEFT JOIN [dbo].[users] u ON m.[assigned_staff_id] = u.[user_id]
WHERE m.[is_deleted] = 0
  AND m.[status] IN ('open', 'in_progress')
ORDER BY s.[space_code];
GO

PRINT 'VERIFICATION: BR14 — Reporting — No-show bookings';
GO
SELECT b.[booking_id], s.[space_code], u.[full_name] AS [requester],
       b.[requested_start_time], b.[requested_end_time], b.[purpose]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE b.[status] = 'no_show'
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time] DESC;
GO

PRINT 'VERIFICATION: BR14 — Reporting — Booking history for a specific lecturer';
GO
SELECT b.[booking_id], s.[space_code], b.[requested_start_time],
       b.[requested_end_time], b.[purpose], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON b.[space_id] = s.[space_id]
INNER JOIN [dbo].[users] u ON b.[requester_id] = u.[user_id]
WHERE u.[email] = N'emily.thompson@university.edu'
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time] DESC;
GO

PRINT 'VERIFICATION: Maintenance records with assigned staff';
GO
SELECT m.[maintenance_id], s.[space_code], m.[problem_description],
       m.[status], u.[full_name] AS [assigned_staff]
FROM [dbo].[maintenances] m
INNER JOIN [dbo].[spaces] s ON m.[space_id] = s.[space_id]
LEFT JOIN [dbo].[users] u ON m.[assigned_staff_id] = u.[user_id]
WHERE m.[assigned_staff_id] IS NOT NULL
  AND m.[is_deleted] = 0;
GO

PRINT '============================================';
PRINT 'Task 06 sample data script completed.';
PRINT 'Review any expected errors above — all should';
PRINT 'display captured error messages, not script abort.';
PRINT '============================================';
GO

-- ============================================================
-- CLEANUP: Drop temp tables
-- ============================================================
DROP TABLE #booking_work;
DROP TABLE #maintenance_ids;
DROP TABLE #facility_ids;
DROP TABLE #space_ids;
DROP TABLE #user_ids;
DROP TABLE #dept_ids;
GO
