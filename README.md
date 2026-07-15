# WareWise

WareWise is a Flutter + Firebase warehouse management system for small-to-medium
multi-hub operations. It replaces the spreadsheet-and-Slack workflow around
stock transfers and procurement with a role-gated app backed by transactional
Cloud Functions: inter-hub stock transfers, an AI-assisted (rule-based)
relocation/reorder advisor, a strategy-driven multi-vendor supplier ranking
and purchase-order pipeline, and role-based financial reporting.

Firebase project: `mwis-inventory` (Firestore in Native mode, default database).

---

## Architecture

- **Client:** Flutter (Android/iOS/Web/Windows/macOS), `provider` for the one
  piece of genuinely global state (`RoleService`), everything else is
  per-page `StatefulWidget` + Firestore `StreamBuilder`/`FutureBuilder`.
- **Data:** Cloud Firestore. Real-time reads happen directly from the client
  (gated by `firestore.rules`); every write that changes stock, roles, or
  money goes through a Cloud Function instead of a direct client write.
- **Backend logic:** `functions/index.js`, Node.js Cloud Functions v2
  (`firebase-functions/v2/https`), each independently re-verifying the
  caller's role from their Firebase Auth custom claim before doing anything.

### Role-based access control

Roles (`associate`, `manager`, `finance`, `owner`) live as Firebase Auth
**custom claims**, set only by the `setUserRole` Cloud Function (owner-only).
The Flutter UI reads the role via `RoleService` to decide what to *show*, but
that is a convenience layer, not the security boundary — every sensitive
Cloud Function calls `requireRole()` and rejects based on the verified claim
in the caller's ID token, not anything the client sends. An Associate cannot
reach a Manager-only action by manipulating the UI; the function checks
independently.

`firestore.rules` mirrors this: direct client writes to `products`,
`transfers`, `purchase_orders`, `suppliers`, and `eligibleSuppliers` are all
`allow write: if false` — every mutation to those collections happens inside
a Cloud Function using the Admin SDK, which bypasses rules by design (that's
where the transactional guarantees below come from).

### Data model (Firestore)

| Collection | Purpose | Written by |
|---|---|---|
| `products/{sku}` | Catalog fields + `cityStock: {Berlin, Munich, Hamburg}` + `quantity` (denormalized sum) | `adminUpsertProduct`, transfer/PO functions |
| `products/{sku}/restricted/cost` | Legacy single-supplier cost (pre-multi-vendor) | `adminUpsertProduct` |
| `products/{sku}/eligibleSuppliers/{supplierId}` | Per-product quoted `unitCost`/`leadTimeDays`/`moq` for a supplier | seed script only (see Known Limitations) |
| `suppliers/{supplierId}` | Supplier directory (name/contact) | seed script only |
| `suppliers/{supplierId}/supplier_performance/{eventId}` | Historical Goods Receipt outcomes (on-time, quality, price variance) — feeds Vendor Score | seed script (synthetic, `seedSource: 'synthetic'`) + `confirmGoodsReceipt` (real, `seedSource: 'real'`) |
| `transfers/{id}` | Inter-hub stock transfer requests/state | client (`create`, Pending only) + transfer functions |
| `purchase_orders/{id}` | Vendor purchase orders from the Sourcing decision matrix | `raisePurchaseOrder`, `confirmGoodsReceipt` |
| `users/{uid}` | Read-only mirror of each user's role, for the Admin UI | `setUserRole` |

### Cloud Functions

| Function | Role | What it does |
|---|---|---|
| `setUserRole` | owner | Sets a user's custom claim + mirrors to `users/{uid}` |
| `approveAndShipTransfer` | manager/owner | Pending → In Transit; decrements source hub stock |
| `confirmDelivery` | associate/manager/owner | In Transit → Delivered; increments destination hub stock |
| `rejectTransfer` | manager/owner | Pending → Rejected (soft status, not deleted) |
| `adminUpsertProduct` | manager/owner | Create/update a product's catalog fields |
| `getSupplierRanking` | manager/finance/owner | Ranks a product's eligible suppliers under a chosen business-priority strategy (`cost`/`reliability`/`balanced`) and returns a rationale per supplier |
| `raisePurchaseOrder` | manager/owner | Creates a PO (status `Raised`) — **does not** touch stock |
| `confirmGoodsReceipt` | manager/owner | The only place a PO increases stock; records a real `supplier_performance` event |

---

## Concurrency & race-condition protection

The four functions that mutate stock or transfer/PO status
(`approveAndShipTransfer`, `confirmDelivery`, `rejectTransfer`,
`confirmGoodsReceipt`) all follow the same pattern:

```js
return db.runTransaction(async (tx) => {
  const snap = await tx.get(docRef);
  if (snap.data().status !== 'ExpectedStatus') {
    throw new HttpsError('failed-precondition', '...');
  }
  tx.update(docRef, { status: 'NextStatus', ... });
  tx.update(otherRef, { stockField: FieldValue.increment(...) });
});
```

The status check reads a value **inside** the transaction, not before it.
If two managers call `confirmGoodsReceipt` (or approve the same transfer) at
the same moment, Firestore serializes the two transaction attempts against
that document. The first to commit wins; the second re-reads the
now-changed status inside its own transaction attempt and throws
`failed-precondition` instead of double-crediting stock. This was verified
directly against the deployed backend during development (a scripted
double-confirm on the same PO produced exactly one stock increment and one
clean rejection).

This also makes client retries safe under network failure: if a request is
sent but the response never arrives (dropped connection), retrying is
harmless — either the original call already committed (the retry gets a
clean rejection) or it didn't (the retry succeeds normally). The one
exception is noted below.

---

## AI / decision-support engine

`OperationsAI.calculateOptimalRoute()` (`lib/services/operations_ai.dart`) is
a deterministic, rule-based function — no external API calls, no ML model.
Given a product's per-hub stock and threshold, it recommends **TRANSFER**
(cheapest hub with surplus, using a static lane-cost table),
**PURCHASE** (reorder from the top-ranked supplier, when no hub has surplus),
**ESCALATE** (associate-visible fallback when cost data isn't visible to
their role), or **OPTIMAL** (no action needed).

The Sourcing page's recommendation banner reads from a `getSupplierRanking`
call fetched with the **Balanced** strategy (a single shared `Future`, not a
separate call), so on first load it and the Compare Suppliers matrix below
always agree on which supplier is "the AI's pick."

### Configurable business-priority strategy

`getSupplierRanking(productId, strategy)` doesn't just rank suppliers — it
actively recommends one, and *which* one depends on a strategy the manager
picks right there in the Compare Suppliers matrix (`ChoiceChip` row, default
Balanced):

| Strategy | What it optimizes for | Suppliers with no delivery history |
|---|---|---|
| `cost` | Lowest quoted `unitCost` — a linear 0-100 fitness score across the eligible peer group (cheapest = 100, priciest = 0) | Still eligible and rankable — price doesn't depend on track record |
| `reliability` | `50% on-time delivery rate + 50% average quality score` — cost is ignored entirely | Score is `null` (unscoreable) and sorts last — reliability can't be judged without data |
| `balanced` | The fixed 40/40/20 weighted formula below (unchanged from the original design) | Same `null`-sorts-last handling |

Every supplier has **two** scores in the response, deliberately kept
separate:

- **`vendorScore`** — always the fixed weighted formula, regardless of
  selected strategy. Stable and comparable no matter what strategy is
  currently selected in the UI:
  ```
  vendorScore = 40% × on-time delivery rate
              + 40% × average quality score
              + 20% × (100 − average |price variance|%)
  ```
- **`strategyScore`** — meaning depends on the selected strategy (see table
  above). This is what determines sort order and which supplier gets the
  **"Recommended for [Strategy Name]"** badge in the UI.

Both are computed server-side in `getSupplierRanking` from every recorded
`supplier_performance` event for that supplier (synthetic seed history and
real Goods Receipt outcomes, once any exist).

### Decision rationale

Each ranked supplier also gets a plain-language `rationale` string, generated
server-side by comparing it against the cheapest and most-reliable peers
under the active strategy — e.g. *"Chosen for reliability: 100% on-time
delivery and a quality score of 93/100. This is $23.35 more expensive than
the cheapest option (Vertex Global Sourcing), but chosen for its stronger
track record."* Shown as body text on every card and as a tap-to-open
tooltip next to the recommendation badge.

### Execute AI Strategy

The matrix's **"Execute AI Strategy"** button is an auto-fill shortcut, not
a new code path: it takes whichever supplier is `SupplierRankingResult.recommended`
under the currently selected strategy and opens the exact same
confirm-and-raise-PO dialog a manual "Select & Authorize PO" tap would, with
the quantity pre-filled. A manager in a rush still has to review and tap
**Authorize & Raise PO** — nothing is ever submitted automatically. The
`raisePurchaseOrder` Cloud Function has no separate "AI-authorized" path; it
can't distinguish an auto-filled confirmation from a manually-picked one, by
design.

**Design note:** the strategy selector is local to the Sourcing page's
matrix, not a global app setting. The banner above it (and the
TRANSFER-vs-PURCHASE decision it drives) always reflects the Balanced
strategy regardless of what a manager has selected in the matrix below —
letting a one-off situational preference ("cheap this week") silently
redefine what counts as "the AI's recommendation" everywhere else in the app
seemed like the wrong default.

---

## Known limitations

Documented here deliberately, not hidden — these are scope/time trade-offs
in the current build, not oversights discovered after the fact.

- **No partial PO receipts.** `confirmGoodsReceipt` is all-or-nothing against
  the full ordered quantity. Real procurement often ships in multiple
  partial deliveries; there's no `receivedQuantity` vs `orderedQuantity`
  tracking or a "partially open" PO state.
- **No Purchase Requisition stage.** The pipeline is PO → Goods Receipt, not
  Requisition → PO → Goods Receipt. An Associate flagging a stockout has no
  way to create a tracked request — the "Escalate" action on a Wise AI card
  is UI feedback only, it persists nothing.
- **No invoice / 3-way match.** Goods Receipt is treated as the end of the
  financial story; there's no separate step verifying a supplier invoice
  against what was ordered and received.
- **1-hour stale-token privilege window.** `setUserRole` sets the custom
  claim but does not call `admin.auth().revokeRefreshTokens()`. A demoted
  user's existing ID token remains valid (with the old role) for up to an
  hour, since Cloud Functions trust the role embedded in the token, not a
  live database lookup. Mitigation would be revoking refresh tokens on every
  role change and having the client force a token refresh more aggressively.
- **No supplier onboarding UI.** `suppliers` and `eligibleSuppliers` are
  populated only by the one-off `seed_supplier_performance.js` script using
  the Admin SDK. There's no Cloud Function to create/update a supplier or
  add them as eligible for a product — adding a real supplier today requires
  a manual script run, not an in-app action.
- **No supplier lifecycle state.** No `isActive`/blacklist flag — a vendor
  you've stopped using stays in every future ranking indefinitely.
- **Vendor Score has no recency weighting.** A Goods Receipt from a year ago
  counts identically to one from last week.
- **Strategy weights are hardcoded, not just the strategy choice.** A manager
  can pick between Cost-Focused / Reliability-Focused / Balanced, but the
  formula behind each (e.g. the 40/40/20 split, or reliability's 50/50) is
  fixed in `functions/index.js` — there's no admin UI to retune the weights
  or add a fourth strategy without a code change and redeploy.
- **No dynamic replenishment quantity.** Reorder quantity is simply
  `threshold − currentStock`; there's no EOQ or safety-stock calculation
  accounting for demand during the supplier's lead time.
- **No offline persistence configured for Flutter Web.** `cloud_firestore`
  does not enable offline caching on web by default, and this project
  doesn't turn it on — a dropped connection mid-session shows loading/error
  states rather than falling back to cached data.
- **No automated tests.** `OperationsAI.calculateOptimalRoute` and the
  Vendor Score aggregation are both pure functions and straightforward to
  unit test; neither currently has coverage, nor do the Cloud Functions
  (no emulator test suite) or any widget tests.
- **All tabs load eagerly.** `main_shell.dart`'s `PageView` builds every
  tab's widget (and therefore every tab's live Firestore listeners)
  immediately on sign-in, not lazily per-tab-visit — so a signed-in session
  maintains real-time listeners for tabs the user hasn't opened yet.
- **Query logic duplicated across pages.** The "stream all products, filter
  client-side for low stock" pattern is implemented independently in
  `dashboard_page.dart`, `alerts_page.dart`, and `sourcing_hub_page.dart`
  rather than centralized — functionally fine at the current catalog size,
  won't scale past a few thousand SKUs without a maintained
  `isLowStock` field and a real Firestore query.

---

## Local development

```bash
flutter pub get
flutter run -d chrome        # or -d windows / an attached device
```

Cloud Functions:

```bash
cd functions && npm install
npx firebase-tools deploy --only functions --project mwis-inventory
npx firebase-tools deploy --only firestore:rules --project mwis-inventory
```

Requires a Firebase service account key (`serviceAccountKey.json`, gitignored,
not included) for the local admin scripts (`upload_to_cloud.py`,
`seed_supplier_performance.js`, `migrate_legacy_purchase_orders.js`).
