SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CS486 Group G05 — Campus Space Management System
-- DDL Script for SQL Server 2019+
-- Source of truth: docs/schema-registry.md (locked)
-- Generated: 2026-06-18
-- ============================================================

-- ============================================================
-- TABLE: departments
-- ============================================================
CREATE TABLE [dbo].[departments] (
    [department_id] INT           NOT NULL IDENTITY(1,1),
    [name]          NVARCHAR(255) NOT NULL,
    [created_at]    DATETIME2     NOT NULL DEFAULT GETDATE(),
    [updated_at]    DATETIME2     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_departments] PRIMARY KEY CLUSTERED ([department_id]),
    CONSTRAINT [UQ_departments_name] UNIQUE ([name])
);
GO

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE [dbo].[users] (
    [user_id]        INT           NOT NULL IDENTITY(1,1),
    [email]          NVARCHAR(255) NOT NULL,
    [full_name]      NVARCHAR(255) NOT NULL,
    [phone_number]   NVARCHAR(50)  NULL,
    [role]           VARCHAR(50)   NOT NULL,
    [department_id]  INT           NOT NULL,
    [account_status] VARCHAR(50)   NOT NULL DEFAULT 'active',
    [created_at]     DATETIME2     NOT NULL DEFAULT GETDATE(),
    [updated_at]     DATETIME2     NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_users] PRIMARY KEY CLUSTERED ([user_id]),
    CONSTRAINT [UQ_users_email] UNIQUE ([email]),
    CONSTRAINT [CK_users_role] CHECK ([role] IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')),
    CONSTRAINT [CK_users_account_status] CHECK ([account_status] IN ('active','inactive','suspended'))
);

ALTER TABLE [dbo].[users]
    ADD CONSTRAINT [FK_users_department_id]
    FOREIGN KEY ([department_id]) REFERENCES [dbo].[departments]([department_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
GO

-- ============================================================
-- TABLE: spaces
-- ============================================================
CREATE TABLE [dbo].[spaces] (
    [space_id]       INT            NOT NULL IDENTITY(1,1),
    [space_code]     NVARCHAR(50)   NOT NULL,
    [space_name]     NVARCHAR(255)  NOT NULL,
    [space_type]     VARCHAR(50)    NOT NULL,
    [building]       NVARCHAR(100)  NOT NULL,
    [floor]          NVARCHAR(50)   NOT NULL,
    [room_number]    NVARCHAR(50)   NOT NULL,
    [capacity]       INT            NOT NULL,
    [current_status] VARCHAR(50)    NOT NULL DEFAULT 'available',
    [usage_policy]   NVARCHAR(MAX)  NULL,
    [created_at]     DATETIME2      NOT NULL DEFAULT GETDATE(),
    [updated_at]     DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_spaces] PRIMARY KEY CLUSTERED ([space_id]),
    CONSTRAINT [UQ_spaces_space_code] UNIQUE ([space_code]),
    CONSTRAINT [CK_spaces_space_type] CHECK ([space_type] IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')),
    CONSTRAINT [CK_spaces_current_status] CHECK ([current_status] IN ('available','in_use','under_maintenance','temporarily_closed','retired')),
    CONSTRAINT [CK_spaces_capacity] CHECK ([capacity] > 0)
);
GO

-- ============================================================
-- TABLE: facilities
-- ============================================================
CREATE TABLE [dbo].[facilities] (
    [facility_id] INT            NOT NULL IDENTITY(1,1),
    [name]        NVARCHAR(255)  NOT NULL,
    [created_at]  DATETIME2      NOT NULL DEFAULT GETDATE(),
    [updated_at]  DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_facilities] PRIMARY KEY CLUSTERED ([facility_id]),
    CONSTRAINT [UQ_facilities_name] UNIQUE ([name])
);
GO

-- ============================================================
-- TABLE: space_facilities (junction)
-- ============================================================
CREATE TABLE [dbo].[space_facilities] (
    [space_id]    INT NOT NULL,
    [facility_id] INT NOT NULL,
    [quantity]    INT NULL,
    CONSTRAINT [PK_space_facilities] PRIMARY KEY CLUSTERED ([space_id], [facility_id]),
    CONSTRAINT [CK_space_facilities_quantity] CHECK ([quantity] IS NULL OR [quantity] > 0)
);

ALTER TABLE [dbo].[space_facilities]
    ADD CONSTRAINT [FK_space_facilities_space_id]
    FOREIGN KEY ([space_id]) REFERENCES [dbo].[spaces]([space_id])
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

ALTER TABLE [dbo].[space_facilities]
    ADD CONSTRAINT [FK_space_facilities_facility_id]
    FOREIGN KEY ([facility_id]) REFERENCES [dbo].[facilities]([facility_id])
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
GO

-- ============================================================
-- TABLE: bookings
-- ============================================================
CREATE TABLE [dbo].[bookings] (
    [booking_id]            INT            NOT NULL IDENTITY(1,1),
    [space_id]              INT            NOT NULL,
    [requester_id]          INT            NOT NULL,
    [requested_start_time]  DATETIME2      NOT NULL,
    [requested_end_time]    DATETIME2      NOT NULL,
    [purpose]               VARCHAR(50)    NOT NULL,
    [expected_participants] INT            NOT NULL,
    [status]                VARCHAR(50)    NOT NULL DEFAULT 'pending',
    [approver_id]           INT            NULL,
    [decision_time]         DATETIME2      NULL,
    [decision_note]         NVARCHAR(MAX)  NULL,
    [rejection_reason]      NVARCHAR(MAX)  NULL,
    [actual_start_time]     DATETIME2      NULL,
    [checked_in_by]         INT            NULL,
    [initial_condition]     NVARCHAR(MAX)  NULL,
    [actual_end_time]       DATETIME2      NULL,
    [final_condition]       NVARCHAR(MAX)  NULL,
    [usage_notes]           NVARCHAR(MAX)  NULL,
    [is_deleted]            BIT            NOT NULL DEFAULT 0,
    [created_at]            DATETIME2      NOT NULL DEFAULT GETDATE(),
    [updated_at]            DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_bookings] PRIMARY KEY CLUSTERED ([booking_id]),
    CONSTRAINT [CK_bookings_requested_end_time] CHECK ([requested_end_time] > [requested_start_time]),
    CONSTRAINT [CK_bookings_purpose] CHECK ([purpose] IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')),
    CONSTRAINT [CK_bookings_expected_participants] CHECK ([expected_participants] > 0),
    CONSTRAINT [CK_bookings_status] CHECK ([status] IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')),
    CONSTRAINT [CK_bookings_actual_time_order] CHECK ([actual_end_time] IS NULL OR [actual_start_time] IS NULL OR [actual_end_time] >= [actual_start_time])
);

ALTER TABLE [dbo].[bookings]
    ADD CONSTRAINT [FK_bookings_space_id]
    FOREIGN KEY ([space_id]) REFERENCES [dbo].[spaces]([space_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE [dbo].[bookings]
    ADD CONSTRAINT [FK_bookings_requester_id]
    FOREIGN KEY ([requester_id]) REFERENCES [dbo].[users]([user_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE [dbo].[bookings]
    ADD CONSTRAINT [FK_bookings_approver_id]
    FOREIGN KEY ([approver_id]) REFERENCES [dbo].[users]([user_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE [dbo].[bookings]
    ADD CONSTRAINT [FK_bookings_checked_in_by]
    FOREIGN KEY ([checked_in_by]) REFERENCES [dbo].[users]([user_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
GO

-- ============================================================
-- TABLE: maintenances
-- ============================================================
CREATE TABLE [dbo].[maintenances] (
    [maintenance_id]     INT            NOT NULL IDENTITY(1,1),
    [space_id]           INT            NOT NULL,
    [reporter_id]        INT            NOT NULL,
    [assigned_staff_id]  INT            NULL,
    [problem_description] NVARCHAR(MAX) NOT NULL,
    [start_time]         DATETIME2      NOT NULL,
    [completion_time]    DATETIME2      NULL,
    [status]             VARCHAR(50)    NOT NULL DEFAULT 'open',
    [result_note]        NVARCHAR(MAX)  NULL,
    [is_deleted]         BIT            NOT NULL DEFAULT 0,
    [created_at]         DATETIME2      NOT NULL DEFAULT GETDATE(),
    [updated_at]         DATETIME2      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT [PK_maintenances] PRIMARY KEY CLUSTERED ([maintenance_id]),
    CONSTRAINT [CK_maintenances_status] CHECK ([status] IN ('open','in_progress','resolved')),
    CONSTRAINT [CK_maintenances_completion_time] CHECK ([completion_time] IS NULL OR [completion_time] >= [start_time])
);

ALTER TABLE [dbo].[maintenances]
    ADD CONSTRAINT [FK_maintenances_space_id]
    FOREIGN KEY ([space_id]) REFERENCES [dbo].[spaces]([space_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE [dbo].[maintenances]
    ADD CONSTRAINT [FK_maintenances_reporter_id]
    FOREIGN KEY ([reporter_id]) REFERENCES [dbo].[users]([user_id])
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;

ALTER TABLE [dbo].[maintenances]
    ADD CONSTRAINT [FK_maintenances_assigned_staff_id]
    FOREIGN KEY ([assigned_staff_id]) REFERENCES [dbo].[users]([user_id])
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
GO

-- ============================================================
-- INDEXES
-- ============================================================

-- users indexes (UQ_users_email created by inline UNIQUE constraint)
CREATE NONCLUSTERED INDEX [idx_users_department_id] ON [dbo].[users] ([department_id]);

-- spaces indexes (UQ_spaces_space_code created by inline UNIQUE constraint)
CREATE NONCLUSTERED INDEX [idx_spaces_current_status] ON [dbo].[spaces] ([current_status]);

-- space_facilities indexes
CREATE NONCLUSTERED INDEX [idx_space_facilities_facility_id] ON [dbo].[space_facilities] ([facility_id]);

-- bookings indexes
CREATE NONCLUSTERED INDEX [idx_bookings_space_id] ON [dbo].[bookings] ([space_id]);
CREATE NONCLUSTERED INDEX [idx_bookings_requester_id] ON [dbo].[bookings] ([requester_id]);
CREATE NONCLUSTERED INDEX [idx_bookings_status] ON [dbo].[bookings] ([status]);
CREATE NONCLUSTERED INDEX [idx_bookings_time_range] ON [dbo].[bookings] ([space_id], [requested_start_time], [requested_end_time]);
CREATE NONCLUSTERED INDEX [idx_bookings_approver_id] ON [dbo].[bookings] ([approver_id]);
CREATE NONCLUSTERED INDEX [idx_bookings_checked_in_by] ON [dbo].[bookings] ([checked_in_by]);
CREATE NONCLUSTERED INDEX [idx_bookings_requested_start] ON [dbo].[bookings] ([requested_start_time]);
CREATE UNIQUE NONCLUSTERED INDEX [uq_bookings_active_overlap]
    ON [dbo].[bookings] ([space_id], [requested_start_time])
    WHERE [status] IN ('approved','checked_in','completed') AND [is_deleted] = 0;

-- maintenances indexes
CREATE NONCLUSTERED INDEX [idx_maintenances_space_id] ON [dbo].[maintenances] ([space_id]);
CREATE NONCLUSTERED INDEX [idx_maintenances_reporter_id] ON [dbo].[maintenances] ([reporter_id]);
CREATE NONCLUSTERED INDEX [idx_maintenances_assigned_staff_id] ON [dbo].[maintenances] ([assigned_staff_id]);
CREATE NONCLUSTERED INDEX [idx_maintenances_status] ON [dbo].[maintenances] ([status]);
GO

-- ============================================================
-- TRIGGERS
-- ============================================================

-- BR1: Prevent overlapping bookings (interval overlap)
GO
CREATE TRIGGER [trg_bookings_prevent_overlap]
ON [dbo].[bookings]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM [dbo].[bookings] b
        INNER JOIN inserted i ON b.[space_id] = i.[space_id] AND b.[booking_id] <> i.[booking_id]
        WHERE b.[status] IN ('approved','checked_in','completed')
          AND b.[is_deleted] = 0
          AND i.[is_deleted] = 0
          AND i.[status] IN ('approved','checked_in','completed')
          AND b.[requested_start_time] < i.[requested_end_time]
          AND b.[requested_end_time] > i.[requested_start_time]
    )
    BEGIN
        RAISERROR('BR1 violation: overlapping booking interval detected.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR2: Unavailable spaces cannot be booked
-- Only validate on INSERT (new booking) or when status transitions TO a live
-- state ('approved', 'checked_in'). Metadata-only updates (e.g. soft-delete,
-- notes, timestamps) do not check the space's live status — otherwise a
-- temporary repair would block legitimate operations on already-processed
-- bookings.
GO
CREATE TRIGGER [trg_bookings_check_space_status]
ON [dbo].[bookings]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN [dbo].[spaces] s ON i.[space_id] = s.[space_id]
        LEFT JOIN deleted d ON i.[booking_id] = d.[booking_id]
        WHERE s.[current_status] NOT IN ('available','in_use')
          AND (
              d.[booking_id] IS NULL  -- INSERT
              OR (                    -- UPDATE with status transition to active state
                  i.[status] IN ('approved', 'checked_in')
                  AND (d.[status] IS NULL OR d.[status] <> i.[status])
              )
          )
    )
    BEGIN
        RAISERROR('BR2 violation: space is not available for booking.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR3: Expected participants <= space capacity
GO
CREATE TRIGGER [trg_bookings_check_capacity]
ON [dbo].[bookings]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN [dbo].[spaces] s ON i.[space_id] = s.[space_id]
        WHERE i.[expected_participants] > s.[capacity]
    )
    BEGIN
        RAISERROR('BR3 violation: expected participants exceed space capacity.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR4: Maintenance blocks booking (overlapping unresolved maintenance)
GO
CREATE TRIGGER [trg_bookings_check_maintenance]
ON [dbo].[bookings]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN [dbo].[maintenances] m ON i.[space_id] = m.[space_id]
        WHERE m.[status] IN ('open','in_progress')
          AND m.[is_deleted] = 0
          AND m.[start_time] < i.[requested_end_time]
          AND (m.[completion_time] IS NULL OR m.[completion_time] > i.[requested_start_time])
    )
    BEGIN
        RAISERROR('BR4 violation: overlapping unresolved maintenance prevents booking.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR6: Decision recording (approver, time, note) when status changes to approved/rejected
GO
CREATE TRIGGER [trg_bookings_approval_validation]
ON [dbo].[bookings]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.[booking_id] = d.[booking_id]
        WHERE i.[status] IN ('approved','rejected')
          AND d.[status] = 'pending'
          AND (i.[approver_id] IS NULL OR i.[decision_time] IS NULL OR i.[decision_note] IS NULL)
    )
    BEGIN
        RAISERROR('BR6 violation: approver_id, decision_time, and decision_note are required when approving or rejecting a booking.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR7: Rejection requires reason
-- Only enforce when status IS CHANGING TO 'rejected' (INSERT or UPDATE).
-- If status is already 'rejected' and another column is updated (e.g. soft-delete
-- is_deleted = 1), do NOT re-validate rejection_reason — this avoids false
-- rejections caused by ORMs that may omit the column from the update payload.
GO
CREATE TRIGGER [trg_bookings_rejection_reason]
ON [dbo].[bookings]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON i.[booking_id] = d.[booking_id]
        WHERE i.[status] = 'rejected'
          AND (d.[booking_id] IS NULL OR d.[status] <> 'rejected')
          AND i.[rejection_reason] IS NULL
    )
    BEGIN
        RAISERROR('BR7 violation: rejection_reason is required when status is rejected.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR8/BR9: Check-in enforcement (actual_start_time, checked_in_by, initial_condition)
GO
CREATE TRIGGER [trg_bookings_checkin_enforcement]
ON [dbo].[bookings]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.[booking_id] = d.[booking_id]
        WHERE i.[status] = 'checked_in'
          AND d.[status] <> 'checked_in'
          AND (i.[actual_start_time] IS NULL OR i.[checked_in_by] IS NULL OR i.[initial_condition] IS NULL)
    )
    BEGIN
        RAISERROR('BR8/BR9 violation: actual_start_time, checked_in_by, and initial_condition are required when checking in.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR8/BR9: Completion enforcement (actual_end_time, final_condition)
GO
CREATE TRIGGER [trg_bookings_completion_enforcement]
ON [dbo].[bookings]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.[booking_id] = d.[booking_id]
        WHERE i.[status] = 'completed'
          AND d.[status] <> 'completed'
          AND (i.[actual_end_time] IS NULL OR i.[final_condition] IS NULL)
    )
    BEGIN
        RAISERROR('BR8/BR9 violation: actual_end_time and final_condition are required when completing a booking.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- Q3: Auto-update space status to 'available' when ALL maintenance is resolved.
-- Only transition to 'available' if no other active (open/in_progress) tickets
-- exist for the same space. Prevents prematurely clearing the status when
-- concurrent maintenance tickets are still unresolved.
GO
CREATE TRIGGER [trg_maintenances_completion_space_status]
ON [dbo].[maintenances]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE s
    SET [current_status] = 'available',
        [updated_at] = GETDATE()
    FROM [dbo].[spaces] s
    INNER JOIN inserted i ON s.[space_id] = i.[space_id]
    INNER JOIN deleted d ON i.[maintenance_id] = d.[maintenance_id]
    WHERE i.[status] = 'resolved'
      AND d.[status] <> 'resolved'
      AND s.[current_status] = 'under_maintenance'
      AND NOT EXISTS (
          SELECT 1
          FROM [dbo].[maintenances] m
          WHERE m.[space_id] = i.[space_id]
            AND m.[maintenance_id] <> i.[maintenance_id]
            AND m.[status] IN ('open', 'in_progress')
            AND m.[is_deleted] = 0
      );
END;
GO

-- ============================================================
-- updated_at auto-stamp triggers
-- DEFAULT GETDATE() only fires on INSERT; these triggers keep
-- updated_at current on every row modification.
-- Guarded with IF NOT UPDATE([updated_at]) to prevent infinite
-- recursion when RECURSIVE_TRIGGERS is ON: if the UPDATE already
-- touched [updated_at] (e.g. this trigger's own inner UPDATE),
-- the recursive invocation is a no-op.
-- ============================================================
GO
CREATE TRIGGER [trg_departments_updated_at]
ON [dbo].[departments]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([updated_at])
    BEGIN
        UPDATE t SET [updated_at] = GETDATE()
        FROM [dbo].[departments] t
        INNER JOIN inserted i ON t.[department_id] = i.[department_id];
    END;
END;
GO

GO
CREATE TRIGGER [trg_users_updated_at]
ON [dbo].[users]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([updated_at])
    BEGIN
        UPDATE t SET [updated_at] = GETDATE()
        FROM [dbo].[users] t
        INNER JOIN inserted i ON t.[user_id] = i.[user_id];
    END;
END;
GO

GO
CREATE TRIGGER [trg_spaces_updated_at]
ON [dbo].[spaces]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([updated_at])
    BEGIN
        UPDATE t SET [updated_at] = GETDATE()
        FROM [dbo].[spaces] t
        INNER JOIN inserted i ON t.[space_id] = i.[space_id];
    END;
END;
GO

GO
CREATE TRIGGER [trg_facilities_updated_at]
ON [dbo].[facilities]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([updated_at])
    BEGIN
        UPDATE t SET [updated_at] = GETDATE()
        FROM [dbo].[facilities] t
        INNER JOIN inserted i ON t.[facility_id] = i.[facility_id];
    END;
END;
GO

GO
CREATE TRIGGER [trg_bookings_updated_at]
ON [dbo].[bookings]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([updated_at])
    BEGIN
        UPDATE t SET [updated_at] = GETDATE()
        FROM [dbo].[bookings] t
        INNER JOIN inserted i ON t.[booking_id] = i.[booking_id];
    END;
END;
GO

GO
CREATE TRIGGER [trg_maintenances_updated_at]
ON [dbo].[maintenances]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE([updated_at])
    BEGIN
        UPDATE t SET [updated_at] = GETDATE()
        FROM [dbo].[maintenances] t
        INNER JOIN inserted i ON t.[maintenance_id] = i.[maintenance_id];
    END;
END;
GO
