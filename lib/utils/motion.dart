import 'package:flutter/material.dart';

/// Shared transition timing so tab switches, page pushes, and status
/// animations all move at the same pace across the app.
const Duration kTabTransitionDuration = Duration(milliseconds: 350);
const Curve kTabTransitionCurve = Curves.easeOutCubic;

/// A [MaterialPageRoute] alternative with a fade+slide transition matching
/// [kTabTransitionCurve], for use where a plain MaterialPageRoute's default
/// platform transition should instead match the rest of the app's motion.
Route<T> buildMotionRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: kTabTransitionCurve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                  .animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: kTabTransitionDuration,
  );
}
