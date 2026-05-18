# Amazon MWIS (Mobile Warehouse Inventory System)

Amazon MWIS is a cross-platform, enterprise-grade logistics fulfillment terminal and financial telemetry ecosystem. Meticulously engineered using the Flutter SDK and powered by an automated, real-time Cloud Firestore synchronization pipeline, the application is designed to optimize supply chain visibility, automate cross-dock rebalancing, and evaluate procurement sourcing metrics across distributed warehouse networks.

The application features a fully responsive, adaptive layout system architected in VS Code to ensure an optimal user experience across desktop browsers, operations tablets, and compact mobile device screens (e.g., OnePlus Nord, Google Pixel 7).

---

## 📱 Core Application Portals & Architecture

The application is unified under a state-managed navigation shell (`main_shell.dart`) that coordinates view tracks seamlessly across four critical enterprise modules:

### 1. Central Inventory Controller & Seeder (`dashboard_page.dart`)
* **Real-Time Database Sync:** Uses a continuous `StreamBuilder` connection to the Firestore `products` data collection to dynamically calculate active warehouse volumes across your core shipping hubs: **Berlin Hub**, **Hamburg Hub**, and **Munich Hub**.
* **Zero-Dependency Native CSV Parser:** Embeds a custom, high-speed CSV parsing loop (`autoUploadKaggleData`) that directly targets your double-extended spreadsheet assets (`assets/amazon_inventory.csv.csv`). It reads row data line-by-line, isolates string values, handles quotation rules, and converts strings into typed database data structures without relying on third-party packages.
* **Firestore Ingestion Safe-Guards:** To prevent quota exhaustion on Firebase free tiers, the engine automatically caps imports at **300 concurrent records max** and groups document insertion commands within structured asynchronous `WriteBatch` operations.
* **Fluid Category Filters:** Features a predictive text search field paired with a horizontally scrolling swipe bar (`SingleChildScrollView` with `BouncingScrollPhysics`) for swift category isolation.

### 2. Logistics Alert Center (`alerts_page.dart`)
* **Asymmetry Intercept Loop:** Runs proactive inventory check queries comparing active regional stock pools against fixed safety thresholds (`minStockLevel`).
* **Instant Stock Deflection:** When a localized deficit is encountered, the page calculates regional supply levels, pinpoints the hub with the largest surplus, and triggers an actionable rebalancing card. Personnel can tap this card to immediately generate an inter-hub transfer manifest.

### 3. Adaptive Cross-Dock Fulfillment Terminal (`operations_page.dart`)
* **Breakpoint Layout Engine:** Leverages `MediaQuery` to evaluate screen space. On widescreen monitors, asset parameters stretch evenly across horizontal rows. On narrow mobile viewports, the app stacks details dynamically into sleek vertical tracking cards to avoid layout breaking.
* **Boundary Overflow Protection:** Eliminates right-side pixel boundary clipping errors (the black-and-yellow hazard bar) by substituting rigid constraints with flexible widgets (`Expanded`, `Flexible`, and `Wrap`).
* **Executive Decision Matrix Container:** A dark-themed, manager-secure panel that automatically models supply chain savings. It contrasts Option A (External Vendor Procurement Loss) against Option B (Internal Transfer Route Freight) based on batch volumes to calculate your exact **Total Capital Retained (Net Profit)**.
* **Lifecycle State Machine:** Advances supply chain operations through a structured state track: `Requested (Awaiting Approval)` ➔ `In Transit (Transfer Initiated)` ➔ `Delivered (Transfer Completed)`.

### 4. Financial Performance Vault (`finance_page.dart`)
* **Authentication Gatekeeper:** Encrypts data behind a visual security vault layer. Tapping the clearance button launches an isolated modal window that challenges user credentials against your security token (`mwis2026`) to unlock the dashboard.
* **Dynamic Arithmetic Calculation Engine:** Iterates programmatically through your category sets (*Beauty & Essentials*, *Electronics & Tech*, *Fashion & Clothing*, *Accessories*, *Home & Appliances*). It aggregates gross revenue pools and net profits on the fly, smoothly adjusting whether a given category holds 9 items, 10 items, or expands further.
* **Decoupled Master-Detail View:** Offloads heavy data grids from nested expandables into an isolated sub-page routing channel (`Navigator.push`). This uncouples dense text rendering from the main screen scroll tree, completely removing swipe gesture lag.

---

## 🗄️ Database Mapping Schema (Cloud Firestore Layout)

The system relies on a clean, denormalized NoSQL structural model inside a single Firebase project database named `mwis-inventory`:

### `products` Collection
```json
products (Collection)
  └── [Auto-Generated Document ID] (Document)
        ├── name: "Dyson Airwrap Multi-Styler 4606" (String)
        ├── category: "Beauty & Essentials" (String)
        ├── price: 549.99 (Number)
        ├── quantity: "2399" (String)
        ├── minStockLevel: "480" (String)
        └── cityStock (Map)
              ├── Berlin: 1146 (Number)
              ├── Hamburg: 608 (Number)
              └── Munich: 645 (Number)

