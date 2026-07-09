# [Module] API

> **Template** — every backend API module doc follows this section order. Delete this
> quote block in real docs. Base URL, auth, envelope and error formats are defined once
> in `foundation/api-conventions.md`; reference, don't repeat.

---

## 1. Overview
- What this module owns, who calls it (staff app / owner app / web / sync worker).
- Business risks it addresses (link to `requirements_and_prompt.md`).

## 2. Data model touched
- Tables read/written (link to `foundation/data-model.md`). Note which table is the
  source of truth vs. derived/cached.

## 3. Auth & permissions
- Required auth (JWT / device token), roles allowed per endpoint, PIN-gated actions.

## 4. Endpoints
For **each** endpoint repeat this block:

### `METHOD /path`
- **Purpose** — one line.
- **Auth** — role(s), scopes, `🔒` if PIN required.
- **Idempotency** — key/header if the endpoint is sync-replayable.
- **Path / query params**

| Param | In | Type | Required | Default | Notes |
|---|---|---|---|---|---|

- **Request body**

| Field | Type | Required | Validation | Notes |
|---|---|---|---|---|

- **Response `200/201`** — schema table (field, type, notes) + JSON example.
- **Status codes & errors** — table of code → `error.code` → when it happens.
- **Example** — `curl`/JSON request + response.

## 5. Business logic & validation
- Server-side rules, computed fields, transactions, what runs atomically.

## 6. Sync & conflict handling
- Idempotency keys, `client_uuid` dedupe, event-log writes, reconciliation.
- Reference `foundation/sync-and-conflict-resolution.md`. "N/A" if not sync-relevant.

## 7. Edge cases & failure modes
- Numbered. Include retries, partial failures, duplicate submits, race conditions.

## 8. Performance & indexing
- Expected volume, hot queries, indexes relied on, pagination/caching.

## 9. Related docs
- Screens that consume this module, sibling API docs, foundation refs.
