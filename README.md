# Medixmart Plus

Medixmart Plus is a pharmacy management system for MedixMart Pharmacy. It is planned as one Flutter application for Windows and Android, backed by a Node.js/Express REST API and PostgreSQL.

The system covers staff authentication, medicines and categories, suppliers, batch-based inventory, billing, customer credit and repayments, expiry and low-stock alerts, birthday notifications, dashboards, and reports.

## Repository layout

```text
Medixmart-Plus/
|-- medixmart-backend/   # Express API, business logic, scheduled jobs, and SQL
|-- medixmart_app/       # Shared Flutter client for Windows and Android
|-- docs/                # Requirements, architecture, API contracts, QA, and guides
|-- scripts/             # Database backup and legacy-data import tooling
|-- deployment/          # Windows server/app and Android release instructions
|-- temp-docs/           # Original proposal and implementation blueprint
`-- README.md
```

See [the project overview](docs/project-overview.md) for the requirements and decisions derived from the source documents, and [the folder guide](docs/folder-structure.md) for directory responsibilities.

## Current status

This repository contains the documented folder scaffold only. The Express server, Flutter project, database schema, dependencies, and tests have not been implemented or initialized. Empty directories contain `.gitkeep` files so Git retains the structure.

The next foundation tasks are to initialize the backend and Flutter projects, define the database schema and API contracts, then implement authentication. Follow the source blueprint's feature-branch and pull-request workflow, with at least one reviewer per PR.
