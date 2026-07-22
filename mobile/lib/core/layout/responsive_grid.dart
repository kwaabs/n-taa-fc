import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// A responsive grid that decides column count from the current [LayoutOf].
///
/// Rules:
/// - Phone (any orientation)      → 1 column
/// - Tablet portrait              → 2 columns
/// - Tablet landscape / wide      → 3 columns
///
/// Items are laid out with a max width cap so cards don't stretch grotesquely
/// on huge screens. If the natural column width exceeds [maxItemWidth], the
/// grid adds extra horizontal padding to keep cards readable.
class ResponsiveGrid extends StatelessWidget {
  /// The children (typically Cards).
  final List<Widget> children;

  /// Outer padding of the grid.
  final EdgeInsetsGeometry padding;

  /// Horizontal + vertical spacing between items.
  final double spacing;

  /// Max width for a single item. Cards wider than this look ugly on tablets.
  final double maxItemWidth;

  /// Aspect ratio (width / height) of each grid cell.
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(12),
    this.spacing = 12,
    this.maxItemWidth = 480,
    this.childAspectRatio = 2.4,
  });

  int _columnsFor(LayoutOf layout) {
    if (layout.isTabletLandscape || layout.isWideTablet) return 3;
    if (layout.isTabletPortrait) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final layout = LayoutOf(context);
    final columns = _columnsFor(layout);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute effective inner width after padding.
        final horizontalPadding = padding.resolve(TextDirection.ltr).horizontal;
        final innerWidth = constraints.maxWidth - horizontalPadding;

        // Column width if we filled evenly.
        final rawColWidth =
            (innerWidth - spacing * (columns - 1)) / columns;

        // If natural columns are wider than the cap, add side padding to
        // constrain the grid width and keep cards readable.
        double extraSidePad = 0;
        if (rawColWidth > maxItemWidth) {
          final targetWidth =
              maxItemWidth * columns + spacing * (columns - 1);
          extraSidePad = (innerWidth - targetWidth) / 2;
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extraSidePad),
          child: GridView.builder(
            padding: padding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: children.length,
            itemBuilder: (context, i) => children[i],
          ),
        );
      },
    );
  }
}