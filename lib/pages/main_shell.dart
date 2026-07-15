import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dashboard_page.dart';
import 'inventory_page.dart';
import 'operations_page.dart';
import 'alerts_page.dart';
import 'finance_page.dart';
import 'sourcing_hub_page.dart';
import 'admin_users_page.dart';
import 'profile_page.dart';
import '../services/role_service.dart';

class _TabSpec {
  final Widget page;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabSpec(
      {required this.page,
      required this.icon,
      required this.activeIcon,
      required this.label});
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigationJumpToTab(int targetIndex) {
    setState(() => _currentIndex = targetIndex);
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  List<_TabSpec> _tabsForRole(String? role) {
    void jumpToOps() => _navigationJumpToTab(2);

    final tabs = <_TabSpec>[
      _TabSpec(
        page: DashboardPage(onTriggerOpsJump: jumpToOps),
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
        label: 'Hub',
      ),
      _TabSpec(
        page: AlertsPage(onTabRedirect: jumpToOps),
        icon: Icons.bolt_rounded,
        activeIcon: Icons.bolt_rounded,
        label: 'Wise AI',
      ),
      const _TabSpec(
        page: OperationsPage(),
        icon: Icons.swap_horizontal_circle_rounded,
        activeIcon: Icons.swap_horizontal_circle_rounded,
        label: 'Ops',
      ),
      const _TabSpec(
        page: InventoryPage(),
        icon: Icons.layers_rounded,
        activeIcon: Icons.layers_rounded,
        label: 'Stock',
      ),
    ];

    if (role == 'manager' || role == 'owner') {
      tabs.add(_TabSpec(
        page:
            SourcingHubPage(onTransferExecuted: () => _navigationJumpToTab(2)),
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        label: 'Sourcing',
      ));
    }

    if (role == 'finance' || role == 'owner') {
      tabs.add(const _TabSpec(
        page: FinancePage(),
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        label: 'Finance',
      ));
    }

    if (role == 'owner') {
      tabs.add(const _TabSpec(
        page: AdminUsersPage(),
        icon: Icons.admin_panel_settings_outlined,
        activeIcon: Icons.admin_panel_settings_rounded,
        label: 'Admin',
      ));
    }

    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final roleService = context.watch<RoleService>();

    if (roleService.isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF009473))),
      );
    }

    final tabs = _tabsForRole(roleService.role);
    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: tabs.map((t) => t.page).toList(),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfilePage())),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Color(0xFF01604B), size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF009473),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.3),
          items: tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.icon, size: 22),
                    activeIcon: Icon(t.activeIcon, size: 24),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
