import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import '../widgets/product_list_view.dart';
import '../widgets/stat_card.dart';
import 'product_detail_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('products');

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';

  bool _isSelectionMode = false;
  final Set<String> _selectedProductIds = {};
  bool _isDeleting = false;
  bool _isImporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- EXCEL-ALIGNED HIGH-PERFORMANCE CSV SEEDER ---
  Future<void> manuallyImportCsv() async {
    setState(() => _isImporting = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) return;

      final rawData = utf8.decode(bytes, allowMalformed: true);
      final normalizedRawData =
          rawData.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      List<String> allLines = normalizedRawData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (allLines.length <= 1) return;

      final String delimiter = allLines[0].contains(';') ? ';' : ',';
      List<String> dataLines = allLines.sublist(1);

      List<WriteBatch> batches = [FirebaseFirestore.instance.batch()];
      int currentBatchIndex = 0;
      int itemsInCurrentBatch = 0;
      int processedRows = 0;

      for (int i = 0; i < dataLines.length; i++) {
        try {
          String line = dataLines[i].trim();
          List<String> row = [];
          bool inQuotes = false;
          StringBuffer currentField = StringBuffer();

          for (int j = 0; j < line.length; j++) {
            if (line[j] == '"') {
              inQuotes = !inQuotes;
            } else if (line[j] == delimiter && !inQuotes) {
              row.add(currentField.toString().trim());
              currentField.clear();
            } else {
              currentField.write(line[j]);
            }
          }
          row.add(currentField.toString().trim());

          if (row.isEmpty || row[0].isEmpty) continue;

          // FIXED: Exact explicit column mapping matching your uploaded excel schema layout
          String productName = row[0];
          String category = row.length > 1 ? row[1].trim() : "Uncategorized";

          double price = 0.0;
          if (row.length > 2) {
            price =
                double.tryParse(row[2].replaceAll(RegExp(r'[^0-9.]'), '')) ??
                    0.0;
          }

          String globalQty = row.length > 3 ? row[3].trim() : "0";
          String minThreshold = row.length > 4 ? row[4].trim() : "0";

          // FIXED: Reads real warehouse stocks from columns 5, 6, and 7 instead of random values
          int berlinStock = row.length > 5 ? (int.tryParse(row[5]) ?? 0) : 0;
          int hamburgStock = row.length > 6 ? (int.tryParse(row[6]) ?? 0) : 0;
          int munichStock = row.length > 7 ? (int.tryParse(row[7]) ?? 0) : 0;

          Map<String, dynamic> productDoc = {
            "name": productName,
            "category": category.isEmpty ? "Uncategorized" : category,
            "price": price,
            "minStockLevel": minThreshold,
            "quantity": globalQty,
            "cityStock": {
              "Berlin": berlinStock,
              "Hamburg": hamburgStock,
              "Munich": munichStock
            }
          };

          if (itemsInCurrentBatch >= 500) {
            batches.add(FirebaseFirestore.instance.batch());
            currentBatchIndex++;
            itemsInCurrentBatch = 0;
          }

          batches[currentBatchIndex].set(_collection.doc(), productDoc);
          itemsInCurrentBatch++;
          processedRows++;
        } catch (e) {
          print("Error seeding row: $e");
        }
      }

      await Future.wait(batches.map((batch) => batch.commit()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Successfully imported $processedRows items from Excel!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error seeding: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  void _handleLongPress(String productId) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedProductIds.add(productId);
      });
    }
  }

  void _handleToggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        if (_selectedProductIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedProducts() async {
    if (_selectedProductIds.isEmpty) return;

    bool confirmDelete = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Bulk Delete'),
            content: Text(
                'Delete ${_selectedProductIds.length} selected items from registry?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) return;
    setState(() => _isDeleting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (String id in _selectedProductIds) {
        batch.delete(_collection.doc(id));
      }
      int totalDeleted = _selectedProductIds.length;
      await batch.commit();
      _clearSelection();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Deleted $totalDeleted products.'),
            backgroundColor: Colors.redAccent));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Deletion failed: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (!_isSelectionMode)
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search Products',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (value) => setState(
                          () => _searchQuery = value.toLowerCase().trim()),
                    ),
                  if (!_isSelectionMode) const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _collection.snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];

                        // Dynamically pull unique categories directly from your database logs
                        final Set<String> uniqueCategories = {'All'};
                        for (var d in docs) {
                          final data = d.data() as Map<String, dynamic>? ?? {};
                          final String cat =
                              data['category']?.toString()?.trim() ??
                                  'Uncategorized';
                          if (cat.isNotEmpty) uniqueCategories.add(cat);
                        }

                        final List<String> computedCategories =
                            uniqueCategories.toList()
                              ..sort((a, b) {
                                if (a == 'All') return -1;
                                if (b == 'All') return 1;
                                return a.compareTo(b);
                              });

                        if (!computedCategories.contains(_selectedCategory)) {
                          _selectedCategory = 'All';
                        }

                        final List<Map<String, dynamic>> products = docs
                            .map<Map<String, dynamic>>(
                                (QueryDocumentSnapshot d) {
                          final data = d.data() as Map<String, dynamic>? ?? {};
                          return <String, dynamic>{
                            'id': d.id,
                            'name':
                                data['name']?.toString() ?? 'Unknown Product',
                            'category': data['category']?.toString()?.trim() ??
                                'Uncategorized',
                            'quantity': data['quantity']?.toString() ?? '0',
                            'minStockLevel':
                                data['minStockLevel']?.toString() ?? '0',
                            'cityStock': data['cityStock'] ?? {},
                          };
                        }).where((Map<String, dynamic> product) {
                          if (_selectedCategory != 'All' &&
                              product['category'] != _selectedCategory)
                            return false;
                          if (_searchQuery.isNotEmpty &&
                              !(product['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_searchQuery))) return false;
                          return true;
                        }).toList();

                        int totalBerlinVolume = 0;
                        int totalHamburgVolume = 0;
                        int totalMunichVolume = 0;

                        for (var p in products) {
                          final cityMap = p['cityStock'] as Map? ?? {};
                          totalBerlinVolume += int.tryParse(
                                  cityMap['Berlin']?.toString() ?? '0') ??
                              0;
                          totalHamburgVolume += int.tryParse(
                                  cityMap['Hamburg']?.toString() ?? '0') ??
                              0;
                          totalMunichVolume += int.tryParse(
                                  cityMap['Munich']?.toString() ?? '0') ??
                              0;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isSelectionMode) ...[
                              const Text('Filter by Category',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 40,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: computedCategories.length,
                                  itemBuilder: (context, index) {
                                    final category = computedCategories[index];
                                    final isSelected =
                                        _selectedCategory == category;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        label: Text(category),
                                        selected: isSelected,
                                        onSelected: (selected) {
                                          if (selected)
                                            setState(() =>
                                                _selectedCategory = category);
                                        },
                                        selectedColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!_isSelectionMode) ...[
                              Row(
                                children: [
                                  Expanded(
                                      child: StatCard(
                                          icon: Icons.location_city,
                                          label: 'Berlin Hub Vol',
                                          value: '$totalBerlinVolume',
                                          color: Colors.blue)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: StatCard(
                                          icon: Icons.warehouse,
                                          label: 'Hamburg Hub Vol',
                                          value: '$totalHamburgVolume',
                                          color: Colors.teal)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: StatCard(
                                          icon: Icons.domain,
                                          label: 'Munich Hub Vol',
                                          value: '$totalMunichVolume',
                                          color: Colors.deepPurple)),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                            Expanded(
                              child: ProductListView(
                                products: products,
                                isSelectionMode: _isSelectionMode,
                                selectedProductIds: _selectedProductIds,
                                onToggleSelection: _handleToggleSelection,
                                onLongPress: _handleLongPress,
                                onProductTap:
                                    (Map<String, dynamic> tappedProduct) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ProductDetailScreen(
                                            product: tappedProduct)),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _isImporting ? null : manuallyImportCsv,
              icon: _isImporting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.upload_file),
              label: Text(_isImporting ? 'Importing...' : 'Import CSV'),
            ),
    );
  }
}
