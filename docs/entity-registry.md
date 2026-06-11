# Entity Registry — CS486 Space Booking System

This document maintains a consolidated view of all entities and their attributes discovered during Tasks 1–3.

## How to use this document

- **During Task 1 (Business Analysis):** Populate this registry with entities extracted from requirements
- **During Task 2 (ERD Design):** Refine entity definitions and confirm relationships
- **During Task 3 (Logical Design):** Lock column names, data types, and constraints
- **After Task 3:** This becomes the reference for schema design (Task 4 validation uses this)

---

## Entity discovery status

| Entity | Task discovered | Status | Last updated |
|---|---|---|---|
| (To be filled during Task 1) | — | — | — |

---

## Core entities (expected from requirement)

_(This is a template. Fill in from `outputs/01-business-analysis-G05.md` when Task 1 is complete.)_

### Users

**Description:** University accounts with assigned role and department

**Candidate keys:**
- `user_id` (surrogate)
- `email` (assuming unique per user)

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| user_id | INT | NO | Surrogate PK |
| email | NVARCHAR(255) | NO | Unique |
| name | NVARCHAR(255) | NO | Full name |
| role | VARCHAR(50) | NO | Enum: student, lecturer, teaching_assistant, facility_staff, department_admin, facility_manager |
| department_id | INT | NO | FK to departments |
| is_active | BIT | NO | Account status |
| created_at | DATETIME2 | NO | Default GETDATE() |
| updated_at | DATETIME2 | NO | Default GETDATE() |

---

### Spaces

**Description:** Bookable rooms/facilities

**Candidate keys:**
- `space_id` (surrogate)
- `room_code` (business key, e.g., "A101")

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| space_id | INT | NO | Surrogate PK |
| room_code | NVARCHAR(50) | NO | Unique business identifier |
| name | NVARCHAR(255) | NO | Display name |
| type | VARCHAR(50) | NO | Enum: auditorium, classroom, computer_lab, project_lab, meeting_room, student_workspace |
| capacity | INT | NO | Max occupants |
| status | VARCHAR(50) | NO | Enum: available, in_use, under_maintenance, temporarily_closed, retired |
| created_at | DATETIME2 | NO | Default GETDATE() |
| updated_at | DATETIME2 | NO | Default GETDATE() |

---

### Bookings

**Description:** Requests to use a space with approval workflow

**Candidate keys:**
- `booking_id` (surrogate)

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| booking_id | INT | NO | Surrogate PK |
| space_id | INT | NO | FK to spaces |
| requester_id | INT | NO | FK to users (person making request) |
| approver_id | INT | YES | FK to users (person approving) |
| requested_start_time | DATETIME2 | NO | When requestor wants to use space |
| requested_end_time | DATETIME2 | NO |  |
| actual_start_time | DATETIME2 | YES | When space was actually occupied |
| actual_end_time | DATETIME2 | YES | When space was actually vacated |
| status | VARCHAR(50) | NO | Enum: pending, approved, rejected, cancelled, checked_in, completed, no_show |
| purpose | VARCHAR(50) | NO | Enum: lecture, examination, seminar, workshop, meeting, student_activity, administrative_event |
| notes | NVARCHAR(MAX) | YES | Additional context |
| is_deleted | BIT | NO | Soft delete flag |
| created_at | DATETIME2 | NO | Default GETDATE() |
| updated_at | DATETIME2 | NO | Default GETDATE() |

---

### Maintenance

**Description:** Records for space problems that block or impact booking

**Candidate keys:**
- `maintenance_id` (surrogate)

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| maintenance_id | INT | NO | Surrogate PK |
| space_id | INT | NO | FK to spaces |
| reported_by_id | INT | NO | FK to users (facility staff) |
| status | VARCHAR(50) | NO | Enum: open, in_progress, resolved |
| description | NVARCHAR(MAX) | NO | What's broken |
| resolved_at | DATETIME2 | YES | When fixed |
| is_deleted | BIT | NO | Soft delete flag |
| created_at | DATETIME2 | NO | Default GETDATE() |
| updated_at | DATETIME2 | NO | Default GETDATE() |

---

### Facilities / Equipment

**Description:** Equipment and amenities available in a space

**Candidate keys:**
- `facility_id` (surrogate)

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| facility_id | INT | NO | Surrogate PK |
| name | NVARCHAR(255) | NO | Equipment type (e.g., "projector", "whiteboard") |
| created_at | DATETIME2 | NO | Default GETDATE() |

---

### Space_Facilities (Junction table)

**Description:** Many-to-many: which equipment is in which space

**Candidate keys:**
- `(space_id, facility_id)` (composite)

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| space_id | INT | NO | FK to spaces |
| facility_id | INT | NO | FK to facilities |

---

### Departments

**Description:** Organizational unit (for grouping users and their bookings)

**Candidate keys:**
- `department_id` (surrogate)
- `code` (business key)

**Attributes:**

| Attribute | Type | Nullable | Notes |
|---|---|---|---|
| department_id | INT | NO | Surrogate PK |
| code | NVARCHAR(50) | NO | Unique code (e.g., "CS", "MATH") |
| name | NVARCHAR(255) | NO | Full name |
| created_at | DATETIME2 | NO | Default GETDATE() |

---

## Revision log

| Date | Change | Reason |
|---|---|---|
| — | Created registry template | Structural planning |

---

_This registry is locked once Task 3 (Logical Design) is marked ✅ in Progress.md._
