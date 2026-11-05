## Description
<!-- Provide a brief summary of the changes introduced by this pull request. -->

## Member / Component
- [ ] Member 1 (Architecture / Auth / Admin)
- [ ] Member 2 (UI / UX / Flutter Integration)
- [ ] Member 3 (Inventory / Batches / Categories)
- [ ] Member 4 (POS / Sales / Receipts)
- [ ] Member 5 (Customers / Credit / Messaging)
- [ ] Member 6 (QA / Reports / Export)

## Backend PR Review Checklist (Mandatory for Server Changes)
- [ ] **SQL Parameterization:** All SQL queries use parameter placeholders (`$1, $2`). No raw string interpolation.
- [ ] **Transaction Safety:** Multi-step database operations acquire a client and use an explicit transaction block (`BEGIN` -> `COMMIT` / `ROLLBACK`).
- [ ] **Connection Release:** Any acquired pool client (`getClient()`) is guaranteed released in a `finally` block.
- [ ] **Error Envelope:** All error responses follow `docs/api/conventions.md` via `src/utils/response.js` without leaking stack traces or internal DB credentials.
- [ ] **Soft Deactivation:** Master entities (medicines, users) are deactivated (`is_active = false`) instead of hard deleted.
- [ ] **Secret Hygiene:** Verified that no `.env`, passwords, token keys, or test credentials are committed.
- [ ] **Automated Tests:** Unit or integration tests added/updated under `tests/` and passing locally (`npm test`).

## How Has This Been Tested?
<!-- Describe the tests you ran to verify your changes. Include curl commands or test script names. -->

