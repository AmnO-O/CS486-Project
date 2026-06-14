# Conceptual Entity-Relationship Diagram (ERD) — Campus Space Management System

## 1. Description and Core Entities
The Campus Space Management System database centers on **Users**, **Spaces**, and **Bookings**, supported by organizational units (**Departments**) and equipment profiles (**Facilities**). The core relationships track the booking request and approval lifecycle, as well as maintenance requests and assignments. Junction table **Space_Facilities** resolves the many-to-many relationship between bookable rooms and equipment types.

## 2. Mermaid.js ERD
```mermaid
erDiagram
    Departments {
        INT department_id PK
        NVARCHAR name
        DATETIME2 created_at
        DATETIME2 updated_at
    }

    Users {
        INT user_id PK
        NVARCHAR email
        NVARCHAR full_name
        NVARCHAR phone_number
        VARCHAR role
        INT department_id FK
        VARCHAR account_status
        DATETIME2 created_at
        DATETIME2 updated_at
    }

    Spaces {
        INT space_id PK
        NVARCHAR space_code
        NVARCHAR space_name
        VARCHAR space_type
        NVARCHAR building
        NVARCHAR floor
        NVARCHAR room_number
        INT capacity
        VARCHAR current_status
        NVARCHAR usage_policy
        DATETIME2 created_at
        DATETIME2 updated_at
    }

    Facilities {
        INT facility_id PK
        NVARCHAR name
        DATETIME2 created_at
        DATETIME2 updated_at
    }

    Space_Facilities {
        INT space_id PK
        INT facility_id PK
        INT quantity
    }

    Bookings {
        INT booking_id PK
        INT space_id FK
        INT requester_id FK
        DATETIME2 requested_start_time
        DATETIME2 requested_end_time
        VARCHAR purpose
        INT expected_participants
        VARCHAR status
        INT approver_id FK
        DATETIME2 decision_time
        NVARCHAR decision_note
        NVARCHAR rejection_reason
        DATETIME2 actual_start_time
        INT checked_in_by FK
        NVARCHAR initial_condition
        DATETIME2 actual_end_time
        NVARCHAR final_condition
        NVARCHAR usage_notes
        BIT is_deleted
        DATETIME2 created_at
        DATETIME2 updated_at
    }

    Maintenance {
        INT maintenance_id PK
        INT space_id FK
        INT reporter_id FK
        INT assigned_staff_id FK
        NVARCHAR problem_description
        DATETIME2 start_time
        DATETIME2 completion_time
        VARCHAR status
        NVARCHAR result_note
        BIT is_deleted
        DATETIME2 created_at
        DATETIME2 updated_at
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
