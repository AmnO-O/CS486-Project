# Business Requirement Analysis — Campus Space Management System

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Date:** 2026-06-12

---

## 1. Project Overview and Purpose

The School of Computer Science manages several shared physical spaces (auditoriums, classrooms, computer labs, project labs, meeting rooms, student workspaces) used for teaching, examinations, seminars, workshops, student projects, research activities, and academic events.

Currently, booking requests are handled manually — lecturers, TAs, students, and staff contact the school office or facility staff by email, phone, or in person. Facility staff check spreadsheets or shared calendars to determine availability, eligibility, equipment needs, and maintenance status. As activity volume grows, this manual process has become untenable.

The **Campus Space Management System** aims to replace the manual process with a database-backed system that manages:

- Space booking and scheduling
- Approval workflows
- Usage session tracking (check-in / check-out)
- Maintenance activities
- Incident reporting
- Facility utilization reporting

**Goal:** A normalized relational database design (minimum 3NF) targeting Microsoft SQL Server (T-SQL) that fully captures the business rules, supports all operational workflows, and preserves historical records for reporting.

---

## 2. Actors / User Roles

Six user roles are defined in the system:

| Role | Description | Typical actions |
|---|---|---|
| **Student** | Enrolled university student | Submit/view personal booking requests |
| **Lecturer** | Academic teaching staff | Submit bookings for lectures, exams, seminars, workshops |
| **Teaching Assistant** | Graduate/postgraduate teaching support | Submit bookings on behalf of courses |
| **Facility Staff** | Operational staff managing spaces | Approve/reject bookings, check-in/check-out sessions, record maintenance, record incidents |
| **Department Administrator** | Administrative staff at department level | Department-level oversight, reporting, viewing booking history |
| **Facility Manager** | Senior staff managing spaces and staff | Manage spaces, manage facility staff assignments, set global policies, manage space status |

Each user has a university account with: User ID, Full Name, Email, Phone Number, Role, Department, Account Status.

---

## 3. Core Domain Objects and Managed Spaces

### 3.1 Spaces

The system manages bookable spaces across campus buildings. Each space has:

- **Space Code** — unique business identifier (e.g., "A101")
- **Space Name** — display name
- **Space Type** — one of: `auditorium`, `classroom`, `computer_lab`, `project_lab`, `meeting_room`, `student_workspace`
- **Building** — building identifier
- **Floor** — floor number
- **Room Number** — room identifier
- **Capacity** — maximum number of occupants
- **Current Status** — one of: `available`, `in_use`, `under_maintenance`, `temporarily_closed`, `retired`
- **Usage Policy** — rules/restrictions for using the space

### 3.2 Facilities / Equipment

Each space may contain multiple facilities (equipment items). Examples:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming Equipment
- Air Conditioner

The system stores the list of facilities available in each space. The relationship between spaces and facilities is many-to-many: a space can have multiple facilities, and a facility type can exist in multiple spaces.

### 3.3 Departments

Users belong to departments (organizational units). Department information is used for role-based oversight and reporting.

### 3.4 Users

University accounts with the attributes listed in Section 2. Users are linked to a department and assigned one role.

---

## 4. Booking Request Lifecycle

### 4.1 Submission

A user submits a booking request by providing:

- Selected Space
- Requested Start Time
- Requested End Time
- Purpose of Use (one of: `lecture`, `examination`, `seminar`, `workshop`, `meeting`, `student_activity`, `administrative_event`)
- Expected Number of Participants

### 4.2 Booking Status Lifecycle

A booking progresses through the following statuses:

```
pending → approved     → checked_in → completed
       → rejected         → no_show
       → cancelled
```

| Status | Description |
|---|---|
| **Pending** | Initial state after submission, awaiting approval |
| **Approved** | Approved by facility staff/manager |
| **Rejected** | Rejected by facility staff/manager |
| **Cancelled** | Cancelled by requester or system |
| **Checked In** | Requester arrived; actual start time recorded |
| **Completed** | Session ended; actual end time recorded |
| **No-Show** | Requester did not check in (no arrival) |

### 4.3 Check-In / Session Completion

When the requester arrives, facility staff check in the booking and record:

- Actual Start Time
- Checked-In By (staff member)
- Initial Condition of Space

When the session ends, facility staff complete the booking and record:

- Actual End Time
- Final Condition of Space
- Usage Notes

---

## 5. Approval Workflow

A booking request (in `pending` status) may require approval from a Facility Staff member or Facility Manager.

### 5.1 Decision Recording

When a booking is approved or rejected, the system records:

- Approver/Rejector (staff member)
- Decision Time
- Decision Note

If rejected, the system also stores a **Rejection Reason**.

### 5.2 Approval Rules

- Only users with Facility Staff or Facility Manager roles may approve/reject bookings.
- Approval is required before a booking can transition to `checked_in` status.
- Rejected bookings may not be checked in.

---

## 6. Maintenance and Incident Handling

### 6.1 Maintenance Lifecycle

Spaces may be taken offline for maintenance. The lifecycle is:

```
open → in_progress → resolved
```

### 6.2 Maintenance Record

Each maintenance record stores:

- Related Space (FK)
- Reporter (user who reported the issue)
- Assigned Staff Member (facility staff responsible)
- Problem Description
- Start Time (when issue was reported)
- Completion Time (when issue was resolved)
- Status (`open`, `in_progress`, `resolved`)
- Result Note (resolution summary)

### 6.3 Maintenance Issues

Possible maintenance issues include:

- Broken Projector
- Air Conditioning Failure
- Damaged Furniture
- Cleaning Issues
- Network Problems

### 6.4 Maintenance Constraint

A space with status `under_maintenance` cannot have approved bookings during the maintenance period.

---

## 7. Key Business Rules and Constraints

### 7.1 Booking Constraints

1. **No overlapping bookings** — The same space cannot have two approved bookings with overlapping time periods. This applies to all statuses that consume the space (`approved`, `checked_in`, `completed` — i.e., any confirmed session).

2. **Unavailable spaces cannot be booked** — A space with status `under_maintenance`, `temporarily_closed`, or `retired` cannot be booked.

3. **Capacity limit** — Expected participants must not exceed space capacity (application-enforced or schema-validated).

### 7.2 Maintenance Constraints

4. **Maintenance blocks booking** — When a space is under maintenance, it cannot be booked for any overlapping period.

5. **Assigned staff tracking** — Each maintenance record must track who is assigned to resolve it.

### 7.3 Approval Constraints

6. **Decision recording** — All approval/rejection decisions must record: approver identity, decision timestamp, and notes.

7. **Rejection requires reason** — When a booking is rejected, a rejection reason must be stored.

### 7.4 Check-In / Completion Constraints

8. **Actual time recording** — Check-in and completion must record actual start and end times.

9. **Space condition tracking** — Both initial and final space conditions must be recorded during the check-in/check-out process.

### 7.5 Data Integrity Constraints

10. **Unique identification** — Each user has a unique email; each space has a unique space code.

11. **Soft deletes** — Bookings and maintenance records use soft deletion (`is_deleted` flag) to preserve historical records for audit and reporting.

12. **Audit trail** — All core tables include `created_at` and `updated_at` timestamps.

### 7.6 Reporting Requirements

13. The system must preserve historical records of bookings and maintenance activities.

14. Staff should be able to view:
    - Booking history (past bookings for a space or user)
    - Upcoming bookings
    - Spaces currently under maintenance
    - No-show bookings

---

## 8. Assumptions / Unresolved Ambiguities

### Assumptions

| # | Assumption | Rationale |
|---|---|---|
| A1 | Users have unique email addresses — email serves as the natural business key. | Requirement specifies email is stored; email naturally identifies users uniquely. |
| A2 | Departments are static entities seeded into the system, not created dynamically by users. | Department structure is stable within a university context. |
| A3 | Booking conflict detection operates on `(space_id, time_range)` — two bookings overlap if `requested_start_time < existing_end_time AND requested_end_time > existing_start_time`. | Standard interval overlap logic; requirement states "no overlapping approved bookings." |
| A4 | Soft deletion (`is_deleted`) is used for bookings and maintenance records to meet the historical-records requirement. | Requirement states "system must keep historical records of bookings and maintenance." |
| A5 | The `no_show` status is set by facility staff after the requested start time passes without check-in. | The requirement lists `no_show` as a booking status but does not specify how it is triggered. |
| A6 | The `in_use` space status is set automatically when a booking is checked in and reverted to `available` when completed. | Logical consequence of space lifecycle management; not explicitly stated in requirements. |
| A7 | Phone number is optional for users. | No explicit mention of phone being mandatory. |

### Unresolved Ambiguities

| # | Question | Impact |
|---|---|---|
| Q1 | **Rejection reason storage** — Should the rejection reason be a separate attribute or part of the decision note? | Affects column design in the booking table. |
| Q2 | **Usage policy storage** — Is usage policy a free-text field, a reference to a document, or a set of coded rules? | Affects data type and complexity of the spaces table. |
| Q3 | **Maintenance-to-booking relationship** — Can a space be booked for a time after a maintenance record is resolved but before the space status is manually updated to `available`? | Affects workflow design and whether status changes are automatic or manual. |
| Q4 | **No-show detection** — Is no-show automatic (system detects no check-in by end time) or manual (staff marks it)? | Affects whether a scheduled job or application logic is required. |
| Q5 | **Building / floor attributes** — Should building and floor be separate reference tables or free-text/varchar fields on spaces? | Affects normalization level and query capability for building-based reports. |

---

## Entity Summary

The following entities have been identified from the requirements:

| Entity | Description | Key Relationships |
|---|---|---|
| **Users** | University accounts with role/department | 1:N with Bookings (requester, approver); 1:N with Maintenance (reporter, assignee) |
| **Departments** | Organizational units | 1:N with Users |
| **Spaces** | Bookable rooms/facilities | 1:N with Bookings; 1:N with Maintenance; M:N with Facilities |
| **Facilities** | Equipment types | M:N with Spaces (via junction) |
| **Space_Facilities** | Junction: space-equipment assignment | N:1 with Spaces; N:1 with Facilities |
| **Bookings** | Space usage requests with workflow | N:1 with Spaces; N:1 with Users (requester, approver) |
| **Maintenance** | Problem reports and resolution tracking | N:1 with Spaces; N:1 with Users (reporter, assignee) |

---

## Next Steps

This analysis feeds into **Task 2 — Conceptual ERD Design**, where entities, attributes, relationships, and cardinalities will be modeled visually.

---

*Generated for CS486 Group G05 — Campus Space Management System*
