/**
 * One-off seed script: migrates each product's existing single incumbent
 * supplier (products/{sku}/restricted/cost) into the new multi-supplier
 * schema (suppliers/{id}, suppliers/{id}/supplier_performance/{eventId},
 * products/{sku}/eligibleSuppliers/{id}), and adds 1-2 synthetic alternate
 * suppliers per product so the ranking/comparison UI has something real to
 * compare. All synthetic data is clearly marked with `seedSource: 'synthetic'`
 * so it can be told apart from real Goods Receipt events later.
 *
 * Run with: node seed_supplier_performance.js
 * Idempotent: supplier IDs are deterministic slugs of supplier names, and
 * performance history is only generated once per supplier (skipped if it
 * already has events).
 */
const admin = require('./functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });
const db = admin.firestore();

const PERSONAS = {
  excellent: { onTimeRate: [0.92, 0.98], quality: [90, 98], variance: [-3, 3] },
  reliable: { onTimeRate: [0.85, 0.92], quality: [80, 90], variance: [-5, 5] },
  average: { onTimeRate: [0.7, 0.85], quality: [65, 80], variance: [-8, 8] },
  cheapUnreliable: { onTimeRate: [0.5, 0.7], quality: [55, 70], variance: [-15, 15] },
  slowQuality: { onTimeRate: [0.55, 0.7], quality: [85, 95], variance: [-6, 6] },
};
const PERSONA_NAMES = Object.keys(PERSONAS);

// Deterministic pseudo-random: same supplier name always gets the same
// persona and the same synthetic events, so re-runs don't drift.
function seededRandom(seedStr) {
  let seed = 0;
  for (let i = 0; i < seedStr.length; i++) seed = (seed * 31 + seedStr.charCodeAt(i)) >>> 0;
  return function next() {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return seed / 4294967296;
  };
}

function slugify(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
}

function randInRange(rand, [min, max]) {
  return min + rand() * (max - min);
}

const ALTERNATE_SUPPLIER_POOL = [
  { name: 'Nordic Freight Supply Co', contactPerson: 'Ingrid Larsen', email: 'sales@nordicfreight.example', phone: '+46701234567', address: 'Gothenburg, Sweden', persona: 'excellent' },
  { name: 'Rapid Source GmbH', contactPerson: 'Felix Bauer', email: 'orders@rapidsource.example', phone: '+493012345678', address: 'Munich, Germany', persona: 'cheapUnreliable' },
  { name: 'Meridian Components Ltd', contactPerson: 'Sarah Whitfield', email: 'procurement@meridiancomp.example', phone: '+442071234567', address: 'Manchester, United Kingdom', persona: 'reliable' },
  { name: 'Atlas Industrial Trading', contactPerson: 'Marco Rossi', email: 'sales@atlastrading.example', phone: '+390212345678', address: 'Milan, Italy', persona: 'average' },
  { name: 'Vertex Global Sourcing', contactPerson: 'Chen Wei', email: 'export@vertexsourcing.example', phone: '+862112345678', address: 'Shanghai, China', persona: 'slowQuality' },
];

async function ensureSupplierPerformance(supplierId, supplierName, persona, eventCount = 12) {
  const perfCol = db.collection('suppliers').doc(supplierId).collection('supplier_performance');
  const existing = await perfCol.limit(1).get();
  if (!existing.empty) return; // already seeded

  const rand = seededRandom(supplierId);
  const profile = PERSONAS[persona];
  const batch = db.batch();
  const now = Date.now();

  for (let i = 0; i < eventCount; i++) {
    const onTime = rand() < randInRange(rand, profile.onTimeRate);
    const qualityScore = Math.round(randInRange(rand, profile.quality));
    const priceVariancePercent = Math.round(randInRange(rand, profile.variance) * 10) / 10;
    const daysAgo = Math.round(rand() * 365);
    const orderDate = new Date(now - daysAgo * 86400000);
    const receivedDate = new Date(orderDate.getTime() + (onTime ? 0 : Math.round(rand() * 5)) * 86400000);

    const eventRef = perfCol.doc();
    batch.set(eventRef, {
      onTime,
      qualityScore,
      priceVariancePercent,
      orderedQty: Math.round(50 + rand() * 450),
      orderDate: admin.firestore.Timestamp.fromDate(orderDate),
      receivedDate: admin.firestore.Timestamp.fromDate(receivedDate),
      seedSource: 'synthetic',
    });
  }
  await batch.commit();
  console.log(`  Seeded ${eventCount} performance events for ${supplierName} (${persona})`);
}

async function main() {
  const productsSnap = await db.collection('products').get();
  console.log(`Found ${productsSnap.size} products.`);

  let processed = 0;
  for (const productDoc of productsSnap.docs) {
    const sku = productDoc.id;
    const product = productDoc.data();
    const restrictedSnap = await productDoc.ref.collection('restricted').doc('cost').get();
    const incumbent = restrictedSnap.data();

    if (!incumbent || !incumbent.supplierName) {
      console.log(`Skipping ${sku}: no incumbent supplier data.`);
      continue;
    }

    // 1. Incumbent supplier: migrate into suppliers/{id} + eligibleSuppliers/{id}.
    const incumbentId = slugify(incumbent.supplierName);
    await db.collection('suppliers').doc(incumbentId).set(
      {
        name: incumbent.supplierName,
        contactPerson: incumbent.contactPerson || null,
        email: incumbent.email || null,
        phone: incumbent.phone || null,
        address: incumbent.address || null,
      },
      { merge: true }
    );
    await productDoc.ref.collection('eligibleSuppliers').doc(incumbentId).set({
      unitCost: incumbent.costPerUnit || 0,
      leadTimeDays: incumbent.leadTimeDays || 0,
      moq: 250,
    });
    const incumbentPersona = PERSONA_NAMES[Math.floor(seededRandom(incumbentId)() * PERSONA_NAMES.length)];
    await ensureSupplierPerformance(incumbentId, incumbent.supplierName, incumbentPersona);

    // 2. Two alternate suppliers per product, drawn deterministically from the pool.
    const rand = seededRandom(sku);
    const shuffled = [...ALTERNATE_SUPPLIER_POOL].sort(() => rand() - 0.5);
    const alternates = shuffled.slice(0, 2);

    for (const alt of alternates) {
      const altId = slugify(alt.name);
      await db.collection('suppliers').doc(altId).set(
        { name: alt.name, contactPerson: alt.contactPerson, email: alt.email, phone: alt.phone, address: alt.address },
        { merge: true }
      );
      const costJitter = 0.85 + rand() * 0.3; // +/-15% vs incumbent
      const leadJitter = Math.max(1, Math.round((incumbent.leadTimeDays || 5) * (0.7 + rand() * 0.6)));
      await productDoc.ref.collection('eligibleSuppliers').doc(altId).set({
        unitCost: Math.round((incumbent.costPerUnit || 0) * costJitter * 100) / 100,
        leadTimeDays: leadJitter,
        moq: 100,
      });
      await ensureSupplierPerformance(altId, alt.name, alt.persona);
    }

    processed++;
    if (processed % 10 === 0) console.log(`Processed ${processed}/${productsSnap.size} products...`);
  }

  console.log(`Done. Processed ${processed} products.`);
}

main()
  .catch((e) => {
    console.error('SEED FAILED:', e);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
