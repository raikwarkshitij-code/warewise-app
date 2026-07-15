const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

const ROLES = ['associate', 'manager', 'finance', 'owner'];

function requireRole(request, allowed) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
  const role = request.auth.token.role;
  if (!allowed.includes(role)) {
    throw new HttpsError(
      'permission-denied',
      `Role '${role || 'none'}' cannot perform this action.`
    );
  }
  return role;
}

/**
 * Assigns a role to a user. Only an 'owner' can call this.
 * Replaces the old hardcoded PIN ('mwis2026') check that lived in the
 * Flutter client and controlled nothing but a local boolean.
 */
exports.setUserRole = onCall(async (request) => {
  requireRole(request, ['owner']);
  const { uid, role } = request.data;

  if (!uid || typeof uid !== 'string') {
    throw new HttpsError('invalid-argument', 'uid is required.');
  }
  if (!ROLES.includes(role)) {
    throw new HttpsError('invalid-argument', `role must be one of ${ROLES.join(', ')}`);
  }

  await admin.auth().setCustomUserClaims(uid, { role });
  await db.collection('users').doc(uid).set(
    { role, updatedAt: admin.firestore.FieldValue.serverTimestamp(), updatedBy: request.auth.uid },
    { merge: true }
  );

  return { success: true };
});

/**
 * Manager/owner approves a pending transfer and ships it.
 * Runs the stock decrement + status change as a single Firestore
 * transaction so a crash or dropped connection can't leave the two
 * halves out of sync (the bug in the original _managerApproveAndShip).
 *
 * Same race-condition protection pattern as confirmGoodsReceipt below: the
 * `status !== 'Pending'` check reads within the transaction, so two
 * simultaneous approve calls on the same transfer can't both succeed — the
 * loser sees the already-updated status and fails cleanly instead of
 * double-decrementing stock.
 */
exports.approveAndShipTransfer = onCall(async (request) => {
  requireRole(request, ['manager', 'owner']);
  const { transferId } = request.data;
  if (!transferId) {
    throw new HttpsError('invalid-argument', 'transferId is required.');
  }

  return db.runTransaction(async (tx) => {
    const transferRef = db.collection('transfers').doc(transferId);
    const transferSnap = await tx.get(transferRef);
    if (!transferSnap.exists) {
      throw new HttpsError('not-found', 'Transfer not found.');
    }
    const transfer = transferSnap.data();
    if (transfer.status !== 'Pending') {
      throw new HttpsError(
        'failed-precondition',
        `Transfer is '${transfer.status}', expected 'Pending'.`
      );
    }

    const volume = Number(transfer.volume);
    if (!Number.isFinite(volume) || volume <= 0) {
      throw new HttpsError('invalid-argument', 'Transfer has an invalid volume.');
    }

    const productRef = db.collection('products').doc(transfer.productId);
    const productSnap = await tx.get(productRef);
    if (!productSnap.exists) {
      throw new HttpsError('not-found', 'Product not found.');
    }
    const product = productSnap.data();
    const sourceHub = transfer.from;
    const currentStock = (product.cityStock && product.cityStock[sourceHub]) || 0;

    if (currentStock < volume) {
      throw new HttpsError(
        'failed-precondition',
        `Only ${currentStock} units available at ${sourceHub}, cannot ship ${volume}.`
      );
    }

    tx.update(productRef, {
      [`cityStock.${sourceHub}`]: admin.firestore.FieldValue.increment(-volume),
      quantity: admin.firestore.FieldValue.increment(-volume),
    });
    tx.update(transferRef, {
      status: 'In Transit',
      approvedBy: request.auth.uid,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
});

/**
 * Associate/manager confirms delivery at the destination hub.
 * Also transactional, and re-checks that the transfer is still
 * 'In Transit' so it can't be double-confirmed.
 */
exports.confirmDelivery = onCall(async (request) => {
  requireRole(request, ['associate', 'manager', 'owner']);
  const { transferId } = request.data;
  if (!transferId) {
    throw new HttpsError('invalid-argument', 'transferId is required.');
  }

  return db.runTransaction(async (tx) => {
    const transferRef = db.collection('transfers').doc(transferId);
    const transferSnap = await tx.get(transferRef);
    if (!transferSnap.exists) {
      throw new HttpsError('not-found', 'Transfer not found.');
    }
    const transfer = transferSnap.data();
    if (transfer.status !== 'In Transit') {
      throw new HttpsError(
        'failed-precondition',
        `Transfer is '${transfer.status}', expected 'In Transit'.`
      );
    }

    const volume = Number(transfer.volume);
    const productRef = db.collection('products').doc(transfer.productId);
    const destinationHub = transfer.to;

    tx.update(productRef, {
      [`cityStock.${destinationHub}`]: admin.firestore.FieldValue.increment(volume),
      quantity: admin.firestore.FieldValue.increment(volume),
    });
    tx.update(transferRef, {
      status: 'Delivered',
      confirmedBy: request.auth.uid,
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
});

/**
 * Manager/owner rejects a pending transfer. Sets a terminal status rather
 * than deleting, so the record stays in the audit trail (reads are already
 * role-gated in firestore.rules).
 */
exports.rejectTransfer = onCall(async (request) => {
  requireRole(request, ['manager', 'owner']);
  const { transferId } = request.data;
  if (!transferId) {
    throw new HttpsError('invalid-argument', 'transferId is required.');
  }

  return db.runTransaction(async (tx) => {
    const transferRef = db.collection('transfers').doc(transferId);
    const transferSnap = await tx.get(transferRef);
    if (!transferSnap.exists) {
      throw new HttpsError('not-found', 'Transfer not found.');
    }
    const transfer = transferSnap.data();
    if (transfer.status !== 'Pending') {
      throw new HttpsError(
        'failed-precondition',
        `Transfer is '${transfer.status}', expected 'Pending'.`
      );
    }

    tx.update(transferRef, {
      status: 'Rejected',
      rejectedBy: request.auth.uid,
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  });
});

const HUBS = ['Berlin', 'Munich', 'Hamburg'];

/**
 * Manager/owner creates or updates a product's catalog fields and its
 * restricted cost/supplier data. This is the only legal write path for
 * `products/{sku}` and `products/{sku}/restricted/cost` from the client,
 * since firestore.rules blocks direct writes to both.
 */
exports.adminUpsertProduct = onCall(async (request) => {
  requireRole(request, ['manager', 'owner']);
  const { sku, name, category, price, threshold, cityStock, supplier } = request.data;

  if (!sku || typeof sku !== 'string') {
    throw new HttpsError('invalid-argument', 'sku is required.');
  }
  if (!name || !category) {
    throw new HttpsError('invalid-argument', 'name and category are required.');
  }
  if (!cityStock || HUBS.some((hub) => typeof cityStock[hub] !== 'number' || cityStock[hub] < 0)) {
    throw new HttpsError(
      'invalid-argument',
      `cityStock must include non-negative numbers for ${HUBS.join(', ')}.`
    );
  }

  const quantity = HUBS.reduce((sum, hub) => sum + cityStock[hub], 0);
  const productRef = db.collection('products').doc(sku);

  await productRef.set(
    {
      sku,
      name: String(name),
      category: String(category),
      price: Number(price) || 0,
      threshold: Number(threshold) || 0,
      cityStock,
      quantity,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
    },
    { merge: true }
  );

  if (supplier) {
    await productRef.collection('restricted').doc('cost').set(supplier, { merge: true });
  }

  return { success: true };
});

const STRATEGY_LABELS = {
  cost: 'Cost-Focused',
  reliability: 'Reliability-Focused',
  balanced: 'Balanced',
};

/**
 * Strategy-relative fit score (0-100, or null if not computable under this
 * strategy). This is what ranking order and the "Recommended for X" badge
 * are based on — separate from `vendorScore`, which stays the fixed
 * balanced formula regardless of strategy so it's always comparable across
 * strategy switches.
 */
function computeStrategyScore(strategy, supplier, peers) {
  if (strategy === 'cost') {
    // Pure price fitness — reliability history is irrelevant to this
    // strategy, so even a brand-new supplier with zero history is eligible.
    const costs = peers.map((p) => p.unitCost);
    const min = Math.min(...costs);
    const max = Math.max(...costs);
    if (max === min) return 100;
    return Math.round((100 * (max - supplier.unitCost)) / (max - min) * 100) / 100;
  }
  if (strategy === 'reliability') {
    // Cost is irrelevant here — but a supplier with no delivery history has
    // nothing to judge reliability on, so it can't be scored (and sorts last).
    if (supplier.eventCount === 0) return null;
    return Math.round((0.5 * supplier.onTimeRate * 100 + 0.5 * supplier.avgQualityScore) * 100) / 100;
  }
  // 'balanced' — reuse the fixed vendorScore (same 40/40/20 formula).
  return supplier.vendorScore;
}

/** Plain-language explanation of why this supplier ranks where it does under the given strategy. */
function buildRationale(strategy, supplier, peers) {
  const others = peers.filter((p) => p.supplierId !== supplier.supplierId);
  const cheapest = peers.reduce((a, b) => (a.unitCost <= b.unitCost ? a : b));

  if (strategy === 'cost') {
    if (supplier.supplierId === cheapest.supplierId) {
      if (others.length === 0) {
        return `Only eligible supplier for this product, at $${supplier.unitCost.toFixed(2)}/unit.`;
      }
      const nextCheapest = others.reduce((a, b) => (a.unitCost <= b.unitCost ? a : b));
      const savings = nextCheapest.unitCost - supplier.unitCost;
      return `Chosen for lowest cost: $${supplier.unitCost.toFixed(2)}/unit, $${savings.toFixed(2)} cheaper than the next option (${nextCheapest.supplierName}).`;
    }
    const delta = supplier.unitCost - cheapest.unitCost;
    return `$${delta.toFixed(2)} more expensive than the cheapest option (${cheapest.supplierName} at $${cheapest.unitCost.toFixed(2)}/unit).`;
  }

  if (strategy === 'reliability') {
    if (supplier.eventCount === 0) {
      return 'No delivery history yet — reliability cannot be assessed for this supplier.';
    }
    const onTimePct = Math.round(supplier.onTimeRate * 100);
    let sentence = `Chosen for reliability: ${onTimePct}% on-time delivery and a quality score of ${supplier.avgQualityScore.toFixed(0)}/100.`;
    if (supplier.supplierId !== cheapest.supplierId) {
      const premium = supplier.unitCost - cheapest.unitCost;
      if (premium > 0) {
        sentence += ` This is $${premium.toFixed(2)} more expensive than the cheapest option (${cheapest.supplierName}), but chosen for its stronger track record.`;
      }
    }
    return sentence;
  }

  // balanced
  if (supplier.vendorScore === null) {
    return 'No delivery history yet — ranked by quoted cost and lead time only.';
  }
  return `Chosen for the best overall balance of cost, reliability, and quality (Vendor Score: ${supplier.vendorScore.toFixed(0)}/100).`;
}

/**
 * Ranks the suppliers eligible to fulfill a product. `vendorScore` is
 * always the fixed weighted formula (40% on-time rate + 40% average
 * quality + 20% price-variance discipline) built from historical Goods
 * Receipt performance — stable regardless of strategy, so it's always
 * directly comparable. `strategyScore` and the sort order/recommendation
 * are strategy-relative (see computeStrategyScore): 'cost' ranks purely by
 * quoted unit price, 'reliability' purely by on-time rate + quality,
 * 'balanced' reuses vendorScore. Each entry also gets a `rationale` string
 * explaining its rank under the selected strategy.
 */
exports.getSupplierRanking = onCall(async (request) => {
  requireRole(request, ['manager', 'finance', 'owner']);
  const { productId, strategy: rawStrategy } = request.data;
  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId is required.');
  }
  const strategy = STRATEGY_LABELS[rawStrategy] ? rawStrategy : 'balanced';

  const eligibleSnap = await db.collection('products').doc(productId).collection('eligibleSuppliers').get();
  if (eligibleSnap.empty) {
    return { suppliers: [], strategy, strategyLabel: STRATEGY_LABELS[strategy] };
  }

  const rawSuppliers = await Promise.all(
    eligibleSnap.docs.map(async (eligibleDoc) => {
      const supplierId = eligibleDoc.id;
      const terms = eligibleDoc.data();

      const [supplierSnap, performanceSnap] = await Promise.all([
        db.collection('suppliers').doc(supplierId).get(),
        db.collection('suppliers').doc(supplierId).collection('supplier_performance').get(),
      ]);

      const supplierInfo = supplierSnap.exists ? supplierSnap.data() : {};
      const events = performanceSnap.docs.map((d) => d.data());
      const eventCount = events.length;

      let vendorScore = null;
      let onTimeRate = null;
      let avgQualityScore = null;
      let avgPriceVariancePercent = null;

      if (eventCount > 0) {
        const onTimeCount = events.filter((e) => e.onTime === true).length;
        onTimeRate = onTimeCount / eventCount;
        avgQualityScore = events.reduce((sum, e) => sum + (Number(e.qualityScore) || 0), 0) / eventCount;
        avgPriceVariancePercent =
          events.reduce((sum, e) => sum + (Number(e.priceVariancePercent) || 0), 0) / eventCount;
        const avgAbsPriceVariance =
          events.reduce((sum, e) => sum + Math.abs(Number(e.priceVariancePercent) || 0), 0) / eventCount;
        vendorScore = Math.max(
          0,
          Math.min(
            100,
            0.4 * onTimeRate * 100 + 0.4 * avgQualityScore + 0.2 * Math.max(0, 100 - avgAbsPriceVariance)
          )
        );
      }

      return {
        supplierId,
        supplierName: supplierInfo.name || 'Unknown Supplier',
        contactPerson: supplierInfo.contactPerson || null,
        email: supplierInfo.email || null,
        phone: supplierInfo.phone || null,
        unitCost: Number(terms.unitCost) || 0,
        leadTimeDays: Number(terms.leadTimeDays) || 0,
        moq: Number(terms.moq) || 0,
        eventCount,
        onTimeRate,
        avgQualityScore,
        avgPriceVariancePercent,
        vendorScore,
      };
    })
  );

  const ranked = rawSuppliers.map((s) => ({
    ...s,
    strategyScore: computeStrategyScore(strategy, s, rawSuppliers),
    rationale: buildRationale(strategy, s, rawSuppliers),
  }));

  ranked.sort((a, b) => {
    if (a.strategyScore === null && b.strategyScore === null) return 0;
    if (a.strategyScore === null) return 1;
    if (b.strategyScore === null) return -1;
    return b.strategyScore - a.strategyScore;
  });

  return { suppliers: ranked, strategy, strategyLabel: STRATEGY_LABELS[strategy] };
});

/**
 * Manager/owner explicitly selects a supplier from the ranking and raises a
 * purchase order. This is the human-in-the-loop step — getSupplierRanking
 * only informs the decision, it never creates a PO on its own.
 */
exports.raisePurchaseOrder = onCall(async (request) => {
  requireRole(request, ['manager', 'owner']);
  const { productId, supplierId, quantity, destinationHub } = request.data;

  if (!productId || typeof productId !== 'string') {
    throw new HttpsError('invalid-argument', 'productId is required.');
  }
  if (!supplierId || typeof supplierId !== 'string') {
    throw new HttpsError('invalid-argument', 'supplierId is required.');
  }
  if (!HUBS.includes(destinationHub)) {
    throw new HttpsError('invalid-argument', `destinationHub must be one of ${HUBS.join(', ')}.`);
  }
  const qty = Number(quantity);
  if (!Number.isFinite(qty) || qty <= 0) {
    throw new HttpsError('invalid-argument', 'quantity must be a positive number.');
  }

  const [productSnap, eligibleSnap, supplierSnap] = await Promise.all([
    db.collection('products').doc(productId).get(),
    db.collection('products').doc(productId).collection('eligibleSuppliers').doc(supplierId).get(),
    db.collection('suppliers').doc(supplierId).get(),
  ]);

  if (!productSnap.exists) {
    throw new HttpsError('not-found', 'Product not found.');
  }
  if (!eligibleSnap.exists) {
    throw new HttpsError('not-found', 'This supplier is not eligible for this product.');
  }

  const terms = eligibleSnap.data();
  const unitCost = Number(terms.unitCost) || 0;
  const leadTimeDays = Number(terms.leadTimeDays) || 0;
  const supplierName = supplierSnap.exists ? supplierSnap.data().name || 'Unknown Supplier' : 'Unknown Supplier';

  const poRef = db.collection('purchase_orders').doc();
  await poRef.set({
    productId,
    productName: productSnap.data().name || productId,
    supplierId,
    supplierName,
    destinationHub,
    quantity: qty,
    unitCost,
    totalCost: Math.round(qty * unitCost * 100) / 100,
    leadTimeDays,
    status: 'Raised',
    raisedBy: request.auth.uid,
    raisedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, poId: poRef.id };
});

/**
 * Manager/owner confirms goods were physically received for a purchase
 * order. This is the ONLY place stock increases from a PO — raising the PO
 * itself never touches inventory. Also records a real supplier_performance
 * event (on-time computed from the quoted lead time vs. actual elapsed
 * time), so future Vendor Score calculations start incorporating real
 * outcomes instead of just the synthetic seed history.
 *
 * Race-condition protection: the status check (`po.status !== 'Raised'`)
 * happens INSIDE db.runTransaction, using a value read within that same
 * transaction. If two managers call this for the same PO at the same
 * moment, Firestore serializes the two transaction attempts — the first to
 * commit wins, and the second re-reads the now-'Received' status and throws
 * failed-precondition instead of incrementing stock a second time. This
 * also makes retries safe: if a client's network drops after the request
 * is sent but before the response arrives, retrying is harmless — either
 * the original call already committed (retry gets a clean rejection) or it
 * didn't (retry succeeds normally).
 */
exports.confirmGoodsReceipt = onCall(async (request) => {
  requireRole(request, ['manager', 'owner']);
  const { poId, qualityScore, priceVariancePercent } = request.data;
  if (!poId || typeof poId !== 'string') {
    throw new HttpsError('invalid-argument', 'poId is required.');
  }

  const poRef = db.collection('purchase_orders').doc(poId);

  const result = await db.runTransaction(async (tx) => {
    const poSnap = await tx.get(poRef);
    if (!poSnap.exists) {
      throw new HttpsError('not-found', 'Purchase order not found.');
    }
    const po = poSnap.data();
    if (po.status !== 'Raised') {
      throw new HttpsError(
        'failed-precondition',
        `Purchase order is '${po.status}', expected 'Raised'.`
      );
    }

    const productRef = db.collection('products').doc(po.productId);
    const productSnap = await tx.get(productRef);
    if (!productSnap.exists) {
      throw new HttpsError('not-found', 'Product not found.');
    }

    // Defensive fallback: POs raised before destinationHub was required
    // (legacy records) won't have this field. Default to Berlin rather than
    // writing `cityStock.undefined` and corrupting the product doc.
    const destinationHub = HUBS.includes(po.destinationHub) ? po.destinationHub : 'Berlin';
    if (destinationHub !== po.destinationHub) {
      console.warn(
        `PO ${poRef.id} has no valid destinationHub (was '${po.destinationHub}') — defaulting to '${destinationHub}'.`
      );
    }

    tx.update(productRef, {
      [`cityStock.${destinationHub}`]: admin.firestore.FieldValue.increment(po.quantity),
      quantity: admin.firestore.FieldValue.increment(po.quantity),
    });
    tx.update(poRef, {
      status: 'Received',
      destinationHub, // backfilled onto the record if it was missing
      receivedBy: request.auth.uid,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return po;
  });

  // Record the real-world outcome as a performance event (best-effort — a
  // failure here shouldn't undo the stock increment that already committed).
  try {
    const raisedAtMs = result.raisedAt && result.raisedAt.toMillis ? result.raisedAt.toMillis() : Date.now();
    const elapsedDays = (Date.now() - raisedAtMs) / (1000 * 60 * 60 * 24);
    const onTime = elapsedDays <= (Number(result.leadTimeDays) || 0) + 1; // 1-day grace period

    await db
      .collection('suppliers')
      .doc(result.supplierId)
      .collection('supplier_performance')
      .add({
        productId: result.productId,
        onTime,
        qualityScore: Number.isFinite(Number(qualityScore)) ? Number(qualityScore) : 85,
        priceVariancePercent: Number.isFinite(Number(priceVariancePercent)) ? Number(priceVariancePercent) : 0,
        orderedQty: result.quantity,
        orderDate: result.raisedAt || admin.firestore.FieldValue.serverTimestamp(),
        receivedDate: admin.firestore.FieldValue.serverTimestamp(),
        seedSource: 'real',
      });
  } catch (e) {
    console.error('Failed to record supplier_performance event for PO', poId, e);
  }

  return { success: true };
});
