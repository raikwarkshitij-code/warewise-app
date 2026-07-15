import 'package:flutter/material.dart';

/// Consistent error state for StreamBuilder/FutureBuilder failures (offline,
/// permission-denied, etc.) — used instead of letting an error silently fall
/// through to a loading spinner or an "empty" state.
class StreamErrorView extends StatelessWidget {
  final Object? error;
  final String? message;

  const StreamErrorView({super.key, this.error, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Something went wrong loading this data.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text('$error',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
