# Member 1: foundation tasks 1-3

Review date: 2026-10-23. Scope: development computer and repository only.

## Task 1: review and list responsibilities - completed locally

Reviewed the complete [proposal](../../temp-docs/Community%20Project%20Proposal%20%281%29.pdf) and [blueprint](../../temp-docs/medixmart_plus_project_blueprint.md.pdf). This is a responsibility inventory, not evidence that the listed features have been implemented.

### Backend

- Own the Express foundation: environment validation, PostgreSQL pool, health/readiness checks, JSON parsing, CORS, routes, async error propagation, consistent errors, safe logs and graceful shutdown.
- Coordinate API contracts, endpoint ownership and integration with the Windows/Android Flutter client; maintain request/error examples and assist client integration.
- Lead backend review across medicine/category CRUD and deactivation, suppliers, batch receipts, customer details, sales, credit repayments, alerts, dashboards and report/export APIs.
- Coordinate the schema with Member 3: users, categories, medicines, suppliers, batches, customers, sales, sale_items, credit_payments and alerts; agree additional settings, audit, messaging and optional return-history records.
- Review server-authoritative prices/totals, validation, parameterized SQL, database constraints and safe handling of historical references.
- Review expiry-first batch allocation with Member 4: row locks, one connection per transaction, rollback, concurrency, sale-item batch traceability and consistent customer-credit changes.
- Own the daily seven-month expiry check, duplicate prevention, startup catch-up and execution logs. Blueprint baseline: 06:00 daily; timezone/boundaries still require agreement.
- Own the low-stock trigger/service integration after stock changes, including the threshold equality case and consistent eligible-stock totals; coordinate alert lifecycle with Member 3.
- Review Member 5's daily birthday processing, interchangeable messaging service, recipient eligibility, send logs, duplicate prevention and development-only test endpoint.
- Coordinate query performance, measured indexes, backend tests, integration/security checks and acceptance-test fixes with Member 6.

### Security

- Implement username/password login, bcrypt password hashes, JWT issuance and verification, protected routes and Admin/Pharmacist authorization enforced on the server.
- Define logout/session invalidation and password-change behavior; handle disabled users and safe administrator seeding.
- Validate inputs before processing/storage; use safe SQL and safe errors; restrict payload sizes and avoid exposing stack traces or SQL internals.
- Keep environment files, token secrets, database credentials and messaging keys outside Git; separate restricted application database access from administrative access.
- Restrict customer data to authorized staff; keep passwords, tokens and private customer details out of logs and exports.
- Apply security headers and login rate limiting; review dependencies and disable development endpoints before release.
- Protect database/network access, backup files and credential handover; verify authorization across all feature routes.

### Administration

- Own protected user listing, creation, update and disabling; enforce allowed roles and username uniqueness and preserve a final usable administrator.
- Own agreed settings read/update behavior and coordinate validation/schema changes.
- Coordinate audit-related records and authorized access without recording secrets.
- Own operational backup/export access and service controls; Member 6 owns report/export implementation, with Member 1 reviewing access and integration.
- Review backend pull requests, request corrections and follow the team's review/merge workflow; maintain setup, recovery and troubleshooting notes.

### Deployment and handover

- Prepare Node.js, npm, PostgreSQL and database tooling on development and pharmacy computers.
- Baseline deployment: Node.js/Express and PostgreSQL on the pharmacy Windows computer; Windows and Android clients connect over the local network.
- Create production database/account and environment configuration with fresh secrets; apply reviewed SQL and coordinate legacy-data import with Members 3-5.
- Configure automatic Windows service/startup, stable local server address and only required firewall access; verify Wi-Fi client connectivity and reboot recovery.
- Automate pg_dump backups outside the repository; agree frequency/retention/failure reporting and demonstrate restore into a separate database.
- Support final installed-system checks and UAT with Member 6; securely hand over credentials, service controls, installation/recovery instructions and support contacts.

### Decisions still requiring agreement

The proposal allows cloud hosting and mentions client-side business logic; the blueprint specifies a local Express/PostgreSQL server with server-side business rules. Treat the blueprint as the implementation baseline pending stakeholder confirmation. Confirm roles, expiry-day eligibility/timezone, available-stock definitions, monetary rounding/discounts, report ownership, messaging channel/recipients/costs, optional supplier-return mutation and backup policy. The blueprint calls allocation FIFO but orders by expiry date; preserve the expiry-first behavior (FEFO).

## Task 2: inspect and confirm locations - completed locally

Verified these directories exist; they currently contain scaffold placeholders, not implemented backend code.

| Responsibility | Confirmed repository location |
| --- | --- |
| Database pool and environment configuration | `medixmart-backend/src/config/` |
| Express resource routes | `medixmart-backend/src/routes/` |
| HTTP validation, coordination and responses | `medixmart-backend/src/controllers/` |
| Reusable business logic and transactions | `medixmart-backend/src/services/` |
| Scheduled expiry and birthday jobs | `medixmart-backend/src/jobs/` |
| Schema, seeds, functions, triggers and indexes | `medixmart-backend/src/sql/` |
| Authentication, authorization and error middleware | `medixmart-backend/src/middleware/` |
| Shared helpers | `medixmart-backend/src/utils/` |
| Unit/integration tests and fixtures | `medixmart-backend/tests/` |
| Backup and import tools | `scripts/backup/`, `scripts/data-import/` |
| Service/release configuration | `deployment/windows/`, `deployment/android/` |
| Operational instructions | `docs/deployment/` |

Use `src/sql/` as the single SQL location, including where later blueprint examples abbreviate it as `sql/`. Backend initialization will later add root `server.js`, `package.json`, tracked `.env.example` and ignored `.env`. No backend initialization is part of tasks 1-3. See also [folder structure](../folder-structure.md).

## Task 3: development tools - completed locally

| Tool | Verified result |
| --- | --- |
| Git | Installed; `git --version`: 2.55.0.windows.5 |
| Node.js | Installed; `node --version`: v24.20.0 |
| npm | Installed; `npm --version`: 11.19.0 |
| PostgreSQL | Installed 17.11; `psql --version` verified; `postgresql-x64-17` service running |
| pgAdmin | Installed 9.18; winget installation succeeded and runtime executable version verified |

Existing working tools were retained. PostgreSQL and pgAdmin were not found in PATH, the standard PostgreSQL installation location or winget's installed package inventory before installation.

PostgreSQL verification: `pg_isready -h 127.0.0.1 -p 5432` returned accepting connections. An authenticated `SELECT current_database(), current_user, 1 AS connection_ok;` returned database `postgres`, user `postgres`, and `connection_ok = 1`. No application schema/database has been created yet. pgAdmin GUI workflows have not been exercised.

PostgreSQL binaries are at `C:\Program Files\PostgreSQL\17\bin\`; use the full path if the current terminal cannot resolve `psql`. pgAdmin is at `%LOCALAPPDATA%\Programs\pgAdmin 4\runtime\pgAdmin4.exe`. Register a local server in pgAdmin with host `127.0.0.1`, port `5432`, maintenance database `postgres` and user `postgres`.

The generated development administrator credential is stored in Git-ignored `secrets/postgres-development.xml`, encrypted with Windows DPAPI for the installing Windows user. In that user's normal PowerShell session, `Import-Clixml` loads it as a PSCredential. Keep this file private; it is not a portable backup and must not be reused as the application's production credential. No plaintext password is included in this document.

The winget PostgreSQL download failed with HTTP 403. The fallback downloaded the same vendor installer directly and verified SHA-256 `612c7f5400a003aaffa0372cb273eed52278f93c680ab911eb9cb2229e329072` before successful unattended installation. pgAdmin installed through winget.

This document records local work. Team review and merge required by the blueprint remain separate release-workflow steps; no review or merge is claimed here.
