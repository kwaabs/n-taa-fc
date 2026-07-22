import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// Renders form field widgets responsively:
/// - Phone / tablet portrait → stacked (one per row)
/// - Tablet landscape / wide → 2 per row, unless [isFullWidth] returns true
///   for a given index, in which case that field spans the full row.
class ResponsiveFormFields extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final bool Function(int index) isFullWidth;
  final double gap;

  const ResponsiveFormFields({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.isFullWidth,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final layout = LayoutOf(context);
    final twoColumn = layout.isTabletLandscape || layout.isWideTablet;

    if (!twoColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < itemCount; i++) ...[
            itemBuilder(context, i),
            if (i < itemCount - 1) SizedBox(height: gap),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;
        final halfWidth = (rowWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < itemCount; i++)
              SizedBox(
                width: isFullWidth(i) ? rowWidth : halfWidth,
                child: itemBuilder(context, i),
              ),
          ],
        );
      },
    );
  }
}