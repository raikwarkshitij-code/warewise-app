import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key});

  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage> {
  bool _isManager = false; // Default to false for strict security guard parameters
  bool _isProcessing = false;

  // --- SECURITY REGULATION: ACCESS CHALLENGE GATING ---
  void _authenticateManagerView(bool tryingToUnlock) {
    if (!tryingToUnlock) {
      setState(() => _isManager = false);
      _showSnackbar("Session downgraded to Warehouse Associate access.", Colors.grey.shade700);
      return;
    }

    final TextEditingController passwordController = TextEditingController();
    final GlobalKey<FormState> authFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.lock_person, color: Colors.amber, size: 26),
              SizedBox(width: 8),
              Text("Manager Authentication", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Form(
            key: authFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This section requires supervisor clearance. Please enter the Manager Security Key:",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Security Access Key",
                    prefixIcon: const Icon(Icons.key),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Access key cannot be blank";
                    }
                    if (value.trim() != "mwis2026") { 
                      return "Invalid supervisor credential";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isManager = false);
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (authFormKey.currentState!.validate()) {
                  Navigator.pop(context);
                  setState(() => _isManager = true);
                  _showSnackbar("Supervisor session authorized successfully!", Colors.green);
                }
              },
              child: const Text("Verify & Unlock"),
            ),
          ],
        );
      },
    );
  }

  // --- ARTIFACT TRANSACTION: GOODS ISSUE ---
  Future<void> _processGoodsIssue(String orderId, String productId, String sourceCity, int amount) async {
    setState(() => _isProcessing = true);
    final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
    final orderRef = FirebaseFirestore.instance.collection('transfers').doc(orderId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productSnapshot = await transaction.get(productRef);
        if (!productSnapshot.exists) return;

        final productData = productSnapshot.data() as Map<String, dynamic>;
        final cityStock = Map<String, dynamic>.from(productData['cityStock'] ?? {});

        int sourceCurrentStock = int.tryParse(cityStock[sourceCity].toString()) ?? 0;

        if (sourceCurrentStock >= amount) {
          cityStock[sourceCity] = sourceCurrentStock - amount;
          
          transaction.update(productRef, {'cityStock': cityStock});
          transaction.update(orderRef, {
            'status': 'In Transit',
            'approvedBy': 'Authenticated Manager Terminal',
            'updatedAt': FieldValue.serverTimestamp()
          });
        }
      });
      _showSnackbar("Transfer Authorized. Cargo is now In Transit!", Colors.green);
    } catch (e) {
      _showSnackbar("Transaction failed: $e", Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // --- ARTIFACT TRANSACTION: GOODS RECEIPT ---
  Future<void> _processGoodsReceipt(String orderId, String productId, String destCity, int amount) async {
    setState(() => _isProcessing = true);
    final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
    final orderRef = FirebaseFirestore.instance.collection('transfers').doc(orderId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productSnapshot = await transaction.get(productRef);
        if (!productSnapshot.exists) return;

        final productData = productSnapshot.data() as Map<String, dynamic>;
        final cityStock = Map<String, dynamic>.from(productData['cityStock'] ?? {});

        int destCurrentStock = int.tryParse(cityStock[destCity].toString()) ?? 0;

        cityStock[destCity] = destCurrentStock + amount;

        transaction.update(productRef, {'cityStock': cityStock});
        transaction.update(orderRef, {
          'status': 'Delivered',
          'completedAt': FieldValue.serverTimestamp()
        });
      });
      _showSnackbar("Goods Receipt posted successfully. Destination stock updated!", Colors.blue);
    } catch (e) {
      _showSnackbar("Receipt execution failed: $e", Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color),
      );
    }
  }

  // --- TRACKING STEPPER ENGINE WIDGET ---
  Widget _buildTrackerStepper(String status) {
    int activeStep = 0;
    Color activeLineColor = Colors.grey.shade300;
    Color deliveryLineColor = Colors.grey.shade300;

    if (status == 'Pending Approval') {
      activeStep = 1;
    } else if (status == 'In Transit') {
      activeStep = 2;
      activeLineColor = Colors.blueAccent;
    } else if (status == 'Delivered') {
      activeStep = 3;
      activeLineColor = Colors.green;
      deliveryLineColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Step 1: Requested
              _buildStepCircle(
                icon: Icons.note_add,
                isActive: activeStep >= 1,
                color: status == 'Rejected' ? Colors.red : (activeStep >= 3 ? Colors.green : Colors.orange),
              ),
              Expanded(child: Container(height: 3, color: status == 'Rejected' ? Colors.red : activeLineColor)),
              
              // Step 2: In Transit
              _buildStepCircle(
                icon: Icons.local_shipping,
                isActive: activeStep >= 2,
                color: activeStep >= 3 ? Colors.green : Colors.blueAccent,
              ),
              Expanded(child: Container(height: 3, color: deliveryLineColor)),
              
              // Step 3: Delivered
              _buildStepCircle(
                icon: Icons.inventory,
                isActive: activeStep >= 3,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subtitles Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(status == 'Rejected' ? "Rejected" : "Requested", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status == 'Rejected' ? Colors.red : Colors.grey.shade700)),
              Text("In Transit", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activeStep >= 2 ? (activeStep >= 3 ? Colors.green : Colors.blueAccent) : Colors.grey)),
              Text("Delivered", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: activeStep >= 3 ? Colors.green : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle({required IconData icon, required bool isActive, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isActive ? color : Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(color: isActive ? color : Colors.grey.shade400, width: 1),
      ),
      child: Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey.shade500),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MWIS Operations Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Row(
            children: [
              Icon(_isManager ? Icons.verified_user : Icons.engineering, size: 18),
              const SizedBox(width: 4),
              Text(_isManager ? "Manager" : "Associate", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isManager,
                onChanged: (val) => _authenticateManagerView(val),
                activeColor: Colors.amber,
              )
            ],
          )
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('transfers').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data?.docs ?? [];

                if (orders.isEmpty) {
                  return const Center(
                    child: Text("No active tracking orders found.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final data = order.data() as Map<String, dynamic>;
                    
                    String status = data['status'] ?? 'Pending Approval';
                    String name = data['productName'] ?? 'Unknown SKU';
                    String trackingNum = data['orderNumber'] ?? 'ORD-000000';
                    String from = data['sourceCity'] ?? '';
                    String to = data['destinationCity'] ?? '';
                    int qty = int.tryParse(data['quantity'].toString()) ?? 0;

                    Color statusColor = Colors.orange;
                    if (status == 'In Transit') statusColor = Colors.blue;
                    if (status == 'Delivered') statusColor = Colors.green;
                    if (status == 'Rejected') statusColor = Colors.red;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Meta details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(trackingNum, style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              ],
                            ),
                            const Divider(height: 16),
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 6),
                            
                            // Hub node routes overview
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("From: $from", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600, fontSize: 13)),
                                Text("Volume: $qty Units", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text("To: $to", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            
                            // Dynamic Tracking Stepper Display
                            _buildTrackerStepper(status),
                            
                            // Interactive context permissions action layouts
                            if (status == 'Pending Approval' && _isManager) ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => order.reference.update({'status': 'Rejected'}),
                                    child: const Text("Reject Order", style: TextStyle(color: Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _processGoodsIssue(order.id, data['productId'], from, qty),
                                    icon: const Icon(Icons.local_shipping, size: 14),
                                    label: const Text("Approve & Ship"),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                  )
                                ],
                              )
                            ],
                            if (status == 'In Transit') ...[
                              const Divider(height: 24),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton.icon(
                                  onPressed: () => _processGoodsReceipt(order.id, data['productId'], to, qty),
                                  icon: const Icon(Icons.inventory, size: 14),
                                  label: const Text("Confirm Goods Receipt"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}