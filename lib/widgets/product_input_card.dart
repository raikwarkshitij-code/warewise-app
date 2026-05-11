import 'package:flutter/material.dart';

class ProductInputCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final VoidCallback onAdd;

  const ProductInputCard({
    super.key,
    required this.nameController,
    required this.quantityController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}