import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'breakpoints.dart';

/// Lock phones to portrait and tablets to landscape.
///
/// On Android, [FlutterView.physicalSize] is often 0×0 during [main] before
/// the first frame — locking then would permanently classify a tablet as a
/// phone. Call [lockAppOrientations] from [main], then again via
/// [OrientationLockBinder] once MediaQuery has a real size.
Future<void> lockAppOrientations({Size? logicalSize}) async {
  final size = logicalSize ?? _viewLogicalSize();
  // Wait for a real metrics readout (not 0×0).
  if (size.shortestSide < 1) return;

  final isTablet = _isTabletFormFactor(size);

  if (isTablet) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
}

Size _viewLogicalSize() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return Size.zero;
  final view = views.first;
  if (view.physicalSize == Size.zero) return Size.zero;
  return view.physicalSize / view.devicePixelRatio;
}

/// Compact field tablets (Tab Active 2) can report ~480–540dp shortest side
/// depending on density. Also accept a large longest side so dense-DPI
/// misreports still count as tablets.
bool _isTabletFormFactor(Size size) {
  if (Breakpoints.isTabletDevice(size.shortestSide)) return true;
  // Fallback: ~7"+ class screens even when density shrinks shortestSide.
  return size.shortestSide >= 480 && size.longestSide >= 800;
}

/// Applies orientation lock once MediaQuery reports a non-zero size.
class OrientationLockBinder extends StatefulWidget {
  final Widget child;

  const OrientationLockBinder({super.key, required this.child});

  @override
  State<OrientationLockBinder> createState() => _OrientationLockBinderState();
}

class _OrientationLockBinderState extends State<OrientationLockBinder>
    with WidgetsBindingObserver {
  double? _lockedShortestSide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _apply();
  }

  void _apply() {
    if (!mounted) return;
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < 1) return;
    // Re-lock only when form-factor bucket might change (or first time).
    if (_lockedShortestSide != null &&
        (_lockedShortestSide! - size.shortestSide).abs() < 1) {
      return;
    }
    _lockedShortestSide = size.shortestSide;
    lockAppOrientations(logicalSize: size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
