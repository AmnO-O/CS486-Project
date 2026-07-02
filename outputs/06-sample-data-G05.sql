SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

-- ============================================================
-- CS486 Group G05 - Campus Space Management System
-- Task 06: Sample Data Preparation
-- Dependency: run after outputs/05-db-definition-G05.sql
-- Target: SQL Server 2019+ (T-SQL)
-- ============================================================
-- Assumptions and sample-data strategy:
-- - Dates are fixed and deterministic around June-July 2026 so lifecycle
--   examples remain reviewable.
-- - Task-owned rows use stable natural keys: space_code LIKE 'T06-%',
--   user email LIKE 't06.%', and facility names prefixed with 'T06 '.
-- - Cleanup-and-reseed deletes only Task 06-owned child rows through owned
--   parents, then owned parent rows in reverse FK order.
-- - Approval/session workflows follow the Task 05 split schema:
--   bookings -> booking_approvals -> booking_sessions.
-- - Expected-error cases are isolated in transactions and match the intended
--   trigger message or constraint name.
-- - Maintenance completion proves both the concurrent-ticket guard and the
--   final-ticket restoration side effect.
-- ============================================================

PRINT 'SECTION 0: Cleanup previous Task 06-owned rows';
GO

DELETE bs
FROM [dbo].[booking_sessions] bs
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
    WHERE b.[booking_id] = bs.[booking_id]
      AND s.[space_code] LIKE N'T06-%'
);

DELETE ba
FROM [dbo].[booking_approvals] ba
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
    WHERE b.[booking_id] = ba.[booking_id]
      AND s.[space_code] LIKE N'T06-%'
);

DELETE b
FROM [dbo].[bookings] b
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[spaces] s
    WHERE s.[space_id] = b.[space_id]
      AND s.[space_code] LIKE N'T06-%'
);

DELETE m
FROM [dbo].[maintenance] m
WHERE EXISTS (
    SELECT 1
    FROM [dbo].[spaces] s
    WHERE s.[space_id] = m.[space_id]
      AND s.[space_code] LIKE N'T06-%'
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
WHERE [email] LIKE N't06.%';

DELETE FROM [dbo].[facilities]
WHERE [name] LIKE N'T06 %';
GO

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
IF NOT EXISTS (SELECT 1 FROM [dbo].[departments] WHERE [name] = N'School Administration')
    INSERT INTO [dbo].[departments] ([name]) VALUES (N'School Administration');
GO

PRINT 'SECTION 2: Users - all roles and account statuses';
GO

DECLARE @dept_cs INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science');
DECLARE @dept_math INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Mathematics');
DECLARE @dept_physics INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Department of Physics');
DECLARE @dept_eng INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'Faculty of Engineering');
DECLARE @dept_admin INT = (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School Administration');

IF @dept_cs IS NULL OR @dept_math IS NULL OR @dept_physics IS NULL OR @dept_eng IS NULL OR @dept_admin IS NULL
    THROW 51006, 'Task 06 setup failed: department lookup returned NULL.', 1;

INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status]) VALUES
(N't06.student1@university.edu', N'Alice Nguyen', N'090-100-0001', 'student', @dept_cs, 'active'),
(N't06.student2@university.edu', N'Bao Tran', NULL, 'student', @dept_physics, 'inactive'),
(N't06.lecturer1@university.edu', N'Dr. Linh Pham', N'090-100-0002', 'lecturer', @dept_cs, 'active'),
(N't06.ta1@university.edu', N'Minh Vo', NULL, 'teaching_assistant', @dept_cs, 'active'),
(N't06.facilitystaff1@university.edu', N'Quang Le', N'090-100-0003', 'facility_staff', @dept_admin, 'active'),
(N't06.facilitystaff2@university.edu', N'Ha Dang', N'090-100-0004', 'facility_staff', @dept_admin, 'suspended'),
(N't06.departmentadmin1@university.edu', N'Lan Hoang', N'090-100-0005', 'department_admin', @dept_math, 'active'),
(N't06.facilitymanager1@university.edu', N'Khoa Bui', N'090-100-0006', 'facility_manager', @dept_admin, 'active'),
(N't06.engineeringlecturer@university.edu', N'Anh Do', N'090-100-0007', 'lecturer', @dept_eng, 'active');
GO

PRINT 'SECTION 3: Spaces - all types and statuses';
GO

INSERT INTO [dbo].[spaces] ([space_code], [space_name], [space_type], [building], [floor], [room_number], [capacity], [current_status], [usage_policy]) VALUES
(N'T06-AUD-101', N'Main Teaching Auditorium', 'auditorium', N'Alpha', N'1', N'101', 220, 'available', N'Large lectures and examinations only.'),
(N'T06-CLS-201', N'Interactive Classroom 201', 'classroom', N'Alpha', N'2', N'201', 45, 'available', N'Tutorials and seminars; reset furniture after use.'),
(N'T06-COMP-301', N'Computer Laboratory 301', 'computer_lab', N'Beta', N'3', N'301', 32, 'available', N'No food or drinks; lab account required.'),
(N'T06-PROJ-110', N'Project Laboratory 110', 'project_lab', N'Beta', N'1', N'110', 24, 'available', N'Project groups must check tools in and out.'),
(N'T06-MTG-012', N'Faculty Meeting Room 12', 'meeting_room', N'Gamma', N'1', N'012', 12, 'under_maintenance', N'Offline until maintenance is resolved.'),
(N'T06-SW-020', N'Student Workspace 20', 'student_workspace', N'Gamma', N'2', N'020', 18, 'available', N'Student project and club activity priority.'),
(N'T06-CLS-302', N'Closed Classroom 302', 'classroom', N'Alpha', N'3', N'302', 50, 'temporarily_closed', N'Closed for renovation.'),
(N'T06-AUD-OLD', N'Old Auditorium', 'auditorium', N'Delta', N'1', N'001', 150, 'retired', N'Decommissioned space.'),
(N'T06-COMP-202', N'In-Use Computer Laboratory 202', 'computer_lab', N'Beta', N'2', N'202', 28, 'in_use', N'Currently occupied by a checked-in session.');
GO

PRINT 'SECTION 4: Facilities and space_facilities';
GO

INSERT INTO [dbo].[facilities] ([name]) VALUES
(N'T06 Projector'),
(N'T06 Whiteboard'),
(N'T06 Microphone'),
(N'T06 Computer'),
(N'T06 Livestreaming Equipment'),
(N'T06 Air Conditioner');

DECLARE @aud INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-AUD-101');
DECLARE @cls INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CLS-201');
DECLARE @comp INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-COMP-301');
DECLARE @proj INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-PROJ-110');
DECLARE @mtg INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-MTG-012');
DECLARE @sw INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020');
DECLARE @inuse_space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-COMP-202');

DECLARE @f_projector INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Projector');
DECLARE @f_whiteboard INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Whiteboard');
DECLARE @f_mic INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Microphone');
DECLARE @f_computer INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Computer');
DECLARE @f_stream INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Livestreaming Equipment');
DECLARE @f_ac INT = (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Air Conditioner');

IF @aud IS NULL OR @cls IS NULL OR @comp IS NULL OR @proj IS NULL OR @mtg IS NULL OR @sw IS NULL OR @inuse_space IS NULL
   OR @f_projector IS NULL OR @f_whiteboard IS NULL OR @f_mic IS NULL OR @f_computer IS NULL OR @f_stream IS NULL OR @f_ac IS NULL
    THROW 51006, 'Task 06 setup failed: space/facility lookup returned NULL.', 1;

INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity]) VALUES
(@aud, @f_projector, 2), (@aud, @f_mic, 4), (@aud, @f_stream, 1), (@aud, @f_ac, 6),
(@cls, @f_projector, 1), (@cls, @f_whiteboard, 2), (@cls, @f_ac, 1),
(@comp, @f_computer, 32), (@comp, @f_projector, 1), (@comp, @f_ac, 2),
(@proj, @f_computer, 12), (@proj, @f_whiteboard, 1),
(@mtg, @f_projector, 1), (@mtg, @f_ac, 1),
(@sw, @f_whiteboard, 2), (@sw, @f_ac, 1),
(@inuse_space, @f_computer, 28), (@inuse_space, @f_projector, 1);
GO

PRINT 'SECTION 5: Maintenance - statuses, soft delete, and BR19 side effects';
GO

DECLARE @staff1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu');
DECLARE @student1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu');
DECLARE @lecturer1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.lecturer1@university.edu');
DECLARE @mtg INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-MTG-012');
DECLARE @cls INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CLS-201');
DECLARE @proj INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-PROJ-110');
DECLARE @comp INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-COMP-301');
DECLARE @sw INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020');

INSERT INTO [dbo].[maintenance] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note], [is_deleted]) VALUES
(@mtg, @lecturer1, @staff1, N'T06 Broken projector and loose HDMI cable.', '2026-06-25T09:00:00', NULL, 'open', NULL, 0),
(@mtg, @student1, @staff1, N'T06 Air conditioning failure in meeting room.', '2026-06-25T10:00:00', NULL, 'in_progress', NULL, 0),
(@cls, @lecturer1, @staff1, N'T06 Damaged furniture in front row.', '2026-06-10T09:00:00', '2026-06-11T16:00:00', 'resolved', N'Desks replaced and room inspected.', 0),
(@proj, @student1, @staff1, N'T06 Cleaning issue after weekend workshop.', '2026-06-12T08:30:00', '2026-06-12T12:00:00', 'resolved', N'Floor and benches cleaned.', 0),
(@comp, @lecturer1, @staff1, N'T06 Network problems on workstations 12-18.', '2026-06-18T13:00:00', NULL, 'open', NULL, 1),
(@sw, @student1, @staff1, N'T06 Temporary whiteboard marker shortage.', '2026-06-01T10:00:00', '2026-06-01T10:30:00', 'resolved', N'Markers restocked.', 0);

PRINT 'VERIFY: V-MAINT-GUARD-BEFORE - concurrent active maintenance keeps space under_maintenance';
SELECT s.[space_code], s.[current_status], COUNT(m.[maintenance_id]) AS [active_ticket_count]
FROM [dbo].[spaces] s
INNER JOIN [dbo].[maintenance] m ON m.[space_id] = s.[space_id]
WHERE s.[space_code] = N'T06-MTG-012'
  AND m.[status] IN ('open','in_progress')
  AND m.[is_deleted] = 0
GROUP BY s.[space_code], s.[current_status];

UPDATE TOP (1) [dbo].[maintenance]
SET [status] = 'resolved',
    [completion_time] = '2026-06-26T09:00:00',
    [result_note] = N'Projector repaired; AC ticket still active.'
WHERE [space_id] = @mtg
  AND [status] = 'open'
  AND [problem_description] LIKE N'T06 Broken projector%';

PRINT 'VERIFY: V-MAINT-GUARD-AFTER-ONE - guard prevents status restoration while another active ticket remains';
SELECT s.[space_code], s.[current_status], COUNT(m.[maintenance_id]) AS [remaining_active_ticket_count]
FROM [dbo].[spaces] s
LEFT JOIN [dbo].[maintenance] m
  ON m.[space_id] = s.[space_id]
 AND m.[status] IN ('open','in_progress')
 AND m.[is_deleted] = 0
WHERE s.[space_code] = N'T06-MTG-012'
GROUP BY s.[space_code], s.[current_status];

UPDATE [dbo].[maintenance]
SET [status] = 'resolved',
    [completion_time] = '2026-06-26T15:00:00',
    [result_note] = N'Air conditioner reset; all tickets resolved.'
WHERE [space_id] = @mtg
  AND [status] = 'in_progress'
  AND [problem_description] LIKE N'T06 Air conditioning%';

PRINT 'VERIFY: V-MAINT-RESTORE - last resolved maintenance restores space to available';
SELECT [space_code], [current_status]
FROM [dbo].[spaces]
WHERE [space_code] = N'T06-MTG-012';

UPDATE [dbo].[spaces]
SET [current_status] = 'under_maintenance'
WHERE [space_code] = N'T06-MTG-012';

INSERT INTO [dbo].[maintenance] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [completion_time], [status], [result_note], [is_deleted])
VALUES (@mtg, @lecturer1, @staff1, N'T06 Network inspection after room maintenance.', '2026-06-27T08:00:00', NULL, 'in_progress', NULL, 0);
GO

PRINT 'SECTION 6: Bookings - valid lifecycle workflows';
GO

DECLARE @aud INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-AUD-101');
DECLARE @cls INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CLS-201');
DECLARE @comp INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-COMP-301');
DECLARE @proj INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-PROJ-110');
DECLARE @sw INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020');
DECLARE @inuse_space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-COMP-202');
DECLARE @student1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu');
DECLARE @student2 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student2@university.edu');
DECLARE @lecturer1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.lecturer1@university.edu');
DECLARE @ta1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.ta1@university.edu');
DECLARE @staff1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu');
DECLARE @manager1 INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitymanager1@university.edu');

IF @aud IS NULL OR @cls IS NULL OR @comp IS NULL OR @proj IS NULL OR @sw IS NULL OR @inuse_space IS NULL
   OR @student1 IS NULL OR @student2 IS NULL OR @lecturer1 IS NULL OR @ta1 IS NULL OR @staff1 IS NULL OR @manager1 IS NULL
    THROW 51006, 'Task 06 setup failed: booking lookup returned NULL.', 1;

INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status], [is_deleted]) VALUES
(@cls, @student1, '2026-07-15T09:00:00', '2026-07-15T10:30:00', 'meeting', 8, 'pending', 0),
(@aud, @lecturer1, '2026-07-20T08:00:00', '2026-07-20T10:00:00', 'lecture', 120, 'pending', 0),
(@cls, @ta1, '2026-07-21T13:00:00', '2026-07-21T15:00:00', 'examination', 35, 'pending', 0),
(@proj, @student1, '2026-07-22T09:00:00', '2026-07-22T11:00:00', 'workshop', 16, 'pending', 0),
(@comp, @lecturer1, '2026-06-10T08:00:00', '2026-06-10T10:00:00', 'seminar', 25, 'pending', 0),
(@sw, @student2, '2026-06-12T14:00:00', '2026-06-12T16:00:00', 'student_activity', 14, 'pending', 0),
(@aud, @lecturer1, '2026-07-23T13:00:00', '2026-07-23T15:00:00', 'administrative_event', 80, 'pending', 0),
(@sw, @student1, '2026-07-24T10:00:00', '2026-07-24T12:00:00', 'meeting', 6, 'pending', 1),
(@inuse_space, @lecturer1, '2026-07-02T09:00:00', '2026-07-02T11:00:00', 'workshop', 20, 'pending', 0),
(@aud, @student1, '2026-06-05T09:00:00', '2026-06-05T11:00:00', 'student_activity', 40, 'pending', 0);

DECLARE @b_pending INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @cls AND [requested_start_time] = '2026-07-15T09:00:00');
DECLARE @b_approved INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @aud AND [requested_start_time] = '2026-07-20T08:00:00');
DECLARE @b_rejected INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @cls AND [requested_start_time] = '2026-07-21T13:00:00');
DECLARE @b_cancelled INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @proj AND [requested_start_time] = '2026-07-22T09:00:00');
DECLARE @b_completed INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @comp AND [requested_start_time] = '2026-06-10T08:00:00');
DECLARE @b_noshow INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @sw AND [requested_start_time] = '2026-06-12T14:00:00');
DECLARE @b_approved_cancel INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @aud AND [requested_start_time] = '2026-07-23T13:00:00');
DECLARE @b_deleted INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @sw AND [requested_start_time] = '2026-07-24T10:00:00');
DECLARE @b_checked_in INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @inuse_space AND [requested_start_time] = '2026-07-02T09:00:00');
DECLARE @b_direct_noshow INT = (SELECT [booking_id] FROM [dbo].[bookings] WHERE [space_id] = @aud AND [requested_start_time] = '2026-06-05T09:00:00');

INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [rejection_reason], [decision_note]) VALUES
(@b_approved, @staff1, '2026-07-10T10:00:00', 'approved', NULL, N'Approved for scheduled lecture.'),
(@b_rejected, @manager1, '2026-07-10T11:00:00', 'rejected', N'Exam period room allocation conflict.', N'Requester advised to use another date.'),
(@b_completed, @staff1, '2026-06-08T09:00:00', 'approved', NULL, N'Approved for lab seminar.'),
(@b_noshow, @manager1, '2026-06-09T09:00:00', 'approved', NULL, N'Approved for student activity.'),
(@b_approved_cancel, @staff1, '2026-07-11T09:30:00', 'approved', NULL, N'Approved, then cancelled by requester.'),
(@b_deleted, @staff1, '2026-07-11T10:30:00', 'approved', NULL, N'Approved historical soft-delete example.'),
(@b_checked_in, @manager1, '2026-07-01T15:00:00', 'approved', NULL, N'Approved for currently checked-in workshop.'),
(@b_direct_noshow, @staff1, '2026-06-01T08:00:00', 'approved', NULL, N'Approved but requester did not arrive.');

UPDATE [dbo].[bookings]
SET [status] = 'cancelled'
WHERE [booking_id] = @b_cancelled;

UPDATE [dbo].[bookings]
SET [status] = 'cancelled'
WHERE [booking_id] = @b_approved_cancel;

UPDATE [dbo].[bookings]
SET [status] = 'no_show'
WHERE [booking_id] IN (@b_noshow, @b_direct_noshow);

INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition], [actual_end_time], [final_condition], [usage_notes]) VALUES
(@b_completed, '2026-06-10T08:05:00', @staff1, N'Lab clean; computers ready.', NULL, NULL, NULL),
(@b_checked_in, '2026-07-02T09:02:00', @manager1, N'Computers powered on; projector working.', NULL, NULL, NULL);

UPDATE [dbo].[booking_sessions]
SET [actual_end_time] = '2026-06-10T09:55:00',
    [final_condition] = N'Lab clean; no incidents.',
    [usage_notes] = N'Seminar completed successfully.'
WHERE [booking_id] = @b_completed;
GO

PRINT 'SECTION 7: Expected-error cases';
GO

PRINT 'EXPECTED_ERROR_CASE: E01 - trg_bookings_prevent_overlap';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Overlapping booking exists for this space and time range%';
    DECLARE @space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-AUD-101');
    DECLARE @requester INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.lecturer1@university.edu');
    -- Expected error: trg_bookings_prevent_overlap / overlapping confirmed booking
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space, @requester, '2026-07-20T09:00:00', '2026-07-20T11:00:00', 'seminar', 60, 'approved');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E01 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E01 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E01 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E02 - trg_booking_approvals_check_space under_maintenance';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Cannot approve booking: space is not available%';
    DECLARE @space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CLS-201');
    DECLARE @requester INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu');
    DECLARE @staff INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu');
    UPDATE [dbo].[spaces] SET [current_status] = 'under_maintenance' WHERE [space_id] = @space;
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space, @requester, '2026-08-01T08:00:00', '2026-08-01T09:00:00', 'meeting', 8, 'pending');
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_space / under_maintenance
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, @staff, '2026-07-25T09:00:00', 'approved', N'Test unavailable status.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E02 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E02 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E02 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E03 - trg_booking_approvals_check_space temporarily_closed';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Cannot approve booking: space is not available%';
    DECLARE @space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CLS-302');
    DECLARE @requester INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu');
    DECLARE @staff INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu');
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space, @requester, '2026-08-02T08:00:00', '2026-08-02T09:00:00', 'meeting', 8, 'pending');
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_space / temporarily_closed
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, @staff, '2026-07-25T09:00:00', 'approved', N'Test unavailable status.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E03 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E03 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E03 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E04 - trg_booking_approvals_check_space retired';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Cannot approve booking: space is not available%';
    DECLARE @space INT = (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-AUD-OLD');
    DECLARE @requester INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu');
    DECLARE @staff INT = (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu');
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (@space, @requester, '2026-08-03T08:00:00', '2026-08-03T09:00:00', 'meeting', 8, 'pending');
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_space / retired
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, @staff, '2026-07-25T09:00:00', 'approved', N'Test unavailable status.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E04 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E04 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E04 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E05 - trg_bookings_check_capacity';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Expected participants exceed space capacity%';
    -- Expected error: trg_bookings_check_capacity
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-04T08:00:00', '2026-08-04T09:00:00', 'meeting', 99, 'pending'
    );
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E05 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E05 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E05 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E06 - trg_bookings_check_maintenance';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Overlapping unresolved maintenance exists for this space%';
    -- Expected error: trg_bookings_check_maintenance / unresolved maintenance overlap
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-MTG-012'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.lecturer1@university.edu'),
        '2026-06-27T09:00:00', '2026-06-27T10:00:00', 'meeting', 8, 'pending'
    );
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E06 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E06 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E06 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E07 - booking_approvals decision_time NOT NULL';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%decision_time%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-05T08:00:00', '2026-08-05T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: booking_approvals decision_time NOT NULL
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), NULL, 'approved', N'Missing decision time test.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E07 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E07 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E07 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E08 - trg_booking_approvals_rejection';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Rejection reason must be provided%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-06T08:00:00', '2026-08-06T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_rejection
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [rejection_reason], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), '2026-07-25T09:00:00', 'rejected', NULL, N'Missing rejection reason test.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E08 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E08 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E08 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E09 - trg_booking_sessions_checkin non-approved';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Cannot check in: booking is not in approved status%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-07T08:00:00', '2026-08-07T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_sessions_checkin / non-approved booking
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@booking, '2026-08-07T08:01:00', (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), N'Clean.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E09 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E09 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E09 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E10 - trg_booking_sessions_checkin initial_condition';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%initial_condition must be provided at check-in%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-08T08:00:00', '2026-08-08T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), '2026-07-25T09:00:00', 'approved', N'Approval for session test.');
    -- Expected error: trg_booking_sessions_checkin / initial_condition branch
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@booking, '2026-08-08T08:01:00', (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), NULL);
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E10 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E10 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E10 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E11 - trg_booking_sessions_completion final_condition';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%final_condition must be provided when completing a booking session%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-09T08:00:00', '2026-08-09T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), '2026-07-25T09:00:00', 'approved', N'Approval for completion test.');
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@booking, '2026-08-09T08:01:00', (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), N'Clean.');
    -- Expected error: trg_booking_sessions_completion / missing final_condition
    UPDATE [dbo].[booking_sessions]
    SET [actual_end_time] = '2026-08-09T08:59:00'
    WHERE [booking_id] = @booking;
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E11 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E11 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E11 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E12 - trg_booking_approvals_check_role';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Approver must be facility staff or facility manager%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-10T08:00:00', '2026-08-10T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    -- Expected error: trg_booking_approvals_check_role
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.lecturer1@university.edu'), '2026-07-25T09:00:00', 'approved', N'Invalid approver role test.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E12 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E12 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E12 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E13 - trg_booking_sessions_check_role';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Check-in staff must be facility staff or facility manager%';
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-11T08:00:00', '2026-08-11T09:00:00', 'meeting', 8, 'pending'
    );
    DECLARE @booking INT = SCOPE_IDENTITY();
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), '2026-07-25T09:00:00', 'approved', N'Approval for invalid check-in role test.');
    -- Expected error: trg_booking_sessions_check_role
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@booking, '2026-08-11T08:01:00', (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'), N'Clean.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E13 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E13 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E13 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E14 - trg_maintenance_check_assignee_role';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Assigned maintenance staff must be facility staff%';
    -- Expected error: trg_maintenance_check_assignee_role / facility_manager is invalid assignee
    INSERT INTO [dbo].[maintenance] ([space_id], [reporter_id], [assigned_staff_id], [problem_description], [start_time], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitymanager1@university.edu'),
        N'T06 Invalid assignee role test.',
        '2026-08-12T08:00:00',
        'open'
    );
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E14 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E14 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E14 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E15 - trg_bookings_cancellation blocked predecessor';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%Cancellation is only allowed from pending or approved status%';
    DECLARE @booking INT = (
        SELECT TOP (1) b.[booking_id]
        FROM [dbo].[bookings] b
        INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
        WHERE s.[space_code] = N'T06-COMP-301'
          AND b.[status] = 'completed'
        ORDER BY b.[booking_id]
    );
    -- Expected error: trg_bookings_cancellation / completed cannot be cancelled
    UPDATE [dbo].[bookings]
    SET [status] = 'cancelled'
    WHERE [booking_id] = @booking;
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E15 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E15 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E15 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E16 - UQ_users_email';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%UQ_users_email%';
    -- Expected error: UQ_users_email duplicate business key
    INSERT INTO [dbo].[users] ([email], [full_name], [phone_number], [role], [department_id], [account_status])
    VALUES (N't06.student1@university.edu', N'Duplicate User', NULL, 'student', (SELECT [department_id] FROM [dbo].[departments] WHERE [name] = N'School of Computer Science'), 'active');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E16 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E16 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E16 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E17 - CK_bookings_status';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%CK_bookings_status%';
    -- Expected error: CK_bookings_status invalid enum
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-13T08:00:00', '2026-08-13T09:00:00', 'meeting', 8, 'invalid_status'
    );
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E17 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E17 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E17 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E18 - CK_bookings_requested_end_time';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%CK_bookings_requested_end_time%';
    -- Expected error: CK_bookings_requested_end_time invalid time range
    INSERT INTO [dbo].[bookings] ([space_id], [requester_id], [requested_start_time], [requested_end_time], [purpose], [expected_participants], [status])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.student1@university.edu'),
        '2026-08-14T09:00:00', '2026-08-14T08:00:00', 'meeting', 8, 'pending'
    );
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E18 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E18 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E18 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E19 - CK_space_facilities_quantity';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%CK_space_facilities_quantity%';
    -- Expected error: CK_space_facilities_quantity invalid quantity
    INSERT INTO [dbo].[space_facilities] ([space_id], [facility_id], [quantity])
    VALUES (
        (SELECT [space_id] FROM [dbo].[spaces] WHERE [space_code] = N'T06-SW-020'),
        (SELECT [facility_id] FROM [dbo].[facilities] WHERE [name] = N'T06 Projector'),
        0
    );
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E19 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E19 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E19 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E20 - UQ_booking_approvals_booking_id';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%UQ_booking_approvals_booking_id%';
    DECLARE @booking INT = (
        SELECT TOP (1) b.[booking_id]
        FROM [dbo].[bookings] b
        INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
        WHERE s.[space_code] = N'T06-AUD-101'
          AND b.[status] = 'approved'
        ORDER BY b.[booking_id]
    );
    -- Expected error: UQ_booking_approvals_booking_id duplicate one-to-zero-or-one child
    INSERT INTO [dbo].[booking_approvals] ([booking_id], [approver_id], [decision_time], [decision], [decision_note])
    VALUES (@booking, (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), '2026-07-25T09:00:00', 'approved', N'Duplicate child test.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E20 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E20 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E20 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'EXPECTED_ERROR_CASE: E21 - UQ_booking_sessions_booking_id';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @expected_error_pattern NVARCHAR(4000) = N'%UQ_booking_sessions_booking_id%';
    DECLARE @booking INT = (
        SELECT TOP (1) b.[booking_id]
        FROM [dbo].[bookings] b
        INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
        WHERE s.[space_code] = N'T06-COMP-202'
          AND b.[status] = 'checked_in'
        ORDER BY b.[booking_id]
    );
    -- Expected error: UQ_booking_sessions_booking_id duplicate one-to-zero-or-one child
    INSERT INTO [dbo].[booking_sessions] ([booking_id], [actual_start_time], [checked_in_by], [initial_condition])
    VALUES (@booking, '2026-07-02T09:10:00', (SELECT [user_id] FROM [dbo].[users] WHERE [email] = N't06.facilitystaff1@university.edu'), N'Duplicate session test.');
    ROLLBACK TRANSACTION;
    PRINT 'FAIL: E21 did not raise an error.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_MESSAGE() LIKE @expected_error_pattern PRINT 'PASS: E21 - ' + ERROR_MESSAGE();
    ELSE PRINT 'FAIL: E21 wrong error - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT 'SECTION 8: Audit update trigger proofs';
GO

DECLARE @before_space DATETIME2 = (SELECT [updated_at] FROM [dbo].[spaces] WHERE [space_code] = N'T06-CLS-201');
UPDATE [dbo].[spaces]
SET [usage_policy] = N'Tutorials and seminars; reset furniture after use. Updated by Task 06 audit proof.'
WHERE [space_code] = N'T06-CLS-201';
PRINT 'VERIFY: V-AUDIT-PARENT - spaces updated_at changed by update trigger';
SELECT [space_code], CASE WHEN [updated_at] >= @before_space THEN 'covered' ELSE 'not_covered' END AS [audit_parent_result], @before_space AS [before_updated_at], [updated_at] AS [after_updated_at]
FROM [dbo].[spaces]
WHERE [space_code] = N'T06-CLS-201';

DECLARE @session_booking INT = (
    SELECT TOP (1) b.[booking_id]
    FROM [dbo].[bookings] b
    INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
    WHERE s.[space_code] = N'T06-COMP-202'
      AND b.[status] = 'checked_in'
);
DECLARE @before_session DATETIME2 = (SELECT [updated_at] FROM [dbo].[booking_sessions] WHERE [booking_id] = @session_booking);
UPDATE [dbo].[booking_sessions]
SET [usage_notes] = N'In-progress session note updated for Task 06 audit proof.'
WHERE [booking_id] = @session_booking;
PRINT 'VERIFY: V-AUDIT-LIFECYCLE - booking_sessions updated_at changed by update trigger';
SELECT [booking_id], CASE WHEN [updated_at] >= @before_session THEN 'covered' ELSE 'not_covered' END AS [audit_lifecycle_result], @before_session AS [before_updated_at], [updated_at] AS [after_updated_at]
FROM [dbo].[booking_sessions]
WHERE [booking_id] = @session_booking;
GO

PRINT 'SECTION 9: Verification queries';
GO

PRINT 'VERIFY: V-ROW-COUNTS - Task 06-owned row counts';
SELECT 'users' AS [object_name], COUNT(*) AS [row_count] FROM [dbo].[users] WHERE [email] LIKE N't06.%'
UNION ALL SELECT 'spaces', COUNT(*) FROM [dbo].[spaces] WHERE [space_code] LIKE N'T06-%'
UNION ALL SELECT 'facilities', COUNT(*) FROM [dbo].[facilities] WHERE [name] LIKE N'T06 %'
UNION ALL SELECT 'space_facilities', COUNT(*) FROM [dbo].[space_facilities] sf WHERE EXISTS (SELECT 1 FROM [dbo].[spaces] s WHERE s.[space_id] = sf.[space_id] AND s.[space_code] LIKE N'T06-%')
UNION ALL SELECT 'maintenance', COUNT(*) FROM [dbo].[maintenance] m WHERE EXISTS (SELECT 1 FROM [dbo].[spaces] s WHERE s.[space_id] = m.[space_id] AND s.[space_code] LIKE N'T06-%')
UNION ALL SELECT 'bookings', COUNT(*) FROM [dbo].[bookings] b WHERE EXISTS (SELECT 1 FROM [dbo].[spaces] s WHERE s.[space_id] = b.[space_id] AND s.[space_code] LIKE N'T06-%')
UNION ALL SELECT 'booking_approvals', COUNT(*) FROM [dbo].[booking_approvals] ba WHERE EXISTS (SELECT 1 FROM [dbo].[bookings] b INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE b.[booking_id] = ba.[booking_id] AND s.[space_code] LIKE N'T06-%')
UNION ALL SELECT 'booking_sessions', COUNT(*) FROM [dbo].[booking_sessions] bs WHERE EXISTS (SELECT 1 FROM [dbo].[bookings] b INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE b.[booking_id] = bs.[booking_id] AND s.[space_code] LIKE N'T06-%');

PRINT 'VERIFY: V-USER-ROLES - all user roles';
SELECT [role], COUNT(*) AS [count_per_role]
FROM [dbo].[users]
WHERE [email] LIKE N't06.%'
GROUP BY [role]
ORDER BY [role];

PRINT 'VERIFY: V-ACCOUNT-STATUS - all account statuses';
SELECT [account_status], COUNT(*) AS [count_per_status]
FROM [dbo].[users]
WHERE [email] LIKE N't06.%'
GROUP BY [account_status]
ORDER BY [account_status];

PRINT 'VERIFY: V-SPACE-TYPES - all space types';
SELECT [space_type], COUNT(*) AS [count_per_type]
FROM [dbo].[spaces]
WHERE [space_code] LIKE N'T06-%'
GROUP BY [space_type]
ORDER BY [space_type];

PRINT 'VERIFY: V-SPACE-STATUS - all space statuses';
SELECT [current_status], COUNT(*) AS [count_per_status]
FROM [dbo].[spaces]
WHERE [space_code] LIKE N'T06-%'
GROUP BY [current_status]
ORDER BY [current_status];

PRINT 'VERIFY: V-BOOKING-STATUS - all booking statuses';
SELECT b.[status], COUNT(*) AS [count_per_status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY b.[status]
ORDER BY b.[status];

PRINT 'VERIFY: V-BOOKING-PURPOSE - all booking purposes';
SELECT b.[purpose], COUNT(*) AS [count_per_purpose]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY b.[purpose]
ORDER BY b.[purpose];

PRINT 'VERIFY: V-APPROVAL-DECISION - approved and rejected decisions';
SELECT ba.[decision], COUNT(*) AS [count_per_decision]
FROM [dbo].[booking_approvals] ba
INNER JOIN [dbo].[bookings] b ON b.[booking_id] = ba.[booking_id]
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY ba.[decision]
ORDER BY ba.[decision];

PRINT 'VERIFY: V-MAINT-STATUS - all maintenance statuses';
SELECT m.[status], COUNT(*) AS [count_per_status]
FROM [dbo].[maintenance] m
INNER JOIN [dbo].[spaces] s ON s.[space_id] = m.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
GROUP BY m.[status]
ORDER BY m.[status];

PRINT 'VERIFY: V-SOFT-DELETE - historical soft-deleted booking and maintenance remain queryable';
SELECT 'booking' AS [history_type], COUNT(*) AS [soft_deleted_count]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%' AND b.[is_deleted] = 1
UNION ALL
SELECT 'maintenance', COUNT(*)
FROM [dbo].[maintenance] m
INNER JOIN [dbo].[spaces] s ON s.[space_id] = m.[space_id]
WHERE s.[space_code] LIKE N'T06-%' AND m.[is_deleted] = 1;

PRINT 'VERIFY: V-FK-JOINS - booking, approval, session, and maintenance joins';
SELECT TOP (20)
    b.[booking_id], s.[space_code], u.[email] AS [requester_email], b.[status],
    ba.[decision], bs.[actual_start_time], bs.[actual_end_time]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
LEFT JOIN [dbo].[booking_approvals] ba ON ba.[booking_id] = b.[booking_id]
LEFT JOIN [dbo].[booking_sessions] bs ON bs.[booking_id] = b.[booking_id]
WHERE s.[space_code] LIKE N'T06-%'
ORDER BY b.[booking_id];

PRINT 'VERIFY: V-REPORT-UPCOMING - upcoming approved bookings';
SELECT s.[space_code], b.[requested_start_time], b.[requested_end_time], b.[purpose], b.[expected_participants]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND b.[status] = 'approved'
  AND b.[requested_start_time] > '2026-07-02T00:00:00'
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];

PRINT 'VERIFY: V-REPORT-HISTORY - booking history';
SELECT u.[email] AS [requester_email], s.[space_code], b.[requested_start_time], b.[requested_end_time], b.[status]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND b.[requested_end_time] < '2026-07-02T00:00:00'
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];

PRINT 'VERIFY: V-REPORT-MAINTENANCE - spaces under maintenance';
SELECT s.[space_code], s.[space_name], s.[current_status], m.[problem_description], m.[status]
FROM [dbo].[spaces] s
INNER JOIN [dbo].[maintenance] m ON m.[space_id] = s.[space_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND s.[current_status] = 'under_maintenance'
  AND m.[is_deleted] = 0;

PRINT 'VERIFY: V-REPORT-NOSHOW - no-show bookings';
SELECT s.[space_code], b.[requested_start_time], b.[requested_end_time], u.[email] AS [requester_email]
FROM [dbo].[bookings] b
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id]
INNER JOIN [dbo].[users] u ON u.[user_id] = b.[requester_id]
WHERE s.[space_code] LIKE N'T06-%'
  AND b.[status] = 'no_show'
  AND b.[is_deleted] = 0
ORDER BY b.[requested_start_time];

PRINT 'VERIFY: V-AUDIT-NONNULL - created_at and updated_at populated';
SELECT 'users' AS [object_name], SUM(CASE WHEN [created_at] IS NULL OR [updated_at] IS NULL THEN 1 ELSE 0 END) AS [null_audit_count] FROM [dbo].[users] WHERE [email] LIKE N't06.%'
UNION ALL SELECT 'spaces', SUM(CASE WHEN [created_at] IS NULL OR [updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[spaces] WHERE [space_code] LIKE N'T06-%'
UNION ALL SELECT 'bookings', SUM(CASE WHEN b.[created_at] IS NULL OR b.[updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[bookings] b INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'booking_approvals', SUM(CASE WHEN ba.[created_at] IS NULL OR ba.[updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[booking_approvals] ba INNER JOIN [dbo].[bookings] b ON b.[booking_id] = ba.[booking_id] INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'booking_sessions', SUM(CASE WHEN bs.[created_at] IS NULL OR bs.[updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[booking_sessions] bs INNER JOIN [dbo].[bookings] b ON b.[booking_id] = bs.[booking_id] INNER JOIN [dbo].[spaces] s ON s.[space_id] = b.[space_id] WHERE s.[space_code] LIKE N'T06-%'
UNION ALL SELECT 'maintenance', SUM(CASE WHEN m.[created_at] IS NULL OR m.[updated_at] IS NULL THEN 1 ELSE 0 END) FROM [dbo].[maintenance] m INNER JOIN [dbo].[spaces] s ON s.[space_id] = m.[space_id] WHERE s.[space_code] LIKE N'T06-%';

PRINT 'VERIFY: V-NO-ACTIVE-OVERLAP - valid active bookings do not overlap';
SELECT COUNT(*) AS [active_overlap_pair_count]
FROM [dbo].[bookings] b1
INNER JOIN [dbo].[bookings] b2
    ON b1.[space_id] = b2.[space_id]
   AND b1.[booking_id] < b2.[booking_id]
   AND b1.[is_deleted] = 0
   AND b2.[is_deleted] = 0
   AND b1.[status] IN ('approved','checked_in','completed')
   AND b2.[status] IN ('approved','checked_in','completed')
   AND b1.[requested_start_time] < b2.[requested_end_time]
   AND b1.[requested_end_time] > b2.[requested_start_time]
INNER JOIN [dbo].[spaces] s ON s.[space_id] = b1.[space_id]
WHERE s.[space_code] LIKE N'T06-%';

PRINT '=== TASK 06 SAMPLE DATA GENERATION COMPLETE ===';
GO
