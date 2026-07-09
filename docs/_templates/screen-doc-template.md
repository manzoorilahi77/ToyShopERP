# [Screen Name] — [Role] · [Platform]

> **Template** — every mobile/web screen doc in this repo follows this exact section
> order so readers (and code generators) can rely on the structure. Delete this quote
> block in real docs. Keep sections even if short; write "N/A" rather than removing.

---

## 1. Purpose & context
- **What this screen is for** (1–2 sentences, in the user's language).
- **Who uses it** (role) and **when** (peak hours? GST season? on the floor?).
- **Why it exists** — tie back to a business risk from `requirements_and_prompt.md`.
- **Frequency / criticality** — how many times a day, how costly a mistake is here.

## 2. Entry points & navigation
- How the user arrives here (tab, button, deep link, notification tap, QR scan).
- Where they can go next (exits), and the back-button behavior.
- Nav diagram if non-trivial: `Home → New Sale → Receipt → Home`.

## 3. Roles & permissions
- Who can open it, what's `🔒 owner-PIN` gated, what's read-only for which role.

## 4. Screen layout (wireframe)
- ASCII/box wireframe of the default state. Label every region.
- Note responsive behavior (phone vs tablet; for web: breakpoints).

## 5. UI components & field-by-field spec
For **every** interactive element, a row in this table:

| # | Element | Type | Source / options | Validation | Default | Behavior on change | Notes |
|---|---|---|---|---|---|---|---|
| 1 | e.g. PIN field | numeric input, 4 digits | user input | required, 4 digits, `[0-9]` | empty | auto-submit on 4th digit | masked dots |

Follow the table with per-field prose only where behavior is subtle.

## 6. States
Describe each: **default / empty / loading / populated / error / offline / success /
permission-denied**. Include what the user sees and what they can do in each.

## 7. Interactions, gestures & hardware
- Taps, long-press, swipe, pull-to-refresh, scanner focus, camera, voice, BT printer.
- Latency budgets where speed matters (e.g. "add-to-cart must feel instant, <100ms").

## 8. Business rules & edge cases
- Numbered, testable rules. Cover the nasty retail-floor cases (offline, dup item,
  negative stock, discount without approval, mid-sale connectivity loss, etc.).

## 9. API interactions
- Table of endpoints this screen calls, in call order, with when/why:

| Trigger | Method + path | Purpose | Offline behavior |
|---|---|---|---|

- Link each to the relevant `cloud/api/**` doc. Show the key request/response fields
  used by this screen (not the full schema — that lives in the API doc).

## 10. Offline & sync behavior
- What works fully offline, what's queued, what's blocked.
- Which local Drift tables are read/written; which `sync_status` values are set.
- Reference `foundation/sync-and-conflict-resolution.md`.

## 11. Analytics & events
- User/business events to emit (e.g. `sale_completed`, `duplicate_prompt_shown`).

## 12. Accessibility, localization & performance
- Tap-target sizes, contrast, large-number legibility, voice, i18n (₹ / GST / date),
  cold-start & interaction perf budgets.

## 13. Acceptance criteria
- Checklist of "done" — each a testable statement.
  - [ ] …

## 14. Related docs
- Links to foundation docs, sibling screens, and API docs.
