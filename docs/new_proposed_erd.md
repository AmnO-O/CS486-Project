The last ERD
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
        int approver_id
        datetime decision_time
        string decision_note
        string rejection_reason
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
    Users |o--o{ Bookings : "approves"
    Users |o--o{ Bookings : "checks_in"
    Spaces ||--o{ Bookings : "booked_for"
    Spaces ||--o{ Space_Facilities : "contains"
    Facilities ||--o{ Space_Facilities : "assigned_to"
    Spaces ||--o{ Maintenance : "requires_maintenance"
    Users ||--o{ Maintenance : "reports"
    Users |o--o{ Maintenance : "assigned_to"
```

Problems with the last ERD:
- Fat Booking Table, violate Single Responsibility Principle. It contains attributes related to booking request, approval, and session check-in. When Booking status is "Pending", many attributes like `approver_id`, `decision_time`, `decision_note`, `rejection_reason`, `actual_start_time`, `checked_in_by`, `initial_condition`, `actual_end_time`, `final_condition`, and `usage_notes` are null, which causes redundancy. 
- Lack of History Tracking of Status Changes. The Booking table only stores the current status of a booking, but it does not keep track of the history of status changes. This makes it difficult to audit or analyze the booking process over time.
- Rejection Reason and Decision Note are stored in the Booking table, which may not be appropriate. These attributes are only relevant when a booking is rejected or approved, and they may not be applicable to all bookings. Storing them in the Booking table can lead to confusion and make it harder to understand the booking process.


```mermaid
erDiagram
    Departments {
        int department_id PK
        string name
    }

    Users {
        int user_id PK
        string email UK
        string full_name
        string phone_number
        string role
        int department_id FK
        string account_status
    }

    Spaces {
        int space_id PK
        string space_code UK
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
        string category
    }

    Space_Facilities {
        int space_id PK,FK
        int facility_id PK,FK
        int quantity
    }

    Bookings {
        int booking_id PK
        int space_id FK
        int requester_id FK
        datetime requested_start_time
        datetime requested_end_time
        string purpose
        int expected_participants
        string status
        datetime created_at
    }

    Booking_Approvals {
        int approval_id PK
        int booking_id FK
        int approver_id FK
        datetime decision_time
        string decision
        string rejection_reason
        string decision_note
    }

    Booking_Sessions {
        int session_id PK
        int booking_id FK
        datetime actual_start_time
        int checked_in_by FK
        string initial_condition
        datetime actual_end_time
        string final_condition
        string usage_notes
    }

    Maintenance {
        int maintenance_id PK
        int space_id FK
        int reporter_id FK
        int assigned_staff_id FK
        string problem_description
        datetime start_time
        datetime completion_time
        string status
        string result_note
    }

    %% Relationships
    Departments ||--o{ Users : "belongs_to"
    Users ||--o{ Bookings : "requests"
    Users |o--o{ Booking_Approvals : "approves"
    Users |o--o{ Booking_Sessions : "checks_in"
    Spaces ||--o{ Bookings : "booked_for"
    Spaces ||--o{ Space_Facilities : "contains"
    Facilities ||--o{ Space_Facilities : "assigned_to"
    Spaces ||--o{ Maintenance : "requires_maintenance"
    Users ||--o{ Maintenance : "reports"
    Users |o--o{ Maintenance : "assigned_to"
    Bookings ||--o| Booking_Approvals : "has_decision"
    Bookings ||--o| Booking_Sessions : "has_session"
```



Improvements in the new ERD:
- Split Booking table into three separate tables: Bookings, Booking_Approvals, and Booking_Sessions. This adheres to the Single Responsibility Principle, reducing redundancy and improving clarity. Each table now focuses on a specific aspect of the booking process: 
  - Booking is used for the initial request
  - Booking_Approvals is used for the approval process,
  - Booking_Sessions is used for session check-in.
