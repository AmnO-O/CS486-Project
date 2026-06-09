# Business Requirement Analysis

## Domain Overview

The School of Computer Science needs a database system to manage shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Currently, space booking is handled manually via email, phone, spreadsheets, and shared calendars — a process that has become unsustainable as activity volume grows.

## Stakeholder Roles

| Role | Responsibility |
|---|---|
| Student | Books spaces for student activities; uses facilities |
| Lecturer | Books spaces for teaching and academic events |
| Teaching Assistant | Books spaces for tutorials/sessions |
| Facility Staff | Manages bookings, check-in/check-out, maintenance |
| Facility Manager | Oversees space utilization and policies |
| Department Administrator | Administrative oversight |

## Core Entities (Identified from Requirements)

1. **User** — Anyone with a university account who interacts with the system
2. **Space** — A bookable physical room/location
3. **Facility** — Equipment or fixture available in a space (e.g., projector, whiteboard)
4. **Booking** — A request or confirmed reservation for a space
5. **Approval Decision** — Record of approve/reject action on a booking
6. **Check-in / Check-out Record** — Actual usage session data
7. **Maintenance Record** — Problem report and resolution tracking

## Key Business Rules

- A booking must not overlap another approved booking in the same space.
- A space that is under maintenance, closed, or retired cannot be booked.
- A booking request may require approval from facility staff or manager.
- Rejected bookings must store a rejection reason.
- Check-in records the actual start time and initial space condition.
- Check-out (completion) records the actual end time and final space condition.
- Maintenance records track reporter, assigned staff, problem, status, and resolution.
- Historical records of bookings and maintenance must be preserved.

## Booking Lifecycle

```
Pending → Approved → Checked In → Completed
Pending → Rejected (with reason)
Pending → Cancelled
Approved → No-Show
```

## Assumptions

- Each user has exactly one university account and one role at a time.
- A booking is always associated with exactly one space and one requester.
- Facilities are defined per space (not shared across spaces implicitly).
- Approval is performed by facility staff or manager — not by the system automatically.
- The system only manages shared/campus spaces, not personal offices or off-campus venues.
- Maintenance completion requires a result note.
- A "no-show" status occurs when a booking is checked in past the start time without action.

## Open Questions

- Can a single booking request involve multiple spaces (e.g., two adjacent rooms for a large event)?
- Can a booking be modified after approval (reschedule, change space)?
- Is there a maximum booking duration or advance booking window?
- Can multiple approvers be required for a single booking?
- How is "no-show" determined — is it automatic after a grace period, or manually set?
- Are there different approval workflows based on space type or requester role?
- Should the system support recurring bookings (e.g., weekly lectures)?
- What is the relationship between a space and its facilities — are facilities tracked as inventory that can be moved?

## Requirement-to-Entity Traceability

| Requirement | Entity(s) |
|---|---|
| Users with university accounts | User |
| Store user info (ID, name, email, phone, role, dept, status) | User |
| Store bookable spaces (code, name, type, building, floor, room, capacity, status, policy) | Space |
| Each space may have several facilities | Facility, Space-Facility |
| Users submit booking requests | Booking |
| Booking has status lifecycle | Booking |
| Prevent conflicting bookings | Booking (constraint) |
| Booking requires approval | Approval Decision |
| Check-in records actual start & initial condition | Booking (checkin fields) |
| Check-out/completion records end time & final condition | Booking (checkout fields) |
| Maintenance management | Maintenance Record |
| Keep historical records | All entities (audit/history) |
