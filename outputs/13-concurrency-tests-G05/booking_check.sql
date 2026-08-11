USE CampusSpaceDB;
GO

SET NOCOUNT ON;

PRINT '============================================================';
PRINT 'CHECKING APPROVED BOOKINGS & APPROVAL DETAILS';
PRINT '============================================================';

-- 1. Danh sách các đơn đặt phòng đã duyệt trong TEST-13 Fixture (status = 'approved')
PRINT '--- 1. Approved Bookings (TEST-13 Spaces) ---';
SELECT 
    b.booking_id,
    s.space_code,
    u_req.full_name AS requester_name,
    u_req.email AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.status,
    b.created_at
FROM dbo.bookings b
JOIN dbo.spaces s ON b.space_id = s.space_id
JOIN dbo.users u_req ON b.requester_id = u_req.user_id
WHERE s.space_code LIKE 'TEST-13%'
  AND b.status IN ('approved', 'checked_in', 'completed')
ORDER BY s.space_code, b.requested_start_time;

-- 2. Chi tiết quyết định phê duyệt (Duyệt tự động Instant user_id = -1 vs Duyệt bởi Staff)
PRINT '--- 2. Approval Decision Details ---';
SELECT 
    a.approval_id,
    a.booking_id,
    s.space_code,
    a.approver_id,
    CASE 
        WHEN a.approver_id = -1 THEN N'System (Instant Auto-Approval)'
        ELSE u_app.full_name + N' (' + u_app.role + N')'
    END AS approver_info,
    a.decision_time,
    a.decision,
    a.decision_note
FROM dbo.booking_approvals a
JOIN dbo.bookings b ON a.booking_id = b.booking_id
JOIN dbo.spaces s ON b.space_id = s.space_id
LEFT JOIN dbo.users u_app ON a.approver_id = u_app.user_id
WHERE s.space_code LIKE 'TEST-13%'
  AND a.decision = 'approved'
ORDER BY a.decision_time DESC;

-- 3. Chi tiết các Xác nhận Cảnh báo Bảo trì đính kèm (Advisory Acknowledgements)
PRINT '--- 3. Advisory Acknowledgements for Approved Bookings ---';
SELECT 
    ack.ack_id,
    ack.booking_id,
    s.space_code,
    ack.maintenance_id,
    m.problem_description AS advisory_description,
    u_ack.full_name AS acknowledged_by_user,
    ack.acknowledged_at
FROM dbo.booking_advisory_acknowledgement ack
JOIN dbo.bookings b ON ack.booking_id = b.booking_id
JOIN dbo.spaces s ON b.space_id = s.space_id
JOIN dbo.maintenance m ON ack.maintenance_id = m.maintenance_id
JOIN dbo.users u_ack ON ack.acknowledged_by = u_ack.user_id
WHERE s.space_code LIKE 'TEST-13%'
ORDER BY ack.ack_id;

-- 4. Thống kê tổng số lượng Booking theo trạng thái trong không gian TEST-13
PRINT '--- 4. TEST-13 Booking Status Breakdown ---';
SELECT 
    b.status,
    COUNT(*) AS booking_count
FROM dbo.bookings b
JOIN dbo.spaces s ON b.space_id = s.space_id
WHERE s.space_code LIKE 'TEST-13%'
GROUP BY b.status
ORDER BY booking_count DESC;

-- 5. Tất cả Approved Bookings trên TOÀN BỘ DATABASE (để tiện tra cứu chung)
PRINT '--- 5. All Approved Bookings Across Whole System (Top 20 latest) ---';
SELECT TOP 20
    b.booking_id,
    s.space_code,
    u_req.email AS requester_email,
    b.requested_start_time,
    b.requested_end_time,
    b.status,
    a.approver_id,
    a.decision_time
FROM dbo.bookings b
JOIN dbo.spaces s ON b.space_id = s.space_id
JOIN dbo.users u_req ON b.requester_id = u_req.user_id
LEFT JOIN dbo.booking_approvals a ON b.booking_id = a.booking_id
WHERE b.status = 'approved'
ORDER BY b.booking_id DESC;
GO
