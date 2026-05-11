import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/product_input_card.dart';
import '../widgets/product_list_view.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final _collection = FirebaseFirestore.instance.collection('products');

  Future<void> addProduct() async {
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    if (name.isEmpty || quantity.isEmpty) return;
    await _collection.add({'name': name, 'quantity': quantity});
    nameController.clear();
    quantityController.clear();
  }

  Future<void> removeProduct(String docId) async {
    await _collection.doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'Product Inventory',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _collection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          final products = docs
              .map((d) => {
                    'id': d.id,
                    'name': (d.data() as Map<String, dynamic>)['name']?.toString() ?? '',
                    'quantity': (d.data() as Map<String, dynamic>)['quantity']?.toString() ?? '0',
                  })
              .toList();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ProductInputCard(
                  nameController: nameController,
                  quantityController: quantityController,
                  onAdd: addProduct,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ProductListView(
                    products: products,
                    onRemove: (index) => removeProduct(docs[index].id),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}