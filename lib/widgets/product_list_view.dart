import 'package:flutter/material.dart';

class ProductListView extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool isSelectionMode;
  final Set<String> selectedProductIds;
  final Function(String productId) onToggleSelection;
  final Function(String productId) onLongPress;
  // Standardized callback name for navigating to detail view, made required
  final Function(Map<String, dynamic> product) onProductTap;

  const ProductListView({
    super.key,
    required this.products,
    required this.onProductTap,
    required this.onToggleSelection,
    required this.onLongPress,
    this.isSelectionMode = false,
    this.selectedProductIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment
              .spaceBetween, // FIXED: Removed the invalid networkAxisAlignment line!
          children: [
            const Text(
              'Products in Stock',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Chip(
              label: Text('${products.length} items'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: products.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No products yet.\nImport your CSV above!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final String productId = product['id']?.toString() ?? '';
                    final bool isSelected =
                        selectedProductIds.contains(productId);

                    // Parse numbers to check for Low Stock Alerts
                    final int qty =
                        int.tryParse(product['quantity']?.toString() ?? '0') ??
                            0;
                    final int minStock = int.tryParse(
                            product['minStockLevel']?.toString() ?? '0') ??
                        0;
                    final bool isLowStock = qty <= minStock;

                    // Determine Card Background Color
                    Color? cardColor;
                    if (isSelected) {
                      cardColor = Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.5);
                    } else if (isLowStock) {
                      cardColor =
                          Colors.red.shade50; // Critical Alert Background
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: cardColor,
                      child: ListTile(
                        onTap: () {
                          if (isSelectionMode) {
                            onToggleSelection(productId);
                          } else {
                            onProductTap(product);
                          }
                        },
                        onLongPress: () => onLongPress(productId),
                        leading: isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  onToggleSelection(productId);
                                },
                              )
                            : CircleAvatar(
                                backgroundColor: isLowStock
                                    ? Colors.red.shade100
                                    : Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isLowStock
                                        ? Colors.red.shade900
                                        : Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        title: Text(
                          product['name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLowStock ? Colors.red.shade900 : null,
                          ),
                        ),
                        subtitle: Text(
                          'Quantity: $qty / Min Threshold: $minStock',
                          style: TextStyle(
                            color: isLowStock
                                ? Colors.red.shade700
                                : Colors.grey.shade700,
                            fontWeight: isLowStock
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelectionMode
                            ? null
                            : Icon(
                                isLowStock
                                    ? Icons.warning_amber_rounded
                                    : Icons.arrow_forward_ios,
                                size: isLowStock ? 24 : 16,
                                color: isLowStock ? Colors.red : Colors.grey,
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
