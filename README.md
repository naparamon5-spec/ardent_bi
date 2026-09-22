# Ardent BI — Mobile

Flutter client for the Ardent BI platform. It talks to the same Express API as
the `ardentBI` web front end (`/api/*`) and mirrors its look and core analytics
so the two clients read as one product.

## What's included

Navigation is a floating bottom bar — **Overview · Sales · Inventory · More** —
with the secondary modules under **More**, gated by role like the web sidebar.

- **Sign in** against `/api/auth/login`, with the JWT and the server URL
  persisted on device. A **Server URL** field on the login screen lets a phone
  reach the API without a rebuild (emulator, LAN, or a deployed host). A
  **"Preview the UI (demo data)"** button opens the whole app with sample
  figures and no server.
- **Overview** — the five headline KPIs, the net-sales/gross-profit monthly
  trend, brand and salesman breakdowns (tap a bar to cross-filter), biggest
  movers, and an inventory glance.
- **Sales** — KPIs, a measure switcher (sales / gross profit / quantity), a
  monthly trend, a breakdown by any dimension, and a recent-transactions list.
- **Inventory** — stock-value / SKU / ageing KPIs, the ageing profile (fixed
  ageing palette), a stock-value breakdown, and a dead-stock summary.
- **Re-Order Point** (More; BU-head-and-above) — items to order, below-ROP
  count, order amount, forecast demand by brand, and the items-to-order list.
- **Accrued Incidentals** (More) — incidental cost and rate, job orders, monthly
  trend, and cost by brand.
- **Period reports** (More) — year-on-year / quarter / month comparison of net
  sales with growth.
- **Account** (More) — profile, data scope, server, sign out.
- **Filters** — one generic bottom-sheet filter across Overview, Sales,
  Inventory, Re-Order Point, Accrued and Period reports: a date range where the
  module has one, plus searchable multi-selects whose options cascade from that
  module's `/options/:dimension` endpoint, mirroring the web filter bar.
  Row-level scope resolved by the API is surfaced as a banner, exactly as on
  the web.

Colours, currency-in-millions formatting, and the categorical/ageing palettes
are lifted from the web front end so figures agree across clients.

## Running

```bash
flutter pub get
flutter run
```

Point the app at your API on the login screen (**Server settings**):

- iOS simulator / desktop: `http://localhost:4000`
- Android emulator: `http://10.0.2.2:4000`
- Real device: `http://<your-server-LAN-IP>:4000`

The `ardentBI` API must be running (`cd server && npm run dev`). See the web
repo's `CLAUDE.md` for backend setup.

## Structure

```
lib/
  api.dart              # HTTP wrapper + JWT (mirrors useApi.js)
  format.dart           # currency/number formatting (mirrors useFormat.js)
  theme.dart            # colour tokens + palettes from the web
  state/                # AuthState, FilterState (the Pinia stores' counterparts)
  widgets/              # KpiTile, BiChart (line/hbar), filter sheet, shared UI
  screens/              # login, home shell, dashboard, sales, inventory, account
```

## Next

Deliberately left to the web (desktop tasks): **Upload** (xlsx import) and
**Administration** (user/access management). Also not yet ported: Sales
Forecast, Targets, and saved "My reports". Each is a new screen plus a `More`
entry on the foundation above.
