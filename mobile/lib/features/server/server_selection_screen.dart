import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/server_config.dart';

class ServerSelectionScreen extends ConsumerStatefulWidget {
  const ServerSelectionScreen({super.key});

  @override
  ConsumerState<ServerSelectionScreen> createState() =>
      _ServerSelectionScreenState();
}

class _ServerSelectionScreenState extends ConsumerState<ServerSelectionScreen> {
  String? _selectedPresetUrl;
  bool _customMode = false;
  late TextEditingController _customUrlController;
  ConnectionTestResult? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(serverConfigProvider.notifier);
    _customUrlController = TextEditingController(
      text: notifier.savedCustomUrl ?? '',
    );
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  List<ServerPreset> get _visiblePresets {
    if (kDebugMode) return kServerPresets;
    return kServerPresets.where((p) => !p.debugOnly).toList();
  }

  String? get _selectedUrl {
    if (_customMode) {
      final t = _customUrlController.text.trim();
      return t.isEmpty ? null : t;
    }
    return _selectedPresetUrl;
  }

  String? get _selectedLabel {
    if (_customMode) return null;
    final preset = kServerPresets
        .where((p) => p.url == _selectedPresetUrl)
        .firstOrNull;
    return preset?.label;
  }

  Future<void> _runTest() async {
    final url = _selectedUrl;
    if (url == null) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await testServerConnection(url);
    if (!mounted) return;
    setState(() {
      _testResult = result;
      _testing = false;
    });
  }

  Future<void> _proceed() async {
    final url = _selectedUrl;
    if (url == null) return;
    final notifier = ref.read(serverConfigProvider.notifier);
    if (_customMode) {
      await notifier.setCustomUrl(url);
    }
    await notifier.setServer(url: url, label: _selectedLabel);
  }

  bool get _canProceed =>
      _selectedUrl != null && _testResult?.success == true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Icon(Icons.cloud_outlined,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Server',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick the Field Collector instance to connect to.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Presets
                  ..._visiblePresets.map((preset) => _PresetTile(
                        preset: preset,
                        selected: !_customMode &&
                            _selectedPresetUrl == preset.url,
                        onTap: () => setState(() {
                          _selectedPresetUrl = preset.url;
                          _customMode = false;
                          _testResult = null;
                        }),
                      )),

                  // Custom option
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => setState(() {
                        _customMode = true;
                        _selectedPresetUrl = null;
                        _testResult = null;
                      }),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: _customMode,
                                  onChanged: (_) => setState(() {
                                    _customMode = true;
                                    _selectedPresetUrl = null;
                                    _testResult = null;
                                  }),
                                ),
                                const Icon(Icons.tune),
                                const SizedBox(width: 8),
                                Text('Custom URL',
                                    style: theme.textTheme.titleSmall),
                              ],
                            ),
                            if (_customMode) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customUrlController,
                                onChanged: (_) =>
                                    setState(() => _testResult = null),
                                decoration: const InputDecoration(
                                  hintText: 'http://192.168.1.50:5355',
                                  prefixIcon: Icon(Icons.link),
                                ),
                                keyboardType: TextInputType.url,
                                autocorrect: false,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Test connection
                  OutlinedButton.icon(
                    onPressed: (_selectedUrl != null && !_testing)
                        ? _runTest
                        : null,
                    icon: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label:
                        Text(_testing ? 'Testing...' : 'Test Connection'),
                  ),

                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    _ResultBanner(result: _testResult!),
                  ],

                  const SizedBox(height: 24),

                  // Continue
                  FilledButton.icon(
                    onPressed: _canProceed ? _proceed : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue'),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    _canProceed
                        ? 'Server verified. Tap Continue to proceed to login.'
                        : 'Test the connection before continuing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final ServerPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Radio<String>(
                value: preset.url,
                groupValue: selected ? preset.url : null,
                onChanged: (_) => onTap(),
              ),
              Icon(
                preset.debugOnly ? Icons.laptop : Icons.cloud,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      preset.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      preset.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final ConnectionTestResult result;

  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOk = result.success;
    final color = isOk
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.errorContainer;
    final onColor = isOk
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_outline : Icons.error_outline,
            color: onColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOk ? 'Connection OK' : 'Connection failed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isOk && result.error != null)
                  Text(
                    result.error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: onColor),
                  ),
                if (isOk && result.serverVersion != null)
                  Text(
                    'Server: ${result.serverVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(color: onColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}