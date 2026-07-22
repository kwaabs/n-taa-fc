import 'package:flutter/material.dart';
import 'responsive_layout.dart';

/// Renders [left] and [right] side by side on tablet landscape / wide,
/// stacked vertically (left then right) on phones and tablet portrait.
///
/// [gap] controls the spacing between columns (side-by-side) OR between
/// the two children when stacked.
class AdaptiveTwoColumn extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;
  final double gap;

  /// Ratio of left column width to total (0.0 – 1.0). Default 0.5.
  final double leftFlex;
  final double rightFlex;

  const AdaptiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.gap = 16,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final layout = LayoutOf(context);
    final useTwoColumns = layout.isTabletLandscape || layout.isWideTablet;

    if (!useTwoColumns) {
      // Phone / tablet portrait — stacked
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...left,
          if (right.isNotEmpty) SizedBox(height: gap),
          ...right,
        ],
      );
    }

    // Tablet landscape / wide — side by side
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: leftFlex.round(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: left,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: rightFlex.round(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: right,
          ),
        ),
      ],
    );
  }
}