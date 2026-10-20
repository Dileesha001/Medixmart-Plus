# Project understanding

## Sources and interpretation

- [Community project proposal](../temp-docs/Community%20Project%20Proposal%20%281%29.pdf): stakeholder needs, eight functional modules, FR01-FR20, and non-functional/security requirements.
- [Project blueprint and eight-week plan](../temp-docs/medixmart_plus_project_blueprint.md.pdf): concrete stack, standard folder layout, database entities, implementation tasks, and handover criteria.

The blueprint supplies the implementation baseline where the proposal lists alternatives. In particular, use Flutter for both Windows and Android, rather than introducing a separate Electron or C# desktop client. Business rules and database writes belong in the Express backend, as described in the blueprint. The proposal also mentions client-side business logic and cloud storage; those statements need reconciliation during detailed design, rather than creating competing architectures.

## Architecture and deployment

Flutter screens use Provider for shared state and services for authenticated JSON REST requests. The Express server validates requests, enforces roles, runs business logic, and accesses PostgreSQL. Scheduled server jobs handle expiry checks and birthday notifications. Messaging should be isolated behind a service so FCM or an agreed SMS provider can be selected later.

The blueprint's initial deployment puts Node.js and PostgreSQL on the pharmacy's Windows computer. The Windows client and Android devices on the same local network use that server. Cloud hosting remains an option in the proposal, not a requirement of this scaffold. Mobile access does not imply independent offline operation.

## Functional modules

| Module | Planned behavior |
| --- | --- |
| User and authentication management | Login, logout, password changes, protected routes, and role-based access for Admin and Pharmacist |
| Medicine and category management | Add, edit, search, and deactivate medicines; maintain categories, prices, and reorder levels |
| Stock and purchase management | Maintain suppliers and receive stock as separate batches with quantity, cost, received date, and expiry |
| Expiry and return alerts | Identify expired stock and stock within the seven-month return window; list return candidates by supplier |
| Sales and credit management | POS checkout, stock deduction, receipts, cash/credit sales, repayments, and outstanding balances |
| Customer management and notifications | Customer directory, birthdays, credit flags, and approved customer messages |
| Dashboard and reports | Sales totals, low-stock/expiry counts, stock and sales reports, outstanding credit, CSV/Excel exports |
| System administration | Users, settings, backups, exports, and audit-related information |

## Rules to preserve during implementation

1. Track stock per batch. Different expiry dates for the same medicine must remain distinguishable, and each sale item must identify its source batch.
2. Allocate sales from the soonest-expiring eligible batches first. The blueprint calls this FIFO, but the specified algorithm orders by expiry date (commonly called FEFO). Preserve the expiry-first behavior when naming or implementing it.
3. Complete a sale in one database transaction, locking eligible batch rows before deduction. Reject insufficient stock and expired batches; failure must leave stock, sale records, and credit balances unchanged.
4. Raise expiry/return warnings for batches with stock expiring within seven months. The blueprint schedules a daily 06:00 check and a startup catch-up; duplicate alerts must be avoided.
5. Raise low-stock alerts when total medicine stock reaches or falls below its reorder level. Agree how expired and returned stock affect available-stock totals before implementing queries.
6. Require a customer for credit sales, increase that customer's balance with the sale, and record repayments separately while reducing the balance.
7. Store password hashes, protect API routes with authentication and appropriate roles, validate inputs, and keep secrets out of source control. The blueprint specifies bcrypt and JWT.
8. Log customer messages and prevent duplicate birthday sends. FCM requires registered client device tokens; customer delivery through FCM or SMS needs a stakeholder decision.
9. Back up PostgreSQL regularly and verify restoration before handover. Use synthetic fixtures in the repository; keep real customer data and backup files outside source control.

## Data model baseline

The blueprint lists ten core tables: `users`, `categories`, `medicines`, `suppliers`, `batches`, `customers`, `sales`, `sale_items`, `credit_payments`, and `alerts`.

One medicine has many batches; one supplier has many batches; one sale has many sale items; each sale item links to the precise medicine and batch used. Customer sales and repayments feed the credit balance. Message logs, settings, audit records, and supplier-return history need detailed schema decisions; the scaffold does not invent those schemas.

## Delivery plan and open decisions

The blueprint plans four two-week sprints from October 5 to November 29, 2026: foundation/authentication, inventory/batches, POS/alerts, and reporting/handover. The critical path is login, medicines, batches, transactional sales, then alerts.

Before implementation, agree API payloads and error shapes, reconcile the deployment statements, confirm notification recipients and delivery method, define supplier-return recording, and settle the available-stock and expiry-date boundary rules. The scaffold reserves locations for these specifications, tests, deployment instructions, and user training materials.
