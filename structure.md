CS486/
├── README.md
├── AGENTS.md                          [KEEP] Always-loaded: quy tắc cứng, cross-tool
├── .gitignore
├── package.json
├── package-lock.json
│
├── req/
│   ├── CS486_Project.pdf
│   ├── CS486_Project.txt
│   └── business-requirement.md
│
├── docs/                              [NEW] Tầng 2 — chi tiết theo domain
│   ├── README.md                      Index + required reading order
│   ├── project-overview.md            (← từ memory/ProductContext.md)
│   ├── tech-stack.md                  (← từ memory/TechStack.md)
│   ├── db-design-pipeline.md          Quy trình 7 bước, workflow chi tiết
│   ├── entity-registry.md             Entities & attributes (task 01→07)
│   ├── schema-registry.md             Relational schema đã thống nhất
│   └── design-decisions.md            Lý do các quyết định thiết kế
│
├── memory/                            Tầng 4 — persistent session memory
│   ├── MEMORY.md                      [NEW] Index — 1 dòng/entry, AI scan đầu session
│   ├── ActiveContext.md               [KEEP] Task đang làm, trạng thái session
│   └── Progress.md                    [KEEP] Task nào xong / chưa xong
│
├── .opencode/
│   ├── commands/
│   │   ├── 01-generate-business-req.md
│   │   ├── 02-generate-erd.md
│   │   ├── 03-generate-logical-design.md
│   │   ├── 04-generate-design-validation.md
│   │   ├── 05-generate-ddl.md
│   │   ├── 06-generate-sample-data.md
│   │   ├── 07-generate-query-design.md
│   │   ├── file-evaluation.md
│   │   └── outputs-evaluation.md
│   │
│   ├── skills/
│   │   └── db-design-pipeline/
│   │       ├── SKILL.md
│   │       └── templates/
│   │           ├── 01-business-req-analysis/
│   │           ├── 02-erd-design/
│   │           ├── 03-logical-design/
│   │           ├── 04-design-validation/
│   │           ├── 05-ddl/
│   │           ├── 06-sample-data/
│   │           └── 07-query-design/
│   │
│   └── evaluations/
│       ├── rubric.md
│       ├── improvement_logs.md
│       ├── evaluations.md
│       └── templates/
│           ├── 01-business-req-analysis-eval.md
│           ├── 02-conceptual-erd-eval.md
│           ├── 03-logical-design-eval.md
│           ├── 04-design-validation-eval.md
│           ├── 05-ddl-eval.md
│           ├── 06-sample-data-eval.md
│           └── 07-query-design-eval.md
│
├── outputs/
│   ├── 01-business-req-analysis-G05.md   [DONE ✓]
│   ├── 02-erd-design-G05.md
│   ├── 03-logical-design-G05.md
│   ├── 04-design-validation-G05.md
│   ├── 05-db-definition-G05.sql
│   ├── 06-sample-data-G05.sql
│   └── 07-query-design-G05.sql
│
├── report/
│   └── G05_Report.pdf
│
└── logs/
    ├── file-eval/
    │   └── YYYY-MM-DD-{task}-reviewer-N.log
    └── output-eval/
        └── YYYY-MM-DD-HHMM-overall-evaluation.log