SET QUOTED_IDENTIFIER ON;
GO

-- ============================================================
-- CS486 — Campus Space Management System
-- Group: G05 | Task 05: Database Definition DDL
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
    CONSTRAINT PK__departments PRIMARY KEY CLUSTERED (department_id),
    CONSTRAINT UQ__departments__name UNIQUE (name)
);

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
    CONSTRAINT PK__users PRIMARY KEY CLUSTERED (user_id),
    CONSTRAINT UQ__users__email UNIQUE (email),
    CONSTRAINT CK__users__role CHECK (role IN ('student','lecturer','teaching_assistant','facility_staff','department_admin','facility_manager')),
    CONSTRAINT CK__users__account_status CHECK (account_status IN ('active','inactive','suspended')),
    CONSTRAINT FK__users__department_id FOREIGN KEY (department_id) REFERENCES departments(department_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

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
    CONSTRAINT PK__spaces PRIMARY KEY CLUSTERED (space_id),
    CONSTRAINT UQ__spaces__space_code UNIQUE (space_code),
    CONSTRAINT CK__spaces__space_type CHECK (space_type IN ('auditorium','classroom','computer_lab','project_lab','meeting_room','student_workspace')),
    CONSTRAINT CK__spaces__capacity CHECK (capacity > 0),
    CONSTRAINT CK__spaces__current_status CHECK (current_status IN ('available','in_use','under_maintenance','temporarily_closed','retired'))
);

-- ============================================================
-- 4. facilities
-- ============================================================
CREATE TABLE facilities (
    facility_id INT NOT NULL IDENTITY(1,1),
    name NVARCHAR(255) NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK__facilities PRIMARY KEY CLUSTERED (facility_id),
    CONSTRAINT UQ__facilities__name UNIQUE (name)
);

-- ============================================================
-- 5. space_facilities (junction: Spaces ↔ Facilities, R6)
-- ============================================================
CREATE TABLE space_facilities (
    space_id INT NOT NULL,
    facility_id INT NOT NULL,
    quantity INT NULL,
    CONSTRAINT PK__space_facilities PRIMARY KEY CLUSTERED (space_id, facility_id),
    CONSTRAINT CK__space_facilities__quantity CHECK (quantity IS NULL OR quantity > 0),
    CONSTRAINT FK__space_facilities__space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK__space_facilities__facility_id FOREIGN KEY (facility_id) REFERENCES facilities(facility_id) ON DELETE CASCADE ON UPDATE NO ACTION
);

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
    is_deleted BIT NOT NULL DEFAULT 0,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK__bookings PRIMARY KEY CLUSTERED (booking_id),
    CONSTRAINT CK__bookings__requested_end_time CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK__bookings__purpose CHECK (purpose IN ('lecture','examination','seminar','workshop','meeting','student_activity','administrative_event')),
    CONSTRAINT CK__bookings__expected_participants CHECK (expected_participants > 0),
    CONSTRAINT CK__bookings__status CHECK (status IN ('pending','approved','rejected','cancelled','checked_in','completed','no_show')),
    CONSTRAINT CK__bookings__actual_time_order CHECK (actual_end_time IS NULL OR actual_start_time IS NULL OR actual_end_time >= actual_start_time),
    CONSTRAINT FK__bookings__space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK__bookings__requester_id FOREIGN KEY (requester_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK__bookings__approver_id FOREIGN KEY (approver_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK__bookings__checked_in_by FOREIGN KEY (checked_in_by) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ============================================================
-- 7. maintenance
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
    CONSTRAINT PK__maintenance PRIMARY KEY CLUSTERED (maintenance_id),
    CONSTRAINT CK__maintenance__status CHECK (status IN ('open','in_progress','resolved')),
    CONSTRAINT CK__maintenance__completion_time CHECK (completion_time IS NULL OR completion_time >= start_time),
    CONSTRAINT FK__maintenance__space_id FOREIGN KEY (space_id) REFERENCES spaces(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK__maintenance__reporter_id FOREIGN KEY (reporter_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK__maintenance__assigned_staff_id FOREIGN KEY (assigned_staff_id) REFERENCES users(user_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ============================================================
-- Indexes
-- ============================================================

-- users
CREATE NONCLUSTERED INDEX idx_users_department_id ON users(department_id);

-- spaces
CREATE NONCLUSTERED INDEX idx_spaces_current_status ON spaces(current_status);

-- space_facilities
CREATE NONCLUSTERED INDEX idx_space_facilities_facility_id ON space_facilities(facility_id);

-- bookings
CREATE NONCLUSTERED INDEX idx_bookings_space_id ON bookings(space_id);
CREATE NONCLUSTERED INDEX idx_bookings_requester_id ON bookings(requester_id);
CREATE NONCLUSTERED INDEX idx_bookings_status ON bookings(status);
CREATE NONCLUSTERED INDEX idx_bookings_time_range ON bookings(space_id, requested_start_time, requested_end_time);
CREATE NONCLUSTERED INDEX idx_bookings_approver_id ON bookings(approver_id);
CREATE NONCLUSTERED INDEX idx_bookings_checked_in_by ON bookings(checked_in_by);
CREATE NONCLUSTERED INDEX idx_bookings_requested_start ON bookings(requested_start_time);
CREATE UNIQUE NONCLUSTERED INDEX uq_bookings_active_overlap ON bookings(space_id, requested_start_time) WHERE status IN ('approved', 'checked_in', 'completed') AND is_deleted = 0;

-- maintenance
CREATE NONCLUSTERED INDEX idx_maintenance_space_id ON maintenance(space_id);
CREATE NONCLUSTERED INDEX idx_maintenance_reporter_id ON maintenance(reporter_id);
CREATE NONCLUSTERED INDEX idx_maintenance_assigned_staff_id ON maintenance(assigned_staff_id);
CREATE NONCLUSTERED INDEX idx_maintenance_status ON maintenance(status);

-- ============================================================
-- Triggers
-- ============================================================

-- BR1: Prevent overlapping approved/checked_in/completed bookings
GO
CREATE TRIGGER trg_bookings_prevent_overlap ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN bookings b
            ON b.space_id = i.space_id
            AND b.is_deleted = 0
            AND b.status IN ('approved', 'checked_in', 'completed')
            AND b.requested_start_time < i.requested_end_time
            AND b.requested_end_time > i.requested_start_time
            AND b.booking_id != i.booking_id
        WHERE i.is_deleted = 0
          AND i.status IN ('approved', 'checked_in', 'completed')
    )
    BEGIN
        RAISERROR('Overlapping booking detected for the same space and time range.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR2: Unavailable spaces cannot be booked
CREATE TRIGGER trg_bookings_check_space_status ON bookings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN spaces s ON i.space_id = s.space_id
        WHERE i.is_deleted = 0
          AND i.status NOT IN ('cancelled', 'rejected', 'no_show')
          AND s.current_status NOT IN ('available', 'in_use')
    )
    BEGIN
        RAISERROR('Cannot book a space that is not available or in use.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR3: Expected participants ≤ space capacity
CREATE TRIGGER trg_bookings_check_capacity ON bookings
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
        RAISERROR('Expected participants exceeds space capacity.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR4: Overlapping unresolved maintenance blocks booking
CREATE TRIGGER trg_bookings_check_maintenance ON bookings
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
            AND m.status IN ('open', 'in_progress')
            AND m.start_time < i.requested_end_time
            AND (m.completion_time IS NULL OR m.completion_time > i.requested_start_time)
        WHERE i.is_deleted = 0
          AND i.status NOT IN ('cancelled', 'rejected')
    )
    BEGIN
        RAISERROR('Cannot book a space with overlapping unresolved maintenance.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR6: Decision recording — approver_id, decision_time, decision_note required on approval/rejection
CREATE TRIGGER trg_bookings_approval_validation ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status IN ('approved', 'rejected')
          AND d.status = 'pending'
          AND (i.approver_id IS NULL OR i.decision_time IS NULL OR i.decision_note IS NULL)
    )
    BEGIN
        RAISERROR('Approval or rejection requires approver_id, decision_time, and decision_note.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR7: Rejection must include a reason
CREATE TRIGGER trg_bookings_rejection_reason ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.status = 'rejected'
          AND i.rejection_reason IS NULL
    )
    BEGIN
        RAISERROR('Rejection requires a rejection_reason.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR8/BR9: Check-in enforcement — require actual_start_time, checked_in_by, initial_condition
CREATE TRIGGER trg_bookings_checkin_enforcement ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status = 'checked_in'
          AND d.status != 'checked_in'
          AND (i.actual_start_time IS NULL OR i.checked_in_by IS NULL OR i.initial_condition IS NULL)
    )
    BEGIN
        RAISERROR('Check-in requires actual_start_time, checked_in_by, and initial_condition.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- BR8/BR9: Completion enforcement — require actual_end_time, final_condition
CREATE TRIGGER trg_bookings_completion_enforcement ON bookings
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON i.booking_id = d.booking_id
        WHERE i.status = 'completed'
          AND d.status != 'completed'
          AND (i.actual_end_time IS NULL OR i.final_condition IS NULL)
    )
    BEGIN
        RAISERROR('Completion requires actual_end_time and final_condition.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

-- Q3: Auto-update space status to 'available' when maintenance is resolved
CREATE TRIGGER trg_maintenance_completion_space_status ON maintenance
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE s
    SET s.current_status = 'available'
    FROM spaces s
    INNER JOIN inserted i ON s.space_id = i.space_id
    INNER JOIN deleted d ON i.maintenance_id = d.maintenance_id
    WHERE i.status = 'resolved'
      AND d.status != 'resolved'
      AND i.is_deleted = 0
      AND s.current_status = 'under_maintenance';
END;
GO
