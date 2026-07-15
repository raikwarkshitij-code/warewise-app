import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore.dart';
import 'alerts_page.dart';
import '../widgets/brand_logo.dart';
import '../widgets/pulse_icon.dart';

class DashboardPage extends StatelessWidget {
  final VoidCallback? onTriggerOpsJump;

  const DashboardPage({super.key, this.onTriggerOpsJump});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('products').snapshots(),
        builder: (context, snapshot) {
          // ---- ERROR STATE ----
          if (snapshot.hasError) {
            return CustomScrollView(
              slivers: [
                _buildHeaderSliver(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildConnectionErrorCard(),
                  ),
                ),
              ],
            );
          }

          final bool isLoading =
              snapshot.connectionState == ConnectionState.waiting;
          final docs = snapshot.data?.docs ?? [];

          // Total Items = number of distinct product documents (SKUs), not total unit count.
          final int totalProductCount = docs.length;
          double absoluteValuation = 0.0;
          int dynamicAlertCount = 0;

          if (!isLoading) {
            for (var document in docs) {
              final payload = document.data() as Map<String, dynamic>;
              final quantity =
                  int.tryParse(payload['quantity']?.toString() ?? '0') ?? 0;
              // Prefer minStock (actual field name in the dataset), fall back to threshold, then a safe default.
              final threshold = int.tryParse(
                    payload['minStock']?.toString() ??
                        payload['threshold']?.toString() ??
                        '',
                  ) ??
                  1000;
              // Gracefully handles documents that don't yet have a price field (defaults to 0).
              final explicitPrice =
                  double.tryParse(payload['price']?.toString() ?? '0.0') ?? 0.0;

              absoluteValuation += (quantity * explicitPrice);
              if (quantity <= threshold) dynamicAlertCount++;
            }
          }

          return CustomScrollView(
            slivers: [
              _buildHeaderSliver(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: isLoading
                                  ? const _MetricSkeletonCard(
                                      key: ValueKey('skeleton_1'))
                                  : _buildAnimatedMetricCard(
                                      'Total Items',
                                      totalProductCount.toDouble(),
                                      Icons.inventory_2_rounded,
                                      false,
                                      key: const ValueKey('metric_items'),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: isLoading
                                  ? const _MetricSkeletonCard(
                                      key: ValueKey('skeleton_2'))
                                  : _buildAnimatedMetricCard(
                                      'Inventory Value',
                                      absoluteValuation,
                                      Icons.account_balance_wallet_rounded,
                                      true,
                                      key: const ValueKey('metric_value'),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('System Operations Risks',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B))),
                          if (!isLoading && dynamicAlertCount > 0)
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AlertsPage(
                                          onTabRedirect: onTriggerOpsJump))),
                              icon: const Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: Color(0xFF009473)),
                              label: const Text('View List',
                                  style: TextStyle(
                                      color: Color(0xFF009473),
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: isLoading
                            ? const _BannerSkeletonCard(
                                key: ValueKey('skeleton_banner'))
                            : (!isLoading && docs.isEmpty)
                                ? _buildEmptyStateBanner(
                                    key: const ValueKey('empty_banner'))
                                : _buildInteractiveAlertBanner(
                                    context, dynamicAlertCount,
                                    key: ValueKey<int>(dynamicAlertCount)),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderSliver() {
    return SliverAppBar(
      expandedHeight: 160.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF01604B),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF014D3C), Color(0xFF01604B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // right: 56 reserves room for the profile icon overlay that
        // main_shell.dart pins to the top-right corner (36px circle + 16px
        // offset + a little breathing room) so long title text can never
        // render underneath/behind it.
        titlePadding: const EdgeInsets.only(left: 20, right: 56, bottom: 20),
        title: Row(
          children: [
            const BrandLogo(size: 28),
            const SizedBox(width: 10),
            // Expanded (not MainAxisSize.min) — on narrow Android widths
            // "Smarter Inventory Control Hub" at 18px bold does not fit
            // next to the logo without this, which throws a RenderFlex
            // overflow. Expanded caps the Column's width to whatever the
            // SliverAppBar title slot actually has left, and the ellipsis
            // below is the graceful fallback if it's still tight.
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome to WareWise',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                          fontWeight: FontWeight.w400)),
                  const SizedBox(height: 2),
                  const Text('Smarter Inventory Control Hub',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEE2E2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(height: 16),
          const Text('Connection Issue',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text(
            "We couldn't reach live inventory data. This will retry automatically once your connection stabilizes.",
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateBanner({Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_outlined,
                color: Color(0xFF64748B), size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Inventory Yet',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF334155))),
                SizedBox(height: 2),
                Text('Run a sync or add products to see live data here.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedMetricCard(String designator, double absoluteTarget,
      IconData structuralIcon, bool prefixCurrency,
      {Key? key}) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween<double>(begin: 0.0, end: absoluteTarget),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutExpo,
      builder: (context, dynamicValue, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 14,
                  offset: const Offset(0, 4))
            ],
            border: Border.all(color: const Color(0xFFEDF2F7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(structuralIcon,
                    color: const Color(0xFF009473), size: 20),
              ),
              const SizedBox(height: 20),
              Text(
                prefixCurrency
                    ? '\$${dynamicValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                    : dynamicValue.toStringAsFixed(0),
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(designator,
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveAlertBanner(BuildContext context, int totalRisks,
      {Key? key}) {
    final bool clearState = totalRisks == 0;
    return InkWell(
      key: key,
      onTap: clearState
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AlertsPage(onTabRedirect: onTriggerOpsJump))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: clearState ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: clearState
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            PulseIcon(
              active: !clearState,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: clearState
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFFEDD5),
                    shape: BoxShape.circle),
                child: Icon(
                  clearState
                      ? Icons.check_circle_rounded
                      : Icons.gpp_maybe_rounded,
                  color: clearState
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEA580C),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clearState
                        ? 'Infrastructure Stable'
                        : 'Critical Stock Depletions Detected',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: clearState
                            ? const Color(0xFF14532D)
                            : const Color(0xFF7C2D12)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    clearState
                        ? 'All supply operational margins active.'
                        : '$totalRisks critical items fall beneath system thresholds.',
                    style: TextStyle(
                        fontSize: 12,
                        color: clearState
                            ? const Color(0xFF166534)
                            : const Color(0xFF9A3412)),
                  ),
                ],
              ),
            ),
            if (!clearState)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFEA580C)),
          ],
        ),
      ),
    );
  }
}

/// A shimmering placeholder box built with a plain [AnimationController] —
/// no external package required.
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value; // 0 -> 1
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0 + t * 3, 0),
              end: Alignment(0.0 + t * 3, 0),
              colors: const [
                Color(0xFFE7ECF1),
                Color(0xFFF4F7FA),
                Color(0xFFE7ECF1),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFE7ECF1),
              borderRadius: widget.borderRadius,
            ),
          ),
        );
      },
    );
  }
}

class _MetricSkeletonCard extends StatelessWidget {
  const _MetricSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(12))),
          SizedBox(height: 20),
          _ShimmerBox(width: 70, height: 22),
          SizedBox(height: 8),
          _ShimmerBox(width: 90, height: 12),
        ],
      ),
    );
  }
}

class _BannerSkeletonCard extends StatelessWidget {
  const _BannerSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF2F7)),
      ),
      child: const Row(
        children: [
          _ShimmerBox(
              width: 52,
              height: 52,
              borderRadius: BorderRadius.all(Radius.circular(26))),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: 180, height: 14),
                SizedBox(height: 8),
                _ShimmerBox(width: 220, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
