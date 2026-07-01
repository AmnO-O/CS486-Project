# Conceptual Entity-Relationship Diagram (ERD) — Campus Space Management System

**Group:** G05
**Course:** CS486 — Introduction to Database System
**Date:** 2026-06-18

---

## 1. Description and Core Entities

The Campus Space Management System database centers on **Users**, **Spaces**, and **Bookings**, supported by organizational units (**Departments**) and equipment profiles (**Facilities**). The booking lifecycle is split across three dedicated tables: **Bookings** handles the initial request, **Booking_Approvals** captures the approval/rejection decision, and **Booking_Sessions** tracks check-in and completion. Maintenance requests and assignments are managed through the **Maintenance** entity, while the **Space_Facilities** junction resolves the many-to-many relationship between bookable rooms and their equipment.

---

## 2. Mermaid.js ERD

### Diagram 1 — Overview (nodes only)

```mermaid
erDiagram
    Departments
    Users
    Spaces
    Facilities
    Space_Facilities
    Bookings
    Booking_Approvals
    Booking_Sessions
    Maintenance

    Departments ||--o{ Users : "belongs_to"
    Users ||--o{ Bookings : "requests"
    Users ||--o{ Booking_Approvals : "approves"
    Users ||--o{ Booking_Sessions : "checks_in"
    Spaces ||--o{ Bookings : "booked_for"
    Spaces ||--o{ Space_Facilities : "contains"
    Facilities ||--o{ Space_Facilities : "assigned_to"
    Spaces ||--o{ Maintenance : "requires_maintenance"
    Users ||--o{ Maintenance : "reports"
    Users |o--o{ Maintenance : "assigned_to"
    Bookings ||--o| Booking_Approvals : "has_decision"
    Bookings ||--o| Booking_Sessions : "has_session"
```

### Diagram 2 — Full Detail

```mermaid
erDiagram
    Departments {
        int department_id PK
        string name
    }

    Users {
        int user_id PK
        string email
        string full_name
        string phone_number
        string role
        int department_id
        string account_status
    }

    Spaces {
        int space_id PK
        string space_code
        string space_name
        string space_type
        string building
        string floor
        string room_number
        int capacity
        string current_status
        string usage_policy
    }

    Facilities {
        int facility_id PK
        string name
    }

    Space_Facilities {
        int space_id PK
        int facility_id PK
        int quantity
    }

    Bookings {
        int booking_id PK
        int space_id
        int requester_id
        datetime requested_start_time
        datetime requested_end_time
        string purpose
        int expected_participants
        string status
    }

    Booking_Approvals {
        int approval_id PK
        int booking_id
        int approver_id
        datetime decision_time
        string decision
        string rejection_reason
        string decision_note
    }

    Booking_Sessions {
        int session_id PK
        int booking_id
        datetime actual_start_time
        int checked_in_by
        string initial_condition
        datetime actual_end_time
        string final_condition
        string usage_notes
    }

    Maintenance {
        int maintenance_id PK
        int space_id
        int reporter_id
        int assigned_staff_id
        string problem_description
        datetime start_time
        datetime completion_time
        string status
        string result_note
    }

    Departments ||--o{ Users : "belongs_to"
    Users ||--o{ Bookings : "requests"
    Users ||--o{ Booking_Approvals : "approves"
    Users ||--o{ Booking_Sessions : "checks_in"
    Spaces ||--o{ Bookings : "booked_for"
    Spaces ||--o{ Space_Facilities : "contains"
    Facilities ||--o{ Space_Facilities : "assigned_to"
    Spaces ||--o{ Maintenance : "requires_maintenance"
    Users ||--o{ Maintenance : "reports"
    Users |o--o{ Maintenance : "assigned_to"
    Bookings ||--o| Booking_Approvals : "has_decision"
    Bookings ||--o| Booking_Sessions : "has_session"
```

---

## 3. Relationship Participation Summary

| # | Relationship | Cardinality | Mermaid Notation | Participation Explanation |
|---|---|---|---|---|
| R1 | Departments → Users | 1:N | `Departments \|\|--o{ Users` | Every User must belong to exactly 1 Department (total on Users — `department_id` NOT NULL); a Department may have zero or many Users. |
| R2 | Users → Bookings (requester) | 1:N | `Users \|\|--o{ Bookings` | Every Booking must have exactly 1 requester (total on Bookings — `requester_id` NOT NULL); a User may have zero or many Bookings. |
| R3 | Users → Booking_Approvals (approver) | 1:N | `Users \|\|--o{ Booking_Approvals` | Every Booking_Approval must have exactly 1 approver (total on Booking_Approvals — `approver_id` NOT NULL); a User may act as approver on zero or many decisions. |
| R4 | Users → Booking_Sessions (checks_in) | 1:N | `Users \|\|--o{ Booking_Sessions` | Every Booking_Session must have exactly 1 staff who performed check-in (total on Booking_Sessions — `checked_in_by` NOT NULL); a User may check in zero or many sessions. |
| R5 | Spaces → Bookings | 1:N | `Spaces \|\|--o{ Bookings` | Every Booking must reference exactly 1 Space (total on Bookings — `space_id` NOT NULL); a Space may have zero or many Bookings. |
| R6 | Spaces ↔ Facilities | M:N | `Spaces \|\|--o{ Space_Facilities` / `Facilities \|\|--o{ Space_Facilities` | A Space may contain zero or many Facility types; a Facility type may be assigned to zero or many Spaces. The junction table Space_Facilities resolves the M:N with a composite PK of (space_id, facility_id). |
| R7 | Spaces → Maintenance | 1:N | `Spaces \|\|--o{ Maintenance` | Every Maintenance record must reference exactly 1 Space (total on Maintenance — `space_id` NOT NULL); a Space may have zero or many Maintenance records. |
| R8 | Users → Maintenance (reporter) | 1:N | `Users \|\|--o{ Maintenance` | Every Maintenance record must have exactly 1 reporter (total on Maintenance — `reporter_id` NOT NULL); a User may report zero or many issues. |
| R9 | Users → Maintenance (assigned staff) | 1:N (partial) | `Users \|o--o{ Maintenance` | A Maintenance record may have zero or one assigned staff member (partial — `assigned_staff_id` is nullable); a User may be assigned to zero or many Maintenance records. |
| R10 | Bookings → Booking_Approvals | 1:0..1 | `Bookings \|\|--o\| Booking_Approvals` | A Booking may have zero or one approval decision (partial on Booking side — not all bookings reach a decision); every Booking_Approval must belong to exactly 1 Booking (total). |
| R11 | Bookings → Booking_Sessions | 1:0..1 | `Bookings \|\|--o\| Booking_Sessions` | A Booking may have zero or one check-in session (partial on Booking side — only checked-in bookings have a session); every Booking_Session must belong to exactly 1 Booking (total). |

---

## 4. Logical Constraints

These constraints are enforced at the application or trigger level and are not expressible in Mermaid ERD syntax:

1. **Approver role constraint** — `Booking_Approvals.approver_id` must reference a User with `role IN ('facility_staff', 'facility_manager')`. Students, lecturers, TAs, and department admins may not approve or reject bookings.

2. **Check-in staff role constraint** — `Booking_Sessions.checked_in_by` must reference a User with `role IN ('facility_staff', 'facility_manager')`. Only authorized facility personnel may perform check-in.

3. **Assigned maintenance staff constraint** — `Maintenance.assigned_staff_id` must reference a User with `role = 'facility_staff'`. Only facility staff may be assigned to resolve maintenance issues.

4. **Booking non-overlap constraint** — No two Bookings for the same Space may have overlapping time ranges when both are in status `approved`, `checked_in`, or `completed`. Overlap condition: `requested_start_time < existing_end_time AND requested_end_time > existing_start_time`.

5. **Space availability constraint** — A Space with `current_status IN ('under_maintenance', 'temporarily_closed', 'retired')` may not receive new approved Bookings.

6. **Soft deletion** — Bookings and Maintenance records use `is_deleted = 1` for logical deletion, preserving historical records for audit and reporting.

---

## Pre-Submission Validation Checklist

- [x] All 9 entities from entity-registry are present (Departments, Users, Spaces, Facilities, Space_Facilities, Bookings, Booking_Approvals, Booking_Sessions, Maintenance)
- [x] All business attributes from entity-registry are present for each entity (audit columns and soft-delete flags omitted — physical-layer concern per Rule E)
- [x] All 11 relationships from the Relationship Registry are present (R1–R11)
- [x] Cardinality is correct: 1:N for R1–R5, R7–R9; M:N resolved via junction for R6; 1:0..1 for R10–R11
- [x] Participation constraints (`||` mandatory, `|o` optional) are explicitly stated and justified per Section 3
- [x] Junction table Space_Facilities is rendered as a standalone entity with 1:N relationships to Spaces and Facilities
- [x] Foreign keys are represented by relationship lines — not marked in entity attribute blocks (only `PK` markers)
- [x] Primary keys are marked with `PK`
- [x] No duplicate entity definitions
- [x] Role-based constraints documented in Section 4 (Logical Constraints)
- [x] Entity count matches entity-registry (9 entities)
- [x] Key design decisions documented in `docs/design-decisions.md` (incident, building/floor, rejection reason, SRP split)

---

*Generated for CS486 Group G05 — Campus Space Management System*
