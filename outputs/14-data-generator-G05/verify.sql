/*
  CS486 G05 - Task 14 verification script
  SQL Server 2019+. Run after load.sql on the same scratch database.

  Every check below is reviewer-runnable and returns rows only on failure,
  except the informational distribution queries which are explicitly labeled.
  No expected row counts are hardcoded (per-run distributions are not asserted).
*/
SET NOCOUNT ON;
GO

PRINT '=== V1/G1/G2: booking volume and span ===';
SELECT
    COUNT(*) AS booking_count,
    CASE WHEN COUNT(*) BETWEEN 100000 AND 500000 THEN 'PASS' ELSE 'FAIL-G1' END AS g1_volume,
    MIN(requested_start_time) AS first_start,
    MAX(requested_end_time)   AS last_end,
    CASE WHEN DATEDIFF(DAY, MIN(requested_start_time), MAX(requested_end_time)) >= 3 * 365
         THEN 'PASS' ELSE 'FAIL-G2' END AS g2_span
FROM dbo.bookings b
INNER JOIN dbo.spaces s
    ON s.space_id = b.space_id
   AND s.space_code LIKE N'T14-%';
GO

PRINT '=== V2/G7/BR1/NR6: confirmed-overlap running-max check (expect 0 rows = PASS) ===';
WITH confirmed_ordered AS (
    SELECT
        b.space_id,
        b.booking_id,
        b.requested_start_time,
        b.requested_end_time,
        MAX(b.requested_end_time) OVER (
            PARTITION BY b.space_id
            ORDER BY b.requested_start_time, b.requested_end_time, b.booking_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS prior_max_end
    FROM dbo.bookings b
    INNER JOIN dbo.spaces s
        ON s.space_id = b.space_id
       AND s.space_code LIKE N'T14-%'
    WHERE b.is_deleted = 0
      AND b.status IN ('approved','checked_in','completed')
)
SELECT
    space_id,
    booking_id,
    requested_start_time,
    requested_end_time,
    prior_max_end
FROM confirmed_ordered
WHERE prior_max_end > requested_start_time;
GO

PRINT '=== V3/BR4: confirmed booking over active out-of-service maintenance (expect 0 rows = PASS) ===';
SELECT b.booking_id, m.maintenance_id, b.requested_start_time, b.requested_end_time,
       m.start_time, m.completion_time
FROM dbo.bookings b
JOIN dbo.maintenance m
  ON m.space_id = b.space_id
 AND m.is_deleted = 0
 AND m.status IN ('open','in_progress')
 AND m.impact_level = 'out-of-service'
 AND m.start_time < b.requested_end_time
 AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time)
JOIN dbo.spaces bs
  ON bs.space_id = b.space_id
 AND bs.space_code LIKE N'T14-%'
JOIN dbo.spaces ms
  ON ms.space_id = m.space_id
 AND ms.space_code LIKE N'T14-%'
WHERE b.is_deleted = 0
  AND b.status IN ('approved','checked_in','completed');
GO

PRINT '=== V4/NR2: confirmed booking missing an ack for an overlapping active advisory (expect 0 rows = PASS) ===';
SELECT b.booking_id, m.maintenance_id
FROM dbo.bookings b
JOIN dbo.maintenance m
  ON m.space_id = b.space_id
 AND m.is_deleted = 0
 AND m.status IN ('open','in_progress')
 AND m.impact_level = 'advisory'
 AND m.start_time < b.requested_end_time
 AND (m.completion_time IS NULL OR m.completion_time > b.requested_start_time)
JOIN dbo.spaces bs
  ON bs.space_id = b.space_id
 AND bs.space_code LIKE N'T14-%'
JOIN dbo.spaces ms
  ON ms.space_id = m.space_id
 AND ms.space_code LIKE N'T14-%'
WHERE b.is_deleted = 0
  AND b.status IN ('approved','checked_in','completed')
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.booking_advisory_acknowledgement a
      WHERE a.booking_id = b.booking_id
        AND a.maintenance_id = m.maintenance_id
  );
GO

PRINT '=== V5a/G4/G6: booking status distribution (informational) ===';
SELECT b.status, COUNT(*) AS row_count
FROM dbo.bookings b
JOIN dbo.spaces s
  ON s.space_id = b.space_id
 AND s.space_code LIKE N'T14-%'
GROUP BY b.status
ORDER BY b.status;
GO

PRINT '=== V5b/G3: maintenance impact/status distribution (informational) ===';
SELECT m.impact_level, m.status, COUNT(*) AS row_count
FROM dbo.maintenance m
JOIN dbo.spaces s
  ON s.space_id = m.space_id
 AND s.space_code LIKE N'T14-%'
GROUP BY m.impact_level, m.status
ORDER BY m.impact_level, m.status;
GO

PRINT '=== V5c/G6: approval origin distribution (both must have COUNT > 0 = PASS) ===';
SELECT
    CASE WHEN a.approver_id = -1 THEN 'instant' ELSE 'staff' END AS origin,
    a.decision, COUNT(*) AS row_count
FROM dbo.booking_approvals a
JOIN dbo.bookings b ON b.booking_id = a.booking_id
JOIN dbo.spaces s ON s.space_id = b.space_id AND s.space_code LIKE N'T14-%'
GROUP BY CASE WHEN a.approver_id = -1 THEN 'instant' ELSE 'staff' END, a.decision
ORDER BY origin, decision;
GO

PRINT '=== V5d/G3: maintenance_impact_history row count (informational; >0 after Mode-A escalation slice) ===';
SELECT COUNT(*) AS impact_history_rows
FROM dbo.maintenance_impact_history h
JOIN dbo.maintenance m ON m.maintenance_id = h.maintenance_id
JOIN dbo.spaces s ON s.space_id = m.space_id AND s.space_code LIKE N'T14-%';
GO

PRINT '=== V5e/G5: acknowledgement row count (informational) ===';
SELECT COUNT(*) AS ack_rows
FROM dbo.booking_advisory_acknowledgement a
JOIN dbo.bookings b ON b.booking_id = a.booking_id
JOIN dbo.spaces s ON s.space_id = b.space_id AND s.space_code LIKE N'T14-%';
GO

PRINT '=== V5f/NR5: instant approvals must use seeded allowed space_type/purpose pairs (expect 0 rows = PASS) ===';
SELECT a.approval_id, a.booking_id, s.space_type, b.purpose
FROM dbo.booking_approvals a
JOIN dbo.bookings b ON b.booking_id = a.booking_id
JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE a.approver_id = -1
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.space_type_allowed_purpose p
      WHERE p.space_type = s.space_type
        AND p.purpose = b.purpose
  );
GO

PRINT '=== V6a/no_show shape: no no_show may have a session (expect 0 rows = PASS) ===';
SELECT b.booking_id
FROM dbo.bookings b
JOIN dbo.spaces s
  ON s.space_id = b.space_id
 AND s.space_code LIKE N'T14-%'
WHERE b.status = 'no_show'
  AND EXISTS (
      SELECT 1 FROM dbo.booking_sessions sess WHERE sess.booking_id = b.booking_id
  );
GO

PRINT '=== V6b/no_show shape: every no_show has an approved decision (expect 0 rows = PASS) ===';
SELECT b.booking_id
FROM dbo.bookings b
JOIN dbo.spaces s
  ON s.space_id = b.space_id
 AND s.space_code LIKE N'T14-%'
WHERE b.status = 'no_show'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.booking_approvals a
      WHERE a.booking_id = b.booking_id
        AND a.decision = 'approved'
  );
GO

PRINT '=== V7/BR3: capacity violation among T14 rows (expect 0 rows = PASS) ===';
SELECT b.booking_id, b.expected_participants, s.capacity
FROM dbo.bookings b
JOIN dbo.spaces s ON s.space_id = b.space_id
WHERE b.expected_participants > s.capacity
  AND b.space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T14-%');
GO

PRINT '=== V8/UQ: duplicate confirmed exact-start collisions on one space (expect 0 rows = PASS) ===';
SELECT space_id, requested_start_time, COUNT(*) AS collisions
FROM dbo.bookings
WHERE is_deleted = 0
  AND status IN ('approved','checked_in','completed')
  AND space_id IN (SELECT space_id FROM dbo.spaces WHERE space_code LIKE N'T14-%')
GROUP BY space_id, requested_start_time
HAVING COUNT(*) > 1;
GO

PRINT '=== V9: ack correspondence sanity (expect 0 rows = PASS; catches malformed T14 acks even before trigger re-check) ===';
SELECT a.ack_id, a.booking_id, a.maintenance_id
FROM dbo.booking_advisory_acknowledgement a
JOIN dbo.bookings b ON b.booking_id = a.booking_id
JOIN dbo.maintenance m ON m.maintenance_id = a.maintenance_id
JOIN dbo.spaces s ON s.space_id = b.space_id AND s.space_code LIKE N'T14-%'
WHERE b.is_deleted = 1
   OR m.is_deleted = 1
   OR m.impact_level <> 'advisory'
   OR m.start_time >= b.requested_end_time
   OR (m.completion_time IS NOT NULL AND m.completion_time <= b.requested_start_time);
GO

PRINT '=== V10: constraint trust after bulk load (CHECK_CONSTRAINTS was requested; expect all rows Is_Not_Trusted = 0) ===';
SELECT OBJECT_NAME(parent_object_id) AS table_name, name AS constraint_name, is_not_trusted
FROM sys.check_constraints
WHERE OBJECT_NAME(parent_object_id) IN (
    'departments','users','spaces','facilities','space_facilities','maintenance',
    'bookings','booking_approvals','booking_sessions',
    'maintenance_impact_history','booking_advisory_acknowledgement',
    'space_type_allowed_purpose'
)
AND is_not_trusted = 1;
GO
-- Remediation on a SCRATCH database only, if V10 returns rows:
--   ALTER TABLE dbo.<table_name> WITH CHECK CHECK CONSTRAINT ALL;

PRINT '=== V11: foreign key trust after bulk load (expect 0 rows) ===';
SELECT OBJECT_NAME(parent_object_id) AS table_name, name AS fk_name, is_not_trusted
FROM sys.foreign_keys
WHERE OBJECT_NAME(parent_object_id) IN (
    'departments','users','spaces','facilities','space_facilities','maintenance',
    'bookings','booking_approvals','booking_sessions',
    'maintenance_impact_history','booking_advisory_acknowledgement',
    'space_type_allowed_purpose'
)
AND is_not_trusted = 1;
GO
-- Remediation on a SCRATCH database only, if V11 returns rows:
--   ALTER TABLE dbo.<table_name> WITH CHECK CHECK CONSTRAINT ALL;

PRINT '=== V12/Task09: spaces schema and instant-policy seed coverage (expect PASS) ===';
SELECT
    CASE
        WHEN COL_LENGTH(N'dbo.spaces', N'usage_policy') IS NULL
         AND COL_LENGTH(N'dbo.spaces', N'max_hours') IS NULL
        THEN 'PASS' ELSE 'FAIL'
    END AS spaces_schema_alignment,
    COUNT(*) AS allowed_purpose_rows,
    COUNT(DISTINCT space_type) AS allowed_space_types,
    CASE
        WHEN COUNT(*) = 18
         AND COUNT(DISTINCT space_type) = 4
        THEN 'PASS' ELSE 'FAIL'
    END AS allowed_purpose_coverage
FROM dbo.space_type_allowed_purpose;
GO

PRINT 'TASK14-VERIFY-COMPLETE: review PASS/FAIL markers and any non-empty result sets above.';
