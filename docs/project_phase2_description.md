# CS486 – Introduction to Database System

**Lecturer:** Lê Thị Nhàn, PhD.  
**TA:** Nguyễn Ngọc Toàn, MSc.; Nguyễn Ngọc Minh Châu, MSc.  
**Lab instructor:** Nguyễn Ngọc Toàn, MSc.; Nguyễn Ngọc Minh Châu, MSc.

## 1. Business requirement description

After the Phase 1 design was completed, the School of Computer Science piloted the space booking system for one semester. Based on the pilot, the Facility Manager announced one change to the maintenance rules and a set of new operating conditions that the system must support. Phase 2 extends the Phase 1 system accordingly.

### 1.1. Requirement change: maintenance impact levels

In Phase 1, any space under maintenance could not be booked. The Facility Manager now refines this rule:

- Some maintenance work makes a space unusable (for example, electrical repair, floor replacement, air-conditioning replacement in summer). Such maintenance has impact level out-of-service: the space cannot be booked for any time period that overlaps the maintenance period, exactly as in Phase 1.
- Other maintenance work affects only part of the space's equipment or comfort, while the space itself remains usable (for example, a broken projector, one faulty air conditioner out of several, a damaged whiteboard). Such maintenance has impact level advisory: the space can still be booked, but the system must notify the requester of all active advisories on the space at booking time, and must record that the requester was informed (an acknowledgement stored with the booking).

Additional rules:

- A space may have several active maintenance records at the same time, with different impact levels.
- The impact level of a maintenance record may be escalated (advisory → out-of-service) or downgraded while the maintenance is still open.
- If an advisory maintenance is escalated to out-of-service, already-approved bookings that overlap the maintenance period must be identified so that staff can contact the requesters; the system must support finding these affected bookings.

### 1.2. New operating conditions: concurrent booking and approval

At the beginning of each semester, many users may submit booking requests at approximately the same time. Popular spaces may therefore receive several requests for overlapping time periods within a short interval. For selected space types, requests that satisfy the usage policy may be approved automatically at submission time. Other requests continue through the existing staff approval workflow.

Because users and staff may perform booking operations concurrently, multiple operations may check the availability of the same space before any of them records its result. Without appropriate concurrency control, conflicting bookings may be approved. The system must ensure that two approved bookings cannot use the same space during overlapping time periods, regardless of whether the bookings are created through instant booking or staff approval. This rule must remain valid even when multiple users or staff members perform booking and approval operations simultaneously.

### 1.3. New reporting needs

With the accumulated booking and maintenance history, the Facility Manager needs the system to support the following reports:

- Total approved booking hours of each space for a given semester.
- Number of approved bookings by weekday and hour for a given semester.
- Available spaces that satisfy a required capacity and a required facility list within a given time period.
- Approved bookings affected when a maintenance record is escalated to out-of-service.

Students must implement all of these queries. Then identify suitable indexes for the booking conflict check, the room finder query, and one additional reporting query selected from the list above. The queries should be tested on a sufficiently large generated dataset so that differences before and after indexing can be observed.

## 2. Phase 2

Phase 2 extends the group's Phase 1 database (and agent). Groups must update AGENT.md and SKILL.md and briefly describe the improvements made.

The required work includes:

- Requirement change analysis: identify the affected entities, relationships, and business rules; determine possible conflicts caused by concurrent booking and approval operations.
- Design update: update the ERD and relational schema to support maintenance impact levels, advisory acknowledgements, and concurrent booking.
- Schema migration: implement the changes on top of the Phase 1 database while preserving existing data or documenting the migration approach.
- Concurrency design and implementation: identify at least one concurrency conflict and implement a suitable solution; provide scripts demonstrating the conflict and its prevention.
- Sample data generation: generate at least three academic years of realistic data with at least 100,000 booking records (and up to 500,000 if needed) including maintenance, cancellations, no-shows, and advisory acknowledgements.
- Analytical queries: implement all reports listed in Section 1.3; select two reporting queries other than the room finder for detailed indexing and performance analysis.
- Indexing and query tuning: tune the booking conflict check, room finder, and the two selected reporting queries; compare execution plans and execution times before and after indexing.
- Normalization validation: identify functional dependencies and ensure all relations satisfy at least Third Normal Form (3NF).

## 3. Required documents

### 3.1. Group Report

Submit G<Group number>_Report_P2.pdf, including:

- Group members and individual queries.
- LLM models used and a brief agent improvement process.
- Identified concurrency conflicts and proposed solutions.
- Concurrency test results.
- Indexing and query-tuning results.

### 3.2. Group Agent Git Repository

Update AGENT.md and SKILL.md, and add:

- 08-requirement-change-analysis-G<Group number>.md
- 09-updated-erd-and-logical-design-G<Group number>.md
- 10-schema-migration-G<Group number>.sql
- 11-concurrency-design-G<Group number>.md
- 12-concurrency-implementation-G<Group number>.sql
- 13-concurrency-tests-G<Group number>/
- 14-data-generator-G<Group number>/
- 15-index-tuning-report-G<Group number>.md
- 16-analytical-queries-G<Group number>.sql
