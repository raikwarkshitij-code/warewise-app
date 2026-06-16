import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/stat_card.dart';
import 'alerts_page.dart'; // Complete route connection

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  // --- 📦 QUICK OPERATIONS FIRESTORE TRANSACTION ENGINE ---
  void _showStockAdjustmentModal(BuildContext context, {required bool isAdding}) {
    final skuController = TextEditingController();
    final qtyController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool internalLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAdding ? Icons.add_circle_rounded : Icons.unarchive_rounded,
                          color: const Color(0xFF009473),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAdding ? 'Quick Stock In' : 'Quick Dispatch / Stock Out',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01604B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: skuController,
                      decoration: const InputDecoration(
                        labelText: 'Product SKU',
                        hintText: 'Enter exact barcode SKU (e.g., PROD005)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'SKU field required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Unit Quantity',
                        hintText: 'How many units?',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || int.tryParse(v.trim()) == null) return 'Enter a valid number';
                        if (int.parse(v.trim()) <= 0) return 'Quantity must be greater than 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009473),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: internalLoading ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          
                          setModalState(() => internalLoading = true);
                          final targetSku = skuController.text.trim();
                          final changeAmount = int.parse(qtyController.text.trim());
                          
                          final docRef = FirebaseFirestore.instance.collection('products').doc(targetSku);
                          
                          try {
                            await FirebaseFirestore.instance.runTransaction((transaction) async {
                              final snapshot = await transaction.get(docRef);
                              
                              if (!snapshot.exists) {
                                throw Exception("SKU '$targetSku' does not exist in inventory system.");
                              }
                              
                              final int currentQty = int.tryParse(snapshot.get('quantity').toString()) ?? 0;
                              int newQty = isAdding ? (currentQty + changeAmount) : (currentQty - changeAmount);
                              
                              if (newQty < 0) {
                                throw Exception("Insufficient inventory. Only $currentQty units available.");
                              }
                              
                              transaction.update(docRef, {'quantity': newQty});
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Inventory Quantities Synchronized!'), backgroundColor: Color(0xFF009473)),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString().replaceAll('Exception:', '')), backgroundColor: Colors.redAccent),
                              );
                            }
                          } finally {
                            if (context.mounted) setModalState(() => internalLoading = false);
                          }
                        },
                        child: internalLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Execute Inventory Modification Ledger'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 🧭 REDIRECT CONTROLLER SHORTCUT ---
  void _navigateToStockTab(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AlertsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Breakpoint manager preventing layout compression alerts on high-density browser panels
    int crossAxisCount = 2;
    double aspectRatio = 1.4;
    
    if (screenWidth > 1100) {
      crossAxisCount = 4;
      aspectRatio = 1.7;
    } else if (screenWidth > 650) {
      crossAxisCount = 2;
      aspectRatio = 1.4;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('products').snapshots(),
          builder: (context, snapshot) {
            String totalItemsCount = '...';
            String totalInventoryValue = '...';
            String activeAlertsCount = '0';

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final docs = snapshot.data!.docs;
              int itemsSum = 0;
              double monetaryValueSum = 0.0;
              int lowStockAlerts = 0;

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                
                final String rawQuantity = data['quantity']?.toString() ?? '0';
                final String rawPrice = data['price']?.toString() ?? '0.0';

                final int quantity = int.tryParse(rawQuantity) ?? 0;
                final double price = double.tryParse(rawPrice) ?? 0.0;
                
                // Set threshold to 1000 to match your wholesale CSV file structures perfectly
                const int forcedMinThreshold = 1000; 

                itemsSum += quantity;
                monetaryValueSum += (quantity * price);
                
                if (quantity <= forcedMinThreshold) {
                  lowStockAlerts++;
                }
              }

              totalItemsCount = itemsSum.toString();
              totalInventoryValue = '\$${monetaryValueSum.toStringAsFixed(0)}';
              activeAlertsCount = lowStockAlerts.toString();
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HERO BRAND CONTAINER BANNER ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF01604B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome to WareWise',
                          style: TextStyle(color: Color(0xFF99D4C7), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Smarter Inventory Control Hub',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.layers_outlined, color: Color(0xFF1CB08F), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Operations Panel Active",
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  // --- 🛡️ GRIDVIEW MATRIX WRAPPER ---
                  GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: aspectRatio,
                    children: [
                      StatCard(icon: Icons.inventory_2_outlined, label: 'Total Items', value: totalItemsCount, flagColor: const Color(0xFF1CB08F)),
                      StatCard(icon: Icons.account_balance_wallet_outlined, label: 'Inventory Value', value: totalInventoryValue, flagColor: const Color(0xFF1CB08F)),
                      StatCard(
                        icon: Icons.shopping_cart_outlined, 
                        label: 'Low Stock Items', 
                        value: activeAlertsCount, 
                        flagColor: activeAlertsCount == '0' ? const Color(0xFF1CB08F) : const Color(0xFFF59E0B),
                      ),
                      const StatCard(icon: Icons.trending_up_rounded, label: 'Monthly Profit', value: '\$4,120', flagColor: Color(0xFF1CB08F)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- QUICK OPERATIONS ROW SECTION ---
                  const Text(
                    'Quick Operations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01604B)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildQuickOpsButton('Stock In', Icons.add_circle_outline_rounded, () => _showStockAdjustmentModal(context, isAdding: true))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildQuickOpsButton('Dispatch', Icons.unarchive_outlined, () => _showStockAdjustmentModal(context, isAdding: false))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildQuickOpsButton('Reports', Icons.insert_chart_outlined_rounded, () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating System Inventory Summary PDF Manifest...')));
                      })),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- EXCEPTION ALERT PANEL ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Low Stock Alerts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01604B)),
                      ),
                      TextButton(
                        onPressed: () => _navigateToStockTab(context),
                        child: const Text('View All', style: TextStyle(color: Color(0xFF009473), fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _navigateToStockTab(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            activeAlertsCount == '0' ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, 
                            color: activeAlertsCount == '0' ? const Color(0xFF1CB08F) : const Color(0xFFF59E0B), 
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            activeAlertsCount == '0' ? 'All stock levels healthy' : '$activeAlertsCount items need immediate restocking',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937), fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickOpsButton(String label, IconData icon, VoidCallback onTapAction) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTapAction,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF009473), size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF01604B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}