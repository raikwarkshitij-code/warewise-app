import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math';
import '../widgets/product_chart_view.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- NATIVE DART CSV PARSER & FIREBASE INJECTOR ---
  Future<void> autoUploadKaggleData() async {
    print("⏳ Loading CSV from assets...");
    
    try {
      // 1. Load the full raw string
      final rawData = await rootBundle.loadString('assets/amazon_inventory.csv.csv');
      List<String> lines = rawData.split('\n');
      
      final collection = FirebaseFirestore.instance.collection('products');
      final random = Random();
      
      // We are now reading the ENTIRE file length
      int uploadCount = lines.length;
      print("🚀 Starting massive upload to Firestore ($uploadCount items)...");

      for (int i = 1; i < uploadCount; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        // Manual CSV Parsing (Handling commas inside quotes)
        List<String> row = [];
        bool inQuotes = false;
        StringBuffer currentField = StringBuffer();
        
        for (int j = 0; j < line.length; j++) {
          if (line[j] == '"') {
            inQuotes = !inQuotes; 
          } else if (line[j] == ',' && !inQuotes) {
            row.add(currentField.toString().trim());
            currentField.clear();
          } else {
            currentField.write(line[j]);
          }
        }
        row.add(currentField.toString().trim()); 

        if (row.isEmpty || row[0].isEmpty) continue;
        
        String productName = row[0];

        // Price formatting
        double price = 19.99; 
        if (row.length > 1) {
          String rawPrice = row[1];
          String cleanedPrice = rawPrice.replaceAll(RegExp(r'[^0-9.]'), '');
          price = double.tryParse(cleanedPrice) ?? 19.99;
        }

        String category = "Electronics & Tech";

        // Generate Random Warehouse Distribution
        int totalQty = random.nextInt(3000) + 100; 
        int minThreshold = (totalQty * 0.2).round(); 
        
        int berlinStock = (totalQty * (random.nextDouble() * 0.5)).round();
        int hamburgStock = (totalQty * (random.nextDouble() * 0.4)).round();
        int munichStock = totalQty - (berlinStock + hamburgStock); 

        Map<String, dynamic> productDoc = {
          "name": productName,
          "category": category,
          "price": price,
          "minStockLevel": minThreshold.toString(),
          "quantity": totalQty.toString(),
          "cityStock": {
            "Berlin": berlinStock,
            "Hamburg": hamburgStock,
            "Munich": munichStock > 0 ? munichStock : 0 
          }
        };

        // Upload to Firestore
        await collection.add(productDoc);

        // --- PROGRESS TRACKER ---
        // Every 50 items, print an update to the VS Code terminal
        if (i % 50 == 0 || i == uploadCount - 1) {
          print("📈 Uploading progress: $i / $uploadCount items completed.");
        }
      }
      
      print("✅ DONE! Successfully parsed and uploaded all items to Firebase!");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database Seeding Complete!'), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("❌ Error uploading: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // Data Injection Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: autoUploadKaggleData,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("INJECT KAGGLE DATA"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search Product (e.g. Wireless)',
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase().trim()),
          ),
          const SizedBox(height: 12),

          // Real-time Suggestions & Telemetry
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                final filteredDocs = _searchQuery.isEmpty 
                    ? [] 
                    : docs.where((d) => (d.data() as Map<String, dynamic>)['name'].toString().toLowerCase().contains(_searchQuery)).toList();

                if (_searchQuery.isEmpty) {
                  return const Center(child: Text('Search for a product to view telemetry.', style: TextStyle(color: Colors.grey, fontSize: 16)));
                }

                if (filteredDocs.isEmpty) {
                  return Center(child: Text('No products found matching "$_searchQuery".', style: const TextStyle(color: Colors.grey, fontSize: 16)));
                }

                int exactMatchIndex = filteredDocs.indexWhere(
                  (d) => (d.data() as Map<String, dynamic>)['name'].toString().toLowerCase().trim() == _searchQuery
                );

                // State: Show suggestions list
                if (exactMatchIndex == -1) {
                  return ListView.builder(
                    itemCount: filteredDocs.length > 10 ? 10 : filteredDocs.length,
                    itemBuilder: (context, index) {
                      final itemData = filteredDocs[index].data() as Map<String, dynamic>;
                      final name = itemData['name'] ?? 'Unknown';
                      return ListTile(
                        leading: const Icon(Icons.label_outlined, color: Colors.blue),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          setState(() {
                            _searchController.text = name;
                            _searchQuery = name.toString().toLowerCase().trim();
                          });
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  );
                }

                // State: Show selected product telemetry
                final targetDoc = filteredDocs[exactMatchIndex];
                final data = targetDoc.data() as Map<String, dynamic>;
                final productName = data['name']?.toString() ?? 'Unknown';
                final minStock = int.tryParse(data['minStockLevel']?.toString() ?? '0') ?? 0;
                
                Map<String, int> cityStock = {};
                if (data.containsKey('cityStock')) {
                  final map = data['cityStock'] as Map<String, dynamic>;
                  cityStock = map.map((key, value) => MapEntry(key, int.tryParse(value.toString()) ?? 0));
                }

                final totalQuantity = cityStock.values.fold(0, (sum, qty) => sum + qty);
                
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _StatCard(icon: Icons.inventory_2, label: 'Global Stock', value: '$totalQuantity', color: Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(icon: Icons.warning_amber, label: 'Min Threshold', value: '$minStock', color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ProductChartView(
                        productName: productName,
                        cityData: cityStock,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}