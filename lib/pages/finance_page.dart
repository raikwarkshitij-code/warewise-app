import 'package:flutter/material.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  // Security State Variables
  bool _isVaultLocked = true;
  final TextEditingController _pinController = TextEditingController();

  // Dynamic Inventory Matrix containing exactly what is listed on your spreadsheets
  final Map<String, List<Map<String, dynamic>>> _categoryProducts = {
    'Beauty & Essentials': [
      {'sku': 'RKYTL', 'name': 'Dyson Airwrap Multi-Styler 4606', 'price': 549.99, 'stock': 2399},
      {'sku': '08GUE', 'name': 'Estée Lauder Night Repair Serum 620', 'price': 85.50, 'stock': 2043},
      {'sku': 'CR973', 'name': 'Crème de la Mer Facial Moisturizer 6973', 'price': 195.00, 'stock': 1851},
      {'sku': 'C03XV', 'name': 'Chanel No. 5 Eau de Parfum 4652', 'price': 135.00, 'stock': 1137},
      {'sku': 'NENS9', 'name': 'Olaplex No. 3 Hair Perfector 811', 'price': 30.00, 'stock': 2883},
      {'sku': 'CE955', 'name': 'CeraVe Hydrating Facial Cleanser 9559', 'price': 15.99, 'stock': 1836},
      {'sku': '2OU7T', 'name': 'The Ordinary Niacinamide Serum 6327', 'price': 6.50, 'stock': 543},
      {'sku': '3DLW1', 'name': 'Kiehl\'s Ultra Facial Cream 2903', 'price': 38.00, 'stock': 2367},
      {'sku': '0FKJL', 'name': 'Laneige Lip Sleeping Mask 5413', 'price': 24.00, 'stock': 4434},
      {'sku': 'MA712', 'name': 'MAC Matte Lipstick 7124', 'price': 23.00, 'stock': 2217}, // 10 Items Total
    ],
    'Electronics & Tech': [
      {'sku': 'A98FD', 'name': 'Philips Wireless External SSD 4652', 'price': 120.00, 'stock': 1067},
      {'sku': 'B71RE', 'name': 'Netgear Essential Microphone 5413', 'price': 89.99, 'stock': 3057},
      {'sku': 'C44TR', 'name': 'Philips Gaming Smart Display 6973', 'price': 349.99, 'stock': 1012},
      {'sku': 'E12IK', 'name': 'Logitech MX Master 3S Wireless Mouse', 'price': 99.99, 'stock': 1500},
      {'sku': 'F90OP', 'name': 'Sony WH-1000XM4 Noise Cancelling ANC', 'price': 279.00, 'stock': 850},
      {'sku': 'G43RE', 'name': 'Apple iPad Air M2 Space Gray', 'price': 599.00, 'stock': 420},
      {'sku': 'H21XW', 'name': 'Anker Prime 20000mAh Power Bank', 'price': 129.99, 'stock': 2100},
      {'sku': 'I88YT', 'name': 'Keychron K2 Mechanical Keyboard v2', 'price': 89.00, 'stock': 1300},
      {'sku': 'J55UU', 'name': 'Dell UltraSharp 27" 4K Monitor', 'price': 449.99, 'stock': 680}, // 9 Items Total
    ],
    'Fashion & Clothing': [
      {'sku': 'F33OP', 'name': 'Uniqlo Ultra Light Down Jacket 5413', 'price': 79.90, 'stock': 1200},
      {'sku': 'FA122', 'name': 'Nike Air Max Running Shoes 90', 'price': 149.99, 'stock': 1600},
      {'sku': 'FB901', 'name': 'Levi\'s 511 Slim Fit Stretch Jeans', 'price': 89.50, 'stock': 2400},
      {'sku': 'FC443', 'name': 'Adidas Tiro Training Track Pants', 'price': 45.00, 'stock': 3100},
      {'sku': 'FD092', 'name': 'Carhartt WIP Acrylic Watch Beanie', 'price': 25.00, 'stock': 4500},
      {'sku': 'FE711', 'name': 'Patagonia Torrentshell 3L Rain Jacket', 'price': 179.00, 'stock': 750},
      {'sku': 'FF822', 'name': 'Champion Reverse Weave Heavy Hoodie', 'price': 65.00, 'stock': 2200},
      {'sku': 'FG332', 'name': 'The North Face Denali Fleece Vest', 'price': 130.00, 'stock': 900},
      {'sku': 'FH110', 'name': 'ZARA Oversized Cotton Corduroy Shirt', 'price': 49.90, 'stock': 1850}, // 9 Items Total
    ],
    'Accessories': [
      {'sku': 'AC881', 'name': 'Leather Travel Wallet Messenger', 'price': 45.00, 'stock': 850},
      {'sku': 'AC092', 'name': 'Ray-Ban Classic Wayfarer Sunglasses', 'price': 163.00, 'stock': 1200},
      {'sku': 'AC711', 'name': 'Fossil Minimalist Chronograph Watch', 'price': 149.00, 'stock': 950},
      {'sku': 'AC332', 'name': 'Herschel Heritage Backpack Canvas', 'price': 69.99, 'stock': 2100},
      {'sku': 'AC441', 'name': 'Bellroy Slim Leather Card Wallet', 'price': 79.00, 'stock': 1750},
      {'sku': 'AC550', 'name': 'Secrid Twinprotector Card Case Aluminum', 'price': 89.00, 'stock': 1400},
      {'sku': 'AC661', 'name': 'Thule Subterra PowerShuttle Tech Bag', 'price': 29.95, 'stock': 2800},
      {'sku': 'AC110', 'name': 'Peak Design Anchor Links Neck Strap', 'price': 24.95, 'stock': 3200},
      {'sku': 'AC992', 'name': 'Ridge Minimalist Carbon Fiber Wallet', 'price': 125.00, 'stock': 1100},
      {'sku': 'AC771', 'name': 'Aer Slim Pack Work Day Backpack', 'price': 119.00, 'stock': 1000}, // 10 Items Total
    ],
    'Home & Appliances': [
      {'sku': 'HM902', 'name': 'Digital Air Fryer Pro XL', 'price': 149.00, 'stock': 620},
      {'sku': 'HM122', 'name': 'Instant Pot Duo 7-in-1 Multi-Cooker', 'price': 99.99, 'stock': 1400},
      {'sku': 'HM711', 'name': 'Keurig K-Elite Single Serve Coffee Maker', 'price': 189.99, 'stock': 780},
      {'sku': 'HM332', 'name': 'Dyson V8 Cordless Stick Vacuum Cleaner', 'price': 399.99, 'stock': 550},
      {'sku': 'HM441', 'name': 'Levoit HEPA Desktop Room Air Purifier', 'price': 89.99, 'stock': 2300},
      {'sku': 'HM550', 'name': 'NutriBullet Pro 900W Nutrient Extractor', 'price': 109.00, 'stock': 1650},
      {'sku': 'HM661', 'name': 'Ring Video Doorbell Plus HD Wireless', 'price': 149.99, 'stock': 1100},
      {'sku': 'HM110', 'name': 'Philips Hue White & Color Ambiance Kit', 'price': 199.99, 'stock': 850},
      {'sku': 'HM992', 'name': 'Cosori Electric Gooseneck Smart Kettle', 'price': 79.99, 'stock': 1900}, // 9 Items Total
    ],
  };

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _showPinGatewayDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          // FIXED DIALOG TITLE BLOCK: Added Expanded constraint boundary tracker
          title: const Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF1E297A)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Finance Security Gateway'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter clearance verification credentials to decrypt financial telemetry records.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    labelText: 'Security PIN',
                    prefixIcon: const Icon(Icons.password)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E297A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                if (_pinController.text.trim() == 'mwis2026') {
                  Navigator.pop(context);
                  setState(() => _isVaultLocked = false);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Access Denied: Invalid Security PIN.'),
                      backgroundColor: Colors.red));
                }
              },
              child: const Text('Verify Code'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLockedVaultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person_outlined, size: 80, color: Colors.indigo.shade200),
            const SizedBox(height: 24),
            const Text(
              'Financial Telemetry Vault Locked',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Restricted to verified Manager & Finance clearances.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E297A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: _showPinGatewayDialog,
              icon: const Icon(Icons.key, size: 18),
              label: const Text('Verify Access Clearance', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVaultLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: _buildLockedVaultView(),
      );
    }

    // ------------------------------------------------------------------
    // DYNAMIC MATHEMATICS RUNTIME PROCESSING CALCULATION ENGINE
    // ------------------------------------------------------------------
    double totalGrossRevenuePool = 0.0;
    double totalNetProfitPool = 0.0;

    Map<String, double> grossCalculations = {};
    Map<String, double> profitCalculations = {};
    Map<String, int> listCalculations = {};

    _categoryProducts.forEach((categoryKey, products) {
      double categoryGrossSum = 0.0;
      double categoryProfitSum = 0.0;

      for (var product in products) {
        double itemPrice = (product['price'] as num).toDouble();
        int itemStockValue = (product['stock'] as num).toInt();

        double computedGross = itemPrice * itemStockValue;
        double computedProfit = computedGross * 0.40;

        categoryGrossSum += computedGross;
        categoryProfitSum += computedProfit;
      }

      grossCalculations[categoryKey] = categoryGrossSum;
      profitCalculations[categoryKey] = categoryProfitSum;
      listCalculations[categoryKey] = products.length;

      totalGrossRevenuePool += categoryGrossSum;
      totalNetProfitPool += categoryProfitSum;
    });
    // ------------------------------------------------------------------

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Health Performance',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select a category tile below to view detailed breakdown logs',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _isVaultLocked = true);
                    },
                    icon: const Icon(Icons.lock_outline, size: 14, color: Colors.red),
                    label: const Text('Lock Vault', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.monetization_on,
                      iconColor: Colors.blue.shade700,
                      value: '€${totalGrossRevenuePool.toStringAsFixed(2)}',
                      label: 'Gross Rev. Pool',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      icon: Icons.trending_up,
                      iconColor: Colors.green.shade700,
                      value: '40.0%',
                      label: 'Net Margin Est.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E297A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Net Profit Earnings', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text('€${totalNetProfitPool.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    const Text('*Calculations model a structured 40% margin ceiling across cost of operations inputs.', style: TextStyle(fontSize: 11, color: Colors.white60, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('Performance Breakdown by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),

              ..._categoryProducts.keys.map((String targetCategory) {
                return _buildCategoryListItem(
                  context,
                  title: targetCategory,
                  totalItems: listCalculations[targetCategory] ?? 0,
                  grossRevenue: '€${(grossCalculations[targetCategory] ?? 0.0).toStringAsFixed(2)}',
                  netProfit: '+€${(profitCalculations[targetCategory] ?? 0.0).toStringAsFixed(2)}',
                  margin: '40.0% margin',
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({required IconData icon, required Color iconColor, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          CircleAvatar(radius: 18, backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildCategoryListItem(BuildContext context, {required String title, required int totalItems, required String grossRevenue, required String netProfit, required String margin}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          List<Map<String, dynamic>> rawProducts = _categoryProducts[title] ?? [];
          List<Map<String, dynamic>> structuredRecords = rawProducts.map((p) {
            double productPrice = (p['price'] as num).toDouble();
            int productStock = (p['stock'] as num).toInt();
            return {
              'sku': p['sku'],
              'name': p['name'],
              'price': productPrice,
              'stock': productStock,
              'gross': productPrice * productStock,
              'profit': (productPrice * productStock) * 0.40,
            };
          }).toList();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryDetailPage(
                categoryTitle: title,
                itemCount: totalItems,
                grossRevenue: grossRevenue,
                netProfit: netProfit,
                productRecords: structuredRecords,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('$totalItems items listed • Gross: $grossRevenue', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(netProfit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade100)),
                    child: Text(margin, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryDetailPage extends StatelessWidget {
  final String categoryTitle;
  final int itemCount;
  final String grossRevenue;
  final String netProfit;
  final List<Map<String, dynamic>> productRecords;

  const CategoryDetailPage({
    super.key,
    required this.categoryTitle,
    required this.itemCount,
    required this.grossRevenue,
    required this.netProfit,
    required this.productRecords,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('$categoryTitle ($itemCount Items)', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E297A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Category Revenue', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(grossRevenue, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Net Capital Contribution', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(netProfit, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: productRecords.isEmpty
                ? const Center(child: Text('No data found for this category.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
                        columnSpacing: 22,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(label: Text('SKU', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))),
                          DataColumn(label: Text('Product Item Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))),
                          DataColumn(label: Text('Retail Price', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))),
                          DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))),
                          DataColumn(label: Text('Gross Revenue', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))),
                          DataColumn(label: Text('Net Profit (40%)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12))),
                        ],
                        rows: productRecords.map((item) {
                          return DataRow(cells: [
                            DataCell(Text(item['sku'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87))),
                            DataCell(Text(item['name'], style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            DataCell(Text('€${(item['price'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text('${item['stock']} units', style: const TextStyle(fontSize: 12))),
                            DataCell(Text('€${(item['gross'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text('€${(item['profit'] as double).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}