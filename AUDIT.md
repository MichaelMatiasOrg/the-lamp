# The Lamp - Comprehensive Codebase Audit

**Date:** 2026-02-06
**Scope:** Full-stack audit covering security, performance, code quality, accessibility, database, deployment, and operations.

---

## Executive Summary

The Lamp is a well-functioning Kanban dashboard with a minimal dependency footprint and thoughtful architectural decisions (action-based API, immutable audit log, local mock mode). However, the audit identified **12 critical**, **25 high**, and **40+ medium** severity issues across security, accessibility, and operational reliability. The most urgent concerns are XSS vulnerabilities in the frontend, a path traversal risk in the server, hardcoded credentials in deploy scripts, and complete absence of ARIA/accessibility support.

### Findings by Category

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Security | 5 | 6 | 6 | - |
| Frontend XSS & Safety | 4 | 3 | 3 | - |
| Accessibility | 2 | 3 | 4 | 2 |
| Performance | - | 4 | 6 | 2 |
| Error Handling | 2 | 3 | 3 | - |
| Code Quality | - | 3 | 5 | 2 |
| Database & Data Integrity | 1 | 3 | 5 | 2 |
| Deployment & Operations | 1 | 4 | 5 | - |
| **Total** | **15** | **29** | **37** | **8** |

---

## TODO: Prioritized Action Items

### Phase 1 — Critical Security Fixes (Do Immediately)

- [ ] **SEC-1: Fix path traversal vulnerability in static file serving** (`server.js:1672-1685`). The file path from `req.url` is joined with `__dirname` without validating the resolved path stays within the project directory. An attacker can request `/../../../etc/passwd` to read arbitrary files. Fix: resolve the path and verify it starts with `__dirname`.

- [ ] **SEC-2: Revoke hardcoded Supabase anon key in deploy.sh** (`deploy.sh:10`). A valid JWT token is committed to version control. Revoke it in the Supabase dashboard, generate a new key, and require the env var without a fallback default.

- [ ] **SEC-3: Apply `escapeHtml()` to all user content rendered via innerHTML** (`index.html` — ~30 locations). Task titles, descriptions, comments, project names, audit log entries, and console session data are all rendered unescaped. The `escapeHtml()` function exists (line 2592) but is only used for subtasks. Apply it consistently to all user-generated content.

- [ ] **SEC-4: Add authentication to task/project write endpoints** (`server.js:1250-1382`). POST to `/api/tasks` and `/api/projects` does not call `checkAuth()`. Any client can create, update, or delete tasks without a token. Add `if (!checkAuth(req, res)) return;` to these handlers.

- [ ] **SEC-5: Fix SSE CORS wildcard** (`server.js:1166`). The `/api/events` endpoint hardcodes `Access-Control-Allow-Origin: *`, bypassing the CORS whitelist used by all other endpoints. Use the same origin checking logic.

- [ ] **SEC-6: Sanitize taskId in image upload handler** (`server.js:1468`). The `taskId` from the request body is used in a Supabase update without passing through `sanitizeId()`.

### Phase 2 — High-Priority Fixes (This Week)

- [ ] **SEC-7: Remove hardcoded Supabase URL and Gist ID defaults from server.js** (`server.js:13,17`). These expose infrastructure identifiers if the code is public. Require them via env vars and fail fast if missing in production.

- [ ] **SEC-8: Require API_TOKEN in production** (`server.js:49`). Currently optional — if unset, all write operations are unauthenticated. Add startup validation: if `SERVICE_NAME` is `production` or `staging`, require `API_TOKEN`.

- [ ] **SEC-9: Add Content Security Policy header** (`index.html`). No CSP meta tag exists. The 70+ inline `onclick`/`onchange` handlers prevent a strict CSP, but adding `script-src 'unsafe-inline'` with other restrictions is still an improvement.

- [ ] **DB-1: Add foreign key constraint on tasks.project_id** (`supabase/schema.sql:22`). Currently a bare TEXT field — deleting a project orphans all associated tasks. Add `REFERENCES projects(id) ON DELETE SET NULL`.

- [ ] **DB-2: Add CHECK constraints on enum-like columns** (`supabase/schema.sql:11-13,31`). `column_name`, `priority`, `task_type`, and `projects.status` accept any text. Add CHECK constraints matching the valid values used in server.js.

- [ ] **PERF-1: Replace `fs.readFileSync` with async `fs.readFile`** (`server.js:1679`). Every static file request blocks the event loop. Use the async variant or cache file contents at startup.

- [ ] **PERF-2: Add timeout for SSE client cleanup** (`server.js:1083,1170`). Dead SSE connections that never fire a `close` event accumulate forever. Add a heartbeat interval and remove clients that don't respond.

- [ ] **PERF-3: Add timeouts to external HTTPS requests** (`server.js:1524,1596`). OpenAI API calls have no timeout configured. A hung request ties up server resources indefinitely. Add `apiReq.setTimeout(30000)`.

- [ ] **ERR-1: Add graceful shutdown handler** (`server.js:1688-1701`). No SIGTERM/SIGINT handler exists. SSE connections are dropped without warning, and in-flight requests are abandoned on deploy. Add `process.on('SIGTERM', ...)` to close the server gracefully.

- [ ] **ERR-2: Add process-level error handlers**. No `process.on('uncaughtException')` or `process.on('unhandledRejection')` handlers. Unhandled errors crash the process silently.

- [ ] **A11Y-1: Add ARIA attributes throughout the frontend** (`index.html`). Zero `aria-label`, `aria-describedby`, `aria-live`, or `role` attributes exist anywhere. Modals lack `role="dialog"`, live regions lack `aria-live="polite"`, and icon-only buttons (emoji) lack `aria-label`.

- [ ] **A11Y-2: Remove `user-scalable=no` from viewport meta tag** (`index.html:5`). This prevents users from zooming, violating WCAG 2.1 SC 1.4.4.

- [ ] **A11Y-3: Add screen reader text for emoji-only elements** (`index.html` — throughout). Buttons like `<button>📦</button>` convey no meaning to screen readers. Add `aria-label` or visually-hidden text.

- [ ] **OPS-1: Create .env.example** documenting all required and optional environment variables with descriptions.

- [ ] **OPS-2: Add a CI workflow** (`.github/workflows/test.yml`). Currently no automated checks run on commits or PRs. At minimum: `node --check server.js`, and later: lint + test.

### Phase 3 — Medium-Priority Improvements (Next 2 Weeks)

- [ ] **SEC-10: Rate-limit write endpoints** (`server.js`). Currently only `/api/generate-image` and `/api/transcribe` are rate-limited. Task creation, updates, and deletes have no rate limits.

- [ ] **SEC-11: Validate X-Forwarded-For before trusting** (`server.js:1151-1154`). Rate limiting uses the `X-Forwarded-For` header, which can be spoofed. Only trust it if behind a known proxy (Render).

- [ ] **SEC-12: Restrict audit table INSERT to service role** (`supabase/audit-table.sql:26`). Currently `WITH CHECK (true)` — anyone with the anon key can insert fake audit records.

- [ ] **DB-3: Add migration version tracking table** (`supabase/`). No system tracks which migrations have been applied. Create a `migrations` table and insert a row for each applied migration.

- [ ] **DB-4: Normalize `seen_at` to TIMESTAMPTZ** (`supabase/schema.sql:16`). Currently `BIGINT` (Unix timestamp) while all other temporal columns use `TIMESTAMPTZ`. This creates type coercion bugs.

- [ ] **DB-5: Add composite indexes for common queries** (`supabase/schema.sql`). Queries like `WHERE column_name = X AND archived = false` and `WHERE project_id = X AND archived = false` lack composite indexes.

- [ ] **PERF-4: Unbounded rate-limit map growth** (`server.js:60,94-99`). The `rateLimits` Map only cleans up every 5 minutes. Under heavy load from many IPs, memory grows unbounded between cleanups. Use a shorter interval or LRU eviction.

- [ ] **PERF-5: Comments loaded unconditionally with tasks** (`server.js:329`). `getTasks()` fetches all comments even if the client only needs task metadata. Consider lazy-loading comments per task, or paginating.

- [ ] **PERF-6: Add `loading="lazy"` to images** (`index.html` — task images, celebration images, comment images). No images use lazy loading.

- [ ] **ERR-3: Wrap scheduled backup in try/catch** (`server.js:1077-1080`). `setInterval(async () => { await backupToGist(); })` has no error handling. If the backup promise rejects, it's an unhandled rejection.

- [ ] **ERR-4: Add concurrent backup execution guard** (`server.js:1077`). If a backup takes longer than the 6-hour interval, the next execution overlaps. Add a lock flag.

- [ ] **ERR-5: Standardize API error response format** (`server.js`). Some errors return `{ ok: false, errors: [] }`, others return `{ error: '...' }`. Pick one format.

- [ ] **CODE-1: Split `handleApiRequest` into route handlers** (`server.js:1157-1638`). At 481 lines, this function handles routing, validation, auth, and business logic for every endpoint. Extract per-endpoint handlers.

- [ ] **CODE-2: Parse URL once at handler entry** (`server.js`). URL is parsed differently in multiple places (`new URL()`, `req.url.split('/')`, `.startsWith()`). Parse once and pass the result.

- [ ] **CODE-3: Remove dead `saveTasks()` function** (`index.html:2125-2165`). Returns `false` on line 1, making all subsequent code unreachable.

- [ ] **UX-1: Replace `alert()`/`prompt()`/`confirm()` with inline UI** (`index.html` — 8+ locations). Blocking browser dialogs disrupt the user experience. Use toast notifications and custom modals.

- [ ] **UX-2: Implement offline change queue** (`index.html:2071-2083`). Offline mode is read-only. Changes made while offline are lost. Queue mutations and sync when reconnected.

- [ ] **UX-3: Check `response.ok` after every fetch** (`index.html` — 10+ locations). Multiple fetch calls don't verify the response status before calling `.json()`, causing cryptic errors on server failures.

- [ ] **A11Y-4: Associate form labels with inputs** (`index.html:1774-1810`). Labels exist but lack `for` attributes linking to their inputs.

- [ ] **A11Y-5: Add focus management for modals** (`index.html:2598,2885`). Opening/closing modals doesn't trap or restore keyboard focus.

- [ ] **OPS-3: Replace sleep-based deploy wait with health check polling** (`deploy.sh:43-46`). Currently waits a fixed 60 seconds. Poll `/api/health` instead, with a timeout.

- [ ] **OPS-4: Add monitoring and alerting**. No error-rate, response-time, or database connectivity alerts exist. At minimum, set up uptime monitoring on `/api/health`.

- [ ] **OPS-5: Document disaster recovery procedure**. No RTO/RPO defined, no tested restore process. The restore command in `sync.sh` is intentionally disabled.

### Phase 4 — Low-Priority & Long-Term

- [ ] **PERF-7: Wrap frontend JavaScript in IIFE or module** (`index.html`). ~25-30 mutable global variables pollute the window scope.

- [ ] **PERF-8: Add pagination or virtualization for large task lists** (`index.html:2234-2255`). All tasks for a column render at once with no limit.

- [ ] **CODE-4: Remove hardcoded author defaults** (`server.js:531,552,609-611`). Author is hardcoded as `'michael'` or `'genie'` in multiple places. Require it from the request.

- [ ] **CODE-5: Use UUID or crypto.randomUUID() for task IDs** (`server.js:516`, `index.html:2020`). `Date.now().toString()` can collide if two tasks are created simultaneously.

- [ ] **DB-6: Review whether fully-open SELECT RLS policies are intentional** (`supabase/schema.sql:91-95`). All tables use `USING (true)` for SELECT — anyone with the anon key can read everything. If this is a public dashboard, document the decision. If not, scope the policies.

- [ ] **DB-7: Add backup retention policy**. Old backups in `$HOME/clawd/dashboard/backups/` are never cleaned up.

- [ ] **OPS-6: Add dev dependencies** (`package.json`). No test framework, linter, or formatter is installed. Add `jest`, `eslint`, `prettier`, and `nodemon` as devDependencies with corresponding npm scripts.

- [ ] **OPS-7: Add pre-commit hooks** (e.g., via `husky` + `lint-staged`). No hooks prevent committing broken or unformatted code.

- [ ] **A11Y-6: Improve color contrast for low-opacity text** (`index.html:25-26`). `rgba(255,255,255,0.4)` on dark backgrounds may fail WCAG AA contrast requirements.

- [ ] **PWA-1: Add a Service Worker** (`index.html`). The PWA manifest exists but no service worker is registered. Without one, the app cannot work offline or be installed reliably.

---

## Detailed Findings by Area

### 1. Security

#### 1.1 Server-Side

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| SEC-1 | **CRITICAL** | `server.js:1672-1685` | Path traversal in static file serving — `req.url` joined with `__dirname` without validation |
| SEC-4 | **CRITICAL** | `server.js:1250-1382` | No auth on task/project POST endpoints — `checkAuth()` only called for `/api/backup` |
| SEC-5 | **CRITICAL** | `server.js:1166` | SSE endpoint uses `Access-Control-Allow-Origin: *`, bypassing CORS whitelist |
| SEC-6 | HIGH | `server.js:1468` | Unsanitized `taskId` in image upload handler |
| SEC-7 | HIGH | `server.js:13,17` | Hardcoded Supabase URL and Gist ID as fallback defaults |
| SEC-8 | HIGH | `server.js:49,1131` | API_TOKEN is optional — write ops are unprotected if unset |
| SEC-10 | MEDIUM | `server.js` | No rate limits on task CRUD endpoints |
| SEC-11 | MEDIUM | `server.js:1151-1154` | X-Forwarded-For trusted without proxy validation |

#### 1.2 Frontend XSS

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| SEC-3a | **CRITICAL** | `index.html:2234-2255` | Task title/description rendered via innerHTML without escaping |
| SEC-3b | **CRITICAL** | `index.html:2399-2413` | Task detail view renders description, successCriteria, userJourney via `linkify()` without escaping |
| SEC-3c | **CRITICAL** | `index.html:2454-2463` | Comment text rendered via `linkify()` without prior escaping |
| SEC-3d | **CRITICAL** | `index.html:2506-2534,3003-3009` | Audit log / changelog renders unescaped author and description fields |
| SEC-3e | HIGH | `index.html:2461` | Comment image onclick uses unescaped URL: `onclick="window.open('${c.image}', '_blank')"` |
| SEC-3f | HIGH | `index.html:3297-3327,3365-3403` | Project cards and detail views render unescaped title/description/comments |
| SEC-3g | HIGH | `index.html:3625,3630` | Console session rendering with unescaped label and currentTask |
| SEC-9 | HIGH | `index.html` | No Content Security Policy header or meta tag |

#### 1.3 Deployment

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| SEC-2 | **CRITICAL** | `deploy.sh:10` | Valid Supabase JWT hardcoded in version control |

### 2. Accessibility

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| A11Y-1 | **CRITICAL** | `index.html` (global) | Zero ARIA attributes in entire application — no roles, labels, or live regions |
| A11Y-2 | **CRITICAL** | `index.html:5` | `user-scalable=no` prevents zoom (WCAG 1.4.4 violation) |
| A11Y-3 | HIGH | `index.html` (throughout) | Emoji-only buttons lack accessible names |
| A11Y-4 | MEDIUM | `index.html:1774-1810` | Form labels not associated via `for` attribute |
| A11Y-5 | MEDIUM | `index.html:2598,2885` | No focus trap or focus restore on modal open/close |
| A11Y-6 | MEDIUM | `index.html:25-26` | Low-opacity text may fail WCAG AA contrast |

### 3. Performance

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| PERF-1 | HIGH | `server.js:1679` | `fs.readFileSync` blocks event loop on every static file request |
| PERF-2 | HIGH | `server.js:1083,1170` | SSE clients stored in Set with no inactivity timeout — potential memory leak |
| PERF-3 | HIGH | `server.js:1524,1596` | External HTTPS requests (OpenAI) have no timeout |
| PERF-4 | MEDIUM | `server.js:60,94-99` | Rate-limit map cleaned only every 5 minutes — unbounded growth |
| PERF-5 | MEDIUM | `server.js:329` | All comments fetched on every `/api/tasks` call regardless of need |
| PERF-6 | MEDIUM | `index.html` (images) | No `loading="lazy"` on any images |
| PERF-7 | LOW | `index.html` (global) | ~25-30 mutable globals; no module encapsulation |
| PERF-8 | LOW | `index.html:2234-2255` | All tasks in a column render at once — no pagination/virtualization |

### 4. Error Handling & Reliability

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| ERR-1 | **CRITICAL** | `server.js:1688-1701` | No SIGTERM/SIGINT handler — no graceful shutdown |
| ERR-2 | **CRITICAL** | `server.js` (global) | No `uncaughtException` or `unhandledRejection` handlers |
| ERR-3 | HIGH | `server.js:1077-1080` | Scheduled backup `async` callback has no try/catch |
| ERR-4 | HIGH | `server.js:1077` | No guard against concurrent backup executions |
| ERR-5 | HIGH | `server.js` (various) | Inconsistent error response formats (`{ok,errors}` vs `{error}`) |
| UX-3 | MEDIUM | `index.html` (10+ locations) | Fetch calls don't check `response.ok` before parsing JSON |

### 5. Database & Data Integrity

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| DB-6 | **CRITICAL** | `schema.sql:91-95` | All SELECT policies are `USING (true)` — fully open reads (verify if intentional) |
| DB-1 | HIGH | `schema.sql:22` | `tasks.project_id` has no FK constraint — orphaned tasks on project delete |
| DB-2 | HIGH | `schema.sql:11-13,31` | No CHECK constraints on `column_name`, `priority`, `task_type`, `status` |
| SEC-12 | HIGH | `audit-table.sql:26` | Audit INSERT policy is `WITH CHECK (true)` — anyone can insert fake records |
| DB-3 | MEDIUM | `supabase/` | No migration version tracking — no way to know which migrations are applied |
| DB-4 | MEDIUM | `schema.sql:16` | `seen_at BIGINT` inconsistent with other `TIMESTAMPTZ` temporal columns |
| DB-5 | MEDIUM | `schema.sql` | Missing composite indexes for common query patterns |

### 6. Deployment & Operations

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| OPS-2 | HIGH | (missing) | No CI/CD pipeline — no automated checks on commits or PRs |
| OPS-1 | HIGH | (missing) | No `.env.example` — new developers don't know required configuration |
| OPS-3 | MEDIUM | `deploy.sh:43-46` | Fixed 60-second sleep instead of polling health check |
| OPS-4 | MEDIUM | (missing) | No monitoring or alerting on error rates, latency, or downtime |
| OPS-5 | MEDIUM | (missing) | No documented disaster recovery plan; restore command intentionally disabled |
| OPS-6 | LOW | `package.json` | No dev dependencies (test, lint, format) |

### 7. Code Quality

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| CODE-1 | MEDIUM | `server.js:1157-1638` | `handleApiRequest` is 481 lines handling all routing + logic |
| CODE-2 | MEDIUM | `server.js` (various) | URL parsed inconsistently across endpoints |
| CODE-3 | MEDIUM | `index.html:2125-2165` | Dead code: `saveTasks()` returns false immediately |
| CODE-4 | LOW | `server.js:531,552,609-611` | Hardcoded `'michael'`/`'genie'` author defaults |
| CODE-5 | LOW | `server.js:516`, `index.html:2020` | Task IDs use `Date.now()` — collision risk |

### 8. PWA & UX

| ID | Severity | Location | Issue |
|----|----------|----------|-------|
| PWA-1 | HIGH | `index.html` | No service worker registered — PWA cannot work offline or install reliably |
| UX-1 | MEDIUM | `index.html` (8+ places) | Uses blocking `alert()`/`prompt()`/`confirm()` dialogs |
| UX-2 | MEDIUM | `index.html:2071-2083` | Offline mode is read-only — no change queue or sync |

---

## Architecture Recommendations

### Short-Term Wins (Low Effort, High Impact)

1. **Wrap `escapeHtml()` around all user content in innerHTML** — prevents the entire class of XSS issues with a mechanical find-and-replace.
2. **Add `path.resolve` guard to static file serving** — 3 lines of code prevent path traversal.
3. **Add `checkAuth(req, res)` to task/project POST handlers** — 2 lines per handler.
4. **Add `process.on('SIGTERM', ...)` for graceful shutdown** — 5 lines of code.
5. **Create `.env.example`** — 10 minutes of documentation.

### Structural Improvements (Medium Effort)

1. **Extract route handlers from `handleApiRequest`** into separate functions or files. This is the single biggest code quality improvement for maintainability.
2. **Add a thin HTML sanitization layer** — either use `escapeHtml()` consistently in a render helper, or adopt a lightweight library like DOMPurify for the frontend.
3. **Implement migration tracking** — a simple `migrations` table prevents "did I run this?" confusion.

### Long-Term Considerations

1. **TypeScript migration** — The codebase is small enough (~5500 lines total) that migrating to TypeScript would catch many of the type-related bugs (e.g., `seen_at` BIGINT vs TIMESTAMPTZ mismatches, enum validation gaps).
2. **Extract frontend JavaScript** from `index.html` into a separate file — enables caching, linting, and eventual bundling.
3. **Add automated tests** — Start with API integration tests (the `test-supabase.js` pattern already exists), then add unit tests for validation logic.
