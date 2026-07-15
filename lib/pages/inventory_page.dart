import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import 'package:provider/provider.dart';
import 'edit_product_screen.dart';
import 'product_detail_screen.dart';
import '../services/role_service.dart';
import '../widgets/tap_scale.dart';
import '../widgets/stream_error_view.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String _activeFilterCategory = 'All';
  final List<String> _staticCategoryDirectory = [
    'All',
    'Electronics',
    'Fashion & Apparel',
    'Beauty & Health',
    'Footwear',
    'Accessories',
    'Consumables',
    'Packaging',
    'Equipment'
  ];

  @override
  Widget build(BuildContext context) {
    final canEditProducts =
        context.watch<RoleService>().hasAnyRole(['manager', 'owner']);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text('Live Stock Ledger',
            style: TextStyle(
                color: Color(0xFF01604B),
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5)),
      ),
      floatingActionButton: canEditProducts
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF009473),
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProductScreen()));
              },
            )
          : null,
      body: Column(
        children: [
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _staticCategoryDirectory.length,
              itemBuilder: (context, idx) {
                final String currentCat = _staticCategoryDirectory[idx];
                final bool isSelected = _activeFilterCategory == currentCat;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(currentCat),
                    labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : const Color(0xFF475569),
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13),
                    selected: isSelected,
                    selectedColor: const Color(0xFF009473),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF009473)
                            : const Color(0xFFCBD5E1),
                        width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (_) =>
                        setState(() => _activeFilterCategory = currentCat),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return StreamErrorView(
                    error: snapshot.error,
                    message: 'Could not load inventory.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF009473)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.cloud_sync_rounded,
                            size: 44, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text('Awaiting automated cloud sync payload...',
                            style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }

                var activeDataset = snapshot.data!.docs;
                if (_activeFilterCategory != 'All') {
                  activeDataset = activeDataset.where((document) {
                    final Map<String, dynamic> dataMap =
                        document.data() as Map<String, dynamic>;
                    return dataMap['category'] == _activeFilterCategory;
                  }).toList();
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: activeDataset.length,
                  itemBuilder: (context, index) {
                    final doc = activeDataset[index];
                    final product = doc.data() as Map<String, dynamic>;

                    final String name =
                        product['name'] ?? 'Unspecified Identifier';
                    final String sku = product['sku'] ?? doc.id;
                    final int qty =
                        int.tryParse(product['quantity']?.toString() ?? '0') ??
                            0;
                    final int threshold = int.tryParse(
                            product['threshold']?.toString() ?? '1000') ??
                        1000;
                    final double price = double.tryParse(
                            product['price']?.toString() ?? '0.0') ??
                        0.0;
                    final bool isLowStock = qty <= threshold;

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: 1.0,
                      child: TapScale(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: product))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isLowStock
                                    ? const Color(0xFFFED7AA)
                                    : const Color(0xFFE2E8F0),
                                width: isLowStock ? 1.5 : 1),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isLowStock
                                    ? const Color(0xFFFFF7ED)
                                    : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.all_inbox_rounded,
                                color: isLowStock
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                    fontSize: 14)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  'SKU: $sku • ${product['category'] ?? 'General'}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8))),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$qty Units',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: isLowStock
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF0F172A),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('\$${price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
