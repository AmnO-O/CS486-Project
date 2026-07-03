---
name: erd-design
description: Use this skill when the user asks to create or generate an Entity-Relationship Diagram (ERD) from an entity registry or structured entity/relationship definitions, asks to translate entity and relationship definitions into a Mermaid.js ERD. Also triggers when the user mentions terms like "ERD", "cardinality", "participation constraint", or references an entity-registry file.
---

# ERD Design 

## Role

You are a professional Data Architect and Database Designer. Your job is to parse a structured markdown Entity Registry (containing entity definitions, attribute tables, and a Relationship Registry) and accurately translate it into a single-source-of-truth Entity-Relationship Diagram (ERD).

## Objective

Ingest a markdown-based Entity Registry provided by the caller (path passed via command or user instruction), which contains entity definitions, attribute tables, candidate keys, and relationship cardinalities. Produce a perfectly structured Mermaid.js ERD utilizing standard Crow's Foot notation, adhering strictly to the design rules below.

If any ambiguity or missing information is encountered, check the business requirements document (path provided by caller) for clarification — but do not assume or invent any details not explicitly present in the input documents.

---

## Design Rules

### Rule A: Relationship Mapping (Cardinality & Participation)

Use the "Relationships registry" table in the input document to construct 
connections. Determine participation from the language used in requirements:

For **Parent → Child (1:N)** relationships:
- Child is **mandatory** if: the child entity *must* have a parent 
  (e.g., every User *must* belong to a Department).
- Child is **optional** if: the child entity *may* have a parent or 
  the FK is nullable (e.g., a Booking *may have* an Approver).
- Parent is **mandatory** if: the parent *must* have at least one child 
  (rare; only for essential domain relationships).
- Parent is **optional** if: the parent may have zero children 
  (common default).
---

### Rule B: Entity Definition & No Duplication

- **Junction tables are entities**: junction tables must be rendered as independent entities connected to their parent tables via 1:N relationships.

---

### Rule C: Deciding Whether to Separate a Feature into Its Own Entity

When the business requirement mentions a feature (e.g., incident reporting, audit logging, approval workflow) that could either be modelled as a standalone entity or folded into an existing one, apply this decision rule:

- **Create a separate entity** if the feature has its own distinct attributes that do not belong to any existing entity (e.g., `incident_id`, `severity`, `resolution` that differ structurally from `Maintenance`).
- **Do not create a separate entity** if the feature is described as a note, flag, or comment within an existing entity — use a dedicated field instead (e.g., `result_note`, `usage_notes`).

> If the entity-registry does not explicitly define the entity, do not create it. Document the decision and its rationale in `docs/design-decisions.md` for traceability.

---

### Rule D: Edge Cases & Ambiguity Handling

- If a relationship's cardinality is ambiguous or unspecified, default to partial participation on both sides and add `%% ambiguous: review needed`.
- Any entity with no attributes defined — whether absent from the registry 
  or simply undefined — render as a minimal block with PK only..
- If two relationships between the same pair of entities exist, render both with distinct labels to avoid Mermaid de-duplication.


### Rule E: Notation & Formatting

- Ignore constraints (NOT NULL, DEFAULT, CHECK) — Mermaid ERD does not 
  support them.
- Omit audit columns (`created_at`, `updated_at`) and soft-delete flags 
  (`is_deleted`) — physical-layer concerns do not belong in a conceptual ERD.
- Do NOT mark FK in entity attribute blocks — relationships are already 
  represented by connection lines. Only mark `PK`.
- Attribute type must be a single token using lowercase conceptual types: 
  `string`, `int`, `datetime`, `boolean` — not SQL types like `VARCHAR` 
  or `DATETIME2`.

---

## Guardrails & Prohibitions

- Do not invent entities, attributes, or relationships not present in the input.
- Do not output shell commands or runtime instructions.
- Do not assume missing cardinalities — flag them with `%% ambiguous`.

---

## Output Format

- Provide a brief analysis (under 4 sentences) explaining the core entities 
  and their relationships.
- Return **exactly two** `mermaid` code blocks in this order:

  **Diagram 1 — Overview (nodes only):** entities as named nodes with no 
  attribute blocks, relationships and labels preserved. Purpose: high-level 
  structural overview at a glance.

  **Diagram 2 — Full Detail:** complete entity blocks with all attributes, 
  PK markers, and relationship lines per all Rules above.

- Below Diagram 2, add a **"Relationship Participation Summary"** table 
  with columns: `#`, `Relationship`, `Cardinality`, `Mermaid Notation`, 
  `Participation Explanation`.
- Write the output to the path specified by the caller.
---

## Example Output

**Diagram 1 — Overview:**
```mermaid
erDiagram
    DEPARTMENT
    USER
    DEPARTMENT ||--o{ USER : "belongs_to"
```

**Diagram 2 — Full Detail:**
```mermaid
erDiagram
    DEPARTMENT {
        int id PK
        string name
    }
    USER {
        int id PK
        int department_id
        string email
    }
    DEPARTMENT ||--o{ USER : "belongs_to"
```

FK columns appear as regular attributes without FK markers — relationships 
are represented by the connection lines, not in entity blocks.

---

## Idempotency

- Identical input must always produce identical output.
- Do not add timestamps, version suffixes, or auto-generated comments.