import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// A wrapper that renders one of up to four layouts based on the current
/// available width.
///
/// Only [phone] is required. The others fall back gracefully if omitted:
///   - `tabletPortrait` falls back to `phone`
///   - `tabletLandscape` falls back to `tabletPortrait` or `phone`
///   - `wideTablet` falls back to `tabletLandscape`, `tabletPortrait`, or `phone`
///
/// This means a screen can start with just a phone layout and progressively
/// add tablet variants without breaking anything.
class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder phone;
  final WidgetBuilder? tabletPortrait;
  final WidgetBuilder? tabletLandscape;
  final WidgetBuilder? wideTablet;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tabletPortrait,
    this.tabletLandscape,
    this.wideTablet,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.categorize(constraints.maxWidth);

        switch (size) {
          case LayoutSize.wideTablet:
            return (wideTablet ?? tabletLandscape ?? tabletPortrait ?? phone)
                .call(context);
          case LayoutSize.tabletLandscape:
            return (tabletLandscape ?? tabletPortrait ?? phone).call(context);
          case LayoutSize.tabletPortrait:
            return (tabletPortrait ?? phone).call(context);
          case LayoutSize.phone:
            return phone.call(context);
        }
      },
    );
  }
}

/// A shorthand helper: quickly branch on layout size within a build method
/// without wrapping in `ResponsiveLayout`.
///
/// Example:
/// ```
/// final layout = LayoutOf(context);
/// if (layout.isTablet) { ... }
/// ```
class LayoutOf {
  final LayoutSize size;
  final double width;

  LayoutOf._(this.size, this.width);

  factory LayoutOf(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return LayoutOf._(Breakpoints.categorize(w), w);
  }

  bool get isPhone => size == LayoutSize.phone;
  bool get isTabletPortrait => size == LayoutSize.tabletPortrait;
  bool get isTabletLandscape => size == LayoutSize.tabletLandscape;
  bool get isWideTablet => size == LayoutSize.wideTablet;
  bool get isAtLeastTablet =>
      size == LayoutSize.tabletLandscape ||
      size == LayoutSize.wideTablet;
}