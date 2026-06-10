# 01 Business Requirement Analysis — G05

## Purpose

Design a database system for the School of Computer Science to manage the booking, approval, usage, maintenance, and incident reporting of shared physical spaces (auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces), replacing the current manual process handled via email, phone, spreadsheets, and shared calendars.

## Actors

| Actor | Description |
|---|---|
| Student | University user who can submit booking requests for student activities and workspaces. |
| Lecturer | University user who can submit booking requests for lectures, seminars, and workshops. |
| Teaching Assistant | University user who can submit booking requests for tutorials and lab sessions. |
| Facility Staff | Staff member who checks in/out bookings, records space conditions, and manages maintenance records. May also approve or reject booking requests. |
| Department Administrator | Staff member who may submit or manage bookings for departmental events. |
| Facility Manager | Senior staff member who oversees facility operations, configures spaces, and may override approvals. |

## Entities

| Entity | Key Attributes |
|---|---|
| User | user_id (PK), full_name, email, phone_number, role, department, account_status |
| Space | space_code (PK), space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy |
| Facility | facility_id (PK), facility_name, description |
| SpaceFacility | space_code (FK), facility_id (FK), quantity |
| BookingRequest | booking_id (PK), requester_id (FK), space_code (FK), requested_start_time, requested_end_time, purpose, expected_participants, booking_type, status |
| ApprovalDecision | decision_id (PK), booking_id (FK), staff_id (FK), decision, decision_time, decision_note, rejection_reason |
| CheckInOut | check_id (PK), booking_id (FK), actual_start_time, actual_end_time, check_in_by (FK), check_out_by (FK), initial_condition, final_condition, usage_notes |
| MaintenanceRecord | maintenance_id (PK), space_code (FK), reporter_id (FK), assigned_staff_id (FK), problem_description, problem_type, start_time, completion_time, status, result_note |

## Relationships

| Entity Pair | Cardinality | Participation | Notes |
|---|---|---|---|
| User → BookingRequest | 1 : N | Mandatory (User) / Optional (Booking) | One user can submit many booking requests. A booking must have a requester. |
| Space → BookingRequest | 1 : N | Mandatory (Space) / Optional (Booking) | One space can have many booking requests. A booking must reference a space. |
| BookingRequest → ApprovalDecision | 1 : 1 | Optional both | Not all bookings require approval. An approval decision belongs to exactly one booking. |
| User → ApprovalDecision | 1 : N | Mandatory (User) / Optional (Decision) | A staff member can make many approval decisions. |
| BookingRequest → CheckInOut | 1 : 1 | Optional both | Check-in/out only occurs when the requester arrives. |
| Space → MaintenanceRecord | 1 : N | Mandatory (Space) / Optional (Maintenance) | One space can have many maintenance records. |
| User → MaintenanceRecord (reporter) | 1 : N | Mandatory (User) / Optional (Maintenance) | A reporter can report many issues. |
| User → MaintenanceRecord (assignee) | 1 : N | Optional (User) / Optional (Maintenance) | An assigned staff may handle many records. |
| Space → SpaceFacility | 1 : N | Mandatory (Space) / Optional (SpaceFacility) | A space may have zero or many facilities. |
| Facility → SpaceFacility | 1 : N | Mandatory (Facility) / Optional (SpaceFacility) | A facility may be present in zero or many spaces. |

## Business Rules

1. Two approved bookings for the same space must not have overlapping time periods.
2. A space that is under maintenance, temporarily closed, or retired cannot be booked.
3. A booking request status can be: pending, approved, rejected, cancelled, checked-in, completed, or no-show.
4. When a booking is approved or rejected, the system must record the staff member who made the decision, the decision time, and a decision note.
5. If a booking is rejected, the rejection reason must be stored.
6. On check-in, the system records the actual start time, the person who checked in the booking, and the initial condition of the space.
7. On completion (check-out), the system records the actual end time, the final condition of the space, and any usage notes.
8. A space under maintenance cannot be booked until the maintenance is resolved.

## Assumptions

- Each user has exactly one role (student, lecturer, teaching assistant, facility staff, department administrator, or facility manager). Roles are stored as an enumerated value.
- A booking request always references exactly one space (no multi-space bookings).
- Approval is done by facility staff or facility manager only. Lecturers, TAs, and students do not approve bookings.
- The system does not handle recurring bookings; each occurrence is a separate booking request.
- Space status is independent of maintenance status. A space may be "in use" but not under maintenance, or "available" but under maintenance (though rule 2 prevents booking in that case).
- The `booking_type` distinguishes the purpose category (lecture, examination, seminar, workshop, meeting, student activity, administrative event).
- The `problem_type` in MaintenanceRecord is one of: broken projector, air-conditioning failure, damaged furniture, cleaning issue, network problem, or other.

## Open Questions

1. Should the system support recurring/periodic bookings (e.g., a lecture series)?
2. What is the maximum duration for a single booking?
3. Can a booking request be edited after submission? If so, what is the allowed window?
4. Should there be a approval hierarchy (e.g., if the booking exceeds a certain capacity, a manager must approve)?
5. How long are historical records retained before archiving or purging?
6. Should users be able to cancel their own bookings, or only staff?
7. Are notifications (email/SMS) part of the system scope?

## Suggested Table Mapping

| Entity | Suggested Table Name |
|---|---|
| User | `Users` |
| Space | `Spaces` |
| Facility | `Facilities` |
| SpaceFacility | `SpaceFacilities` |
| BookingRequest | `BookingRequests` |
| ApprovalDecision | `ApprovalDecisions` |
| CheckInOut | `CheckInOuts` |
| MaintenanceRecord | `MaintenanceRecords` |

---

*Generated from `req/business-requirement.md` for group G05.*
