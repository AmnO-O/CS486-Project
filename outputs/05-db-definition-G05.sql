SET QUOTED_IDENTIFIER ON
GO

-- =====================================================
-- CS486 G05 — Campus Space Management System
-- SQL Server 2019+  |  Database: CS486_G05
-- =====================================================

-- 1. departments
CREATE TABLE departments (
    department_id INT IDENTITY(1,1) NOT NULL,
    name NVARCHAR(255) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_departments PRIMARY KEY CLUSTERED (department_id),
    CONSTRAINT UQ_departments_name UNIQUE (name)
);
GO

-- 2. users
CREATE TABLE users (
    user_id INT IDENTITY(1,1) NOT NULL,
    email NVARCHAR(255) NOT NULL,
    full_name NVARCHAR(255) NOT NULL,
    phone_number NVARCHAR(50) NULL,
    role VARCHAR(50) NOT NULL,
    department_id INT NOT NULL,
    account_status VARCHAR(50) NOT NULL CONSTRAINT DF_users_account_status DEFAULT 'active',
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_users PRIMARY KEY CLUSTERED (user_id),
    CONSTRAINT UQ_users_email UNIQUE (email),
    CONSTRAINT CK_users_role CHECK (role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')),
    CONSTRAINT CK_users_account_status CHECK (account_status IN ('active','inactive','suspended')),
    CONSTRAINT FK_users_department_id FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- 3. spaces
CREATE TABLE spaces (
    space_id INT IDENTITY(1,1) NOT NULL,
    space_code NVARCHAR(50) NOT NULL,
    space_name NVARCHAR(255) NOT NULL,
    space_type VARCHAR(50) NOT NULL,
    building NVARCHAR(100) NOT NULL,
    floor NVARCHAR(50) NOT NULL,
    room_number NVARCHAR(50) NOT NULL,
    capacity INT NOT NULL,
    current_status VARCHAR(50) NOT NULL CONSTRAINT DF_spaces_current_status DEFAULT 'available',
    usage_policy NVARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_spaces PRIMARY KEY CLUSTERED (space_id),
    CONSTRAINT UQ_spaces_space_code UNIQUE (space_code),
    CONSTRAINT CK_spaces_space_type CHECK (space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')),
    CONSTRAINT CK_spaces_capacity CHECK (capacity > 0),
    CONSTRAINT CK_spaces_current_status CHECK (current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired'))
);
GO

-- 4. facilities
CREATE TABLE facilities (
    facility_id INT IDENTITY(1,1) NOT NULL,
    name NVARCHAR(255) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_facilities PRIMARY KEY CLUSTERED (facility_id),
    CONSTRAINT UQ_facilities_name UNIQUE (name)
);
GO

-- 5. space_facilities (junction: M:N Spaces ↔ Facilities)
CREATE TABLE space_facilities (
    space_id INT NOT NULL,
    facility_id INT NOT NULL,
    quantity INT NULL,
    CONSTRAINT PK_space_facilities PRIMARY KEY CLUSTERED (space_id, facility_id),
    CONSTRAINT FK_space_facilities_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_space_facilities_facility_id FOREIGN KEY (facility_id) REFERENCES facilities(facility_id) ON DELETE CASCADE ON UPDATE NO ACTION
);
GO

-- 6. bookings
CREATE TABLE bookings (
    booking_id INT IDENTITY(1,1) NOT NULL,
    space_id INT NOT NULL,
    requester_id INT NOT NULL,
    requested_start_time DATETIME2 NOT NULL,
    requested_end_time DATETIME2 NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    expected_participants INT NOT NULL,
    status VARCHAR(50) NOT NULL CONSTRAINT DF_bookings_status DEFAULT 'pending',
    approver_id INT NULL,
    decision_time DATETIME2 NULL,
    decision_note NVARCHAR(MAX) NULL,
    rejection_reason NVARCHAR(MAX) NULL,
    actual_start_time DATETIME2 NULL,
    checked_in_by INT NULL,
    initial_condition NVARCHAR(MAX) NULL,
    actual_end_time DATETIME2 NULL,
    final_condition NVARCHAR(MAX) NULL,
    usage_notes NVARCHAR(MAX) NULL,
    is_deleted BIT NOT NULL CONSTRAINT DF_bookings_is_deleted DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_bookings PRIMARY KEY CLUSTERED (booking_id),
    CONSTRAINT CK_bookings_requested_end_time CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK_bookings_purpose CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')),
    CONSTRAINT CK_bookings_expected_participants CHECK (expected_participants > 0),
    CONSTRAINT CK_bookings_status CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')),
    CONSTRAINT FK_bookings_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_bookings_requester_id FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_bookings_approver_id FOREIGN KEY (approver_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_bookings_checked_in_by FOREIGN KEY (checked_in_by) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- 7. maintenances
CREATE TABLE maintenances (
    maintenance_id INT IDENTITY(1,1) NOT NULL,
    space_id INT NOT NULL,
    reporter_id INT NOT NULL,
    assigned_staff_id INT NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    start_time DATETIME2 NOT NULL,
    completion_time DATETIME2 NULL,
    status VARCHAR(50) NOT NULL CONSTRAINT DF_maintenances_status DEFAULT 'open',
    result_note NVARCHAR(MAX) NULL,
    is_deleted BIT NOT NULL CONSTRAINT DF_maintenances_is_deleted DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_maintenances PRIMARY KEY CLUSTERED (maintenance_id),
    CONSTRAINT CK_maintenances_status CHECK (status IN ('open','in_progress','resolved')),
    CONSTRAINT FK_maintenances_space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_maintenances_reporter_id FOREIGN KEY (reporter_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_maintenances_assigned_staff_id FOREIGN KEY (assigned_staff_id) REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE NO ACTION
);
GO

-- =====================================================
-- Non-clustered indexes
-- =====================================================

CREATE INDEX idx_users_department_id ON users(department_id);
GO

CREATE INDEX idx_spaces_current_status ON spaces(current_status);
GO

CREATE INDEX idx_space_facilities_facility_id ON space_facilities(facility_id);
GO

CREATE INDEX idx_bookings_space_id ON bookings(space_id);
GO

CREATE INDEX idx_bookings_requester_id ON bookings(requester_id);
GO

CREATE INDEX idx_bookings_approver_id ON bookings(approver_id);
GO

CREATE INDEX idx_bookings_checked_in_by ON bookings(checked_in_by);
GO

CREATE INDEX idx_bookings_status ON bookings(status);
GO

CREATE INDEX idx_bookings_requested_start ON bookings(requested_start_time);
GO

CREATE INDEX idx_bookings_time_range ON bookings(space_id, requested_start_time, requested_end_time);
GO

CREATE INDEX idx_maintenances_space_id ON maintenances(space_id);
GO

CREATE INDEX idx_maintenances_reporter_id ON maintenances(reporter_id);
GO

CREATE INDEX idx_maintenances_assigned_staff_id ON maintenances(assigned_staff_id);
GO

CREATE INDEX idx_maintenances_status ON maintenances(status);
GO

-- Filtered unique index: BR1 exact start-time collision prevention
CREATE UNIQUE NONCLUSTERED INDEX uq_bookings_active_overlap ON bookings(space_id, requested_start_time)
    WHERE status IN ('approved','checked_in','completed') AND is_deleted = 0;
GO

-- =====================================================
-- Triggers — Business Rule Enforcement (see docs/schema-registry.md § Business Rule Coverage)
-- =====================================================

-- BR1: No overlapping approved bookings
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
        INNER JOIN bookings b ON i.space_id = b.space_id
            AND i.booking_id <> b.booking_id
            AND b.is_deleted = 0
            AND b.status IN ('approved','checked_in','completed')
            AND i.requested_start_time < b.requested_end_time
            AND i.requested_end_time > b.requested_start_time
    )
    BEGIN
        RAISERROR('BR1 violation: overlapping booking conflict detected for this space and time range.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR2: Unavailable spaces cannot be booked
GO
CREATE TRIGGER trg_bookings_check_space_status
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN spaces s ON i.space_id = s.space_id
        WHERE s.current_status NOT IN ('available','in_use')
    )
    BEGIN
        RAISERROR('BR2 violation: space is not available for booking (current_status = ''%s'').', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
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
        INNER JOIN spaces s ON i.space_id = s.space_id
        WHERE i.expected_participants > s.capacity
    )
    BEGIN
        RAISERROR('BR3 violation: expected participants (%d) exceed space capacity (%d).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR4: Maintenance blocks booking
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
        INNER JOIN maintenances m ON i.space_id = m.space_id
        WHERE m.is_deleted = 0
            AND m.status IN ('open','in_progress')
            AND m.start_time < i.requested_end_time
            AND (m.completion_time IS NULL OR m.completion_time > i.requested_start_time)
    )
    BEGIN
        RAISERROR('BR4 violation: space has overlapping unresolved maintenance ticket(s).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR6: Decision recording (approver, time, note) required on approval or rejection
GO
CREATE TRIGGER trg_bookings_approval_validation
ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status IN ('approved','rejected')
            AND d.status = 'pending'
            AND (i.approver_id IS NULL OR i.decision_time IS NULL OR i.decision_note IS NULL)
    )
    BEGIN
        RAISERROR('BR6 violation: approver_id, decision_time, and decision_note are required when approving or rejecting a booking.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- BR7: Rejection requires reason (scoped to status transition to 'rejected')
GO
CREATE TRIGGER trg_bookings_rejection_reason
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status = 'rejected'
            AND (d.status IS NULL OR d.status <> 'rejected')
            AND i.rejection_reason IS NULL
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
CREATE TRIGGER trg_bookings_checkin_enforcement
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status = 'checked_in'
            AND (d.status IS NULL OR d.status <> 'checked_in')
            AND (i.actual_start_time IS NULL OR i.checked_in_by IS NULL OR i.initial_condition IS NULL)
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
CREATE TRIGGER trg_bookings_completion_enforcement
ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status = 'completed'
            AND (d.status IS NULL OR d.status <> 'completed')
            AND (i.actual_end_time IS NULL OR i.final_condition IS NULL)
    )
    BEGIN
        RAISERROR('BR8/BR9 violation: actual_end_time and final_condition are required when completing a booking.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- Q3: Maintenance completion → auto-update space status (checks for concurrent unresolved tickets)
GO
CREATE TRIGGER trg_maintenances_completion_space_status
ON maintenances
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN deleted d ON i.maintenance_id = d.maintenance_id
        WHERE i.status = 'resolved'
            AND (d.status IS NULL OR d.status <> 'resolved')
    )
    BEGIN
        UPDATE s
        SET s.current_status = 'available',
            s.updated_at = GETDATE()
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id
        WHERE s.current_status = 'under_maintenance'
            AND NOT EXISTS (
                SELECT 1
                FROM maintenances m
                WHERE m.space_id = i.space_id
                    AND m.maintenance_id <> i.maintenance_id
                    AND m.is_deleted = 0
                    AND m.status IN ('open','in_progress')
            );
    END;
END;
GO

-- =====================================================
-- Additional integrity safeguards: updated_at auto-stamp
-- (not part of locked schema registry — keeps timestamps current on UPDATE)
-- =====================================================

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
        SET d.updated_at = GETDATE()
        FROM departments d
        INNER JOIN inserted i ON d.department_id = i.department_id;
    END;
END;
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
        SET u.updated_at = GETDATE()
        FROM users u
        INNER JOIN inserted i ON u.user_id = i.user_id;
    END;
END;
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
        SET s.updated_at = GETDATE()
        FROM spaces s
        INNER JOIN inserted i ON s.space_id = i.space_id;
    END;
END;
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
        SET f.updated_at = GETDATE()
        FROM facilities f
        INNER JOIN inserted i ON f.facility_id = i.facility_id;
    END;
END;
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
        SET b.updated_at = GETDATE()
        FROM bookings b
        INNER JOIN inserted i ON b.booking_id = i.booking_id;
    END;
END;
GO

GO
CREATE TRIGGER trg_maintenances_updated_at
ON maintenances
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(updated_at)
    BEGIN
        UPDATE m
        SET m.updated_at = GETDATE()
        FROM maintenances m
        INNER JOIN inserted i ON m.maintenance_id = i.maintenance_id;
    END;
END;
GO
