# Query 14 — Implementation Plan

## Action required
Append to `outputs/07-query-design-G05.sql` after the last `GO` (line ~853).

## SQL to append

```sql
-- ============================================================
-- Query 14: Lab availability by day-of-week and hour
-- ============================================================
-- --student-name: Cao Quang Hung
-- --target-user: student
-- --business-question: Based on booking history from the past
--    year, which days of the week and time slots have the
--    highest number of available project and computer
--    laboratories?
-- ============================================================
-- Business question:
--   Based on booking history from the past year, which days
--   of the week and time slots have the highest number of
--   available project and computer laboratories?
--
-- Target user(s):
--   Student
--
-- Why useful:
--   A student looking for a lab to work in does not want to
--   walk across campus only to find every workstation taken.
--   This query analyzes one year of booking history to reveal
--   which days of the week and hourly time slots consistently
--   have the most free lab spaces. By targeting a high-
--   availability window, the student maximizes their chance
--   of finding an open seat.
-- ============================================================

DECLARE @space_types    VARCHAR(255) = 'computer_lab,project_lab';
DECLARE @lookback_year  INT          = 1;
DECLARE @top_n          INT          = 10;

WITH
lab_spaces AS (
    SELECT [space_id], [space_code], [space_name]
    FROM [dbo].[spaces]
    WHERE [space_type] IN (
        SELECT [value] FROM STRING_SPLIT(@space_types, ',')
    )
),
total_labs AS (
    SELECT COUNT(*) AS [cnt] FROM [lab_spaces]
),
all_hours AS (
    SELECT 0 AS [h] UNION ALL SELECT 1  UNION ALL SELECT 2  UNION ALL SELECT 3
    UNION ALL SELECT 4  UNION ALL SELECT 5  UNION ALL SELECT 6  UNION ALL SELECT 7
    UNION ALL SELECT 8  UNION ALL SELECT 9  UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),
all_dow AS (
    SELECT N'Monday' AS [day_name], 1 AS [day_num]
    UNION ALL SELECT N'Tuesday',   2
    UNION ALL SELECT N'Wednesday', 3
    UNION ALL SELECT N'Thursday',  4
    UNION ALL SELECT N'Friday',    5
    UNION ALL SELECT N'Saturday',  6
    UNION ALL SELECT N'Sunday',    7
),
bookings_window AS (
    SELECT
        b.[space_id],
        b.[requested_start_time],
        b.[requested_end_time],
        (DATEPART(WEEKDAY, b.[requested_start_time]) + @@DATEFIRST + 6) % 7 + 1
            AS [dow_num]
    FROM [dbo].[bookings] b
    WHERE b.[is_deleted] = 0
      AND b.[status] IN ('approved', 'checked_in', 'completed')
      AND b.[requested_start_time] >= DATEADD(YEAR, -@lookback_year, GETDATE())
      AND b.[requested_start_time] < GETDATE()
),
occupied_lab_hours AS (
    SELECT DISTINCT
        bw.[dow_num],
        ah.[h]          AS [hour_slot],
        bw.[space_id]
    FROM [bookings_window] bw
    INNER JOIN [lab_spaces] ls ON bw.[space_id] = ls.[space_id]
    CROSS JOIN [all_hours] ah
    WHERE CAST(bw.[requested_start_time] AS TIME)
          < DATEADD(HOUR, ah.[h] + 1, '00:00')
      AND CAST(bw.[requested_end_time] AS TIME)
          > DATEADD(HOUR, ah.[h],     '00:00')
),
booked_counts AS (
    SELECT
        [dow_num],
        [hour_slot],
        COUNT(DISTINCT [space_id]) AS [booked_labs]
    FROM [occupied_lab_hours]
    GROUP BY [dow_num], [hour_slot]
)
SELECT TOP (@top_n)
    d.[day_name]                              AS [day_of_week],
    h.[h]                                     AS [hour],
    FORMAT(DATEADD(HOUR, h.[h], '00:00'), N'HH:mm') AS [time_from],
    FORMAT(DATEADD(HOUR, h.[h] + 1, '00:00'), N'HH:mm') AS [time_to],
    t.[cnt] - COALESCE(bc.[booked_labs], 0)   AS [available_labs],
    t.[cnt]                                   AS [total_labs],
    ROUND(
        100.0 * (t.[cnt] - COALESCE(bc.[booked_labs], 0)) / t.[cnt], 1
    )                                         AS [pct_available]
FROM [all_dow] d
CROSS JOIN [all_hours] h
CROSS JOIN [total_labs] t
LEFT JOIN [booked_counts] bc
    ON bc.[dow_num] = d.[day_num]
   AND bc.[hour_slot] = h.[h]
WHERE t.[cnt] > 0
ORDER BY [available_labs] DESC, d.[day_num], h.[h];

-- Fallback: no lab spaces found
SELECT N'No lab spaces found matching the given types.' AS [message]
WHERE (SELECT [cnt] FROM [total_labs]) = 0;
GO
```

## Also update

1. `logs/eval/task07/2026-06-28-1500-07-query-compile.log` — append Query 14 verification
2. `logs/trajectory/task07/2026-06-28-1500-07-query-caoquanghung.md` — append Query 14 section
