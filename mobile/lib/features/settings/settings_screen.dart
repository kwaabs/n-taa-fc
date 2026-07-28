import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api/dio_client.dart';
import '../../core/app_update.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/basemap_options.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme.dart';

import 'external_gnss_screen.dart';
import 'gnss_diagnostic_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
        data: (settings) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionHeader(label: 'Appearance'),
                  _ThemeModePicker(current: settings.themeMode),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'Map appearance'),
                  _BasemapPicker(currentId: settings.basemap),
                  const SizedBox(height: 8),
                  _ShowMyLocationToggle(enabled: settings.showMyLocation),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'Data capture'),
                  _SnapToggle(enabled: settings.snapEnabled),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'GPS tracking'),
                  _TrackPresetPicker(currentId: settings.trackPreset),
                  const SizedBox(height: 8),
                  _AccuracyFilterPicker(
                      currentMeters: settings.trackAccuracyFilterMeters),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'Location source'),
                  const _LocationSourcePlaceholder(),
                  const SizedBox(height: 8),
                  const _GnssDiagnosticTile(),
                  const SizedBox(height: 24),
                  _SectionHeader(label: 'About'),
                  const _AboutTile(),
                  const SizedBox(height: 8),
                  const _CheckForUpdatesTile(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Theme mode ──────────────────────────────────────────────

class _ThemeModePicker extends ConsumerWidget {
  final AppThemeMode current;
  const _ThemeModePicker({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(current.icon),
        title: const Text('Theme'),
        subtitle: Text('${current.label} — ${current.description}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showModalBottomSheet<AppThemeMode>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Choose theme',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final mode in AppThemeMode.values)
                        RadioListTile<AppThemeMode>(
                          value: mode,
                          groupValue: current,
                          title: Text(mode.label),
                          subtitle: Text(mode.description),
                          secondary: Icon(mode.icon),
                          onChanged: (v) => Navigator.pop(ctx, v),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
          if (picked != null) {
            await ref.read(settingsProvider.notifier).setThemeMode(picked);
          }
        },
      ),
    );
  }
}

// ── Basemap ─────────────────────────────────────────────────

class _BasemapPicker extends ConsumerWidget {
  final BasemapId currentId;
  const _BasemapPicker({required this.currentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = basemapById(currentId);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.map_outlined),
        title: const Text('Basemap'),
        subtitle: Text(current.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showModalBottomSheet<BasemapId>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Choose basemap',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final opt in basemapOptions)
                        RadioListTile<BasemapId>(
                          value: opt.id,
                          groupValue: currentId,
                          onChanged: (v) {
                            if (v != null) Navigator.of(ctx).pop(v);
                          },
                          title: Text(opt.label),
                          subtitle: Text(opt.description),
                        ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Note: basemap changes apply the next time you open '
                          'a map screen.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

          if (picked != null && picked != currentId) {
            await ref.read(settingsProvider.notifier).setBasemap(picked);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Basemap set to ${basemapById(picked).label}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Snap toggle ─────────────────────────────────────────────

class _SnapToggle extends ConsumerWidget {
  final bool enabled;
  const _SnapToggle({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          Icons.center_focus_weak,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Snap to nearby vertices'),
        subtitle: const Text(
          'When capturing lines and polygons, snap taps to existing '
          'feature vertices for cleaner geometry.',
        ),
        value: enabled,
        onChanged: (v) async {
          await ref.read(settingsProvider.notifier).setSnapEnabled(v);
        },
      ),
    );
  }
}

// ── Track preset ────────────────────────────────────────────

class _TrackPresetPicker extends ConsumerWidget {
  final String currentId;
  const _TrackPresetPicker({required this.currentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = trackPresetById(currentId);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer_outlined),
        title: const Text('Tracking sampling'),
        subtitle: Text('${current.label} — ${current.description}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Sampling preset',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final p in trackPresets)
                        RadioListTile<String>(
                          value: p.id,
                          groupValue: currentId,
                          onChanged: (v) {
                            if (v != null) Navigator.of(ctx).pop(v);
                          },
                          title: Text(p.label),
                          subtitle: Text(p.description),
                        ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Applies to the next tracking session — active tracks '
                          'keep their original sampling.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

          if (picked != null && picked != currentId) {
            await ref.read(settingsProvider.notifier).setTrackPreset(picked);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Tracking preset: ${trackPresetById(picked).label}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Accuracy filter ─────────────────────────────────────────

class _AccuracyFilterPicker extends ConsumerWidget {
  final int currentMeters;
  const _AccuracyFilterPicker({required this.currentMeters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.filter_alt_outlined),
        title: const Text('Accuracy filter'),
        subtitle: Text(
          'Reject points worse than: ${trackAccuracyLabel(currentMeters)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final picked = await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Accuracy filter',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final m in trackAccuracyOptions)
                        RadioListTile<int>(
                          value: m,
                          groupValue: currentMeters,
                          onChanged: (v) {
                            if (v != null) Navigator.of(ctx).pop(v);
                          },
                          title: Text(trackAccuracyLabel(m)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );

          if (picked != null && picked != currentMeters) {
            await ref
                .read(settingsProvider.notifier)
                .setTrackAccuracyFilter(picked);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Accuracy filter: ${trackAccuracyLabel(picked)}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

// ── Location source placeholder ─────────────────────────────

class _LocationSourcePlaceholder extends ConsumerWidget {
  const _LocationSourcePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final usingExternal = settings?.locationSource == 'external';
    final deviceName = settings?.externalDeviceName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gps_fixed,
                    size: 20,
                    color: usingExternal
                        ? Colors.grey.shade500
                        : Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Phone GPS',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: usingExternal ? Colors.grey.shade600 : null,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: usingExternal
                        ? Colors.grey.shade200
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    usingExternal ? 'STANDBY' : 'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: usingExternal
                          ? Colors.grey.shade600
                          : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Built-in device GPS — typical accuracy 3-15 m.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const Divider(height: 24),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExternalGnssScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth_searching,
                        size: 20,
                        color: usingExternal
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'External GNSS receiver',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color:
                                  usingExternal ? null : Colors.grey.shade600,
                            ),
                          ),
                          if (usingExternal && deviceName != null)
                            Text(
                              deviceName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            )
                          else
                            Text(
                              'Tap to pair a Bluetooth GNSS device.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: usingExternal
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        usingExternal ? 'ACTIVE' : 'CONFIGURE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: usingExternal
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        final subtitle = info == null
            ? 'Loading…'
            : 'v${info.version} · build ${info.buildNumber}';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Field Collector'),
            subtitle: Text(subtitle),
          ),
        );
      },
    );
  }
}

class _CheckForUpdatesTile extends ConsumerStatefulWidget {
  const _CheckForUpdatesTile();

  @override
  ConsumerState<_CheckForUpdatesTile> createState() =>
      _CheckForUpdatesTileState();
}

class _CheckForUpdatesTileState extends ConsumerState<_CheckForUpdatesTile> {
  var _busy = false;

  Future<void> _check() async {
    final dio = ref.read(dioProvider);
    if (dio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to a server first')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await fetchAndroidUpdate(dio);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No published release found')),
        );
        return;
      }
      if (!result.updateAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are up to date (v${result.localVersionName})',
            ),
          ),
        );
        return;
      }
      await showUpdateDialog(context, result, allowDismiss: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update check failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.system_update),
        title: const Text('Check for updates'),
        subtitle: const Text('Download the latest Android APK if available'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : _check,
      ),
    );
  }
}

class _GnssDiagnosticTile extends StatelessWidget {
  const _GnssDiagnosticTile();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.speed),
        title: const Text('GNSS diagnostic'),
        subtitle: const Text('See live position from the active source'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const GnssDiagnosticScreen(),
            ),
          );
        },
      ),
    );
  }
}

class _ShowMyLocationToggle extends ConsumerWidget {
  final bool enabled;
  const _ShowMyLocationToggle({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          Icons.my_location,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Show my location'),
        subtitle: const Text(
          'Display a live pulsing marker at your current GPS position '
          'with an accuracy ring.',
        ),
        value: enabled,
        onChanged: (v) async {
          await ref.read(settingsProvider.notifier).setShowMyLocation(v);
        },
      ),
    );
  }
}
