USE CampusSpaceDB;
GO

SET NOCOUNT ON;

PRINT '============================================================';
PRINT 'CHECKING TEST-13 FIXTURE DATA (00_setup.sql)';
PRINT '============================================================';

-- 1. Kiểm tra Department test
PRINT '--- 1. Department ---';
SELECT * FROM dbo.departments WHERE name = N'TEST-13-Dept';

-- 2. Kiểm tra 2 Users test
PRINT '--- 2. Users (Requester & Staff) ---';
SELECT user_id, email, full_name, role, account_status FROM dbo.users WHERE email LIKE 'test13%';

-- 3. Kiểm tra 9 Spaces test
PRINT '--- 3. Spaces (9 Meeting Rooms) ---';
SELECT space_id, space_code, space_name, space_type, capacity, current_status FROM dbo.spaces WHERE space_code LIKE 'TEST-13%';

-- 4. Kiểm tra 2 vé Bảo trì (Maintenance)
PRINT '--- 4. Maintenance Tickets (M3 & M9) ---';
SELECT maintenance_id, space_id, problem_description, start_time, status, impact_level FROM dbo.maintenance WHERE problem_description LIKE 'TEST-13%';

-- 5. Kiểm tra các Pending Bookings test (6 bookings)
PRINT '--- 5. Pending Bookings (6 bookings) ---';
SELECT b.booking_id, b.space_id, s.space_code, b.requested_start_time, b.requested_end_time, b.purpose, b.status 
FROM dbo.bookings b
JOIN dbo.spaces s ON b.space_id = s.space_id
WHERE s.space_code LIKE 'TEST-13%'
ORDER BY s.space_code, b.requested_start_time;

-- 6. Tổng hợp số lượng dữ liệu fixture đã insert (Summary Count)
PRINT '--- 6. Fixture Summary Count ---';
SELECT 
    (SELECT COUNT(*) FROM dbo.departments WHERE name = N'TEST-13-Dept') AS dept_count,
    (SELECT COUNT(*) FROM dbo.users WHERE email LIKE 'test13%') AS users_count,
    (SELECT COUNT(*) FROM dbo.spaces WHERE space_code LIKE 'TEST-13%') AS spaces_count,
    (SELECT COUNT(*) FROM dbo.maintenance WHERE problem_description LIKE 'TEST-13%') AS maintenance_count,
    (SELECT COUNT(*) FROM dbo.bookings b JOIN dbo.spaces s ON b.space_id = s.space_id WHERE s.space_code LIKE 'TEST-13%') AS bookings_count;
GO