
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/product_input_card.dart';
import '../widgets/product_list_view.dart';
import 'product_detail_screen.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController minStockLevelController = TextEditingController();

  final _collection = FirebaseFirestore.instance.collection('products');

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    minStockLevelController.dispose();
    super.dispose();
  }

  Future<void> addProduct() async {
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    final minStock = minStockLevelController.text.trim().isEmpty
        ? '0'
        : minStockLevelController.text.trim();
    if (name.isEmpty || quantity.isEmpty) return;
    await _collection.add({
      'name': name,
      'quantity': quantity,
      'minStockLevel': minStock,
    });
    nameController.clear();
    quantityController.clear();
    minStockLevelController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final products = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return <String, dynamic>{
            'id': d.id,
            'name': data['name']?.toString() ?? '',
            'quantity': data['quantity']?.toString() ?? '0',
            'minStockLevel': data['minStockLevel']?.toString() ?? '0',
          };
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ProductInputCard(
                nameController: nameController,
                quantityController: quantityController,
                minStockLevelController: minStockLevelController,
                onAdd: addProduct,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ProductListView(
                  products: products,
                  onTap: (product) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
