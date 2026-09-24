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
  final double shortestSide;
  final Orientation orientation;

  LayoutOf._(this.size, this.width, this.shortestSide, this.orientation);

  factory LayoutOf(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    return LayoutOf._(
      Breakpoints.categorize(size.width),
      size.width,
      size.shortestSide,
      mq.orientation,
    );
  }

  bool get isPhone => size == LayoutSize.phone;
  bool get isTabletPortrait => size == LayoutSize.tabletPortrait;
  bool get isTabletLandscape => size == LayoutSize.tabletLandscape;
  bool get isWideTablet => size == LayoutSize.wideTablet;

  /// Width-based "large tablet landscape" (legacy; prefers ≥900dp width).
  bool get isAtLeastTablet =>
      size == LayoutSize.tabletLandscape || size == LayoutSize.wideTablet;

  /// Device is a tablet-class form factor (incl. compact 8" tablets).
  bool get isTabletDevice => Breakpoints.isTabletDevice(shortestSide);

  /// Map / multi-pane chrome: tablet device held (or locked) in landscape.
  /// Prefer this over [isAtLeastTablet] for map side panels — Tab Active 2
  /// landscape width is often only ~850dp, below the 900 width bucket.
  bool get useTabletMapChrome =>
      isTabletDevice && orientation == Orientation.landscape;
}