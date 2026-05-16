
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  late Future<List<Map<String, dynamic>>> _suppliersFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _suppliersFuture = fetchSuppliers();
  }

  Future<List<Map<String, dynamic>>> fetchSuppliers() async {
    final response = await http.get(
      Uri.parse(
        'https://restcountries.com/v3.1/region/europe'
        '?fields=name,capital,flags,currencies,population',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load suppliers (status ${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body);

    data.sort((a, b) =>
        (a['name']['common'] as String).compareTo(b['name']['common'] as String));

    return data.map<Map<String, dynamic>>((country) {
      final capital =
          (country['capital'] as List<dynamic>?)?.isNotEmpty == true
              ? country['capital'][0] as String
              : 'N/A';

      String currency = 'N/A';
      final currencies = country['currencies'] as Map<String, dynamic>?;
      if (currencies != null && currencies.isNotEmpty) {
        final firstCurrency = currencies.values.first as Map<String, dynamic>;
        currency = firstCurrency['name']?.toString() ?? 'N/A';
      }

      return {
        'name': country['name']['common'] as String,
        'capital': capital,
        'flagUrl': country['flags']['png'] as String? ?? '',
        'currency': currency,
        'population': country['population'] as int? ?? 0,
      };
    }).toList();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search suppliers...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _suppliersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load suppliers.\n${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final allSuppliers = snapshot.data ?? [];
              final suppliers = _searchQuery.isEmpty
                  ? allSuppliers
                  : allSuppliers
                      .where((s) => s['name']
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                      .toList();

              if (suppliers.isEmpty) {
                return const Center(
                  child: Text(
                    'No suppliers found.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          supplier['flagUrl'] as String,
                          width: 50,
                          height: 36,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                              width: 50,
                              height: 36,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.flag, size: 36),
                        ),
                      ),
                      title: Text(
                        supplier['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('HQ: ${supplier['capital']}'),
                          Text('Currency: ${supplier['currency']}'),
                          Text(
                              'Annual Volume: ${_formatNumber(supplier['population'] as int)}'),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
