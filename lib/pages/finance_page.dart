import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore.dart';
import 'package:provider/provider.dart';
import '../services/role_service.dart';

/// Where a product's cost basis came from — distinguishes an actual
/// historical purchase price (from a Received PO with a specific vendor)
/// from the legacy catalog estimate, so the P&L is honest about which
/// numbers are realized vs. still assumed.
enum CostSource { purchaseOrder, catalog }

class ProductFinancials {
  final String sku;
  final String name;
  final String category;
  final double price;
  final int quantity;
  final int threshold;
  final double costPerUnit;
  final CostSource costSource;
  final String? vendorName;
  final DateTime? costAsOf;

  ProductFinancials({
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.quantity,
    required this.threshold,
    required this.costPerUnit,
    required this.costSource,
    this.vendorName,
    this.costAsOf,
  });

  bool get isRealized => costSource == CostSource.purchaseOrder;
  double get gross => price * quantity;
  double get profit => (price - costPerUnit) * quantity;
  double get margin => price == 0 ? 0 : (price - costPerUnit) / price;
  double get reorderCost =>
      quantity < threshold ? (threshold - quantity) * costPerUnit : 0;
}

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late Future<List<ProductFinancials>> _dataFuture = _loadFinancials();

  Future<List<ProductFinancials>> _loadFinancials() async {
    final productsSnap = await db.collection('products').get();

    // One query for every Received PO, instead of a per-product PO lookup —
    // then pick the most recent per productId client-side. Keeps this a
    // fixed number of reads regardless of how many products exist.
    final poSnap = await db
        .collection('purchase_orders')
        .where('status', isEqualTo: 'Received')
        .get();

    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
        latestReceivedPoByProduct = {};
    for (final doc in poSnap.docs) {
      final productId = doc.data()['productId'] as String?;
      if (productId == null) continue;
      final receivedAt = doc.data()['receivedAt'] as Timestamp?;
      final existing = latestReceivedPoByProduct[productId];
      final existingReceivedAt = existing?.data()['receivedAt'] as Timestamp?;
      if (existing == null ||
          (receivedAt != null &&
              (existingReceivedAt == null ||
                  receivedAt.compareTo(existingReceivedAt) > 0))) {
        latestReceivedPoByProduct[productId] = doc;
      }
    }

    final results = await Future.wait(productsSnap.docs.map((doc) async {
      final data = doc.data();
      final latestPo = latestReceivedPoByProduct[doc.id];

      double costPerUnit;
      CostSource costSource;
      String? vendorName;
      DateTime? costAsOf;

      if (latestPo != null) {
        final po = latestPo.data();
        costPerUnit = (po['unitCost'] as num?)?.toDouble() ?? 0.0;
        costSource = CostSource.purchaseOrder;
        vendorName = po['supplierName'] as String?;
        costAsOf = (po['receivedAt'] as Timestamp?)?.toDate();
      } else {
        // No real purchase history yet for this product — fall back to the
        // legacy catalog estimate rather than showing a $0 cost.
        final restrictedSnap =
            await doc.reference.collection('restricted').doc('cost').get();
        final restricted = restrictedSnap.data() ?? {};
        costPerUnit = (restricted['costPerUnit'] as num?)?.toDouble() ?? 0.0;
        costSource = CostSource.catalog;
      }

      return ProductFinancials(
        sku: doc.id,
        name: data['name'] ?? 'Unknown Item',
        category: data['category'] ?? 'Uncategorized',
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (data['quantity'] as num?)?.toInt() ?? 0,
        threshold: (data['threshold'] as num?)?.toInt() ?? 0,
        costPerUnit: costPerUnit,
        costSource: costSource,
        vendorName: vendorName,
        costAsOf: costAsOf,
      );
    }));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final canView = context
        .watch<RoleService>()
        .hasAnyRole(['finance', 'manager', 'owner']);
    if (!canView) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
            child: Text('Restricted to Finance, Manager, and Owner roles.',
                style: TextStyle(color: Colors.grey))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FutureBuilder<List<ProductFinancials>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1E297A)));
          }

          final products = snapshot.data!;
          final Map<String, List<ProductFinancials>> byCategory = {};
          for (final p in products) {
            byCategory.putIfAbsent(p.category, () => []).add(p);
          }

          double totalGross = 0, totalProfit = 0, totalReorderCost = 0;
          int realizedCount = 0;
          for (final p in products) {
            totalGross += p.gross;
            totalProfit += p.profit;
            totalReorderCost += p.reorderCost;
            if (p.isRealized) realizedCount++;
          }
          final double blendedMargin =
              totalGross == 0 ? 0 : totalProfit / totalGross;

          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _dataFuture = _loadFinancials()),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Financial Health Performance',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                      '$realizedCount of ${products.length} products priced from actual purchase orders — the rest use catalog estimates',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.monetization_on,
                          iconColor: Colors.blue.shade700,
                          value: '\$${totalGross.toStringAsFixed(2)}',
                          label: 'Gross Rev. Pool',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          icon: Icons.trending_up,
                          iconColor: Colors.green.shade700,
                          value: '${(blendedMargin * 100).toStringAsFixed(1)}%',
                          label: 'Blended Margin',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E297A),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Realized Margin (Price − Actual Vendor Cost) × Stock',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Text('\$${totalProfit.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.amberAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estimated Reorder Cost (below threshold): \$${totalReorderCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Performance Breakdown by Category',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 12),
                  ...byCategory.entries.map((entry) {
                    final categoryProducts = entry.value;
                    final categoryGross = categoryProducts.fold<double>(
                        0, (total, p) => total + p.gross);
                    final categoryProfit = categoryProducts.fold<double>(
                        0, (total, p) => total + p.profit);
                    final categoryMargin =
                        categoryGross == 0 ? 0 : categoryProfit / categoryGross;
                    return _buildCategoryListItem(
                      context,
                      title: entry.key,
                      totalItems: categoryProducts.length,
                      grossRevenue: '\$${categoryGross.toStringAsFixed(2)}',
                      netProfit:
                          '${categoryProfit >= 0 ? '+' : ''}\$${categoryProfit.toStringAsFixed(2)}',
                      margin:
                          '${(categoryMargin * 100).toStringAsFixed(1)}% margin',
                      products: categoryProducts,
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(
      {required IconData icon,
      required Color iconColor,
      required String value,
      required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withOpacity(0.1),
              child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: iconColor))),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryListItem(
    BuildContext context, {
    required String title,
    required int totalItems,
    required String grossRevenue,
    required String netProfit,
    required String margin,
    required List<ProductFinancials> products,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryDetailPage(
                categoryTitle: title,
                itemCount: totalItems,
                grossRevenue: grossRevenue,
                netProfit: netProfit,
                products: products,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('$totalItems items listed • Gross: $grossRevenue',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(netProfit,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade100)),
                    child: Text(margin,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryDetailPage extends StatelessWidget {
  final String categoryTitle;
  final int itemCount;
  final String grossRevenue;
  final String netProfit;
  final List<ProductFinancials> products;

  const CategoryDetailPage({
    super.key,
    required this.categoryTitle,
    required this.itemCount,
    required this.grossRevenue,
    required this.netProfit,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('$categoryTitle ($itemCount Items)',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E297A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Category Revenue',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(grossRevenue,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Net Capital Contribution',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(netProfit,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700)),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('No data found for this category.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: DataTable(
                        headingRowColor:
                            MaterialStateProperty.all(Colors.blueGrey.shade50),
                        columnSpacing: 22,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(
                              label: Text('SKU',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                          DataColumn(
                              label: Text('Product Item Name',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                          DataColumn(
                              label: Text('Retail Price',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                          DataColumn(
                              label: Text('Stock',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                          DataColumn(
                              label: Text('Gross Revenue',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                          DataColumn(
                              label: Text('Net Profit',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                          DataColumn(
                              label: Text('Cost Source',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                      fontSize: 12))),
                        ],
                        rows: products.map((p) {
                          return DataRow(cells: [
                            DataCell(Text(p.sku,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87))),
                            DataCell(Text(p.name,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black87))),
                            DataCell(Text('\$${p.price.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text('${p.quantity} units',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text('\$${p.gross.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text('\$${p.profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700))),
                            DataCell(_CostSourceBadge(product: p)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shows whether a row's cost basis is a real historical purchase price
/// (from a Received PO with a named vendor) or still a catalog estimate.
class _CostSourceBadge extends StatelessWidget {
  final ProductFinancials product;

  const _CostSourceBadge({required this.product});

  @override
  Widget build(BuildContext context) {
    if (!product.isRealized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6)),
        child: const Text('Catalog Est.',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }
    final vendor = product.vendorName ?? 'Vendor';
    final asOf = product.costAsOf;
    final asOfLabel =
        asOf != null ? '${asOf.month}/${asOf.day}/${asOf.year}' : '';
    return Tooltip(
      message: asOf != null
          ? 'Actual purchase price from $vendor, received $asOfLabel'
          : 'Actual purchase price from $vendor',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade100)),
        child: Text('Realized · $vendor',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800)),
      ),
    );
  }
}
