SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
    
-- ============================================================
-- CS486 Group G05 - Campus Space Management System
-- Task 06: Sample Data Preparation
-- Dependency: run after outputs/05-db-definition-G05.sql
-- Target: SQL Server 2019+ (T-SQL)
-- Authentication note: validation command uses sqlcmd Windows Auth (-E).
-- ============================================================
-- Sample-data assumptions and strategy:
-- - A single @now = SYSDATETIME() anchor drives past/current/future rows.
-- - Task-owned rows use stable natural keys: T06-* space codes,
--   t06.*@university.edu emails, and T06-prefixed facility names.
-- - Cleanup-and-reseed deletes only Task 06-owned rows through owned spaces,
--   users, and facilities in reverse FK order.
-- - Departments are canonical reference rows inserted with guarded inserts.
-- - Booking workflow follows Task 05 split tables:
--   bookings -> booking_approvals -> booking_sessions.
-- - Expected-error cases are isolated in transactions and match the intended
--   trigger message or DDL constraint name.
-- - Maintenance completion proves both the concurrent-ticket guard and the
--   final-ticket restoration side effect.
-- ============================================================

PRINT 'SECTION 0: Cleanup previous Task 06-owned rows';

DELETE bs
FROM [dbo].[booking_sessions] bs
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[bookings] b
    LEFT JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
    LEFT JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
    WHERE b.[booking_id] = bs.[booking_id]
      AND (s.[space_code] LIKE N'T06-%' OR u.[email] LIKE N't06.%@university.edu')
);

DELETE ba
FROM [dbo].[booking_approvals] ba
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[bookings] b
    LEFT JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
    LEFT JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
    WHERE b.[booking_id] = ba.[booking_id]
      AND (s.[space_code] LIKE N'T06-%' OR u.[email] LIKE N't06.%@university.edu')
);

DELETE b
FROM [dbo].[bookings] b
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[spaces] s
    WHERE s.[space_id] = b.[space_id]
      AND s.[space_code] LIKE N'T06-%'
)
OR EXISTS (
    SELECT 1
    FROM [dbo].[users] u
    WHERE u.[user_id] = b.[requester_id]
      AND u.[email] LIKE N't06.%@university.edu'
);

DELETE m
FROM [dbo].[maintenance] m
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[spaces] s
    WHERE s.[space_id] = m.[space_id]
      AND s.[space_code] LIKE N'T06-%'
)
OR EXISTS (
    SELECT 1
    FROM [dbo].[users] u
    WHERE (u.[user_id] = m.[reporter_id] OR u.[user_id] = m.[assigned_staff_id])
      AND u.[email] LIKE N't06.%@university.edu'
);

DELETE sf
FROM [dbo].[space_facilities] sf
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[spaces] s
    WHERE s.[space_id] = sf.[space_id]
      AND s.[space_code] LIKE N'T06-%'
)
OR EXISTS (
    SELECT 1
    FROM [dbo].[facilities] f
    WHERE f.[facility_id] = sf.[facility_id]
      AND f.[name] LIKE N'T06 %'
);

DELETE FROM [dbo].[spaces]
WHERE [space_code] LIKE N'T06-%';

DELETE FROM [dbo].[users]
WHERE [email] LIKE N't06.%@university.edu';

DELETE FROM [dbo].[facilities]
WHERE [name] LIKE N'T06 %';

PRINT 'SECTION 1: Departments';

IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School of Computer Science')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School of Computer Science');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Mathematics');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Department of Physics')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Department of Physics');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'Faculty of Engineering');
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School Administration')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School Administration');

PRINT 'SECTION 2: Users - all roles and account statuses';

DECLARE @now DATETIME2 = SYSDATETIME();
DECLARE @dept_cs INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @dept_math INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @dept_physics INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Physics');
DECLARE @dept_eng INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering');
DECLARE @dept_admin INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School Administration');

IF @dept_cs IS NULL OR @dept_math IS NULL OR @dept_physics IS NULL OR @dept_eng IS NULL OR @dept_admin IS NULL
    THROW 51006, 'Task 06 setup failed: department lookup returned NULL.', 1;

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status]) VALUES
(N't06.student1@university.edu', N'Alice Nguyen', N'090-100-0001', 'student', @dept_cs, 'active'),
(N't06.lecturer1@university.edu', N'Dr. Minh Tran', N'090-100-0002', 'lecturer', @dept_cs, 'active'),
(N't06.ta1@university.edu', N'Bao Pham', N'090-100-0003', 'teaching_assistant', @dept_math, 'active'),
(N't06.staff1@university.edu', N'Chi Le', N'090-100-0004', 'facility_staff', @dept_admin, 'active'),
(N't06.manager1@university.edu', N'Dung Ho', N'090-100-0005', 'facility_manager', @dept_admin, 'active'),
(N't06.admin1@university.edu', N'Ha Vu', N'090-100-0006', 'department_admin', @dept_cs, 'inactive'),
(N't06.student2@university.edu', N'Lan Do', NULL, 'student', @dept_physics, 'suspended'),
(N't06.staff2@university.edu', N'Khanh Bui', N'090-100-0008', 'facility_staff', @dept_eng, 'active');

DECLARE @student INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu');
DECLARE @student2 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student2@university.edu');
DECLARE @lecturer INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.lecturer1@university.edu');
DECLARE @ta INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.ta1@university.edu');
DECLARE @staff INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.staff1@university.edu');
DECLARE @staff2 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.staff2@university.edu');
DECLARE @manager INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.manager1@university.edu');
DECLARE @dept_admin_user INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.admin1@university.edu');

IF @student IS NULL OR @lecturer IS NULL OR @ta IS NULL OR @staff IS NULL OR @staff2 IS NULL OR @manager IS NULL OR @dept_admin_user IS NULL
    THROW 51006, 'Task 06 setup failed: user lookup returned NULL.', 1;

PRINT 'SECTION 3: Spaces - all types and statuses';

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy]) VALUES
(N'T06-AUD-001', N'Main Auditorium', 'auditorium', N'Alpha Building', N'1', N'AUD-001', 300, 'available', N'Large events require staff supervision.'),
(N'T06-CL-101', N'Classroom 101', 'classroom', N'Beta Building', N'1', N'101', 60, 'available', N'Teaching use has priority during business hours.'),
(N'T06-LAB-201', N'Computer Lab 201', 'computer_lab', N'Gamma Building', N'2', N'201', 45, 'available', N'Food and drink are not allowed.'),
(N'T06-PL-301', N'Project Lab 301', 'project_lab', N'Delta Building', N'3', N'301', 30, 'under_maintenance', N'Safety briefing required before project work.'),
(N'T06-MR-401', N'Meeting Room 401', 'meeting_room', N'Alpha Building', N'4', N'401', 20, 'available', N'Administrative meetings limited to two hours.'),
(N'T06-SW-501', N'Student Workspace 501', 'student_workspace', N'Library Annex', N'5', N'501', 80, 'available', N'Open collaboration area.'),
(N'T06-AUD-002', N'Closed Auditorium Annex', 'auditorium', N'Alpha Building', N'B1', N'AUD-002', 120, 'temporarily_closed', N'Closed for acoustic treatment.'),
(N'T06-OLD-001', N'Retired Seminar Room', 'meeting_room', N'Old Campus', N'2', N'210', 25, 'retired', N'Retired from booking inventory.'),
(N'T06-CL-102', N'Classroom 102 Maintenance Drill', 'classroom', N'Beta Building', N'1', N'102', 50, 'under_maintenance', N'Used for maintenance restoration proof.');

DECLARE @sp_aud INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-AUD-001');
DECLARE @sp_class INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CL-101');
DECLARE @sp_lab INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-LAB-201');
DECLARE @sp_project INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-PL-301');
DECLARE @sp_meeting INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-MR-401');
DECLARE @sp_workspace INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-501');
DECLARE @sp_closed INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-AUD-002');
DECLARE @sp_retired INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-OLD-001');
DECLARE @sp_restoration INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CL-102');

IF @sp_aud IS NULL OR @sp_class IS NULL OR @sp_lab IS NULL OR @sp_project IS NULL OR @sp_meeting IS NULL OR @sp_workspace IS NULL OR @sp_closed IS NULL OR @sp_retired IS NULL OR @sp_restoration IS NULL
    THROW 51006, 'Task 06 setup failed: space lookup returned NULL.', 1;

PRINT 'SECTION 4: Facilities and space_facilities';

INSERT INTO [dbo].[facilities] ([name]) VALUES
(N'T06 Projector'),
(N'T06 Whiteboard'),
(N'T06 Microphone'),
(N'T06 Computer'),
(N'T06 Livestreaming Equipment'),
(N'T06 Air Conditioner');

DECLARE @fac_projector INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Projector');
DECLARE @fac_whiteboard INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Whiteboard');
DECLARE @fac_microphone INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Microphone');
DECLARE @fac_computer INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Computer');
DECLARE @fac_stream INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Livestreaming Equipment');
DECLARE @fac_ac INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Air Conditioner');

IF @fac_projector IS NULL OR @fac_whiteboard IS NULL OR @fac_microphone IS NULL OR @fac_computer IS NULL OR @fac_stream IS NULL OR @fac_ac IS NULL
    THROW 51006, 'Task 06 setup failed: facility lookup returned NULL.', 1;

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES
(@sp_aud, @fac_projector, 2), (@sp_aud, @fac_microphone, 6), (@sp_aud, @fac_stream, 1), (@sp_aud, @fac_ac, 4),
(@sp_class, @fac_projector, 1), (@sp_class, @fac_whiteboard, 2), (@sp_class, @fac_ac, 1),
(@sp_lab, @fac_computer, 45), (@sp_lab, @fac_projector, 1), (@sp_lab, @fac_ac, 2),
(@sp_project, @fac_whiteboard, 1), (@sp_project, @fac_computer, 12),
(@sp_meeting, @fac_projector, 1), (@sp_meeting, @fac_whiteboard, 1),
(@sp_workspace, @fac_whiteboard, 3), (@sp_workspace, @fac_ac, 2);

PRINT 'SECTION 5: Maintenance valid rows and restoration workflow';

INSERT INTO [dbo].[maintenance] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note]) VALUES
(@sp_project, @staff, @staff2, N'Broken Projector prevents project demonstrations.', DATEADD(day, -3, @now), NULL, 'open', NULL),
(@sp_lab, @lecturer, @staff, N'Network Problems affecting exam lab machines.', DATEADD(day, -10, @now), DATEADD(day, -8, @now), 'resolved', N'Switch replaced and tested.'),
(@sp_project, @student, @staff, N'Cleaning Issues after student activity.', DATEADD(day, -2, @now), NULL, 'in_progress', N'Cleaning team scheduled.'),
(@sp_closed, @manager, @staff, N'Damaged Furniture in closed auditorium annex.', DATEADD(day, -14, @now), DATEADD(day, -12, @now), 'resolved', N'Furniture removed from service.'),
(@sp_retired, @staff, @staff2, N'Air Conditioning Failure in retired room; retained for history.', DATEADD(day, -30, @now), DATEADD(day, -29, @now), 'resolved', N'No repair because room is retired.'),
(@sp_class, @student2, @staff, N'Soft-deleted historical maintenance report.', DATEADD(day, -40, @now), DATEADD(day, -39, @now), 'resolved', N'Retained for audit.');

UPDATE [dbo].[maintenance]
SET [is_deleted] = 1
WHERE [space_id] = @sp_class
  AND [problem_description] = N'Soft-deleted historical maintenance report.';

INSERT INTO [dbo].[maintenance] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note]) VALUES
(@sp_restoration, @staff, @staff, N'Restoration proof ticket A - AC inspection.', DATEADD(day, -1, @now), NULL, 'in_progress', NULL),
(@sp_restoration, @staff2, @staff2, N'Restoration proof ticket B - lighting inspection.', DATEADD(day, -1, @now), NULL, 'in_progress', NULL);

DECLARE @maint_a INT = (SELECT [maintenance_id] FROM [dbo].[maintenance] WHERE [space_id] = @sp_restoration AND [problem_description] = N'Restoration proof ticket A - AC inspection.');
DECLARE @maint_b INT = (SELECT [maintenance_id] FROM [dbo].[maintenance] WHERE [space_id] = @sp_restoration AND [problem_description] = N'Restoration proof ticket B - lighting inspection.');

PRINT 'VERIFY: V00A - maintenance restoration guard keeps space under maintenance while another active ticket remains';
UPDATE [dbo].[maintenance]
SET [status] = 'resolved',
    [completion_time] = DATEADD(minute, -30, @now),
    [result_note] = N'AC inspection complete; lighting ticket remains active.'
WHERE [maintenance_id] = @maint_a;
SELECT [space_code], [current_status] AS status_after_first_resolution
FROM [dbo].[spaces]
WHERE [space_id] = @sp_restoration;

PRINT 'VERIFY: V00B - maintenance restoration side effect restores availability after final active ticket';
UPDATE [dbo].[maintenance]
SET [status] = 'resolved',
    [completion_time] = DATEADD(minute, -20, @now),
    [result_note] = N'Lighting inspection complete; no active maintenance remains.'
WHERE [maintenance_id] = @maint_b;
SELECT [space_code], [current_status] AS status_after_final_resolution
FROM [dbo].[spaces]
WHERE [space_id] = @sp_restoration;

PRINT 'SECTION 6: Booking lifecycle valid workflows';

-- pending / lecture
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_class, @lecturer, DATEADD(day, 7, @now), DATEADD(hour, 2, DATEADD(day, 7, @now)), 'lecture', 45);
DECLARE @booking_pending INT = SCOPE_IDENTITY();

-- approved / examination
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_aud, @lecturer, DATEADD(day, 8, @now), DATEADD(hour, 3, DATEADD(day, 8, @now)), 'examination', 180);
DECLARE @booking_approved INT = SCOPE_IDENTITY();
INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
VALUES (@booking_approved, @manager, DATEADD(minute, 5, @now), 'approved', N'Approved for final examination seating plan.');

-- rejected / seminar
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_meeting, @ta, DATEADD(day, 9, @now), DATEADD(hour, 1, DATEADD(day, 9, @now)), 'seminar', 18);
DECLARE @booking_rejected INT = SCOPE_IDENTITY();
INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [rejection_reason], [decision_note])
VALUES (@booking_rejected, @staff, DATEADD(minute, 6, @now), 'rejected', N'Room reserved for department board meeting.', N'Requester advised to choose another slot.');

-- cancelled from pending / workshop
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_workspace, @student, DATEADD(day, 10, @now), DATEADD(hour, 2, DATEADD(day, 10, @now)), 'workshop', 35);
DECLARE @booking_cancelled_pending INT = SCOPE_IDENTITY();
UPDATE [dbo].[bookings]
SET [status] = 'cancelled'
WHERE [booking_id] = @booking_cancelled_pending;

-- cancelled from approved / meeting
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_meeting, @dept_admin_user, DATEADD(day, 11, @now), DATEADD(hour, 1, DATEADD(day, 11, @now)), 'meeting', 15);
DECLARE @booking_cancelled_approved INT = SCOPE_IDENTITY();
INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
VALUES (@booking_cancelled_approved, @staff, DATEADD(minute, 7, @now), 'approved', N'Approved, then requester cancelled.');
UPDATE [dbo].[bookings]
SET [status] = 'cancelled'
WHERE [booking_id] = @booking_cancelled_approved;

-- checked_in / student_activity
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_meeting, @student, DATEADD(minute, -30, @now), DATEADD(hour, 2, @now), 'student_activity', 12);
DECLARE @booking_checked_in INT = SCOPE_IDENTITY();
INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
VALUES (@booking_checked_in, @manager, DATEADD(minute, -45, @now), 'approved', N'Approved for student club planning session.');
INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
VALUES (@booking_checked_in, DATEADD(minute, -25, @now), @staff, N'Room clean, projector remote present.');

-- completed / administrative_event
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_lab, @dept_admin_user, DATEADD(day, -6, @now), DATEADD(hour, 2, DATEADD(day, -6, @now)), 'administrative_event', 30);
DECLARE @booking_completed INT = SCOPE_IDENTITY();
INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
VALUES (@booking_completed, @staff, DATEADD(day, -7, @now), 'approved', N'Approved for software installation briefing.');
INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
VALUES (@booking_completed, DATEADD(day, -6, @now), @staff2, N'Computers powered on; network stable.');
UPDATE [dbo].[booking_sessions]
SET [actual_end_time] = DATEADD(hour, 2, DATEADD(day, -6, @now)),
    [final_condition] = N'Lab returned clean; all computers shut down.',
    [usage_notes] = N'Administrative event completed without incidents.'
WHERE [booking_id] = @booking_completed;

-- no_show / meeting, direct operational transition
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
VALUES (@sp_workspace, @ta, DATEADD(day, -2, @now), DATEADD(hour, 1, DATEADD(day, -2, @now)), 'meeting', 10);
DECLARE @booking_no_show INT = SCOPE_IDENTITY();
INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
VALUES (@booking_no_show, @staff, DATEADD(day, -3, @now), 'approved', N'Approved for TA consultation meeting.');
UPDATE [dbo].[bookings]
SET [status] = 'no_show'
WHERE [booking_id] = @booking_no_show;

-- soft-deleted booking history
INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [is_deleted])
VALUES (@sp_class, @student2, DATEADD(day, -20, @now), DATEADD(hour, 1, DATEADD(day, -20, @now)), 'student_activity', 25, 'cancelled', 1);

PRINT 'SECTION 7: Audit update proofs';

DECLARE @class_updated_before DATETIME2 = (SELECT [updated_at] FROM [dbo].[spaces] WHERE [space_id] = @sp_class);
WAITFOR DELAY '00:00:01';
UPDATE [dbo].[spaces]
SET [usage_policy] = N'Teaching use has priority during business hours. Updated by Task 06 audit proof.'
WHERE [space_id] = @sp_class;
DECLARE @class_updated_after DATETIME2 = (SELECT [updated_at] FROM [dbo].[spaces] WHERE [space_id] = @sp_class);
IF @class_updated_after > @class_updated_before
    PRINT 'PASS: AUDIT_PARENT - trg_spaces_updated_at advanced updated_at.';
ELSE
    PRINT 'FAIL: AUDIT_PARENT - trg_spaces_updated_at did not advance updated_at.';

DECLARE @approval_updated_before DATETIME2 = (SELECT [updated_at] FROM [dbo].[booking_approvals] WHERE [booking_id] = @booking_approved);
WAITFOR DELAY '00:00:01';
UPDATE [dbo].[booking_approvals]
SET [decision_note] = N'Approved for final examination seating plan. Audit proof note updated.'
WHERE [booking_id] = @booking_approved;
DECLARE @approval_updated_after DATETIME2 = (SELECT [updated_at] FROM [dbo].[booking_approvals] WHERE [booking_id] = @booking_approved);
IF @approval_updated_after > @approval_updated_before
    PRINT 'PASS: AUDIT_CHILD - trg_booking_approvals_updated_at advanced updated_at.';
ELSE
    PRINT 'FAIL: AUDIT_CHILD - trg_booking_approvals_updated_at did not advance updated_at.';

PRINT 'SECTION 8: Expected-error cases';

-- E01: BR1 interval overlap trigger
PRINT 'EXPECTED_ERROR_CASE: E01 - BR1 overlapping active booking interval';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E01 NVARCHAR(4000) = N'%Overlapping booking exists for this space and time range%';
    -- Expected error: trg_bookings_prevent_overlap / Overlapping booking exists for this space and time range.
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@sp_aud, @student, DATEADD(minute, 30, DATEADD(day, 8, @now)), DATEADD(hour, 4, DATEADD(day, 8, @now)), 'seminar', 40, 'approved');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E01 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E01 PRINT 'PASS: E01 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E01 wrong error - ' + ERROR_MESSAGE();
END CATCH;

-- E02A-C: BR2 unavailable spaces cannot be approved
PRINT 'EXPECTED_ERROR_CASE: E02A - BR2 approve under_maintenance space';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E02A NVARCHAR(4000) = N'%Cannot approve booking: space is not available%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_project, @student, DATEADD(day, -8, @now), DATEADD(hour, 1, DATEADD(day, -8, @now)), 'meeting', 5);
    DECLARE @e02a_booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_space / Cannot approve booking: space is not available.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e02a_booking, @staff, @now, 'approved', N'Should fail because space status is under_maintenance.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E02A did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E02A PRINT 'PASS: E02A - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E02A wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E02B - BR2 approve temporarily_closed space';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E02B NVARCHAR(4000) = N'%Cannot approve booking: space is not available%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_closed, @student, DATEADD(day, 15, @now), DATEADD(hour, 1, DATEADD(day, 15, @now)), 'meeting', 8);
    DECLARE @e02b_booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_space / Cannot approve booking: space is not available.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e02b_booking, @manager, @now, 'approved', N'Should fail because space status is temporarily_closed.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E02B did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E02B PRINT 'PASS: E02B - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E02B wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E02C - BR2 approve retired space';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E02C NVARCHAR(4000) = N'%Cannot approve booking: space is not available%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_retired, @student, DATEADD(day, 16, @now), DATEADD(hour, 1, DATEADD(day, 16, @now)), 'meeting', 8);
    DECLARE @e02c_booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_space / Cannot approve booking: space is not available.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e02c_booking, @manager, @now, 'approved', N'Should fail because space status is retired.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E02C did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E02C PRINT 'PASS: E02C - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E02C wrong error - ' + ERROR_MESSAGE();
END CATCH;

-- E03-E06: capacity, maintenance, approval metadata, rejection reason
PRINT 'EXPECTED_ERROR_CASE: E03 - BR3 capacity limit';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E03 NVARCHAR(4000) = N'%Expected participants exceed space capacity%';
    -- Expected error: trg_bookings_check_capacity / Expected participants exceed space capacity.
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_meeting, @student, DATEADD(day, 18, @now), DATEADD(hour, 1, DATEADD(day, 18, @now)), 'meeting', 999);
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E03 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E03 PRINT 'PASS: E03 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E03 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E04 - BR4 unresolved maintenance overlap';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E04 NVARCHAR(4000) = N'%Overlapping unresolved maintenance exists for this space%';
    -- Expected error: trg_bookings_check_maintenance / Overlapping unresolved maintenance exists for this space.
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_project, @lecturer, DATEADD(day, 2, @now), DATEADD(hour, 2, DATEADD(day, 2, @now)), 'workshop', 15);
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E04 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E04 PRINT 'PASS: E04 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E04 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E05A - BR6 approver_id NOT NULL';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E05A NVARCHAR(4000) = N'%approver_id%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 19, @now), DATEADD(hour, 1, DATEADD(day, 19, @now)), 'meeting', 10);
    DECLARE @e05a_booking INT = SCOPE_IDENTITY();
    -- Expected error: booking_approvals.approver_id NOT NULL.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e05a_booking, NULL, @now, 'approved', N'Should fail because approver_id is NULL.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E05A did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E05A PRINT 'PASS: E05A - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E05A wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E05B - BR6 decision_time NOT NULL';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E05B NVARCHAR(4000) = N'%decision_time%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 20, @now), DATEADD(hour, 1, DATEADD(day, 20, @now)), 'meeting', 10);
    DECLARE @e05b_booking INT = SCOPE_IDENTITY();
    -- Expected error: booking_approvals.decision_time NOT NULL.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e05b_booking, @staff, NULL, 'approved', N'Should fail because decision_time is NULL.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E05B did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E05B PRINT 'PASS: E05B - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E05B wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E06 - BR7 rejection reason required';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E06 NVARCHAR(4000) = N'%Rejection reason must be provided%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 21, @now), DATEADD(hour, 1, DATEADD(day, 21, @now)), 'seminar', 10);
    DECLARE @e06_booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_rejection / Rejection reason must be provided when decision is rejected.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e06_booking, @staff, @now, 'rejected', N'Should fail because rejection_reason is NULL.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E06 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E06 PRINT 'PASS: E06 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E06 wrong error - ' + ERROR_MESSAGE();
END CATCH;

-- E07-E09: session trigger branches
PRINT 'EXPECTED_ERROR_CASE: E07 - BR8 check-in requires approved booking';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E07 NVARCHAR(4000) = N'%Cannot check in: booking is not in approved status%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 22, @now), DATEADD(hour, 1, DATEADD(day, 22, @now)), 'meeting', 10);
    DECLARE @e07_booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_sessions_checkin / Cannot check in: booking is not in approved status.
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@e07_booking, @now, @staff, N'Clean room.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E07 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E07 PRINT 'PASS: E07 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E07 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E08 - BR9 initial condition required';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E08 NVARCHAR(4000) = N'%initial_condition must be provided%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 23, @now), DATEADD(hour, 1, DATEADD(day, 23, @now)), 'meeting', 10);
    DECLARE @e08_booking INT = SCOPE_IDENTITY();
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e08_booking, @staff, @now, 'approved', N'Fixture for missing initial condition test.');
    -- Expected error: trg_booking_sessions_checkin / initial_condition must be provided at check-in.
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@e08_booking, @now, @staff, NULL);
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E08 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E08 PRINT 'PASS: E08 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E08 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E09 - BR9 final condition required';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E09 NVARCHAR(4000) = N'%final_condition must be provided%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 24, @now), DATEADD(hour, 1, DATEADD(day, 24, @now)), 'meeting', 10);
    DECLARE @e09_booking INT = SCOPE_IDENTITY();
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e09_booking, @staff, @now, 'approved', N'Fixture for missing final condition test.');
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@e09_booking, @now, @staff, N'Initial condition present.');
    -- Expected error: trg_booking_sessions_completion / final_condition must be provided when completing a booking session.
    UPDATE [dbo].[booking_sessions]
    SET [actual_end_time] = DATEADD(hour, 1, @now), [final_condition] = NULL
    WHERE [booking_id] = @e09_booking;
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E09 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E09 PRINT 'PASS: E09 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E09 wrong error - ' + ERROR_MESSAGE();
END CATCH;

-- E10-E13: role validation and cancellation
PRINT 'EXPECTED_ERROR_CASE: E10 - BR15 invalid approver role';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E10 NVARCHAR(4000) = N'%Approver must be facility staff or facility manager%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 25, @now), DATEADD(hour, 1, DATEADD(day, 25, @now)), 'meeting', 10);
    DECLARE @e10_booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_role / Approver must be facility staff or facility manager.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e10_booking, @student, @now, 'approved', N'Should fail because student cannot approve.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E10 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E10 PRINT 'PASS: E10 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E10 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E11 - BR16 invalid check-in role';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E11 NVARCHAR(4000) = N'%Check-in staff must be facility staff or facility manager%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 26, @now), DATEADD(hour, 1, DATEADD(day, 26, @now)), 'meeting', 10);
    DECLARE @e11_booking INT = SCOPE_IDENTITY();
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e11_booking, @staff, @now, 'approved', N'Fixture for invalid check-in role.');
    -- Expected error: trg_booking_sessions_check_role / Check-in staff must be facility staff or facility manager.
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@e11_booking, @now, @student, N'Initial condition present.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E11 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E11 PRINT 'PASS: E11 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E11 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E12 - BR17 invalid maintenance assignee role';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E12 NVARCHAR(4000) = N'%Assigned maintenance staff must be facility staff%';
    -- Expected error: trg_maintenance_check_assignee_role / Assigned maintenance staff must be facility staff.
    INSERT INTO [dbo].[maintenance] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (@sp_class, @student, @manager, N'Invalid manager assignment fixture.', @now, 'open');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E12 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E12 PRINT 'PASS: E12 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E12 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E13 - BR18 invalid cancellation from completed';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E13 NVARCHAR(4000) = N'%Cancellation is only allowed from pending or approved status%';
    -- Expected error: trg_bookings_cancellation / Cancellation is only allowed from pending or approved status.
    UPDATE [dbo].[bookings]
    SET [status] = 'cancelled'
    WHERE [booking_id] = @booking_completed;
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E13 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E13 PRINT 'PASS: E13 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E13 wrong error - ' + ERROR_MESSAGE();
END CATCH;

-- E14-E20: declarative constraints and unique child FKs
PRINT 'EXPECTED_ERROR_CASE: E14 - invalid user role enum';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E14 NVARCHAR(4000) = N'%CK_users_role%';
    -- Expected error: CK_users_role invalid enum.
    INSERT INTO [dbo].[users] ([email], [full_name], [role], [department_id], [account_status])
    VALUES (N't06.badrole@university.edu', N'Invalid Role User', 'visitor', @dept_cs, 'active');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E14 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E14 PRINT 'PASS: E14 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E14 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E15 - invalid booking time range';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E15 NVARCHAR(4000) = N'%CK_bookings_requested_end_time%';
    -- Expected error: CK_bookings_requested_end_time invalid time range.
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 27, @now), DATEADD(day, 27, @now), 'meeting', 10);
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E15 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E15 PRINT 'PASS: E15 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E15 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E16 - duplicate user email';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E16 NVARCHAR(4000) = N'%UQ_users_email%';
    -- Expected error: UQ_users_email duplicate business key.
    INSERT INTO [dbo].[users] ([email], [full_name], [role], [department_id], [account_status])
    VALUES (N't06.student1@university.edu', N'Duplicate Email User', 'student', @dept_cs, 'active');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E16 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E16 PRINT 'PASS: E16 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E16 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E17 - invalid junction quantity';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E17 NVARCHAR(4000) = N'%CK_space_facilities_quantity%';
    -- Expected error: CK_space_facilities_quantity invalid quantity.
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
    VALUES (@sp_retired, @fac_projector, 0);
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E17 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E17 PRINT 'PASS: E17 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E17 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E18 - duplicate booking approval child';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E18 NVARCHAR(4000) = N'%UQ_booking_approvals_booking_id%';
    -- Expected error: UQ_booking_approvals_booking_id unique child FK.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking_approved, @staff, @now, 'approved', N'Should fail because approval child already exists.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E18 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E18 PRINT 'PASS: E18 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E18 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E19 - duplicate booking session child';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E19 NVARCHAR(4000) = N'%UQ_booking_sessions_booking_id%';
    -- Expected error: UQ_booking_sessions_booking_id unique child FK.
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@booking_checked_in, @now, @staff, N'Should fail because session child already exists.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E19 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E19 PRINT 'PASS: E19 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E19 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E20 - filtered unique active booking exact collision';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E20 NVARCHAR(4000) = N'%uq_bookings_active_overlap%';
    -- Expected error: uq_bookings_active_overlap filtered unique index.
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@sp_aud, @student, DATEADD(day, 8, @now), DATEADD(hour, 1, DATEADD(day, 8, @now)), 'seminar', 30, 'approved');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E20 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E20 PRINT 'PASS: E20 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E20 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'EXPECTED_ERROR_CASE: E21 - invalid approval decision enum';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern_E21 NVARCHAR(4000) = N'%CK_booking_approvals_decision%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants])
    VALUES (@sp_class, @student, DATEADD(day, 28, @now), DATEADD(hour, 1, DATEADD(day, 28, @now)), 'meeting', 10);
    DECLARE @e21_booking INT = SCOPE_IDENTITY();
    -- Expected error: CK_booking_approvals_decision invalid enum.
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@e21_booking, @staff, @now, 'deferred', N'Should fail because decision enum is invalid.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E21 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern_E21 PRINT 'PASS: E21 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E21 wrong error - ' + ERROR_MESSAGE();
END CATCH;

PRINT 'SECTION 9: Verification queries';

PRINT 'VERIFY: V01 - row counts for every table seeded or referenced';
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM [dbo].[departments] WHERE [name] IN (N'School of Computer Science', N'Department of Mathematics', N'Department of Physics', N'Faculty of Engineering', N'School Administration')
UNION ALL SELECT 'users', COUNT(*) FROM [dbo].[users] WHERE [email] LIKE N't06.%@university.edu'
UNION ALL SELECT 'spaces', COUNT(*) FROM [dbo].[spaces] WHERE [space_code] LIKE N'T06-%'
UNION ALL SELECT 'facilities', COUNT(*) FROM [dbo].[facilities] WHERE [name] LIKE N'T06 %'
UNION ALL SELECT 'space_facilities', COUNT(*) FROM [dbo].[space_facilities] sf INNER JOIN [dbo].[spaces] s ON s.[space_id] = sf.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'maintenance', COUNT(*) FROM [dbo].[maintenance] m INNER JOIN [dbo].[spaces] s ON s.[space_id] = m.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'bookings', COUNT(*) FROM [dbo].[bookings] b INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'booking_approvals', COUNT(*) FROM [dbo].[booking_approvals] ba INNER JOIN [dbo].[bookings] b ON b.[booking_id] = ba.[booking_id] INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'booking_sessions', COUNT(*) FROM [dbo].[booking_sessions] bs INNER JOIN [dbo].[bookings] b ON b.[booking_id] = bs.[booking_id] INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE s.[space_code] LIKE N'T06-%';

PRINT 'VERIFY: V02 - user roles and account statuses';
SELECT [role], [account_status], COUNT(*) AS users_count
FROM [dbo].[users]
WHERE [email] LIKE N't06.%@university.edu'
GROUP BY [role], [account_status]
ORDER BY [role], [account_status];

PRINT 'VERIFY: V03 - space types and current statuses';
SELECT [space_type], [current_status], COUNT(*) AS spaces_count
FROM [dbo].[spaces]
WHERE [space_code] LIKE N'T06-%'
GROUP BY [space_type], [current_status]
ORDER BY [space_type], [current_status];

PRINT 'VERIFY: V04 - facility assignments by space';
SELECT s.[space_code], f.[name] AS facility_name, sf.[quantity]
FROM [dbo].[space_facilities] sf
INNER JOIN [dbo].[spaces] s ON s.[space_id] = sf.[space_id]
INNER JOIN [dbo].[facilities] f ON f.[facility_id] = sf.[facility_id]
WHERE s.[space_code] LIKE N'T06-%'
ORDER BY s.[space_code], f.[name];

PRINT 'VERIFY: V05 - maintenance statuses, soft delete, and assigned staff role';
SELECT m.[status], m.[is_deleted], u.[role] AS assigned_role, COUNT(*) AS maintenance_count
FROM [dbo].[maintenance] m
INNER JOIN [dbo].[spaces] s ON s.[space_id] = m.[space_id]
LEFT JOIN [dbo].[users] u ON u.[user_id] = m.[assigned_staff_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY m.[status], m.[is_deleted], u.[role]
ORDER BY m.[status], m.[is_deleted], u.[role];

PRINT 'VERIFY: V06 - booking statuses and purposes';
SELECT b.[status], b.[purpose], COUNT(*) AS booking_count
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY b.[status], b.[purpose]
ORDER BY b.[status], b.[purpose];

PRINT 'VERIFY: V07 - approval decisions and valid approver roles';
SELECT ba.[decision], u.[role] AS approver_role, COUNT(*) AS approvals_count
FROM [dbo].[booking_approvals] ba
INNER JOIN [dbo].[users] u ON u.[user_id] = ba.[approver_id]
INNER JOIN [dbo].[bookings] b ON b.[booking_id] = ba.[booking_id]
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY ba.[decision], u.[role]
ORDER BY ba.[decision], u.[role];

PRINT 'VERIFY: V08 - sessions and completion fields';
SELECT b.[status], COUNT(*) AS sessions_count,
       SUM(CASE WHEN bs.[actual_end_time] IS NOT NULL AND bs.[final_condition] IS NOT NULL THEN 1 ELSE 0 END) AS completed_sessions_with_final_condition
FROM [dbo].[booking_sessions] bs
INNER JOIN [dbo].[bookings] b ON b.[booking_id] = bs.[booking_id]
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY b.[status]
ORDER BY b.[status];

PRINT 'VERIFY: V09 - soft-deleted history remains queryable';
SELECT 'bookings' AS table_name, COUNT(*) AS soft_deleted_count
FROM [dbo].[bookings] b INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%' AND b.[is_deleted] = 1
UNION ALL
SELECT 'maintenance', COUNT(*)
FROM [dbo].[maintenance] m INNER JOIN [dbo].[spaces] s ON s.[space_id] = m.[space_id]
WHERE s.[space_code] LIKE N'T06-%' AND m.[is_deleted] = 1;

PRINT 'VERIFY: V10 - audit timestamps exist';
SELECT 'spaces' AS table_name, COUNT(*) AS rows_with_audit
FROM [dbo].[spaces]
WHERE [space_code] LIKE N'T06-%' AND [created_at] IS NOT NULL AND [updated_at] IS NOT NULL
UNION ALL
SELECT 'booking_approvals', COUNT(*)
FROM [dbo].[booking_approvals] ba INNER JOIN [dbo].[bookings] b ON b.[booking_id] = ba.[booking_id] INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%' AND ba.[created_at] IS NOT NULL AND ba.[updated_at] IS NOT NULL;

PRINT 'VERIFY: V11 - booking history report';
SELECT TOP 20 s.[space_code], u.[email] AS requester_email, b.[purpose], b.[status], b.[requested_start_time], b.[requested_end_time]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND b.[requested_end_time] < @now
ORDER BY b.[requested_start_time] DESC;

PRINT 'VERIFY: V12 - upcoming actionable bookings report';
SELECT s.[space_code], u.[email] AS requester_email, b.[purpose], b.[status], b.[requested_start_time]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND b.[is_deleted] = 0
  AND b.[requested_start_time] > @now
  AND b.[status] IN ('pending','approved')
ORDER BY b.[requested_start_time];

PRINT 'VERIFY: V13 - spaces under maintenance report';
SELECT s.[space_code], s.[space_name], m.[problem_description], m.[status]
FROM [dbo].[spaces] s
INNER JOIN [dbo].[maintenance] m ON m.[space_id] = s.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND s.[current_status] = 'under_maintenance'
  AND m.[status] IN ('open','in_progress')
  AND m.[is_deleted] = 0
ORDER BY s.[space_code], m.[status];

PRINT 'VERIFY: V14 - no-show bookings report';
SELECT s.[space_code], u.[email] AS requester_email, b.[requested_start_time], b.[requested_end_time], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND b.[is_deleted] = 0
  AND b.[status] = 'no_show'
ORDER BY b.[requested_start_time] DESC;

PRINT 'VERIFY: V15 - FK joins for request, approval, session, maintenance';
SELECT TOP 20 b.[booking_id], s.[space_code], requester.[email] AS requester_email,
       ba.[decision], approver.[email] AS approver_email,
       bs.[actual_start_time], checker.[email] AS checked_in_by_email
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] requester ON requester.[user_id] = b.[requester_id]
LEFT JOIN [dbo].[booking_approvals] ba ON ba.[booking_id] = b.[booking_id]
LEFT JOIN [dbo].[users] approver ON approver.[user_id] = ba.[approver_id]
LEFT JOIN [dbo].[booking_sessions] bs ON bs.[booking_id] = b.[booking_id]
LEFT JOIN [dbo].[users] checker ON checker.[user_id] = bs.[checked_in_by]
WHERE s.[space_code] LIKE N'T06-%'
ORDER BY b.[booking_id];

PRINT 'VERIFY: V16 - Task 06 sample data generation completed';
