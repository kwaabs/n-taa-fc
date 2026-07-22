import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persistent side panel used on tablet landscape.
///
/// Wraps content with a styled Material surface, elevation, and rounded
/// corners so it looks like a floating component, not chrome.
class MapSidePanel extends ConsumerWidget {
  final Widget child;

  const MapSidePanel({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: child,
        ),
      ),
    );
  }
}

/// A floating pill button representing a panel mode. When tapped, expands
/// the panel to show that mode's content.
///
/// When [selected] is true, shows a filled background (indicates this mode
/// is currently visible in the expanded panel).
class MapModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  const MapModePill({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      elevation: selected ? 6 : 3,
      color: selected
          ? cs.primaryContainer
          : cs.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? cs.onPrimaryContainer
                      : cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header widget for the expanded panel — shows a set of mode tabs
/// and a chevron button to collapse.
class MapSidePanelTabsHeader extends StatelessWidget {
  final List<MapSidePanelTab> tabs;
  final VoidCallback onCollapse;

  const MapSidePanelTabsHeader({
    super.key,
    required this.tabs,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++) ...[
                  MapModePill(
                    icon: tabs[i].icon,
                    label: tabs[i].label,
                    selected: tabs[i].selected,
                    onTap: tabs[i].onTap,
                  ),
                  if (i < tabs.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          elevation: 2,
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onCollapse,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MapSidePanelTab {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const MapSidePanelTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
}

/// A section-styled container inside the side panel — used as a wrapper
/// around any content for consistent look.
class MapSidePanelSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MapSidePanelSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// Backward-compatibility alias — kept because T1b.1 code was importing it.
/// It behaves the same as [MapSidePanelTabsHeader] but with a single title
/// instead of tabs.
class MapSidePanelHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback onCollapse;

  const MapSidePanelHeader({
    super.key,
    required this.title,
    this.icon,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return MapSidePanelTabsHeader(
      tabs: [
        MapSidePanelTab(
          icon: icon ?? Icons.tune,
          label: title,
          selected: true,
          onTap: () {},
        ),
      ],
      onCollapse: onCollapse,
    );
  }
}