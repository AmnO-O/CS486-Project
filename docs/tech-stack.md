# Tech Stack & Conventions — CS486

## Database target

- **RDBMS:** Microsoft SQL Server (MSSQL)
- **SQL dialect:** T-SQL (Transact-SQL)
- **Compatibility level:** SQL Server 2019 or later

## Naming conventions

| Object | Convention | Example |
|---|---|---|
| Table | snake_case, plural | `booking_requests`, `space_facilities` |
| Column | snake_case | `actual_start_time`, `decision_note` |
| Primary key | `<table_singular>_id` | `booking_id`, `space_id`, `user_id` |
| Foreign key | same name as referenced PK | `space_id`, `user_id` |
| Junction table | `<tableA>_<tableB>` (alpha order) | `space_facilities` |
| Enum/status | lowercase with underscores | `no_show`, `checked_in` |
| Index | `idx_<table>_<column>` | `idx_bookings_space_id` |

## Enum values (must match requirement exactly)

**User roles:** `student`, `lecturer`, `teaching_assistant`, `facility_staff`,
`department_admin`, `facility_manager`

**Space status:** `available`, `in_use`, `under_maintenance`,
`temporarily_closed`, `retired`

**Space types:** `auditorium`, `classroom`, `computer_lab`, `project_lab`,
`meeting_room`, `student_workspace`

**Booking status:** `pending`, `approved`, `rejected`, `cancelled`,
`checked_in`, `completed`, `no_show`

**Booking purpose:** `lecture`, `examination`, `seminar`, `workshop`,
`meeting`, `student_activity`, `administrative_event`

**Maintenance status:** (not explicitly listed in requirement — use)
`open`, `in_progress`, `resolved`

## Design rules

- All tables must have a surrogate primary key using `INT IDENTITY(1,1)` or `UNIQUEIDENTIFIER` (use `INT IDENTITY` unless globally unique ID is required)
- Use `DATETIME2` for all timestamp columns (not `DATETIME` — lower precision and range)
- `created_at` and `updated_at` on every table; use `DEFAULT GETDATE()` for `created_at`
- No many-to-many without a junction table
- Soft delete preferred — add `is_deleted BIT NOT NULL DEFAULT 0` on bookings and maintenance records
- MSSQL has no native `ENUM` type — use `VARCHAR(50)` with a `CHECK` constraint for status columns
- Do NOT add columns or tables not derived from the requirement without documenting them as assumptions

## MSSQL-specific syntax reminders

| Need | MSSQL syntax |
|---|---|
| Auto-increment PK | `INT IDENTITY(1,1) PRIMARY KEY` |
| Current timestamp default | `DEFAULT GETDATE()` |
| Boolean | `BIT NOT NULL DEFAULT 0` |
| Enum substitute | `VARCHAR(50) CHECK (col IN ('a','b','c'))` |
| String type | `NVARCHAR(n)` for Unicode, `VARCHAR(n)` for ASCII |
| Limit rows | `SELECT TOP n` or `OFFSET ... FETCH NEXT` |
| String concat | `+` operator or `CONCAT()` |
| Schema prefix | `dbo.<table_name>` (default schema) |
