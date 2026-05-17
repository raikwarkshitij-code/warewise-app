import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/stat_card.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool _hasAccess = false;
  final TextEditingController _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // --- SECURITY REGISTRY GATEWAY ---
  void _showFinanceAuthDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              const Text('Financial Portal Gate'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This screen contains sensitive revenue data records. Enter management or finance authorization credentials to unlock.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  labelText: 'Security PIN',
                  prefixIcon: const Icon(Icons.enhanced_encryption),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (_pinController.text.trim() == 'mwis2026') {
                  Navigator.pop(context);
                  setState(() => _hasAccess = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Access Denied: Invalid security PIN.'),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Unlock Portal'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person, size: 64, color: Colors.indigo.shade200),
            const SizedBox(height: 16),
            const Text(
              'Financial Telemetry Vault Locked',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              'Restricted to verified Manager & Finance clearances.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _showFinanceAuthDialog,
              icon: const Icon(Icons.vpn_key),
              label: const Text('Verify Access Clearance',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Financial Health Performance',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        'Click on individual categories below to view itemized background analysis lines',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _hasAccess = false),
                  icon:
                      const Icon(Icons.lock_reset, size: 16, color: Colors.red),
                  label: const Text('Lock Vault',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                )
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return Center(
                        child: Text(
                            'Database extraction block: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data?.docs ?? [];

                  double totalPotentialRevenue = 0.0;
                  double totalDerivedCost = 0.0;

                  // Maps categories to their financial stats and an array of individual product lines
                  Map<String, Map<String, dynamic>> categoryMetrics = {};

                  for (var d in docs) {
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final String id = d.id;
                    final String name =
                        data['name']?.toString() ?? 'Unknown SKU';
                    final double price =
                        double.tryParse(data['price']?.toString() ?? '0.0') ??
                            0.0;
                    final int qty =
                        int.tryParse(data['quantity']?.toString() ?? '0') ?? 0;
                    final String category =
                        data['category']?.toString() ?? 'Uncategorized';

                    double productRevenue = price * qty;
                    double productCost = productRevenue * 0.60;
                    double productProfit = productRevenue - productCost;

                    totalPotentialRevenue += productRevenue;
                    totalDerivedCost += productCost;

                    if (!categoryMetrics.containsKey(category)) {
                      categoryMetrics[category] = {
                        'revenue': 0.0,
                        'cost': 0.0,
                        'items': <Map<String, dynamic>>[]
                      };
                    }

                    categoryMetrics[category]!['revenue'] =
                        categoryMetrics[category]!['revenue'] + productRevenue;
                    categoryMetrics[category]!['cost'] =
                        categoryMetrics[category]!['cost'] + productCost;

                    // Save detailed nested metadata maps for the sub-table breakdowns
                    (categoryMetrics[category]!['items']
                            as List<Map<String, dynamic>>)
                        .add({
                      'sku': id.length > 5
                          ? id.substring(0, 5).toUpperCase()
                          : id.toUpperCase(),
                      'name': name,
                      'price': price,
                      'stock': qty,
                      'revenue': productRevenue,
                      'profit': productProfit,
                    });
                  }

                  double totalProfit = totalPotentialRevenue - totalDerivedCost;
                  double structuralProfitMargin = totalPotentialRevenue > 0
                      ? (totalProfit / totalPotentialRevenue) * 100
                      : 0.0;

                  return ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              icon: Icons.monetization_on,
                              label: 'Gross Rev. Pool',
                              value:
                                  '€${totalPotentialRevenue.toStringAsFixed(2)}',
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              icon: Icons.trending_up,
                              label: 'Net Margin Est.',
                              value:
                                  '${structuralProfitMargin.toStringAsFixed(1)}%',
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Card(
                        elevation: 2,
                        color: Colors.indigo.shade900,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimated Net Profit Earnings',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Text('€${totalProfit.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              const Text(
                                  '*Calculations model a structured 40% margin ceiling across cost of operations inputs.',
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text('Performance Breakdown by Category',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      const SizedBox(height: 12),

                      // INTERACTIVE BREAKDOWN ACCORDION SHEET GENERATOR
                      ...categoryMetrics.entries.map((entry) {
                        double rev = entry.value['revenue']!;
                        double cost = entry.value['cost']!;
                        double profit = rev - cost;
                        double margin = rev > 0 ? (profit / rev) * 100 : 0.0;
                        List<Map<String, dynamic>> productsList =
                            List<Map<String, dynamic>>.from(
                                entry.value['items']!);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.black87)),
                              subtitle: Text(
                                  'Gross Revenue: €${rev.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('+€${profit.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        '${margin.toStringAsFixed(1)}% margin',
                                        style: TextStyle(
                                            color: Colors.green.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10)),
                                  )
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                Container(
                                  width: double.infinity,
                                  color: Colors.grey.shade50,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                              Colors.indigo.shade50),
                                      columnSpacing: 20,
                                      columns: const [
                                        DataColumn(
                                            label: Text('SKU',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.indigo))),
                                        DataColumn(
                                            label: Text('Product Item Name',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.indigo))),
                                        DataColumn(
                                            label: Text('Retail Price',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.indigo))),
                                        DataColumn(
                                            label: Text('Stock',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.indigo))),
                                        DataColumn(
                                            label: Text('Gross Revenue',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.indigo))),
                                        DataColumn(
                                            label: Text('Net Profit (40%)',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: Colors.indigo))),
                                      ],
                                      rows: productsList.map((product) {
                                        return DataRow(cells: [
                                          DataCell(Text(product['sku'],
                                              style: const TextStyle(
                                                  fontFamily: 'monospace',
                                                  fontSize: 12))),
                                          DataCell(Text(product['name'],
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w500))),
                                          DataCell(Text(
                                              '€${product['price'].toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                          DataCell(Text(
                                              '${product['stock']} units',
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                          DataCell(Text(
                                              '€${product['revenue'].toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                          DataCell(Text(
                                              '€${product['profit'].toStringAsFixed(2)}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green.shade700,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                        ]);
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
