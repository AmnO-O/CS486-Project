# Task 15 - Index Tuning Report

## 1. Environment & Dataset

- Scratch database:
- SQL Server version:
- Task 14 booking count:
- Dataset date span:
- Task 14 verification result:
- Benchmark mode: `measured` / `static-only`
- Query parameters:

## 2. Query Selection

Mandatory targets: Q1 booking conflict check and Q2 room finder.

Additional reports selected:

| Query | Baseline logical reads | Baseline CPU ms | Baseline elapsed ms | Selection reason |
|---|---:|---:|---:|---|
| Q3/Q4/Q5 |  |  |  |  |
| Q3/Q4/Q5 |  |  |  |  |

## 2.1 Execution Plan Evidence

| Query | Before plan file | After plan file | Before hash | After hash | Cost delta | Main plan shift |
|---|---|---|---|---|---:|---|
| Q1 |  |  |  |  |  |  |
| Q2 |  |  |  |  |  |  |
| Q[ID] |  |  |  |  |  |  |
| Q[ID] |  |  |  |  |  |  |

## 3. Q1 - Booking Conflict Check

### 3.1 Baseline measurements

| Metric | Run 1 | Run 2 | Run 3 | Median |
|---|---:|---:|---:|---:|
| Logical reads |  |  |  |  |
| Physical reads |  |  |  |  |
| CPU ms |  |  |  |  |
| Elapsed ms |  |  |  |  |

### 3.2 Plan analysis

- Existing indexes:
- Dominant operators:
- Estimated vs actual rows:
- Predicate/selectivity observation:

### 3.3 Candidate index

```sql
-- Candidate only; not applied to production.
```

- Candidate name:
- Key columns and order:
- Included columns:
- Filter predicate:
- Expected benefit:
- Write/storage cost:

### 3.4 Comparison after candidate

| Metric | Baseline median | Candidate median | Delta | Delta % |
|---|---:|---:|---:|---:|
| Logical reads |  |  |  |  |
| CPU ms |  |  |  |  |
| Elapsed ms |  |  |  |  |

Plan change:

### 3.5 Recommendation

Adopt / modify / reject. Reason:

## 4. Q2 - Room Finder

### 4.1 Baseline measurements

| Metric | Run 1 | Run 2 | Run 3 | Median |
|---|---:|---:|---:|---:|
| Logical reads |  |  |  |  |
| Physical reads |  |  |  |  |
| CPU ms |  |  |  |  |
| Elapsed ms |  |  |  |  |

### 4.2 Plan analysis

- Existing indexes:
- Dominant operators:
- Facility-division cost:
- Booking/maintenance overlap cost:

### 4.3 Candidate index

```sql
-- Candidate only; not applied to production.
```

- Candidate name:
- Key columns and order:
- Included columns:
- Filter predicate:
- Expected benefit:
- Write/storage cost:

### 4.4 Comparison after candidate

| Metric | Baseline median | Candidate median | Delta | Delta % |
|---|---:|---:|---:|---:|
| Logical reads |  |  |  |  |
| CPU ms |  |  |  |  |
| Elapsed ms |  |  |  |  |

Plan change:

### 4.5 Recommendation

Adopt / modify / reject. Reason:

## 5. Report A - Q[ID]

Use the same five-part structure as Sections 3-4. Preserve the exact query
semantics and U4 parameters.

## 6. Report B - Q[ID]

Use the same five-part structure as Sections 3-4. Preserve the exact query
semantics and U4 parameters.

## 7. Summary & Adoption Table

| Query | Candidate index | Baseline median reads | Candidate median reads | CPU/elapsed result | Decision |
|---|---|---:|---:|---|---|
| Q1 |  |  |  |  |  |
| Q2 |  |  |  |  |  |
| Q[ID] |  |  |  |  |  |
| Q[ID] |  |  |  |  |  |

## 8. Limitations & Notes

- Benchmark cache controls:
- Plan capture method:
- Median calculation:
- Parameter values and U4 window:
- Existing indexes preserved:
- Static-only limitations, if applicable:
- Recommended follow-up migration/registry changes require reviewer approval.
