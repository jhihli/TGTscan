## Claude Design Brief: TGT Scan — Zebra Scanner App (v2)
Project Overview
Build the TGT Scan Flutter app for Zebra warehouse mobile devices. The app connects to a Django REST backend and handles two core workflows: pallet inbound (when a vendor delivers pallets) and board inbound (workers logging circuit board data). Vendor and chip brand management is handled on the web app only — this app is purely for warehouse floor use.

## Tech Stack
Flutter + Dart, targeting Zebra Android devices (TC-series handheld scanners)
Zebra DataWedge integration via flutter_datawedge package — the hardware scanner auto-fills whichever text field is currently focused
Screen size: ~5–6" portrait, gloved-hand use. Prioritize large tap targets, high contrast, minimal scrolling.
State: StatefulWidget + TextEditingController only (no Provider/Bloc)
Authentication
Login Screen — username + password, JWT login via POST /account/users/

Store JWT access token in memory for the session
Check network connectivity before attempting login
Inline error display (no toast, just an animated error container)
App Navigation
HomeScreen with a bottom navigation bar (3 tabs):

Tab	Icon	Label	Purpose
0	inventory	Pallet	Pallet inbound
1	dashboard	Board	Board inbound
2	qr_code_scanner	Scan	Placeholder (not redesigned)
## Screen 1: Pallet Inbound
Purpose: Receive a vendor delivery. A worker scans the SO number label on a pallet to open the SO, then records weight and pallet count.

Workflow:

Worker scans the SO number barcode → DataWedge fills SO Number field
App calls GET /product/sos/?q={so_number} to fetch SO details
Shows a read-only info row: vendor name + weight rule (e.g. MSFT · Per Pallet)
Worker fills weight, pallet qty, licence/payload, optionally takes photos
Submit → POST /product/scanner/ with action=lot_inbound
Form resets on success
Fields (in order):

SO Number — text, required, auto-uppercase, scan-to-fill via DataWedge. After entry, auto-fetch SO info from backend.
SO Info display — read-only row showing {vendor_name} · {weight_rule} when SO is found. Show loading state during fetch. Show warning if SO not found.
Licence + Payload — side by side, optional
Date — date picker, defaults to today
Weight (kg) — decimal number, required. DataWedge fills this field when it has focus.
Pallet Qty — integer:
If SO weight_rule = per_pallet → locked to 1, read-only, visually greyed
If weight_rule = aggregated → editable
Note — optional text
Photos — camera-only, multiple photos, grid preview with remove button
Submit — primary action button
API payload (POST /product/scanner/, Bearer token):


{
  "action": "lot_inbound",
  "so_number": "...",
  "licence_number": "...",
  "payload_number": "...",
  "pallet_weight": "...",
  "pallet_qty": "1",
  "date": "YYYY-MM-DD",
  "noted": "..."
}
## Screen 2: Board Inbound
Purpose: Log circuit boards arriving in an SO. Workers typically scan many boards in sequence for the same SO.

Workflow:

Worker types or scans SO number → debounced search (400ms) queries GET /product/sos/?q=... and shows a dropdown overlay of matching SOs
Worker selects an SO → shows info row (vendor name + date)
Worker scans barcodes one by one — DataWedge fills the first empty barcode field, or appends a new field if all are filled
Fills catalog, MPN, weight, chip qty
Submit → POST /product/scanner/ with action=board_inbound
SO Number persists after submit (workers scan many boards per SO in one session); barcodes and other fields reset
Fields (in order):

SO Number — text, required, uppercase, inline dropdown overlay showing search results as worker types
SO Info display — read-only: vendor name + date when SO is selected
Barcodes — dynamic list starting with 1 field; + adds another, − removes; DataWedge auto-fills next empty barcode
Catalog — optional text with autocomplete
MPN — optional text (Material Part Number)
Weight (kg) — optional decimal
Chip Qty — optional integer (total chip count; brand assignment is done on the web)
Note — optional text
Submit — primary action button; show success snackbar after submit (not a dialog)
API payload (POST /product/scanner/, Bearer token):


{
  "action": "board_inbound",
  "so_number": "...",
  "barcodes": "[\"BC001\", \"BC002\"]",
  "catalog": "...",
  "mpn": "...",
  "weight": "...",
  "chip_qty": "4",
  "noted": "..."
}
## Key Behaviors
DataWedge scan routing — scan result goes to the currently-focused field. On Pallet screen: licence field → fill + advance to payload; weight field → fill weight. On Board screen: fills first empty barcode or appends a new one.
Uppercase enforcement on all SO Number fields.
Debounced SO search overlay on Board screen — dropdown appears after 400ms, disappears when SO is selected or field loses focus.
Loading overlay during API calls — semi-transparent dark overlay + spinner over the whole screen.
Error handling — timeout, network error, and server errors each show appropriate messages. Login uses inline error; forms use snackbar.
Form reset after submit — Pallet screen: full reset. Board screen: keep SO number, clear everything else.
Files to Create
lib/main.dart — LoginScreen + HomeScreen (bottom nav) + ScanScreen (placeholder, keep minimal)
lib/lot_screen.dart — Pallet Inbound screen
lib/board_screen.dart — Board Inbound screen


## API Configuration
Config is loaded from `.env` via `flutter_dotenv`. Env file is bundled as a Flutter asset.

| Env Var | Purpose |
|---------|---------|
| `API_BASE_URL` | Base URL (falls back to production if unset) |
| `API_KEY` | API authentication key |

- **Production**: `https://api.toyoshimainventory.com`
- **Test/Local**: `http://192.168.0.19:8000`