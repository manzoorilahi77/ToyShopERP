═══════════════════════════════════════════════════════════
BUSINESS CONTEXT & URGENCY
═══════════════════════════════════════════════════════════
This is a small retail shop selling battery-operated toy cars, bikes, ride-on toys, and other kids' 
play items. The shop operates in a high-footfall, high-chaos retail environment:

- 5-6 sales staff simultaneously handle walk-in customers, demonstrate toys, assemble battery cars 
  on the spot, and process payments — there is NO time for slow data entry.
- The owner floats the floor, personally negotiates and approves discounts for demanding customers, 
  and needs a real-time pulse on sales/stock without being glued to a screen.
- Products arrive from suppliers with NO barcodes, NO SKUs — only a supplier-given name and 
  physical appearance to go by. This is a major operational risk: staff currently rely on memory, 
  which causes wrong pricing, lost stock counts, and "aging stock" piling up in the backyard 
  unnoticed for months.
- Peak hours are evenings/weekends when the shop is busiest — this is when data entry MUST be 
  fastest and most error-proof, since this is also when mistakes (wrong item sold at wrong price, 
  double-counted stock) are most likely.
- At GST filing time (monthly/quarterly), the owner currently struggles to compile purchase/sales 
  data across possibly multiple GST registrations (GSTIN) manually — this must become automatic.
- Business urgency: every day without this system means continued stock mismatches, undetected 
  slow-moving inventory tying up cash, no visibility into which staff member sells best, and 
  stressful, error-prone manual GST compilation.

The system must feel less like "software" and more like a fast, forgiving assistant that a 
non-technical 19-year-old shop boy can use correctly on his 3rd day of work.

═══════════════════════════════════════════════════════════
ARCHITECTURE
═══════════════════════════════════════════════════════════
Single Flutter codebase, three build targets, shared business logic/models/API layer:
1. STAFF APP — Flutter Android/iOS/Web
2. OWNER APP — Flutter Android/iOS/Web, lightweight, on-the-go approvals and quick reports
3. OWNER WEB DASHBOARD — Flutter Web, same codebase, deployed to a URL for GST season desktop use

Backend: Node.js/Express.js + MySQL, single API serving all three surfaces.

═══════════════════════════════════════════════════════════
REQUIREMENT 1: CONTINUOUS SYNC + OFFLINE FALLBACK
═══════════════════════════════════════════════════════════
- Default mode: every action (sale, purchase, stock adjustment) attempts an immediate API call to 
  sync with the backend the instant it happens.
- If no internet: write the transaction to local Drift (SQLite) storage immediately with a 
  "pending_sync" flag, so the staff app NEVER blocks or shows an error to the user — the sale still 
  completes instantly from the staff's point of view.
- Background sync worker (using WorkManager on Android) runs continuously, checking connectivity 
  via connectivity_plus every few seconds; when online, it pushes all "pending_sync" records in 
  order, marks them "synced" only after backend confirms, and retries failed pushes with 
  exponential backoff.
- Conflict resolution: since stock quantity can be affected by multiple staff selling the same 
  product offline simultaneously, use a server-side "last-write-wins with quantity reconciliation" 
  approach — server recalculates true stock from the full event log (sum of purchases minus sum of 
  sales) rather than trusting a single client's local counter, preventing negative-stock errors 
  after sync.
- Show a subtle sync status indicator (small icon: synced/pending/syncing) so staff and owner are 
  never confused about data freshness, without being intrusive during fast billing.

═══════════════════════════════════════════════════════════
REQUIREMENT 2: AVOIDING DUPLICATE ITEMS + EXACT ITEM RETRIEVAL
═══════════════════════════════════════════════════════════
This is the most critical risk area since there are no barcodes/SKUs. Implement layered 
safeguards:

A) DUPLICATE PREVENTION AT ENTRY (when staff/owner adds a new product):
   - Before saving a new product, run an on-device or server-side image similarity check 
     (using a lightweight image embedding model or vector similarity search) comparing the new 
     product photo against existing catalog photos; if similarity exceeds a threshold, show a 
     "This looks similar to [existing product] — is this the same item?" prompt before allowing a 
     duplicate save.
   - Additionally run fuzzy text matching (e.g., Levenshtein distance) on product name + supplier 
     name combination to catch near-duplicate manual entries like "Red Racer Car" vs "Red Racer 
     Cars."
   - Require category + supplier name as mandatory fields (not optional) to narrow duplicate 
     search scope and improve match accuracy.

B) EXACT ITEM RETRIEVAL WHILE SELLING (fast, unambiguous, low-typing):
   - Primary method: visual grid browsing by category (e.g., "Battery Cars," "Ride-on Bikes," 
     "Play Sets") — staff taps the category, then taps the matching photo; this mirrors how they 
     already mentally organize stock.
   - Secondary method: recent/frequently-sold items shown as a "quick pick" strip at the top of the 
     billing screen, since a small subset of toys likely accounts for most daily sales (80/20 rule) 
     — this alone can resolve most transactions in one tap.
   - Tertiary method: text search with autocomplete/fuzzy match on name, falling back gracefully if 
     photo browsing is slow for a new staff member.
   - On selecting an item, show a confirmation card with photo + name + price before adding to 
     cart, so staff visually double-check before confirming — this single UX step prevents most 
     wrong-item sales.

═══════════════════════════════════════════════════════════
REQUIREMENT 3: EASIER-THAN-PHOTO IDENTIFICATION (beyond image/name)
═══════════════════════════════════════════════════════════
Since even photo browsing requires visual scanning, add these lighter-weight alternatives to make 
identification even faster:

- INTERNAL QR/STICKER CODE (self-generated, not from supplier): even without supplier barcodes, the 
  shop can print small self-adhesive QR stickers (from a cheap thermal label printer) at the time 
  products first arrive, and stick them onto the physical toy or its box. This gives you all the 
  speed benefits of barcode scanning without depending on suppliers ever adopting SKUs.
- COLOR + SHELF LOCATION TAGGING: allow tagging each product with a shelf/bin location code (e.g., 
  "Rack A2") and dominant color as searchable filters, since staff often remember "the red car on 
  rack 3" faster than an exact name.
- VOICE SEARCH: allow staff to speak a product name/category instead of typing, using on-device 
  speech-to-text, which is faster than typing on a small phone screen during a rush.
- FAVORITES PER STAFF: let each staff member pin their most-frequently-sold items to a personal 
  quick-access row, since different staff may specialize in different toy types (e.g., one staff 
  member always handles ride-on bikes).

Recommendation: adopt the self-generated QR sticker approach as the primary long-term solution 
since it gives near-barcode speed and accuracy at near-zero cost, while keeping photo browsing as 
the fallback for older stock that hasn't been re-tagged yet.

═══════════════════════════════════════════════════════════
REQUIREMENT 4: CLEAN PURCHASE, SALES, GST & REPORTING FLOWS
═══════════════════════════════════════════════════════════

PURCHASE FLOW (Owner or designated staff):
1. Tap "New Purchase" → select or scan supplier (or add new supplier).
2. Add item(s): photo/QR scan → auto-suggest matching existing product (using duplicate-detection 
   logic above) or confirm as new product → enter quantity + cost price.
3. Select which GSTIN this purchase applies to (if multiple registrations exist) → enter supplier 
   GSTIN for input credit tracking.
4. Review summary screen (all items, quantities, total cost) → confirm → stock auto-updates 
   instantly.

SALES FLOW (Staff, optimized for speed):
1. Tap product (via quick-pick, category grid, QR scan, or search) → confirm item card → add to 
   cart.
2. Repeat for multiple items → running total visible at all times.
3. Optional: apply discount (requires owner PIN) → select payment mode (cash/UPI/card).
4. Confirm sale → receipt auto-generated → share via WhatsApp or print via Bluetooth thermal 
   printer → stock auto-decrements instantly (or queued if offline).

GST FILING FLOW (Owner/Accountant, on web dashboard primarily):
1. Select GSTIN + reporting period (month/quarter) from a dropdown.
2. Dashboard auto-shows: total outward supply value (sales), output GST liability, total input tax 
   credit (from purchases), net GST payable.
3. One-click export: GSTR-1 (outward supplies) and GSTR-3B (summary) as CSV/Excel, formatted ready 
   for upload to the GST portal or handoff to a CA.
4. Reconciliation view: flags any purchase missing a supplier GSTIN (incomplete ITC claim risk) so 
   the owner can follow up with that supplier before filing.

STOCK REPORTS FLOW (Owner, both mobile and web):
1. Dashboard tile: "Aging Stock" — items unsold beyond configurable threshold (30/60/90 days), 
   sorted by how long they've sat, with a "push for clearance" action button.
2. Dashboard tile: "Low Stock" — items below reorder threshold, with a "create purchase order" 
   shortcut.
3. Filterable stock ledger: every stock movement (purchase in, sale out, adjustment) with 
   timestamp and staff/owner responsible, for full audit traceability.

═══════════════════════════════════════════════════════════
REQUIREMENT 5: MODERN DASHBOARD + STAFF INCENTIVES
═══════════════════════════════════════════════════════════

OWNER DASHBOARD (clean, card-based, modern UI):
- Top row: today's sales total, today's profit estimate, items sold today, pending GST liability 
  (live counters, large numbers, minimal clutter).
- Sales trend chart (line/bar) toggle between daily/weekly/monthly.
- "Top performer today" card highlighting the best-selling staff member by revenue or units sold.
- Aging stock and low stock alert tiles with one-tap drill-down.
- Profit margin leaderboard by product category.

STAFF APP DASHBOARD (motivating, gamified, simple):
- Personal sales counter for the day/week/month (units sold, revenue generated) shown prominently 
  on login — instant positive reinforcement.
- Leaderboard among the 5-6 staff (points based on units sold or revenue) updated in real time, 
  since gamification elements like points and leaderboards are proven to boost engagement and 
  motivation in retail/POS environments.
- Badges/milestones (e.g., "Sold 50 toys this month," "Top seller of the week") to recognize 
  achievement without requiring cash incentives every time.
- Simple staff profile screen: name, photo, join date, total lifetime sales, badges earned — gives 
  staff a sense of ownership and progress tracking.
- Optional owner-configurable incentive rules (e.g., bonus per unit sold above a monthly target), 
  visible to staff as a live progress bar toward their next incentive tier — breaking large targets 
  into smaller visible milestones is shown to keep sales staff more engaged than a single 
  end-of-month number.

═══════════════════════════════════════════════════════════
REQUIREMENT 6: DETAILED SCREEN-BY-SCREEN WBS PER ROLE
═══════════════════════════════════════════════════════════

ROLE: STAFF
1. Login Screen — PIN entry, staff photo/name confirmation.
2. Home/Dashboard — personal sales counter, leaderboard snippet, quick-pick items, "New Sale" 
   button.
3. New Sale Screen — category grid → product grid → item confirmation card → cart → discount PIN 
   prompt (if applicable) → payment mode → confirm.
4. Receipt Screen — preview, share (WhatsApp), print (Bluetooth), "New Sale" shortcut.
5. My Sales History — list of today's/past sales made by this staff member, filterable by date.
6. Product Search/Browse Screen — category filters, search bar, voice search icon, QR scan icon.
7. Profile Screen — photo, name, badges, lifetime stats, logout.

ROLE: OWNER (Mobile App)
1. Login Screen — PIN or credential entry.
2. Dashboard Home — today's KPIs, top performer card, alerts (low stock/aging stock), quick nav.
3. Discount Approval Screen — pending discount requests from staff, approve/reject with PIN.
4. New Purchase Screen — supplier selection, item entry (photo/QR/duplicate-check), GSTIN 
   selection, cost entry, confirm.
5. Product Catalog Management — add/edit/deactivate products, duplicate-check on add, bulk photo 
   upload.
6. Staff Management Screen — add/edit staff, assign PIN, view individual performance.
7. Reports Screen (condensed mobile view) — sales summary, stock aging, quick GST snapshot.
8. GST Registrations Screen — add/manage multiple GSTIN entries, mark active/inactive.
9. Notifications Screen — low stock, aging stock, sync failures, discount requests.

ROLE: OWNER/ACCOUNTANT (Web Dashboard)
1. Login Screen — credential-based (web session).
2. Dashboard Home — full KPI cards, sales trend charts, staff leaderboard, category profit margin 
   breakdown.
3. Sales Ledger — full filterable/sortable table of all sales (date, staff, product, amount, 
   GSTIN, payment mode), export to Excel.
4. Purchase Ledger — full filterable/sortable table of all purchases, supplier-wise breakdown, 
   export to Excel.
5. Stock Report Screen — current stock table, aging stock table, low stock table, stock movement 
   history/audit log.
6. GST Filing Screen — GSTIN + period selector, auto-computed GSTR-1/GSTR-3B summary, one-click 
   export, reconciliation flags for missing supplier GSTIN.
7. Staff Performance Screen — detailed per-staff sales stats, incentive tier progress, badge 
   history.
8. Product Catalog Management (web, bulk-friendly) — bulk edit/upload, duplicate-detection review 
   queue for flagged similar items.
9. Settings Screen — aging stock threshold config, incentive rule config, GSTIN management, backup 
   settings.

═══════════════════════════════════════════════════════════
DATABASE SCHEMA (MySQL) — extend previous schema with:
═══════════════════════════════════════════════════════════
- products: add columns for internal_qr_code, shelf_location, color_tag, image_embedding_vector 
  (for duplicate detection), is_active
- sales: add payment_mode, sync_status, device_id (to trace which offline device generated it)
- staff: add total_lifetime_sales, current_month_points, badges_earned (JSON array)
- incentive_rules: id, rule_type, target_value, reward_description, active_from, active_to
- duplicate_review_queue: id, new_product_id, matched_existing_product_id, similarity_score, 
  status (pending/confirmed_duplicate/confirmed_unique)
- sync_log: id, transaction_type, transaction_id, device_id, synced_at, status

═══════════════════════════════════════════════════════════
DELIVERABLES (build in this order)
═══════════════════════════════════════════════════════════
1. MySQL schema with migrations (including new duplicate-detection and incentive tables).
2. Node.js/Express API with sync-conflict-resolution logic for stock quantities.
3. Flutter shared package: models, API client, offline sync manager, duplicate-detection service.
4. Staff app: sales flow, QR/photo browsing, offline sync, Bluetooth printing, gamified dashboard.
5. Owner mobile app: approvals, purchase entry, catalog management, condensed reports.
6. Owner web dashboard: full ledgers, GST filing module, staff performance analytics.

Start by delivering the MySQL schema and sync-conflict-resolution logic design before writing any 
Flutter code, since correct stock reconciliation is the highest-risk component of this system.