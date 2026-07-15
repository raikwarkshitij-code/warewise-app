import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operations_ai.dart';
import '../services/product_service.dart';
import '../services/role_service.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const EditProductScreen({super.key, this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _thresholdController;
  late TextEditingController _priceController;
  String _selectedCategory = 'Electronics';

  late TextEditingController _supplierNameController;
  late TextEditingController _supplierCostController;
  late TextEditingController _supplierDaysController;

  final Map<String, TextEditingController> _cityStockControllers = {
    for (final hub in kHubs) hub: TextEditingController(),
  };

  bool _isSaving = false;

  final List<String> _categories = [
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
  void initState() {
    super.initState();
    final p = widget.product ?? {};

    _skuController = TextEditingController(text: p['sku'] ?? '');
    _nameController = TextEditingController(text: p['name'] ?? '');
    _thresholdController =
        TextEditingController(text: (p['threshold'] ?? 0).toString());
    _priceController =
        TextEditingController(text: (p['price'] ?? '').toString());

    if (p['category'] != null && _categories.contains(p['category'])) {
      _selectedCategory = p['category'];
    }

    final cityStock = Map<String, dynamic>.from(p['cityStock'] as Map? ?? {});
    for (final hub in kHubs) {
      _cityStockControllers[hub]!.text = (cityStock[hub] ?? 0).toString();
    }

    _supplierNameController = TextEditingController();
    _supplierCostController = TextEditingController();
    _supplierDaysController = TextEditingController();

    final sku = p['sku'] as String?;
    if (sku != null && sku.isNotEmpty) {
      ProductService.fetchRestrictedCost(sku).then((restricted) {
        if (!mounted || restricted == null) return;
        setState(() {
          _supplierNameController.text = restricted['supplierName'] ?? '';
          _supplierCostController.text =
              (restricted['costPerUnit'] ?? '').toString();
          _supplierDaysController.text =
              (restricted['leadTimeDays'] ?? '').toString();
        });
      }).catchError((Object e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not load supplier data: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.orange,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _thresholdController.dispose();
    _priceController.dispose();
    _supplierNameController.dispose();
    _supplierCostController.dispose();
    _supplierDaysController.dispose();
    for (final c in _cityStockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalQuantity => kHubs.fold(
      0,
      (sum, hub) =>
          sum + (int.tryParse(_cityStockControllers[hub]!.text) ?? 0));

  Future<void> _saveToCloud() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final payload = {
      'sku': _skuController.text.trim(),
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'threshold': int.tryParse(_thresholdController.text) ?? 0,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'cityStock': {
        for (final hub in kHubs)
          hub: int.tryParse(_cityStockControllers[hub]!.text) ?? 0,
      },
      'supplier': {
        'supplierName': _supplierNameController.text.trim(),
        'costPerUnit': double.tryParse(_supplierCostController.text) ?? 0.0,
        'leadTimeDays': int.tryParse(_supplierDaysController.text) ?? 0,
      },
    };

    try {
      await ProductService.upsertProduct(payload);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Product synchronized with Cloud successfully!'),
              backgroundColor: Color(0xFF009473)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        context.watch<RoleService>().hasAnyRole(['manager', 'owner']);
    if (!canEdit) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text('Restricted to Manager and Owner roles.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF01604B)),
        title: Text(widget.product == null ? 'Add New Product' : 'Edit Product',
            style: const TextStyle(
                color: Color(0xFF01604B), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded,
                color: Color(0xFF009473)),
            onPressed: _isSaving ? null : _saveToCloud,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Core Identification'),
            _buildTextField(
                _nameController, 'Product Name', Icons.inventory_2_outlined),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(_skuController,
                        'SKU (e.g., PROD-01)', Icons.qr_code_2_rounded)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration:
                        _inputStyle('Category', Icons.category_outlined),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child:
                                Text(c, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Stock & Pricing'),
            _buildTextField(_thresholdController, 'Min. Threshold',
                Icons.warning_amber_rounded,
                isNumber: true),
            _buildTextField(_priceController, 'Retail Price (\$)',
                Icons.attach_money_rounded,
                isNumber: true),
            const SizedBox(height: 16),
            _buildSectionHeader('Supplier Logistics (For AI Engine)'),
            _buildTextField(_supplierNameController, 'Supplier Name',
                Icons.factory_outlined),
            Row(
              children: [
                Expanded(
                    child: _buildTextField(_supplierCostController,
                        'Unit Cost (\$)', Icons.payments_outlined,
                        isNumber: true)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildTextField(_supplierDaysController,
                        'Lead Time (Days)', Icons.local_shipping_outlined,
                        isNumber: true)),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Hub Stock (For AI Engine)'),
            for (final hub in kHubs)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildTextField(_cityStockControllers[hub]!, '$hub Qty',
                    Icons.warehouse_outlined,
                    isNumber: true, onChanged: (_) => setState(() {})),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Quantity',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF01604B))),
                  Text('$_totalQuantity',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF01604B))),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveToCloud,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF01604B),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Synchronize with Cloud',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontSize: 16)),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isNumber = false, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
        onChanged: onChanged,
        decoration: _inputStyle(label, icon),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF009473), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF009473), width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
    );
  }
}
