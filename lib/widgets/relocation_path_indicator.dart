import 'package:flutter/material.dart';

/// A small looping hub -> hub indicator used on relocation-suggestion cards
/// (Wise AI, Sourcing) to visualize the recommended transfer route.
class RelocationPathIndicator extends StatefulWidget {
  final String fromHub;
  final String toHub;
  final Color color;

  const RelocationPathIndicator({
    super.key,
    required this.fromHub,
    required this.toHub,
    required this.color,
  });

  @override
  State<RelocationPathIndicator> createState() =>
      _RelocationPathIndicatorState();
}

class _RelocationPathIndicatorState extends State<RelocationPathIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _hubChip(widget.fromHub),
        SizedBox(
          width: 48,
          height: 20,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _DashedArrowPainter(
                    progress: _controller.value, color: widget.color),
                size: const Size(48, 20),
              );
            },
          ),
        ),
        _hubChip(widget.toHub),
      ],
    );
  }

  Widget _hubChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: widget.color)),
    );
  }
}

class _DashedArrowPainter extends CustomPainter {
  final double progress;
  final Color color;

  _DashedArrowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width - 6, y), paint);

    final arrowPaint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width, y)
      ..lineTo(size.width - 8, y - 5)
      ..lineTo(size.width - 8, y + 5)
      ..close();
    canvas.drawPath(path, arrowPaint);

    // Traveling dot to suggest motion along the route.
    final dotX = (size.width - 10) * progress;
    canvas.drawCircle(Offset(dotX, y), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DashedArrowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
