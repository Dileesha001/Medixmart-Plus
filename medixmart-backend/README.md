# Medixmart Plus — Backend Service

The core REST API and business logic engine for Medixmart Plus, powering both Windows desktop and Android mobile pharmacy clients.

---

## 1. Technology Stack

- **Runtime:** Node.js (v24+ / v26 LTS recommended)
- **Framework:** Express.js (v4.21+)
- **Database:** PostgreSQL 17
- **Database Client:** `pg` (node-postgres) connection pool
- **Security:** `helmet`, `cors`, `bcrypt` (password hashing), `jsonwebtoken` (JWT issuance & verification)
- **Scheduling:** `node-cron`
- **Testing:** `supertest`, Node.js native assertion suite

---

## 2. Directory Structure

```text
medixmart-backend/
|-- src/
|   |-- config/          # Environment validation & PostgreSQL connection pool
|   |   |-- environment.js
|   |   `-- db.js
|   |-- controllers/     # Request handlers, input validation & HTTP orchestration
|   |-- middleware/      # Auth (JWT), role checking (RBAC), and centralized error handling
|   |-- routes/          # Express route definitions grouped by domain resource
|   |-- services/        # Reusable business logic, FEFO stock allocation, transactions
|   |-- jobs/            # Scheduled cron jobs (06:00 Expiry alert, 08:00 Birthday greeting)
|   |-- sql/             # Schema scripts, migrations, functions, and seed data
|   |-- utils/           # Shared response builders and async error wrappers
|   |   `-- response.js
|   |-- app.js           # Express application configuration & middleware stack
|   `-- server.js        # HTTP server entry point, network binding & graceful shutdown
|-- tests/
|   |-- fixtures/        # Test data fixtures
|   |-- integration/     # API integration tests (e.g. run_health_test.js)
|   `-- unit/            # Isolated business logic unit tests
|-- .env.example         # Tracked template for environment configuration
|-- .env                 # Private, local environment configuration (NEVER commit)
`-- package.json
```

---

## 3. Local Developer Setup

### 3.1 Prerequisites
- **Node.js:** v24 or higher (`node --version`)
- **npm:** v11 or higher (`npm --version`)
- **PostgreSQL 17:** Running on local port `5432` (`pg_isready -h 127.0.0.1 -p 5432`)

### 3.2 Installation
From the `medixmart-backend` directory:
```bash
npm install
```

### 3.3 Environment Configuration
1. Copy the template to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Configure `.env` with your local PostgreSQL credentials:
   ```dotenv
   PORT=3000
   NODE_ENV=development

   DB_HOST=127.0.0.1
   DB_PORT=5432
   DB_NAME=postgres
   DB_USER=postgres
   DB_PASSWORD=your_local_password
   DB_MAX_CONNECTIONS=20
   DB_IDLE_TIMEOUT_MS=30000
   DB_CONNECTION_TIMEOUT_MS=5000

   JWT_SECRET=generate_a_random_32_character_string_here
   JWT_EXPIRES_IN=8h

   CORS_ORIGIN=*
   TIMEZONE=Asia/Colombo
   EXPIRY_WINDOW_MONTHS=7
   ```
   > [!IMPORTANT]
   > The server performs strict startup validation. If any required variable (`PORT`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`) is empty, the process aborts immediately.

### 3.4 Running the Application
- **Development mode (with auto-restart on file change):**
  ```bash
  npm run dev
  ```
- **Production mode:**
  ```bash
  npm start
  ```

### 3.5 Running Tests
Execute the automated integration test suite:
```bash
npm test
```

---

## 4. Health Check & Verification

Once started, the server binds to `0.0.0.0:3000` to allow local loopback and Wi-Fi LAN access.

Verify the service by requesting the health endpoint:
```bash
curl -i http://127.0.0.1:3000/api/health
```

Expected response (`HTTP 200 OK`):
```json
{
  "success": true,
  "status": "healthy",
  "uptimeSeconds": 4,
  "timestamp": "2026-11-05T07:16:09.444Z",
  "environment": "development",
  "database": {
    "connected": true,
    "database": "postgres",
    "user": "postgres",
    "serverTime": "2026-11-05T07:16:09.413Z"
  }
}
```

---

## 5. Development Guidelines & Pull Requests

All team members must follow these standards before submitting code:
1. **API Conventions:** Strictly follow [`docs/api/conventions.md`](../docs/api/conventions.md). Always format responses using [`src/utils/response.js`](src/utils/response.js).
2. **SQL Safety:** Never interpolate strings into SQL statements. Use parameterized queries `$1, $2`.
3. **Transaction Safety:** Wrap multi-entity mutations in a single client transaction (`getClient()`, `BEGIN`, `COMMIT`, `ROLLBACK` in `try...finally`).
4. **PR Review Checklist:** Consult [`docs/project-management/backend-pr-checklist.md`](../docs/project-management/backend-pr-checklist.md) before opening a pull request.
