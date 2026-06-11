# Product Context — CS486 Space Booking System

## What is this project?

A relational database design project for CS486 (Database Systems course).
The deliverable is a complete database design document, not a working application.

## The problem being solved

The School of Computer Science currently manages shared spaces (classrooms,
labs, auditoriums, meeting rooms) manually via email, phone, and spreadsheets.
This causes overlapping bookings, unavailable spaces being booked, and no
reliable usage history. The School wants a database system to fix this.

## Who uses the system?

Six roles with different permissions:
- **Student** — submit booking requests, view own bookings
- **Lecturer / Teaching Assistant** — submit bookings for classes and seminars
- **Facility Staff** — approve/reject bookings, check in/out, report maintenance
- **Department Administrator** — oversight of department bookings
- **Facility Manager** — full system access, manage spaces and staff

## What the system manages

1. **Users** — university accounts with role and department
2. **Spaces** — bookable rooms with type, capacity, status, and equipment
3. **Bookings** — requests with approval workflow, check-in/out, and history
4. **Maintenance** — records for space problems that block booking
5. **Facilities** — equipment list per space (projector, AC, microphone, etc.)

## Project constraints

- **Group:** G05
- **Output naming:** `outputs/0X-<step-name>-G05.md` or `.sql`
- **Normalization:** Database must be at least 3NF
- **Requirements source:** All business rules from `req/business-requirement.md` must be reflected in schema
- **Target RDBMS:** Microsoft SQL Server (T-SQL)

## Key requirements reference

See `req/` folder for official project documents:
- `CS486_Project.pdf` — Full project specification
- `CS486_Project.txt` — Text version
- `business-requirement.md` — Business rules and constraints
