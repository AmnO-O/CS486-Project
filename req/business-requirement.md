# CS486 – Introduction to Database System


---

# 1. Business Requirement Description

The School of Computer Science manages several shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events.

These spaces include:

* Auditoriums
* Classrooms
* Computer laboratories
* Project laboratories
* Meeting rooms
* Student workspaces

Currently, requests to use these spaces are handled manually. Lecturers, teaching assistants, students, and staff usually contact the school office or facility staff by email, phone, or in person.

Facility staff then check spreadsheets or shared calendars to determine:

* Whether a room is available
* Whether the requester is allowed to use it
* Whether special equipment is needed
* Whether the room is under maintenance

As the number of classes, student projects, workshops, seminars, and academic events increases, the manual process has become difficult to manage.

The School wants to build a database system to manage:

* Space booking
* Approval workflows
* Usage sessions
* Maintenance activities
* Incident reporting
* Facility utilization

---

## Facility Manager Requirement Summary

The School wants to develop a system to manage the booking and usage of shared campus spaces such as classrooms, computer laboratories, meeting rooms, and auditoriums.

### User Management

Each user must have a university account.

The system stores:

* User ID
* Full Name
* Email
* Phone Number
* Role
* Department
* Account Status

Possible user roles:

* Student
* Lecturer
* Teaching Assistant
* Facility Staff
* Department Administrator
* Facility Manager

---

### Space Management

The School manages many bookable spaces.

For each space, the system stores:

* Space Code (unique)
* Space Name
* Space Type
* Building
* Floor
* Room Number
* Capacity
* Current Status
* Usage Policy

Possible space statuses:

* Available
* In Use
* Under Maintenance
* Temporarily Closed
* Retired

---

### Facility Management

Each space may contain multiple facilities, such as:

* Projector
* Whiteboard
* Microphone
* Computer
* Livestreaming Equipment
* Air Conditioner

The system stores the list of facilities available in each space.

---

### Booking Requests

Users can submit booking requests by providing:

* Selected Space
* Requested Start Time
* Requested End Time
* Purpose of Use
* Expected Number of Participants

Possible booking purposes:

* Lecture
* Examination
* Seminar
* Workshop
* Meeting
* Student Activity
* Administrative Event

Each booking request has a status:

* Pending
* Approved
* Rejected
* Cancelled
* Checked In
* Completed
* No-Show

#### Booking Constraints

The system must prevent conflicting bookings.

Business rules:

* The same space cannot have two approved bookings with overlapping time periods.
* A space that is under maintenance, closed, or retired cannot be booked.

---

### Booking Approval

A booking request may require approval from a facility staff member or facility manager.

When a booking is approved or rejected, the system records:

* Staff Member
* Decision Time
* Decision Note

If rejected, the system also stores:

* Rejection Reason

---

### Check-In and Session Completion

When the requester arrives, facility staff can check in the booking.

The system records:

* Actual Start Time
* Checked-In By
* Initial Condition of Space

When the session ends, facility staff can complete the booking.

The system records:

* Actual End Time
* Final Condition of Space
* Usage Notes

---

### Maintenance Management

The system supports maintenance management.

Possible maintenance issues:

* Broken Projector
* Air Conditioning Failure
* Damaged Furniture
* Cleaning Issues
* Network Problems

Each maintenance record stores:

* Related Space
* Reporter
* Assigned Staff Member
* Problem Description
* Start Time
* Completion Time
* Status
* Result Note

#### Maintenance Constraint

A space under maintenance cannot be booked.

---

### Historical Records and Reporting

The system must keep historical records of:

* Bookings
* Maintenance Activities

Staff should be able to view:

* Booking History
* Upcoming Bookings
* Spaces Under Maintenance
* No-Show Bookings

---

### Main Business Goal

The system aims to:

* Manage shared campus spaces fairly
* Avoid overlapping bookings
* Prevent the use of unavailable spaces
* Preserve usage history

---

# 2. Phase 1

## Task 1 — Business Requirement Analysis

Analyze the requirements to identify:

* Business Purpose
* Actors
* Entities
* Attributes
* Relationships
* Cardinalities
* Business Rules

---

## Task 2 — Conceptual Database Design

Design an ERD showing:

* Main Entities
* Attributes
* Relationships
* Cardinalities
* Participation Constraints

---

## Task 3 — Logical Database Design

Convert the ERD into a relational schema containing:

* Relations
* Attributes
* Primary Keys
* Foreign Keys
* Candidate Keys
* Key Constraints

---

## Task 4 — Database Design Validation

Evaluate whether the relational schema:

* Correctly represents the ERD
* Satisfies business rules
* Uses appropriate keys
* Uses appropriate relationships
* Uses appropriate constraints

---

## Task 5 — Database Implementation

Implement the database using SQL DDL.

Include:

* Tables
* Primary Keys
* Foreign Keys
* Constraints
* CHECK Constraints
* Default Values

---

## Task 6 — Sample Data Preparation

Insert realistic sample data supporting:

* Normal operations
* Important exceptional cases

---

## Task 7 — Query Design

Each student must design and execute at least **5 meaningful SQL queries**.

Each query must include:

1. Business Question
2. Target User(s)
3. Explanation of Usefulness
4. SQL Statement

---

# 3. Required Documents

## 3.1 Group Report

Submit a PDF report named:

```text
G<Group Number>_Report.pdf
```

Example:

```text
G01_Report.pdf
```

The report must include:

* Student ID and Full Name of all group members
* LLM Model(s) used by the group
* A concise description of the agent improvement process
* How the agent was evaluated
* How the group refined or improved the agent based on evaluation results

---

## 3.2 Group Agent Git Repository

The repository must include, at minimum:

```text
AGENT.md
SKILL.md
outputs/
```

### Required Outputs

```text
outputs/
├── 01-business-req-analysis-G<Group Number>.md
├── 02-erd-design-G<Group Number>.md
├── 03-logical-design-G<Group Number>.md
├── 04-design-validation-G<Group Number>.md
├── 05-db-definition-G<Group Number>.sql
├── 06-sample-data-G<Group Number>.sql
└── 07-query-design-G<Group Number>.sql
```

### Example for Group 01

```text
01-business-req-analysis-G01.md
```
