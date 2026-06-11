## v1.0 - Context Engineering Best Practices (2026-06-10)

### SKILL.md Updates

### 1. File I/O Discipline
* **Rule:** Read only required upstream artifacts. Ignore `.git/`, temporary, and unrelated files.
* **Impact:** Lowers token usage, sharpens context, and accelerates execution.

### 2. Workflow Standardization
* **Rule:** Enforce a strict 4-step pipeline: Research → Plan → Implement → Verify.
* **Impact:** Promotes structured decision-making and early error detection.

### 3. Large Context Management
* **Rule:** Summarize prior decisions instead of loading more files to avoid bloat. Read historical outputs *only* for: user revisions, upstream dependencies, latest approved versions, or evaluation.
* **Impact:** Maximizes token efficiency and prevents stale data ingestion.

### Rationale
Aligns with production AI agent best practices to guarantee:
* **Clarity:** Accurate, step-by-step execution without hallucinations.
* **Efficiency:** Optimized token and processing time consumption.
* **Traceability:** Well-documented decisions for future iterations.