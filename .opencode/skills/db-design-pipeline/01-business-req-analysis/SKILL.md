Skill: db-design-pipeline:01-business-req-analysis

Title: Business Requirement Analysis

Purpose:
Extract actors, entities, attributes, relationships, cardinalities, business rules, assumptions, and open questions from the requirement files under `req/` and produce a readable analysis artifact `outputs/01-business-req-analysis-G{{group}}.md`.

Inputs:
- requirement files under `req/` (required)
- `--group` (optional, default: G05)

Outputs:
- `outputs/01-business-req-analysis-G{{group}}.md`

Behavior / Steps:
1. Read all requirement files under `req/` (or the provided requirement path) and split content into logical sections (overview, actors, requirements, constraints).
2. Identify and list actors with brief role descriptions.
3. Identify candidate entities and their key attributes.
4. Identify relationships between entities and note cardinalities and participation (mandatory/optional) where explicit.
5. Extract hard business rules and convert them into explicit, numbered business rules.
6. Record assumptions where the requirement is ambiguous and list open questions for follow-up.
7. Produce a short mapping of entities -> suggested relation/table names.
8. Output a Markdown file containing the above sections and a short summary for reviewers.

Prompt template (internal to the skill):
```
You are a database design assistant. Read the following business requirement content from all files under req/ and extract:
- a concise purpose statement (1-2 sentences)
- a list of actors
- a list of candidate entities with their important attributes
- relationships and cardinalities (if stated)
- explicit business rules (numbered)
- assumptions and open questions

Input requirement:
{{requirement_text}}

Return the result in Markdown sections titled: Purpose, Actors, Entities, Relationships, Business Rules, Assumptions, Open Questions, Suggested Table Mapping.
```

Validation checks (post-generation):
- Ensure the output contains at least one `Actors` item and at least three `Entities`.
- Ensure at least one business rule is present.

Idempotency:
- Overwrite `outputs/01-business-req-analysis-G{{group}}.md` if it exists.

Notes for implementers:
- The skill is intentionally modular so teams can implement each step independently and test outputs incrementally.
- Keep the prompt concise to reduce token usage; for long requirements, pre-process to extract only the relevant prose.
