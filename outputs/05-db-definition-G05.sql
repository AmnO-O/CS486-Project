SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CS486 G05 — Campus Space Management System
-- Task 05: Database Definition (DDL)
-- Target: SQL Server 2019+ (T-SQL)
-- ============================================================

-- ============================================================
-- 1. departments
-- ============================================================
CREATE TABLE departments (
    department_id INT NOT NULL IDENTITY(1,1),
    name NVARCHAR(255) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_departments PRIMARY KEY (department_id),
    CONSTRAINT UQ_departments_name UNIQUE (name)
);
GO

-- ============================================================
-- 2. users
-- ============================================================
CREATE TABLE users (
    user_id INT NOT NULL IDENTITY(1,1),
    email NVARCHAR(255) NOT NULL,
    full_name NVARCHAR(255) NOT NULL,
    phone_number NVARCHAR(50) NULL,
    role VARCHAR(50) NOT NULL,
    department_id INT NOT NULL,
    account_status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_users PRIMARY KEY (user_id),
    CONSTRAINT UQ_users_email UNIQUE (email),
    CONSTRAINT CK_users_role CHECK (role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')),
    CONSTRAINT CK_users_account_status CHECK (account_status IN ('active','inactive','suspended')),
    CONSTRAINT FK_users_department_id FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ============================================================
-- 3. spaces
-- ============================================================
CREATE TABLE spaces (
    space_id INT NOT NULL IDENTITY(1,1),
    space_code NVARCHAR(50) NOT NULL,
    space_name NVARCHAR(255) NOT NULL,
    space_type VARCHAR(50) NOT NULL,
    building NVARCHAR(100) NOT NULL,
    floor NVARCHAR(50) NOT NULL,
    room_number NVARCHAR(50) NOT NULL,
    capacity INT NOT NULL,
    current_status VARCHAR(50) NOT NULL DEFAULT 'available',
    usage_policy NVARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_spaces PRIMARY KEY (space_id),
    CONSTRAINT UQ_spaces_space_code UNIQUE (space_code),
    CONSTRAINT CK_spaces_space_type CHECK (space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')),
    CONSTRAINT CK_spaces_capacity CHECK (capacity > 0),
    CONSTRAINT CK_spaces_current_status CHECK (current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired'))
);
GO

-- ============================================================
-- 4. facilities
-- ============================================================
CREATE TABLE facilities (
    facility_id INT NOT NULL IDENTITY(1,1),
    name NVARCHAR(255) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_facilities PRIMARY KEY (facility_id),
    CONSTRAINT UQ_facilities_name UNIQUE (name)
);
GO

-- ============================================================
-- 5. space_facilities (junction table)
-- ============================================================
CREATE TABLE space_facilities (
    space_id INT NOT NULL,
    facility_id INT NOT NULL,
    quantity INT NULL,
    CONSTRAINT PK_space_facilities PRIMARY KEY (space_id, facility_id),
    CONSTRAINT FK_space_facilities_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_space_facilities_facility_id FOREIGN KEY (facility_id) REFERENCES facilities(facility_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT CK_space_facilities_quantity CHECK (quantity IS NULL OR quantity > 0)
);
GO

-- ============================================================
-- 6. bookings
-- ============================================================
CREATE TABLE bookings (
    booking_id INT NOT NULL IDENTITY(1,1),
    space_id INT NOT NULL,
    requester_id INT NOT NULL,
    requested_start_time DATETIME2 NOT NULL,
    requested_end_time DATETIME2 NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    expected_participants INT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    is_deleted BIT NOT NULL DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_bookings PRIMARY KEY (booking_id),
    CONSTRAINT CK_bookings_requested_end_time CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK_bookings_purpose CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')),
    CONSTRAINT CK_bookings_expected_participants CHECK (expected_participants > 0),
    CONSTRAINT CK_bookings_status CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')),
    CONSTRAINT FK_bookings_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_bookings_requester_id FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ============================================================
-- 7. booking_approvals
-- ============================================================
CREATE TABLE booking_approvals (
    approval_id INT NOT NULL IDENTITY(1,1),
    booking_id INT NOT NULL,
    approver_id INT NOT NULL,
    decision_time DATETIME2 NOT NULL,
    decision VARCHAR(50) NOT NULL,
    rejection_reason NVARCHAR(MAX) NULL,
    decision_note NVARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_booking_approvals PRIMARY KEY (approval_id),
    CONSTRAINT UQ_booking_approvals_booking_id UNIQUE (booking_id),
    CONSTRAINT CK_booking_approvals_decision CHECK (decision IN ('approved','rejected')),
    CONSTRAINT FK_booking_approvals_booking_id FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_booking_approvals_approver_id FOREIGN KEY (approver_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ============================================================
-- 8. booking_sessions
-- ============================================================
CREATE TABLE booking_sessions (
    session_id INT NOT NULL IDENTITY(1,1),
    booking_id INT NOT NULL,
    actual_start_time DATETIME2 NOT NULL,
    checked_in_by INT NOT NULL,
    initial_condition NVARCHAR(MAX) NULL,
    actual_end_time DATETIME2 NULL,
    final_condition NVARCHAR(MAX) NULL,
    usage_notes NVARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_booking_sessions PRIMARY KEY (session_id),
    CONSTRAINT UQ_booking_sessions_booking_id UNIQUE (booking_id),
    CONSTRAINT FK_booking_sessions_booking_id FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_booking_sessions_checked_in_by FOREIGN KEY (checked_in_by) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ============================================================
-- 9. maintenance
-- ============================================================
CREATE TABLE maintenance (
    maintenance_id INT NOT NULL IDENTITY(1,1),
    space_id INT NOT NULL,
    reporter_id INT NOT NULL,
    assigned_staff_id INT NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    start_time DATETIME2 NOT NULL,
    completion_time DATETIME2 NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    result_note NVARCHAR(MAX) NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_maintenance PRIMARY KEY (maintenance_id),
    CONSTRAINT CK_maintenance_status CHECK (status IN ('open','in_progress','resolved')),
    CONSTRAINT FK_maintenance_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_maintenance_reporter_id FOREIGN KEY (reporter_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_maintenance_assigned_staff_id FOREIGN KEY (assigned_staff_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

-- ============================================================
-- Non-clustered and filtered indexes
-- ============================================================

-- users
CREATE INDEX idx_users_department_id ON users (department_id);
GO

-- spaces
CREATE INDEX idx_spaces_current_status ON spaces (current_status);
GO

-- space_facilities
CREATE INDEX idx_space_facilities_facility_id ON space_facilities (facility_id);
GO

-- bookings
CREATE INDEX idx_bookings_space_id ON bookings (space_id);
GO
CREATE INDEX idx_bookings_requester_id ON bookings (requester_id);
GO
CREATE INDEX idx_bookings_status ON bookings (status);
GO
CREATE INDEX idx_bookings_time_range ON bookings (space_id, requested_start_time, requested_end_time);
GO
CREATE INDEX idx_bookings_requested_start ON bookings (requested_start_time);
GO

-- Filtered unique index — prevents exact start-time collision for confirmed bookings
CREATE UNIQUE NONCLUSTERED INDEX uq_bookings_active_overlap ON bookings (space_id, requested_start_time)
    WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0;
GO

-- booking_approvals
CREATE INDEX idx_booking_approvals_approver_id ON booking_approvals (approver_id);
GO

-- booking_sessions
CREATE INDEX idx_booking_sessions_checked_in_by ON booking_sessions (checked_in_by);
GO

-- maintenance
CREATE INDEX idx_maintenance_space_id ON maintenance (space_id);
GO
CREATE INDEX idx_maintenance_reporter_id ON maintenance (reporter_id);
GO
CREATE INDEX idx_maintenance_assigned_staff_id ON maintenance (assigned_staff_id);
GO
CREATE INDEX idx_maintenance_status ON maintenance (status);
GO

-- ============================================================
-- Triggers
-- ============================================================

-- BR1: No overlapping approved bookings (interval overlap check)
GO
CREATE TRIGGER trg_bookings_prevent_overlap
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b
            ON b.space_id = i.space_id
            AND b.booking_id <> i.booking_id
            AND b.is_deleted = 0
            AND b.status IN ('approved','checked_in','completed')
            AND b.requested_start_time < i.requested_end_time
            AND b.requested_end_time > i.requested_start_time
    )
    BEGIN
        RAISERROR('Overlapping booking exists for this space and time range.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR2: Unavailable spaces cannot be approved
GO
CREATE TRIGGER trg_booking_approvals_check_space
ON booking_approvals
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b ON b.booking_id = i.booking_id
        INNER JOIN spaces s ON s.space_id = b.space_id
        WHERE i.decision = 'approved'
          AND s.current_status NOT IN ('available','in_use')
    )
    BEGIN
        RAISERROR('Cannot approve booking: space is not available.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR3: Expected participants ≤ space capacity
GO
CREATE TRIGGER trg_bookings_check_capacity
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN spaces s ON s.space_id = i.space_id
        WHERE i.expected_participants > s.capacity
    )
    BEGIN
        RAISERROR('Expected participants exceed space capacity.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR4: Maintenance blocks booking (overlapping unresolved maintenance)
GO
CREATE TRIGGER trg_bookings_check_maintenance
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN maintenance m
            ON m.space_id = i.space_id
            AND m.is_deleted = 0
            AND m.status IN ('open','in_progress')
            AND m.start_time < i.requested_end_time
            AND (m.completion_time IS NULL OR m.completion_time > i.requested_start_time)
    )
    BEGIN
        RAISERROR('Overlapping unresolved maintenance exists for this space.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR6: Decision recording (approver, time, decision)
GO
CREATE TRIGGER trg_booking_approvals_decision
ON booking_approvals
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.approver_id IS NULL OR i.decision_time IS NULL
    )
    BEGIN
        RAISERROR('approver_id and decision_time must not be NULL.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    UPDATE b
    SET status = i.decision
    FROM bookings b
    INNER JOIN inserted i ON b.booking_id = i.booking_id;
END
GO

-- BR7: Rejection requires reason
GO
CREATE TRIGGER trg_booking_approvals_rejection
ON booking_approvals
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.decision = 'rejected'
          AND i.rejection_reason IS NULL
    )
    BEGIN
        RAISERROR('Rejection reason must be provided when decision is rejected.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR8/BR9: Check-in validation and space/booking status update
GO
CREATE TRIGGER trg_booking_sessions_checkin
ON booking_sessions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b ON b.booking_id = i.booking_id
        WHERE b.status != 'approved'
    )
    BEGIN
        RAISERROR('Cannot check in: booking is not in approved status.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.initial_condition IS NULL
    )
    BEGIN
        RAISERROR('initial_condition must be provided at check-in.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
    UPDATE b
    SET status = 'checked_in'
    FROM bookings b
    INNER JOIN inserted i ON b.booking_id = i.booking_id;
    UPDATE s
    SET current_status = 'in_use'
    FROM spaces s
    INNER JOIN bookings b ON b.space_id = s.space_id
    INNER JOIN inserted i ON b.booking_id = i.booking_id;
END
GO

-- BR8/BR9: Completion validation and space/booking status update
GO
CREATE TRIGGER trg_booking_sessions_completion
ON booking_sessions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.session_id = d.session_id
        WHERE d.actual_end_time IS NULL
          AND i.actual_end_time IS NOT NULL
    )
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            INNER JOIN deleted d ON i.session_id = d.session_id
            WHERE d.actual_end_time IS NULL
              AND i.actual_end_time IS NOT NULL
              AND i.final_condition IS NULL
        )
        BEGIN
            RAISERROR('final_condition must be provided when completing a booking session.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        UPDATE b
        SET status = 'completed'
        FROM bookings b
        INNER JOIN inserted i ON b.booking_id = i.booking_id
        INNER JOIN deleted d ON i.session_id = d.session_id
        WHERE d.actual_end_time IS NULL
          AND i.actual_end_time IS NOT NULL;
        UPDATE s
        SET current_status = 'available'
        FROM spaces s
        INNER JOIN bookings b ON b.space_id = s.space_id
        INNER JOIN inserted i ON b.booking_id = i.booking_id
        INNER JOIN deleted d ON i.session_id = d.session_id
        WHERE d.actual_end_time IS NULL
          AND i.actual_end_time IS NOT NULL;
    END
END
GO

-- BR15: Approver must be facility staff or facility manager
GO
CREATE TRIGGER trg_booking_approvals_check_role
ON booking_approvals
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN users u ON u.user_id = i.approver_id
        WHERE u.role NOT IN ('facility_staff','facility_manager')
    )
    BEGIN
        RAISERROR('Approver must be facility staff or facility manager.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR16: Check-in staff must be facility staff or facility manager
GO
CREATE TRIGGER trg_booking_sessions_check_role
ON booking_sessions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN users u ON u.user_id = i.checked_in_by
        WHERE u.role NOT IN ('facility_staff','facility_manager')
    )
    BEGIN
        RAISERROR('Check-in staff must be facility staff or facility manager.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR17: Assigned maintenance staff must be facility staff
GO
CREATE TRIGGER trg_maintenance_check_assignee_role
ON maintenance
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN users u ON u.user_id = i.assigned_staff_id
        WHERE i.assigned_staff_id IS NOT NULL
          AND u.role != 'facility_staff'
    )
    BEGIN
        RAISERROR('Assigned maintenance staff must be facility staff.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO

-- BR18: Cancellation validity and space cleanup
GO
CREATE TRIGGER trg_bookings_cancellation
ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status = 'cancelled'
          AND d.status != 'cancelled'
    )
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM inserted i
            INNER JOIN deleted d ON i.booking_id = d.booking_id
            WHERE i.status = 'cancelled'
              AND d.status NOT IN ('pending','approved')
        )
        BEGIN
            RAISERROR('Cancellation is only allowed from pending or approved status.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        UPDATE s
        SET current_status = 'available'
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id
        INNER JOIN booking_sessions bs ON bs.booking_id = i.booking_id;
    END
END
GO

-- BR19: Maintenance completion restores space status
GO
CREATE TRIGGER trg_maintenance_completion_space_status
ON maintenance
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.maintenance_id = d.maintenance_id
        WHERE i.status = 'resolved'
          AND d.status != 'resolved'
    )
    BEGIN
        UPDATE s
        SET current_status = 'available'
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id
        WHERE NOT EXISTS (
            SELECT 1
            FROM maintenance m
            WHERE m.space_id = i.space_id
              AND m.status IN ('open','in_progress')
              AND m.is_deleted = 0
        );
    END
END
GO

-- updated_at auto-stamp triggers (all tables with updated_at column)
GO
CREATE TRIGGER trg_departments_updated_at
ON departments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE d
        SET updated_at = GETDATE()
        FROM departments d
        INNER JOIN inserted i ON d.department_id = i.department_id;
    END
END
GO

GO
CREATE TRIGGER trg_users_updated_at
ON users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE u
        SET updated_at = GETDATE()
        FROM users u
        INNER JOIN inserted i ON u.user_id = i.user_id;
    END
END
GO

GO
CREATE TRIGGER trg_spaces_updated_at
ON spaces
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE s
        SET updated_at = GETDATE()
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id;
    END
END
GO

GO
CREATE TRIGGER trg_facilities_updated_at
ON facilities
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE f
        SET updated_at = GETDATE()
        FROM facilities f
        INNER JOIN inserted i ON f.facility_id = i.facility_id;
    END
END
GO

GO
CREATE TRIGGER trg_bookings_updated_at
ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE b
        SET updated_at = GETDATE()
        FROM bookings b
        INNER JOIN inserted i ON b.booking_id = i.booking_id;
    END
END
GO

GO
CREATE TRIGGER trg_booking_approvals_updated_at
ON booking_approvals
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE ba
        SET updated_at = GETDATE()
        FROM booking_approvals ba
        INNER JOIN inserted i ON ba.approval_id = i.approval_id;
    END
END
GO

GO
CREATE TRIGGER trg_booking_sessions_updated_at
ON booking_sessions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE bs
        SET updated_at = GETDATE()
        FROM booking_sessions bs
        INNER JOIN inserted i ON bs.session_id = i.session_id;
    END
END
GO

GO
CREATE TRIGGER trg_maintenance_updated_at
ON maintenance
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE m
        SET updated_at = GETDATE()
        FROM maintenance m
        INNER JOIN inserted i ON m.maintenance_id = i.maintenance_id;
    END
END
GO
