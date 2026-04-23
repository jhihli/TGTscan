## Project Context

I'm building the Django backend and web UI for a warehouse receiving management system. The data model and UI design have already been finalized through earlier planning. Your job is to implement the Django application — models, admin, views, templates, and URL routing — matching the approved design.

A companion Zebra scanner mobile app will be built later as a separate project. It will talk to this Django backend via REST API. For now, focus on the Django web UI for warehouse managers and office staff on desktop browsers.

## Key notes:

1. For the autho login user keep using | `account_customuser` | extends AbstractUser + role field |. 
2. The product table can be removed and replaced with the new tables follow by .claude/rules/data model.md
3. The frontend UI is already disigned in Claude Design. Please find code here: /claude/claude design ui/inventory-web
4. For api, only Account (`/account/`) keep using, others need to be create. ./claude/rules/api.md


## Data Semantics Cheat Sheet
These three scenarios show exactly how data should be stored and how the model properties compute values. Use these as reference cases for writing seed data, tests, and UI displays.
Scenario 1: MSFT delivers 3 pallets (Per Pallet mode)
Each pallet is recorded as its own row with qty=1. This is the default and most common case.
SO-001 (vendor=MSFT, weight_rule=per_pallet)
├── Pallet row 1: weight=24, qty=1    ← Pallet #1, 24kg
├── Pallet row 2: weight=36, qty=1    ← Pallet #2, 36kg
└── Pallet row 3: weight=28, qty=1    ← Pallet #3, 28kg
Expected query results:

so.total_pallet_count → 1 + 1 + 1 = 3 physical pallets ✓
so.total_pallet_weight → 24 + 36 + 28 = 88 kg ✓
so.pallet_record_count → 3 rows
so.effective_weight_rule → 'per_pallet' (inherited from MSFT default)

In this mode total_pallet_count and pallet_record_count are always equal, so the UI shows the same number for KPI card and tab badge.
Scenario 2: SMS delivers 12 pallets in two batches (Aggregated mode)
Pallets are grouped by shared characteristics and stored as aggregate rows. Each row's qty represents how many physical pallets it covers; weight is the combined weight of those pallets.
SO-002 (vendor=SMS, weight_rule=aggregated)
├── Pallet row 1: weight=100, qty=5   ← 5 pallets totaling 100kg
└── Pallet row 2: weight=124, qty=7   ← 7 pallets totaling 124kg
Expected query results:

so.total_pallet_count → 5 + 7 = 12 physical pallets ✓
so.total_pallet_weight → 100 + 124 = 224 kg ✓
so.pallet_record_count → 2 rows
so.effective_weight_rule → 'aggregated' (inherited from SMS default)

This is the case where naive count() would return 2 and severely under-report the 12 physical pallets. The UI must show "2 records · 12 physical pallets total" above the Pallets table to make both numbers visible.
Scenario 3: MSFT uses Aggregated just this once (Override)
A user creates a new SO for MSFT but switches the weight rule to Aggregated for this shipment only. This does NOT change MSFT's default rule — only this one SO is affected.
SO-003 (vendor=MSFT, weight_rule=aggregated  ← overrides MSFT default)
└── Pallet row 1: weight=240, qty=10  ← 10 pallets totaling 240kg
Expected query results:

so.total_pallet_count → 10 physical pallets ✓
so.total_pallet_weight → 240 kg ✓
so.pallet_record_count → 1 row
so.effective_weight_rule → 'aggregated' (SO's own value wins over vendor default)
so.vendor.default_weight_rule → still 'per_pallet' (unchanged)

Key behavior: SO.weight_rule takes precedence over Vendor.default_weight_rule. If SO.weight_rule is blank, effective_weight_rule falls back to the vendor's default. This is handled automatically by the save() method and the effective_weight_rule property — do not re-implement this logic elsewhere.
Seed Data Requirement
When writing the seed_data management command, ensure the generated data reflects all three scenarios. Specifically:

For per_pallet vendors (MSFT, Dell, Lenovo): every Pallet row must have qty=1
For aggregated vendors (SMS, HPE): Pallet rows should have qty between 3 and 15
Include at least 2 SOs that override their vendor default (one per_pallet vendor using aggregated, one aggregated vendor using per_pallet) to exercise the override logic



## Pages to Implement

The UI design has been finalized in Claude Design. Implement these pages matching the approved design language: clean, data-dense, Linear/Notion/Retool-inspired aesthetic with neutral monospace-flavored style.

### Page 1: Dashboard (`/`)
- 4 KPI cards: Today's SOs, This week's boards, Active vendors, Pallets this month (use `Sum('qty')`)
- Line chart: Daily SO count for last 30 days (use Chart.js via CDN)
- Bar chart: Top 5 vendors by board count
- Recent scans: last 10 boards table (barcode, SO, vendor, MPN, qty, scanned_at)

### Page 2: SO List (`/sos/`)
- Top toolbar: search bar (so_number, licence_number), vendor filter, date range picker, "+ New SO" button (opens modal)
- Columns: SO Number, Vendor, Date, Licence No, Payload, **Pallets** (use `total_pallet_count`), Total Weight, Boards, right chevron
- Each row links to SO Detail
- Pagination: 20 per page

### Page 3: SO Detail (`/sos/<pk>/`)
- Breadcrumb: Home / Sales Orders / SO-XXXX
- Header: SO number as h1, subtitle "Received YYYY-MM-DD · Vendor · Created ...", Export + Edit buttons
- Info strip (6 columns): Vendor, Weight Rule, Licence No, Payload No, **Pallets** (use `total_pallet_count`, this is physical count), Boards
- NOTE section: double-click to edit inline (use htmx)
- PHOTOS section: thumbnail grid + Add Photo button
- Tabs: Pallets | Boards
  - **Pallets tab**: badge shows `pallet_record_count`. Above the table, show "X records · Y physical pallets total" when the two differ. Columns: SEQ, WEIGHT (KG), QTY, delete icon. Bottom TOTAL row shows Sum('weight') and Sum('qty'). Add pallet button on right.
  - **Boards tab**: badge shows `total_board_count`. Columns: barcode (clickable link), catalog, mpn, weight, qty, chips (use `total_chip_count`), scanned_at. Each row links to Board Detail.

### Page 4: Board Detail (`/sos/<so_pk>/boards/<board_pk>/`)
- Breadcrumb: Home / Sales Orders / SO-XXXX / BC-XXXXX
- Header: barcode as h1, subtitle "SO SO-XXXX · Scanned YYYY-MM-DD HH:MM", Edit + Delete buttons
- 2-column layout: Photo on left (with Replace photo button), info fields on right (Barcode, Catalog, MPN, Weight, Quantity, Scanned At)
- NOTE section: double-click to edit inline
- CHIPS section header: "CHIPS X brands · Y total" (show both metrics)
- Chips table: BRAND (dropdown selecting ChipBrand), QTY, NOTE, delete icon. Bottom TOTAL CHIPS row with Sum('qty'). Add chip button.

### Page 5: New SO Modal (triggered from SO List)
Fields:
- SO NUMBER (text, required, unique)
- VENDOR (dropdown, required) — when selected, auto-populates default weight rule below
- DATE (date picker, default today)
- LICENCE NUMBER (text, optional)
- PAYLOAD NUMBER (text, optional)
- **WEIGHT RULE section (collapsed by default):**
  - Shows "Per Pallet INHERITED FROM [Vendor]" with a "Change" button
  - On click Change: expands to show two radio options
  - If user picks the non-default option, show warning: "⚠️ Overriding [Vendor] default. This applies only to this SO."
- NOTE (textarea, optional)
- Cancel / Create buttons

Implement this as an htmx-loaded modal (not full page reload).

### Page 6: Vendors List (`/vendors/`)
Table: NAME, DEFAULT WEIGHT RULE (pill badge), SO COUNT, Edit link, Delete link
- "+ New vendor" button opens modal: name + default weight rule dropdown with helper text explaining both options

### Page 7: Chip Brands List (`/chip-brands/`)
Table: BRAND, CHIPS RECORDED (use `Sum('qty')` across all Chips), Edit, Delete
- "+ New brand" button opens simple modal: just name field

## Navigation Structure

Left sidebar (fixed):
```
Toyoshima
INVENTORY

MENU
├─ Dashboard
├─ Sales Orders
├─ Vendors
├─ Chip Brands
└─ Settings (placeholder for now)
```

Top bar: search box (global), location tag "WH-01 · BAY 3" (hardcoded for now), notifications bell, user avatar (stub)

## Inline Editing Pattern (use htmx)

Many cells support double-click inline editing. Pattern:

```html
<!-- Static display -->
<td hx-get="{% url 'edit_pallet_weight' pallet.pk %}" 
    hx-trigger="dblclick"
    hx-swap="outerHTML">
    {{ pallet.weight }}
</td>

<!-- View returns the editor -->
<td>
    <input type="number" 
           hx-post="{% url 'save_pallet_weight' pallet.pk %}"
           hx-trigger="blur, keyup[key=='Enter']"
           value="{{ pallet.weight }}">
</td>
```

Build this pattern for: Pallet weight/qty, SO note, Board note, Chip qty/note, Photo caption.

## REST API (for future Zebra app)

Create DRF endpoints at `/api/v1/` with these resources:
- `POST/GET /vendors/`
- `POST/GET/PATCH/DELETE /sos/`
- `POST/GET/PATCH/DELETE /sos/<id>/pallets/`
- `POST/GET/PATCH/DELETE /sos/<id>/photos/`
- `POST/GET/PATCH/DELETE /sos/<id>/boards/`
- `POST/GET/PATCH/DELETE /boards/<id>/chips/`
- `POST/GET /chip-brands/`

Use drf-spectacular to auto-generate `openapi.yaml`. This file is the contract shared with the Zebra app.

Important API behaviors:
- When creating a SO, if `weight_rule` is not provided, use vendor's `default_weight_rule`
- When listing SOs, include computed fields: `total_pallet_count`, `total_pallet_weight`, `total_board_count`
- Return both `pallet_record_count` and `total_pallet_count` so clients can display both


## Seed Data Script

Create a management command `python manage.py seed_data` that creates realistic test data:
- 5 vendors: MSFT (per_pallet), Dell (per_pallet), Lenovo (per_pallet), SMS (aggregated), HPE (aggregated)
- 5 chip brands: Samsung, Intel, Micron, SK Hynix, Kioxia
- 50 SOs spread across the last 30 days, assigned to random vendors
- Each SO has realistic pallets matching its vendor rule:
  - Per Pallet vendors: 1-5 pallet rows each with qty=1
  - Aggregated vendors: 1-3 rows with qty between 5-15
- Each SO has 5-15 boards with random mpn, catalog, barcode
- Some boards have 1-3 chip records

