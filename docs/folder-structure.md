# Folder structure

The two application roots and their main source directories follow the blueprint's standard layout (page 5). Test, documentation, asset, script, and deployment folders support the later testing and handover tasks.

```text
Medixmart-Plus/
|-- medixmart-backend/
|   |-- src/
|   |   |-- config/
|   |   |-- routes/
|   |   |-- controllers/
|   |   |-- middleware/
|   |   |-- services/
|   |   |-- jobs/
|   |   |-- sql/
|   |   `-- utils/
|   `-- tests/
|       |-- unit/
|       |-- integration/
|       `-- fixtures/
|-- medixmart_app/
|   |-- lib/
|   |   |-- config/
|   |   |-- screens/
|   |   |   |-- auth/
|   |   |   |-- dashboard/
|   |   |   |-- medicines/
|   |   |   |-- categories/
|   |   |   |-- suppliers/
|   |   |   |-- stock/
|   |   |   |-- pos/
|   |   |   |-- customers/
|   |   |   |-- credit/
|   |   |   |-- alerts/
|   |   |   |-- reports/
|   |   |   `-- administration/
|   |   |-- providers/
|   |   |-- services/
|   |   |-- models/
|   |   |-- widgets/
|   |   `-- utils/
|   |-- assets/
|   |   |-- images/
|   |   |-- icons/
|   |   `-- fonts/
|   |-- test/
|   |   |-- unit/
|   |   `-- widget/
|   `-- integration_test/
|-- docs/
|   |-- project-overview.md
|   |-- folder-structure.md
|   |-- requirements/
|   |-- architecture/
|   |   `-- diagrams/
|   |-- api/
|   |-- testing/
|   |   |-- postman/
|   |   `-- uat/
|   |-- deployment/
|   |-- user-guide/
|   `-- project-management/
|-- scripts/
|   |-- backup/
|   `-- data-import/
|-- deployment/
|   |-- windows/
|   `-- android/
`-- temp-docs/
```

## Backend responsibilities

| Directory | Purpose |
| --- | --- |
| `src/config` | PostgreSQL connection pool and environment/settings configuration |
| `src/routes` | Express route declarations grouped by resource |
| `src/controllers` | HTTP request validation/coordination and response handling |
| `src/middleware` | Authentication, role checks, shared request checks, and error handling |
| `src/services` | Reusable stock allocation, sales/credit transactions, reporting, and notification delivery logic |
| `src/jobs` | Scheduled expiry checks and birthday processing; call services rather than duplicating logic |
| `src/sql` | Ordered schema, seed, function, trigger, and index scripts |
| `src/utils` | Small shared helpers such as async error wrappers |
| `tests` | Unit tests, database/API integration tests, and synthetic fixtures |

Use `src/sql` as the single SQL location, following the blueprint's directory tree; later sprint tasks abbreviate this as `sql/`. Do not create duplicate schema directories. Backend initialization will add `server.js` and `package.json` at `medixmart-backend/`, with an untracked local `.env` and a tracked `.env.example` containing placeholders.

## Flutter responsibilities

| Directory | Purpose |
| --- | --- |
| `lib/config` | API base URL, routing, and shared application configuration |
| `lib/screens` | Feature-specific screens; stock includes receiving batches and supplier-return views, POS includes receipts |
| `lib/providers` | Provider state such as authentication, cart, medicines, and customers |
| `lib/services` | API access, authenticated requests, receipt generation, and client integrations |
| `lib/models` | Typed API/domain data models |
| `lib/widgets` | Reusable UI components |
| `lib/utils` | Shared formatting and validation helpers |
| `assets` | Application images, icons, and fonts |
| `test`, `integration_test` | Unit/widget checks and complete application workflows |

Flutter initialization will generate `pubspec.yaml`, `lib/main.dart`, `android/`, and `windows/` inside `medixmart_app/`. These SDK-generated files are deliberately deferred rather than replaced with incomplete platform stubs. The top-level `deployment/android` and `deployment/windows` folders are for release configuration and packaging, not Flutter platform source.

## Supporting directories

`docs/requirements` holds the SRS and acceptance criteria. `docs/architecture` holds system/database design and editable diagrams. `docs/api` holds agreed endpoint and payload contracts. `docs/testing` holds test plans, Postman collections, and UAT evidence. `docs/deployment` holds installation/restore instructions, while top-level `deployment` holds packaging and service configuration. User training materials belong in `docs/user-guide`, and sprint plans/handover tracking in `docs/project-management`.

`scripts/backup` and `scripts/data-import` are for executable maintenance tooling. Backup outputs, real customer data, and credentials must stay outside source control. `temp-docs` retains the two original source PDFs unchanged.
