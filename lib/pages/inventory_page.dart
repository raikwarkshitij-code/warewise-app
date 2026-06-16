import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool _isUploading = false;
  String _selectedCategory = 'All';

  // --- FUZZY HEADER MAPPING ENGINE ---
  Future<void> _pickAndUploadCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return; 

      setState(() => _isUploading = true);
      String csvContent = '';

      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes != null) csvContent = utf8.decode(bytes);
      } else {
        if (result.files.first.bytes != null) {
          csvContent = utf8.decode(result.files.first.bytes!);
        }
      }

      List<String> lines = const LineSplitter().convert(csvContent);
      if (lines.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      // Extract headers from Row 1 and clean them completely
      List<String> headers = lines[0].split(',').map((e) => e.trim().toLowerCase()).toList();
      
      // Strict matching lookups first
      int skuIndex = headers.indexOf('sku');
      int nameIndex = headers.indexOf('name');
      int quantityIndex = headers.indexOf('quantity');
      int priceIndex = headers.indexOf('price');
      int categoryIndex = headers.indexOf('category');

      // --- SMART FUZZY SEARCH SAFETY NET ---
      // If direct matching fails, search line blocks for keyword approximations
      for (int i = 0; i < headers.length; i++) {
        String h = headers[i];
        if (skuIndex == -1 && (h.contains('id') || h.contains('code') || h.contains('number'))) skuIndex = i;
        if (nameIndex == -1 && (h.contains('product') || h.contains('title') || h.contains('item'))) nameIndex = i;
        if (quantityIndex == -1 && (h.contains('qty') || h.contains('stock') || h.contains('units') || h.contains('count'))) quantityIndex = i;
        if (priceIndex == -1 && (h.contains('cost') || h.contains('rate') || h.contains('amount') || h.contains('mrp'))) priceIndex = i;
        
        // Dynamic Category Multi-match Rule
        if (categoryIndex == -1 && (h.contains('cat') || h.contains('type') || h.contains('dept') || h.contains('group') || h.contains('class'))) {
          categoryIndex = i;
        }
      }

      // Validation fallback boundaries
      if (nameIndex == -1 || quantityIndex == -1) {
        throw Exception("Could not map file format. Ensure columns for 'Name' and 'Quantity' are present.");
      }

      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('products');

      for (int i = 1; i < lines.length; i++) {
        if (lines[i].trim().isEmpty) continue;
        List<String> row = lines[i].split(',');
        
        if (row.length <= nameIndex || row.length <= quantityIndex) continue;

        String sku = skuIndex != -1 && row.length > skuIndex ? row[skuIndex].trim() : '';
        String name = row[nameIndex].trim();
        int quantity = int.tryParse(row[quantityIndex].trim()) ?? 0;
        double price = priceIndex != -1 && row.length > priceIndex ? (double.tryParse(row[priceIndex].trim()) ?? 0.0) : 0.0;
        
        // Capture data from the discovered fuzzy column index slot position
        String category = 'Miscellaneous'; 
        if (categoryIndex != -1 && row.length > categoryIndex && row[categoryIndex].trim().isNotEmpty) {
          String rawCat = row[categoryIndex].trim();
          if (rawCat.toLowerCase() != 'general' && rawCat.toLowerCase() != 'general stock') {
            category = rawCat;
          }
        }

        DocumentReference docRef = collection.doc(sku.isNotEmpty ? sku : null);
        batch.set(docRef, {
          'sku': sku,
          'name': name,
          'quantity': quantity,
          'price': price,
          'category': category,
          'minThreshold': 10,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      
      setState(() {
        _isUploading = false;
        _selectedCategory = 'All';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory Synced with Adaptive Fuzzy Mapping!'), 
            backgroundColor: Color(0xFF009473),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF01604B), 
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.layers_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Inventory Control',
              style: TextStyle(color: Color(0xFF01604B), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          _isUploading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF009473)),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _pickAndUploadCSV,
                  icon: const Icon(Icons.drive_folder_upload_outlined, color: Color(0xFF009473)),
                  label: const Text('Import CSV', style: TextStyle(color: Color(0xFF009473), fontWeight: FontWeight.bold)),
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF009473)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF99D4C7)),
                  SizedBox(height: 12),
                  Text('Warehouse empty', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF01604B))),
                  Text('Tap Import CSV to seed data fields.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }

          final productsList = snapshot.data!.docs;

          // --- ALL-CATEGORY EXTRACTOR DOCK ENGINE ---
          final chipSet = {'All'};
          for (var doc in productsList) {
            final data = doc.data() as Map<String, dynamic>;
            final String categoryTag = data['category'] ?? 'Miscellaneous';
            
            if (categoryTag.toLowerCase() != 'general' && categoryTag.toLowerCase() != 'general stock') {
              chipSet.add(categoryTag);
            }
          }

          final filteredProducts = productsList.where((doc) {
            if (_selectedCategory == 'All') return true;
            final data = doc.data() as Map<String, dynamic>;
            return (data['category'] ?? 'Miscellaneous') == _selectedCategory;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HORIZONTAL CHIP VIEW SELECTION TRAIL ---
              Container(
                height: 54,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: chipSet.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF01604B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF009473),
                        backgroundColor: const Color(0xFFF1F5F9),
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              
              // --- PRODUCT CARDS HUB PORT ---
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(child: Text('No item listings match this category filter.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final item = filteredProducts[index].data() as Map<String, dynamic>;
                          final int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
                          final int min = int.tryParse(item['minThreshold']?.toString() ?? '10') ?? 10;
                          final bool isLow = qty <= min;

                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isLow ? Colors.amber.shade400 : const Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isLow ? const Color(0xFFFEF3C7) : const Color(0xFFE6F4F1),
                                child: Icon(
                                  Icons.inventory_2_rounded, 
                                  color: isLow ? const Color(0xFFD97706) : const Color(0xFF009473), 
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['name'] ?? 'Unknown Item', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                'SKU: ${item['sku'] ?? 'N/A'} • Category: ${item['category'] ?? 'Miscellaneous'}', 
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$qty Units', 
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                  Text(
                                    '\$${(item['price'] ?? 0.0).toString()}', 
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}