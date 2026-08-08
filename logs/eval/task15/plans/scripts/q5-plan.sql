SET SHOWPLAN_XML ON;
GO

WITH escalation_events AS (
    SELECT
        mih.history_id,
        mih.maintenance_id,
        mih.changed_at AS escalation_time,
        mih.changed_by,
        mih.prior_level,
        mih.new_level,
        mih.reason AS escalation_reason,
        m.space_id,
        m.problem_description,
        m.status AS maintenance_status,
        m.start_time AS maintenance_start_time,
        m.completion_time AS maintenance_end_time
    FROM dbo.maintenance_impact_history mih
    INNER JOIN dbo.maintenance m
        ON m.maintenance_id = mih.maintenance_id
    WHERE mih.prior_level = 'advisory'
      AND mih.new_level = 'out-of-service'
      AND m.is_deleted = 0
)
SELECT
    ee.history_id,
    ee.escalation_time,
    escalator.full_name AS escalated_by,
    ee.prior_level,
    ee.new_level,
    ee.escalation_reason,
    ee.maintenance_id,
    ee.problem_description,
    ee.maintenance_status,
    ee.maintenance_start_time,
    ee.maintenance_end_time,
    s.space_id,
    s.space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    b.booking_id,
    b.requested_start_time,
    b.requested_end_time,
    b.purpose,
    b.expected_participants,
    b.status AS booking_status,
    requester.user_id AS requester_id,
    requester.full_name AS requester_name,
    requester.email AS requester_email,
    requester.phone_number AS requester_phone,
    baa.acknowledged_at,
    acknowledger.full_name AS acknowledged_by,
    ROUND(
        DATEDIFF_BIG(
            SECOND,
            CASE
                WHEN b.requested_start_time < ee.maintenance_start_time
                    THEN ee.maintenance_start_time
                ELSE b.requested_start_time
            END,
            CASE
                WHEN b.requested_end_time > COALESCE(ee.maintenance_end_time, b.requested_end_time)
                    THEN COALESCE(ee.maintenance_end_time, b.requested_end_time)
                ELSE b.requested_end_time
            END
        ) / 3600.0,
        2
    ) AS overlap_hours,
    CASE
        WHEN b.status = 'approved'
            THEN N'Contact requester: booking remains approved after escalation'
        WHEN b.status = 'checked_in'
            THEN N'Contact requester: session checked in after escalation'
        ELSE N'Contact requester: completed booking affected by escalation'
    END AS recommended_action
FROM escalation_events ee
INNER JOIN dbo.booking_approvals ba
    ON ba.decision = 'approved'
   AND ba.decision_time <= ee.escalation_time
INNER JOIN dbo.bookings b
    ON b.booking_id = ba.booking_id
   AND b.space_id = ee.space_id
   AND b.is_deleted = 0
   AND b.status IN ('approved', 'checked_in', 'completed')
   AND b.requested_start_time < COALESCE(ee.maintenance_end_time, CONVERT(DATETIME2, '9999-12-31T23:59:59'))
   AND b.requested_end_time > ee.maintenance_start_time
INNER JOIN dbo.booking_advisory_acknowledgement baa
    ON baa.booking_id = b.booking_id
   AND baa.maintenance_id = ee.maintenance_id
INNER JOIN dbo.spaces s
    ON s.space_id = ee.space_id
INNER JOIN dbo.users requester
    ON requester.user_id = b.requester_id
INNER JOIN dbo.users escalator
    ON escalator.user_id = ee.changed_by
INNER JOIN dbo.users acknowledger
    ON acknowledger.user_id = baa.acknowledged_by
ORDER BY ee.escalation_time DESC, b.requested_start_time ASC, b.booking_id ASC;
GO

SET SHOWPLAN_XML OFF;
GO
