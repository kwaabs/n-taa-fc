/// Layout breakpoints used across the app for tablet/phone responsive design.
///
/// Screens use these to decide whether to render a phone layout (stacked,
/// single-column) or a tablet layout (multi-pane, side panels, wider fields).
class Breakpoints {
  static const double phone = 600;
  static const double tabletCompact = 900;
  static const double tabletWide = 1200;

  /// True if the given width qualifies as "at least tablet."
  static bool isTablet(double width) => width >= tabletCompact;

  /// True if the width qualifies as "wide tablet or larger."
  static bool isWideTablet(double width) => width >= tabletWide;

  /// A convenient enum-like helper that returns the current layout category
  /// for a given width.
  static LayoutSize categorize(double width) {
    if (width >= tabletWide) return LayoutSize.wideTablet;
    if (width >= tabletCompact) return LayoutSize.tabletLandscape;
    if (width >= phone) return LayoutSize.tabletPortrait;
    return LayoutSize.phone;
  }
}

/// Discrete layout categories. Screens can switch on this to decide
/// their presentation.
enum LayoutSize {
  /// < 600px width. Phone in portrait or landscape.
  phone,

  /// 600-900px. Small tablet portrait or landscape phone.
  tabletPortrait,

  /// 900-1200px. Standard tablet landscape.
  tabletLandscape,

  /// >= 1200px. Large tablet, foldable, or desktop.
  wideTablet,
}