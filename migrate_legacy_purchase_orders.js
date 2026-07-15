/**
 * One-time migration: backfills `destinationHub` on any purchase_orders
 * documents raised before that field was required (pre-existing 'Raised'
 * POs from before this session's raisePurchaseOrder update). Defaults to
 * 'Berlin'. Safe to re-run — only touches docs missing the field.
 *
 * Run with: node migrate_legacy_purchase_orders.js
 */
const admin = require('./functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();

const DEFAULT_HUB = 'Berlin';

async function main() {
  const snap = await db.collection('purchase_orders').get();
  const legacy = snap.docs.filter((doc) => !doc.data().destinationHub);

  if (legacy.length === 0) {
    console.log('No legacy purchase orders found — nothing to migrate.');
    return;
  }

  console.log(`Found ${legacy.length} purchase order(s) missing destinationHub:`);
  for (const doc of legacy) {
    console.log(`  ${doc.id} — ${doc.data().productName || doc.data().productId} (status: ${doc.data().status})`);
  }

  const batch = db.batch();
  for (const doc of legacy) {
    batch.update(doc.ref, { destinationHub: DEFAULT_HUB, destinationHubBackfilled: true });
  }
  await batch.commit();

  console.log(`Backfilled destinationHub='${DEFAULT_HUB}' on ${legacy.length} document(s).`);
}

main()
  .catch((e) => {
    console.error('MIGRATION FAILED:', e);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
