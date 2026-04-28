import 'package:flutter/widgets.dart';

enum Breakpoint { compact, medium, expanded }

class Breakpoints {
  Breakpoints._();

  static const double compactMax = 600;
  static const double mediumMax = 1000;

  static Breakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static Breakpoint fromWidth(double width) {
    if (width < compactMax) return Breakpoint.compact;
    if (width < mediumMax) return Breakpoint.medium;
    return Breakpoint.expanded;
  }
}

extension BreakpointX on Breakpoint {
  bool get isCompact => this == Breakpoint.compact;
  bool get isMedium => this == Breakpoint.medium;
  bool get isExpanded => this == Breakpoint.expanded;
  bool get isAtLeastMedium => this != Breakpoint.compact;
}
