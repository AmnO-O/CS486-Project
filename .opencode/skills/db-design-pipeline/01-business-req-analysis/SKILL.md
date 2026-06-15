Skill: db-design-pipeline:01-business-req-analysis

Title: Business Requirement Analysis

Purpose:
Produce the business requirement analysis prompt and expected behavior for Task 01, generating `outputs/01-business-req-analysis-G05.md` from `req/` and `docs/project-overview.md`.

Inputs:
- requirement files under req/ (required)
- docs/project-overview.md (required)
- --group (optional, default: G05)

Outputs:
- outputs/01-business-req-analysis-G{{group}}.md

Behavior / Steps:
1. Read docs/project-overview.md and all files under req/.
2. Identify project purpose, actors, core domain objects, and key activities.
3. Summarize booking request lifecycle, approval workflow, maintenance handling, and incident tracking.
4. Extract explicit business rules and constraints.
5. Record assumptions and unresolved ambiguities without assuming the database design is finalized.
6. Format the result as a final markdown deliverable.

Cognitive Rules / Guidelines:

- Role: act as a database design analyst and rule-enforcer (system-level persona).
- Input sources: only `docs/project-overview.md` and all files under `req/`.
- Output intent: produce a concise, reviewer-ready business requirement analysis in Markdown.
- Do NOT embed a static, hardcoded prompt template in this skill file — templates/responses are provided by the runtime or a separate `templates/` asset when needed.

Extraction priorities (in order):
1. Project purpose and scope
2. Actors / user roles and brief role descriptions
3. Candidate domain objects and important attributes
4. Key processes: booking lifecycle, approval workflow, maintenance, incidents
5. Explicit business rules, constraints, and invariants
6. Assumptions and unresolved ambiguities

Formatting expectations:
- Provide well-labelled Markdown sections matching the extraction priorities above.
- Prefer short enumerated lists and numbered business rules for clarity.
- Avoid prescribing table names, column names, or finalized schema details.

Guardrails and prohibitions:
- Do not invent capabilities, constraints, or actors not supported by the input sources.
- Do not output runtime instructions, shell commands, or system orchestration details.
- Do not assume the database design is finalized; record when design choices would be speculative.

Interoperability:
- The runtime/command should provide any output layout template if a specific visual format is required.
- The skill must enforce validation checks (see below) and return a structured summary suitable for the runtime to render into the final document.

Validation checks (post-generation):
- Verify the output includes all required sections.
- Verify the output is markdown-formatted.
- Verify the output does not assume a finalized database design.

Idempotency:
- Overwrite outputs/01-business-req-analysis-G{{group}}.md if it exists.

Notes:
- The skill should be prompt-focused and not include runtime shell behavior.
- Use only the specified input documents and do not reference other design artifacts as required sources.
