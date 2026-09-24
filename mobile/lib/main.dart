import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/layout/orientation_lock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientations();
  runApp(
    const ProviderScope(
      child: FieldCollectorApp(),
    ),
  );
}