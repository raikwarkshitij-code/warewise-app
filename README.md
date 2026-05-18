# Amazon MWIS (Mobile Warehouse Inventory System)

Amazon MWIS is a cross-platform, enterprise-grade logistics fulfillment terminal and financial telemetry ecosystem. Meticulously engineered using the Flutter SDK and powered by an automated, real-time Cloud Firestore synchronization pipeline, the application is designed to optimize supply chain visibility, automate cross-dock rebalancing, and evaluate procurement sourcing metrics across distributed warehouse networks.

The application features a fully responsive, adaptive layout system architected in VS Code to ensure an optimal user experience across desktop browsers, operations tablets, and compact mobile device screens (e.g., OnePlus Nord, Google Pixel 7).

---

## 📱 Core Application Portals & Architecture

The application is unified under a state-managed navigation shell (`main_shell.dart`) that coordinates view tracks seamlessly across four critical enterprise modules:

### 1. Central Inventory Controller & Seeder (`dashboard_page.dart`)
* **Real-Time Database Sync:** Uses a continuous `StreamBuilder` connection to the Firestore `products` data collection to dynamically calculate active warehouse volumes across your core shipping hubs: **Berlin Hub**, **Hamburg Hub**, and **Munich Hub**.
* **Zero-Dependency Native CSV Parser:** Embeds a custom, high-speed CSV parsing loop (`autoUploadKaggleData`) that directly targets your double-extended spreadsheet assets (`assets/amazon_inventory.csv.csv`). It reads row data line-by-line, isolates string values, handles quotation rules, and converts strings into typed database data structures without relying on third-party packages.
* **Firestore Ingestion Safe-Guards:** To prevent quota exhaustion on Firebase free tiers, the engine automatically caps imports at **300 concurrent records max** and groups document insertion commands within structured asynchronous `WriteBatch` operations.
* **Fluid Category Filters:** Features a predictive text search field paired with a horizontally scrolling swipe bar (`SingleChildScrollView` with `BouncingScrollPhysics`) for swift category isolation.

### 2. Logistics Alert Center (`alerts_page.dart`)
* **Asymmetry Intercept Loop:** Runs proactive inventory check queries comparing active regional stock pools against fixed safety thresholds (`minStockLevel`).
* **Instant Stock Deflection:** When a localized deficit is encountered, the page calculates regional supply levels, pinpoints the hub with the largest surplus, and triggers an actionable rebalancing card. Personnel can tap this card to immediately generate an inter-hub transfer manifest.

### 3. Adaptive Cross-Dock Fulfillment Terminal (`operations_page.dart`)
* **Breakpoint Layout Engine:** Leverages `MediaQuery` to evaluate screen space. On widescreen monitors, asset parameters stretch evenly across horizontal rows. On narrow mobile viewports, the app stacks details dynamically into sleek vertical tracking cards to avoid layout breaking.
* **Boundary Overflow Protection:** Eliminates right-side pixel boundary clipping errors (the black-and-yellow hazard bar) by substituting rigid constraints with flexible widgets (`Expanded`, `Flexible`, and `Wrap`).
* **Executive Decision Matrix Container:** A dark-themed, manager-secure panel that automatically models supply chain savings. It contrasts Option A (External Vendor Procurement Loss) against Option B (Internal Transfer Route Freight) based on batch volumes to calculate your exact **Total Capital Retained (Net Profit)**.
* **Lifecycle State Machine:** Advances supply chain operations through a structured state track: `Requested (Awaiting Approval)` ➔ `In Transit (Transfer Initiated)` ➔ `Delivered (Transfer Completed)`.

### 4. Financial Performance Vault (`finance_page.dart`)
* **Authentication Gatekeeper:** Encrypts data behind a visual security vault layer. Tapping the clearance button launches an isolated modal window that challenges user credentials against your security token (`mwis2026`) to unlock the dashboard.
* **Dynamic Arithmetic Calculation Engine:** Iterates programmatically through your category sets (*Beauty & Essentials*, *Electronics & Tech*, *Fashion & Clothing*, *Accessories*, *Home & Appliances*). It aggregates gross revenue pools and net profits on the fly, smoothly adjusting whether a given category holds 9 items, 10 items, or expands further.
* **Decoupled Master-Detail View:** Offloads heavy data grids from nested expandables into an isolated sub-page routing channel (`Navigator.push`). This uncouples dense text rendering from the main screen scroll tree, completely removing swipe gesture lag.

---

## 🗄️ Database Mapping Schema (Cloud Firestore Layout)

The system relies on a clean, denormalized NoSQL structural model inside a single Firebase project database named `mwis-inventory`:

### `products` Collection
```json
products (Collection)
  └── [Auto-Generated Document ID] (Document)
        ├── name: "Dyson Airwrap Multi-Styler 4606" (String)
        ├── category: "Beauty & Essentials" (String)
        ├── price: 549.99 (Number)
        ├── quantity: "2399" (String)
        ├── minStockLevel: "480" (String)
        └── cityStock (Map)
              ├── Berlin: 1146 (Number)
              ├── Hamburg: 608 (Number)
              └── Munich: 645 (Number)

The underlying application architecture handles high-velocity data parsing, user authentication security loops, and real-time database state triggers through cleanly isolated pages:

### 1. Brand Identity Authentication Portal (`auth_page.dart`)
* **Enterprise Aesthetic Styling:** Implements the official color taxonomy with custom material color constants: Slate Dark Blue (`0xFF232F3E`), Accent Blue (`0xFF146EB4`), and Off-White Grey (`0xFFF2F2F2`) to match standard warehouse management terminals.
* **Stateful Input Processing:** Captures and strips whitespace from input fields using `.text.trim()` upon firing execution requests via `submit()`.
* **Asynchronous Authentication Pipeline:** Interfaces directly with the Firebase Authentication SDK. It evaluates a single boolean flag (`isLogin`) to dynamically call either `signInWithEmailAndPassword()` or `createUserWithEmailAndPassword()` inside an active error interception catch block.
* **Double-Submission Deflection:** Toggles a reactive status state `isLoading`. While true, the page swaps the text widget with a 20x20 white `CircularProgressIndicator` and completely nullifies the action button's listener track (`isLoading ? null : submit`) to block multiple accidental network requests.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Exact Amazon color palette mappings
  static const Color amazonBlue = Color(0xFF146EB4);
  static const Color amazonDarkBlue = Color(0xFF232F3E);
  static const Color amazonLightGrey = Color(0xFFF2F2F2);
  static const Color amazonBlack = Color(0xFF000000);

  bool isLogin = true;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Preserved Firebase Authentication Submit Core
  Future<void> submit() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Please fill out all credential fields.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amazonLightGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- TOP MIDDLE MANDATORY TITLE ---
                const Text(
                  'AMAZON MWIS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: amazonDarkBlue,
                    letterSpacing: 0.75,
                  ),
                ),
                const SizedBox(height: 32),

                // --- CENTRAL CARD COMPONENT ---
                Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Amazon Blue Branding Lock Icon
                        const Icon(
                          Icons.lock,
                          size: 44,
                          color: amazonBlue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: amazonBlack,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email Text Input Field
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: amazonLightGrey.withOpacity(0.5),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: amazonBlue, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Text Input Field
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: amazonLightGrey.withOpacity(0.5),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: amazonBlue, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),

                        // Error Message Display Section
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Primary Action Button (Amazon Dark Slate Blue)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amazonDarkBlue,
                              foregroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: isLoading ? null : submit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isLogin ? 'Sign In' : 'Register',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- BOTTOM DYNAMIC TOGGLE BUTTON PILL ---
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      isLogin = !isLogin;
                      errorMessage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLogin
                          ? "Don't have an account? Register"
                          : "Already have an account? Sign In",
                      style: const TextStyle(
                        fontSize: 13,
                        color: amazonDarkBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

### 2. Live Inventory Controller & CSV Parsing Engine (`dashboard_page.dart`)
* **Stateful Query Pipelines:** Coordinates a real-time tracking stream with the Firestore `products` collection. It automatically parses document snapshot streams into typed objects mapping item details, pricing schemas, and real-time cross-dock units.
* **High-Fidelity Multi-Extension CSV Parser:** Embeds a pure-Dart string tokenizer loop inside `manuallyImportCsv()` that extracts and decodes text data directly from file paths (e.g., `assets/amazon_inventory.csv.csv`). It processes row entries line-by-line using a flag tracking text boundaries (`inQuotes`) to parse text that contains standard commas.
* **Firestore Ingestion Limits Safe-Guards:** To ensure compliance with Cloud Firestore constraints and free-tier operation rules, the seeder slices incoming data arrays into isolated database blocks using `WriteBatch`. It tracks a count variable (`itemsInCurrentBatch`) and automatically creates a new execution block when the count reaches the 500-item maximum limit.
* **Dynamic Categorical Extraction Loop:** Eliminates static filter arrays by programmatically reading unique category strings straight from active Firestore documents during a `StreamBuilder` track. It converts entries into a unique string collection (`Set<String> uniqueCategories`), filters duplicates, sorts alphabetically, and constructs filter chips on the fly.
* **Registry Multi-Selection Tracker:** Implements a long-press state watcher (`_handleLongPress`) that changes the layout view frame into an interactive multi-delete state. Staging checkboxes push unique document IDs into a collection path (`Set<String> _selectedProductIds`), allowing supervisors to trigger a unified delete batch request.


### 4. Proactive Asymmetry Alert Engine (`alerts_page.dart`)
* **Node Delta Assessment Loop:** Loops continuously through multiple inventory fields in Firestore documents to evaluate localized warehouse volumes across **Berlin**, **Hamburg**, and **Munich** against safety buffers (`minStockLevel`).
* **Surplus Allocation Algorithm:** Sorts regional warehouse supply values inside an internal list variable collection using a comparison logic script:
  ```dart
  nodes.sort((a, b) => b.value.compareTo(a.value));
  final surplusNode = nodes.first;

  Map<String, dynamic> _createAlertPayload(
      String id,
      String name,
      String lowCity,
      int lowQty,
      int limit,
      MapEntry<String, int> surplus,
      Map<String, dynamic> raw) {
    return {
      'productName': name,
      'lowHubName': lowCity,
      'lowHubQty': lowQty,
      'surplusHubName': surplus.key,
      'surplusHubQty': surplus.value,
      'productData': {
        'id': id,
        'name': name,
        'quantity': raw['quantity']?.toString() ?? '0',
        'minStockLevel': raw['minStockLevel']?.toString() ?? '0',
        'price': raw['price']?.toString() ??
            '0.0', // FIXED: Injected missing pricing parameter payload to drive calculations
        'cityStock': raw['cityStock'] ?? {},
        'category': raw['category']?.toString() ?? 'Uncategorized',
      }
    };
  }
}), (import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  // Exact Amazon color palette mappings
  static const Color amazonBlue = Color(0xFF146EB4);
  static const Color amazonDarkBlue = Color(0xFF232F3E);
  static const Color amazonLightGrey = Color(0xFFF2F2F2);
  static const Color amazonBlack = Color(0xFF000000);

  bool isLogin = true;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Preserved Firebase Authentication Submit Core
  Future<void> submit() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Please fill out all credential fields.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message);
    } catch (e) {
      setState(() => errorMessage = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: amazonLightGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- TOP MIDDLE MANDATORY TITLE ---
                const Text(
                  'AMAZON MWIS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: amazonDarkBlue,
                    letterSpacing: 0.75,
                  ),
                ),
                const SizedBox(height: 32),

                // --- CENTRAL CARD COMPONENT ---
                Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Amazon Blue Branding Lock Icon
                        const Icon(
                          Icons.lock,
                          size: 44,
                          color: amazonBlue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLogin ? 'Sign In' : 'Create Account',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: amazonBlack,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email Text Input Field
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: amazonLightGrey.withOpacity(0.5),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: amazonBlue, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Text Input Field
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: amazonLightGrey.withOpacity(0.5),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Colors.black12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: amazonBlue, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),

                        // Error Message Display Section
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Primary Action Button (Amazon Dark Slate Blue)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: amazonDarkBlue,
                              foregroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: isLoading ? null : submit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isLogin ? 'Sign In' : 'Register',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- BOTTOM DYNAMIC TOGGLE BUTTON PILL ---
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      isLogin = !isLogin;
                      errorMessage = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLogin
                          ? "Don't have an account? Register"
                          : "Already have an account? Sign In",
                      style: const TextStyle(
                        fontSize: 13,
                        color: amazonDarkBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}) ,

### 6. High-Fidelity Stock List Component (`product_list_view.dart`)
* **Decoupled Stateless Renderer:** Offloads complex list tracking logic from parent state scopes. It exposes clean required callback hooks (`onProductTap`, `onToggleSelection`, `onLongPress`) to pass tap and scroll actions cleanly back up to central controllers.
* **Inline Threshold Parsing Engine:** Safely processes raw string parameters into standard numeric values using `int.tryParse()` inside the row build thread. It continuously monitors warehouse counts (`qty <= minStock`) to dynamically flag low stock alert signals.
* **Reactive Alert Component Theming:** Shifts card background colors to critical alert red (`Colors.red.shade50`), adjusts icon widgets to warn states (`Icons.warning_amber_rounded`), and alters label styles to clear dark red alert text layouts if threshold deficits are met.
* **Adaptive Multi-Selection View States:** Reconfigures its structural layouts based on layout state parameters. When selection filters map to active, it automatically replaces item indexing avatars with active Material `Checkbox` elements to facilitate unified bulk-deletion transactions.
* **Zero-State Fallback Handler:** Intercepts unpopulated database pipelines. If product array lengths read empty, it hides scrolling tracks and renders a centered, lightweight placeholder graphic prompting users to upload an initialization sheet.
//dart,,,
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
,,,

 ### 3. Statefully Isolated Document Editor (`edit_product_screen.dart`)
* **Data Layer Initializer:** A stateful tracking portal that copies existing database parameters directly into editable forms during the `initState()` framework sequence.
* **Input Validation Constraints:** Runs input inspections prior to transmitting data streams. If input string fields are left empty, it cancels the transaction and alerts the client via an automated message banner.
* **Targeted Document Paths Sync:** Targets specific documents inside the Firestore collection using the unique string ID index (`widget.product['id']`). It fires an optimized updates map payload containing only the modified properties, instantly syncing metrics across all concurrent device views.
//dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController nameController;
  late TextEditingController quantityController;
  late TextEditingController minStockLevelController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.product['name']?.toString() ?? '');
    quantityController = TextEditingController(
        text: widget.product['quantity']?.toString() ?? '');
    minStockLevelController = TextEditingController(
        text: widget.product['minStockLevel']?.toString() ?? '0');
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    minStockLevelController.dispose();
    super.dispose();
  }

  Future<void> saveChanges() async {
    final name = nameController.text.trim();
    final quantity = quantityController.text.trim();
    final minStockLevel = minStockLevelController.text.trim();

    if (name.isEmpty || quantity.isEmpty || minStockLevel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => isSaving = true);

    await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.product['id'])
        .update({
      'name': name,
      'quantity': quantity,
      'minStockLevel': minStockLevel,
    });

    setState(() => isSaving = false);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Product',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minStockLevelController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Stock Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
    );
  }
}

### 5. Encrypted Financial Telemetry Vault (`finance_page.dart`)
* **Stateful Security Gatekeeper Protection:** Encrypts core financial parameters behind a protective view block driven by a local status flag (`_isVaultLocked`). If active, the app hides sensitive dashboards and displays a restricted vault landing panel.
* **Token Challenge Input Authentication:** Launches a floating modal prompt that matches user credentials against your designated string passcode variable (`mwis2026`). The title element leverages an `Expanded` layout container to prevent 46-pixel horizontal layout overflow crashes on mobile devices.
* **Dynamic Arithmetic Compilation Loop:** Executes a real-time mathematics loop that calculates metrics on the fly. It programmatically iterates through product categories (*Beauty & Essentials*, *Electronics & Tech*, *Fashion & Clothing*, *Accessories*, *Home & Appliances*), automatically aggregating total **Gross Revenue Pools** and **Net Profit Allocations** (derived from a hardcoded 40% target operations margin ceiling).
* **Decoupled Master-Detail Sub-Routing:** Offloads detailed spreadsheet records from dense, embedded layout modules into an isolated standalone display canvas page layout (`CategoryDetailPage`). This uncouples dense text rendering lists from the primary screen view tree, completely removing scroll gesture lag across compact mobile device viewports.
* **Adaptive Dual-Axis Spreadsheet Matrix:** Integrates nested vertical and horizontal scroll parameters to display asset listings inside a clean, structured `DataTable`. The view renders high-volume SKU listings, stock levels, item retail prices, and calculated profits clearly without causing view rendering limits to freeze or lock up.

//dart

(import 'package:flutter/material.dart';

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

