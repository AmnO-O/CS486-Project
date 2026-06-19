# Data Coverage

Generate realistic valid data for all locked tables. Use enum values exactly as defined by Task 05 DDL.

## Departments

- Insert at least 4 departments.
- Include the School of Computer Science.
- Include at least two other university departments for reporting variety.

## Users

- Include all roles: `student`, `lecturer`, `teaching_assistant`, `facility_staff`, `department_admin`, `facility_manager`.
- Include mixed account statuses: `active`, `inactive`, `suspended`.
- Use unique university-style emails.

## Spaces

- Include all space types: `auditorium`, `classroom`, `computer_lab`, `project_lab`, `meeting_room`, `student_workspace`.
- Include all space statuses: `available`, `in_use`, `under_maintenance`, `temporarily_closed`, `retired`.
- Include varied buildings, floors, room numbers, capacities, and usage policies.

## Facilities

Include realistic facility types from the requirements:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming Equipment
- Air Conditioner

## Space Facilities

- Assign multiple facilities to multiple spaces.
- Use valid positive quantities.

## Maintenances

- Include `open`, `in_progress`, and `resolved` maintenance rows.
- Include at least one active maintenance record for a space with `current_status = 'under_maintenance'`.
- Include at least one row with `assigned_staff_id` populated by a valid facility staff or facility manager user.
- Include realistic problem descriptions: broken projector, air conditioning failure, damaged furniture, cleaning issues, and network problems.
- Include at least one soft-deleted maintenance row (`is_deleted = 1`) or pair this requirement with a soft-deleted booking row to demonstrate historical preservation.

## Bookings

- Include all booking statuses: `pending`, `approved`, `rejected`, `cancelled`, `checked_in`, `completed`, `no_show`.
- Include all booking purposes: `lecture`, `examination`, `seminar`, `workshop`, `meeting`, `student_activity`, `administrative_event`.
- Include future approved bookings for upcoming-booking reports.
- Include past completed bookings for history reports.
- Include no-show rows for no-show reports.
- Include rejected rows with approver, decision time, decision note, and rejection reason.
- Include checked-in rows with `actual_start_time`, `checked_in_by`, and `initial_condition`.
- Include completed rows with `actual_start_time`, `checked_in_by`, `initial_condition`, `actual_end_time`, `final_condition`, and `usage_notes`.
- Include at least one soft-deleted booking row (`is_deleted = 1`) or pair this requirement with a soft-deleted maintenance row.
- Include rows that directly support staff reports: booking history, upcoming bookings, spaces under maintenance, and no-show bookings.
