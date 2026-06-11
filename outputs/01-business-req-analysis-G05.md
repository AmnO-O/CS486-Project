# Business Requirement Analysis

**Group:** G05  
**Course:** CS486 – Introduction to Database Systems  
**Project:** Shared Campus Space Booking & Maintenance Management System  

---

## Purpose
The primary purpose of the database system is to streamline, automate, and digitalize the booking, approval, usage, and maintenance operations of shared campus spaces (such as auditoriums, classrooms, computer laboratories, project laboratories, meeting rooms, and student workspaces) within the School of Computer Science. The system aims to replace manual processes, prevent booking conflicts (scheduling overlaps), enforce space policies, track space utilization, and preserve a comprehensive historical record of both usage sessions and maintenance activities.

---

## Actors
The system supports six distinct roles/actors, each with specific permissions and responsibilities:

1. **Student**: 
   - Can submit booking requests for student projects, student activities, or workshops.
   - Can view booking history and upcoming bookings.
2. **Lecturer**: 
   - Can submit booking requests for classes, teaching, examinations, seminars, or academic events.
   - Can view booking history and upcoming bookings.
3. **Teaching Assistant (TA)**: 
   - Can submit booking requests for teaching, laboratory sessions, or student project guidance.
   - Can view booking history and upcoming bookings.
4. **Department Administrator**: 
   - Can submit and manage booking requests on behalf of departments.
   - Can view space availability, booking records, and historical utilization.
5. **Facility Staff**: 
   - Reviews, approves, or rejects pending booking requests.
   - Performs check-ins when rectors arrive (recording actual start time and initial space condition).
   - Performs completions when sessions end (recording actual end time, final space condition, and usage notes).
   - Reports space maintenance issues and updates maintenance statuses.
6. **Facility Manager**: 
   - Manages space assets (creating, editing, retiring spaces) and space facilities.
   - Oversees booking requests, approvals, check-ins, and completions.
   - Schedules, assigns, and resolves maintenance records.
   - Reviews complete history reports for bookings and maintenance activities to evaluate utilization.

---

## Entities and Attributes

### 1. User
Represents any person with a university account registered in the system.
- **UserID** (Primary Key): Unique university account identifier.
- **FullName**: User's complete name.
- **Email**: Unique university email address.
- **Phone**: User's contact phone number.
- **Role**: User's role in the system (`Student`, `Lecturer`, `Teaching Assistant`, `Facility Staff`, `Department Administrator`, `Facility Manager`).
- **Department**: The academic/administrative department the user belongs to.
- **AccountStatus**: Current state of the account (`Active`, `Suspended`, `Inactive`).

### 2. Space
Represents physical campus spaces managed by the school.
- **SpaceCode** (Primary Key): Unique alphanumeric room identifier (e.g., `CS-301`).
- **SpaceName**: Descriptive name (e.g., "Advanced Computer Lab 1").
- **SpaceType**: Classification of the space (`Classroom`, `Computer Laboratory`, `Project Laboratory`, `Meeting Room`, `Auditorium`, `Student Workspace`).
- **Building**: Building name or identifier (e.g., "Building B").
- **Floor**: Floor number (e.g., 3).
- **RoomNumber**: Room number (e.g., "301").
- **Capacity**: Maximum number of people allowed.
- **CurrentStatus**: Operational status of the space (`Available`, `In Use`, `Under Maintenance`, `Temporarily Closed`, `Retired`).
- **UsagePolicy**: Guidelines and booking restrictions for the space.

### 3. Facility
Represents the physical equipment/amenities available inside a specific space.
- **FacilityID** (Primary Key): Unique facility identifier.
- **SpaceCode** (Foreign Key): The space where the facility is located.
- **FacilityName**: Name/type of equipment (`Projector`, `Whiteboard`, `Microphone`, `Computer`, `Livestreaming Equipment`, `Air Conditioner`).
- **Description**: Technical details or asset tag number of the facility.

### 4. BookingRequest
Represents a user's request to reserve a space for a specific purpose and time period.
- **BookingID** (Primary Key): Unique booking identifier.
- **SpaceCode** (Foreign Key): The space being booked.
- **RequesterID** (Foreign Key): The user requesting the space.
- **RequestedStartTime**: Date and time when the requested reservation begins.
- **RequestedEndTime**: Date and time when the requested reservation ends.
- **Purpose**: Category of use (`Lecture`, `Examination`, `Seminar`, `Workshop`, `Meeting`, `Student Activity`, `Administrative Event`).
- **ExpectedParticipants**: Expected number of people attending.
- **BookingStatus**: Current state of the request (`Pending`, `Approved`, `Rejected`, `Cancelled`, `Checked In`, `Completed`, `No-Show`).
- **ApprovedBy** (Foreign Key, Nullable): Facility Staff or Manager who approved/rejected the booking.
- **DecisionTime** (Nullable): Timestamp of approval/rejection.
- **DecisionNote** (Nullable): Brief explanation of the approval/rejection decision.
- **RejectionReason** (Nullable): Explanatory text if the booking is rejected.
- **ActualStartTime** (Nullable): Timestamp of the actual check-in.
- **CheckedInBy** (Foreign Key, Nullable): Facility Staff who performed the check-in.
- **InitialCondition** (Nullable): Note describing the space condition at check-in.
- **ActualEndTime** (Nullable): Timestamp of the actual completion/check-out.
- **CompletedBy** (Foreign Key, Nullable): Facility Staff who completed the booking.
- **FinalCondition** (Nullable): Note describing the space condition at check-out.
- **UsageNotes** (Nullable): General observations or incidents logged during the session.

### 5. MaintenanceRecord
Represents a recorded maintenance problem, task, or incident in a space.
- **MaintenanceID** (Primary Key): Unique maintenance record identifier.
- **SpaceCode** (Foreign Key): The space requiring maintenance.
- **ReporterID** (Foreign Key): User who reported the problem.
- **AssignedStaffID** (Foreign Key, Nullable): Facility Staff member assigned to fix the issue.
- **ProblemDescription**: Description of the issue (e.g., "broken projector", "AC leaking").
- **StartTime**: Date and time the maintenance work began.
- **CompletionTime** (Nullable): Date and time the maintenance work was completed.
- **MaintenanceStatus**: Current state of maintenance (`Reported`, `In Progress`, `Resolved`).
- **ResultNote** (Nullable): Resolution details or comments from the assigned technician.

---

## Relationships and Cardinalities

1. **User to BookingRequest** (One-to-Many):
   - A `User` can submit zero or many `BookingRequests`.
   - Each `BookingRequest` is submitted by exactly one `User` (Requester).
   - Participation: `User` is optional; `BookingRequest` is mandatory.
2. **Space to BookingRequest** (One-to-Many):
   - A `Space` can be associated with zero or many `BookingRequests`.
   - Each `BookingRequest` is for exactly one `Space`.
   - Participation: `Space` is optional; `BookingRequest` is mandatory.
3. **Space to Facility** (One-to-Many):
   - A `Space` can have zero or many `Facilities`.
   - Each `Facility` belongs to exactly one `Space`.
   - Participation: `Space` is optional; `Facility` is mandatory.
4. **BookingRequest to User (Decision Maker)** (Many-to-One):
   - A `BookingRequest` may be approved or rejected by zero or one `User` (with role `Facility Staff` or `Facility Manager`).
   - A `User` (Staff/Manager) can approve/reject zero or many `BookingRequests`.
   - Participation: `BookingRequest` is optional (nullable); `User` is optional.
5. **BookingRequest to User (Check-In Staff)** (Many-to-One):
   - A `BookingRequest` can be checked in by zero or one `User` (with role `Facility Staff` or `Facility Manager`).
   - A `User` (Staff/Manager) can check-in zero or many bookings.
   - Participation: `BookingRequest` is optional; `User` is optional.
6. **BookingRequest to User (Check-Out Staff)** (Many-to-One):
   - A `BookingRequest` can be completed by zero or one `User` (with role `Facility Staff` or `Facility Manager`).
   - A `User` (Staff/Manager) can complete zero or many bookings.
   - Participation: `BookingRequest` is optional; `User` is optional.
7. **Space to MaintenanceRecord** (One-to-Many):
   - A `Space` can have zero or many `MaintenanceRecords`.
   - Each `MaintenanceRecord` is for exactly one `Space`.
   - Participation: `Space` is optional; `MaintenanceRecord` is mandatory.
8. **MaintenanceRecord to User (Reporter)** (Many-to-One):
   - A `MaintenanceRecord` is reported by exactly one `User`.
   - A `User` can report zero or many `MaintenanceRecords`.
   - Participation: `MaintenanceRecord` is mandatory; `User` is optional.
9. **MaintenanceRecord to User (Assigned Staff)** (Many-to-One):
   - A `MaintenanceRecord` may be assigned to zero or one `User` (with role `Facility Staff` or `Facility Manager`).
   - A `User` (Staff/Manager) can be assigned to zero or many `MaintenanceRecords`.
   - Participation: `MaintenanceRecord` is optional; `User` is optional.

---

## Business Rules

1. **Unique Account Constraint**: Every user in the database must have a unique university account. Email and Phone number must be unique across all records.
2. **Space Uniqueness**: Each room/space must have a unique `SpaceCode` identifier.
3. **Capacity Enforceability**: The expected number of participants for any booking request must not exceed the specified `Capacity` of the target space.
4. **Booking Conflicts Prevention**: The system must enforce that a single space cannot have two approved booking requests that overlap in time. Two bookings ($B_1$ and $B_2$) for the same space overlap if:
   $$\text{RequestedStartTime}(B_1) < \text{RequestedEndTime}(B_2) \quad \text{and} \quad \text{RequestedStartTime}(B_2) < \text{RequestedEndTime}(B_1)$$
   This check only applies to bookings with a status of `Approved`, `Checked In`, or `Completed`.
5. **Availability Constraint**: A space cannot be booked if its status is `Under Maintenance`, `Temporarily Closed`, or `Retired`. Booking requests can only be placed on spaces with `Available` or `In Use` status.
6. **Mandatory Approvals**: A booking request must be approved by a `Facility Staff` or `Facility Manager` before it can be checked in. Upon approval/rejection, the system must record the staff member ID, the decision timestamp, and a decision note. Rejection requires a rejection reason.
7. **Workflow Sequence Enforceability**:
   - A booking cannot be checked in unless its current status is `Approved`.
   - A booking cannot be completed unless its current status is `Checked In`.
   - A booking check-in must record the `ActualStartTime`, the checking-in staff member, and the `InitialCondition`.
   - A booking completion must record the `ActualEndTime`, the completing staff member, the `FinalCondition`, and optionally `UsageNotes`.
8. **Maintenance Blockage**: Once a space has an active (non-resolved) maintenance record or is set to `Under Maintenance`, it is completely blocked from any new booking requests.
9. **No-Show Tracking**: If a booking is `Approved` but the requester does not check-in within an established buffer time after `RequestedStartTime`, its status can be changed to `No-Show`.

---

## Assumptions

1. **Role Restrictions**: While any registered university user can submit booking requests, certain rooms may have custom restrictions written in their `UsagePolicy`.
2. **Cancellation**: Requesters can only cancel (`Cancelled`) booking requests that are currently in `Pending` or `Approved` status. Once a booking is `Checked In`, it can only be `Completed`.
3. **No Retroactive Bookings**: The requested start time of a booking must be in the future (greater than the transaction time of the booking submission).
4. **Time Alignment**: All date and time entries are stored with timezone awareness (or UTC) to ensure consistent comparison.
5. **Staff/Manager Self-Booking**: Facility staff and managers can submit booking requests for themselves, but they cannot approve their own booking requests (to ensure fairness and auditability).

---

## Open Questions

1. **Recurrent Bookings**: Does the system need native support for recurrent bookings (e.g., "every Tuesday from 9 AM to 11 AM for 15 weeks") or should recurrences be created as individual, independent booking requests? *(Assumed: Individual booking requests for each occurrence for this database version).*
2. **Buffer Time**: Is there a specific buffer period (e.g., 30 minutes) after which an approved booking automatically changes to a `No-Show` if the requester fails to check in?
3. **Role-based Space Booking Limits**: Are there quota limits on how many spaces a student can book concurrently or how many hours a student can reserve in a week?
4. **Maintenance Schedule Pre-booking Check**: If a space is scheduled for maintenance in the future, should the system allow booking requests that occur before that maintenance start time? *(Assumed: Yes, bookings can be made as long as they don't overlap with the maintenance window).*

---

## Suggested Table Mapping

Based on the entities, we suggest mapping to the following Relational Database tables in Microsoft SQL Server:

1. **`Users`**: Holds university account records.
   - Columns: `UserID` (PK, VARCHAR(50)), `FullName` (NVARCHAR(100)), `Email` (VARCHAR(100), UNIQUE), `Phone` (VARCHAR(20), UNIQUE), `Role` (VARCHAR(30)), `Department` (NVARCHAR(100)), `AccountStatus` (VARCHAR(20)).
2. **`Spaces`**: Holds physical rooms details.
   - Columns: `SpaceCode` (PK, VARCHAR(20)), `SpaceName` (NVARCHAR(100)), `SpaceType` (VARCHAR(30)), `Building` (NVARCHAR(50)), `Floor` (INT), `RoomNumber` (VARCHAR(20)), `Capacity` (INT), `CurrentStatus` (VARCHAR(30)), `UsagePolicy` (NVARCHAR(MAX)).
3. **`Facilities`**: Holds equipment lists within rooms.
   - Columns: `FacilityID` (PK, INT IDENTITY), `SpaceCode` (FK, VARCHAR(20)), `FacilityName` (NVARCHAR(100)), `Description` (NVARCHAR(250)).
4. **`Bookings`**: Tracks reservation requests, approvals, check-ins, and completions.
   - Columns: `BookingID` (PK, INT IDENTITY), `SpaceCode` (FK, VARCHAR(20)), `RequesterID` (FK, VARCHAR(50)), `RequestedStartTime` (DATETIME), `RequestedEndTime` (DATETIME), `Purpose` (VARCHAR(50)), `ExpectedParticipants` (INT), `BookingStatus` (VARCHAR(20)), `ApprovedBy` (FK, VARCHAR(50), NULL), `DecisionTime` (DATETIME, NULL), `DecisionNote` (NVARCHAR(MAX), NULL), `RejectionReason` (NVARCHAR(MAX), NULL), `ActualStartTime` (DATETIME, NULL), `CheckedInBy` (FK, VARCHAR(50), NULL), `InitialCondition` (NVARCHAR(MAX), NULL), `ActualEndTime` (DATETIME, NULL), `CompletedBy` (FK, VARCHAR(50), NULL), `FinalCondition` (NVARCHAR(MAX), NULL), `UsageNotes` (NVARCHAR(MAX), NULL).
5. **`MaintenanceRecords`**: Tracks maintenance and issue logs.
   - Columns: `MaintenanceID` (PK, INT IDENTITY), `SpaceCode` (FK, VARCHAR(20)), `ReporterID` (FK, VARCHAR(50)), `AssignedStaffID` (FK, VARCHAR(50), NULL), `ProblemDescription` (NVARCHAR(MAX)), `StartTime` (DATETIME), `CompletionTime` (DATETIME, NULL), `MaintenanceStatus` (VARCHAR(20)), `ResultNote` (NVARCHAR(MAX), NULL).

---

### Verification and Quality Checklist
- [x] Actor List (6 roles identified: Student, Lecturer, TA, Administrator, Staff, Manager)
- [x] Entities List (5 main entities: User, Space, Facility, Booking, MaintenanceRecord)
- [x] Explicit Business Rules (Conflict prevention, Capacity, Availability, Workflow, Maintenance block)
- [x] Traceability from Requirements to Suggested Schema
