import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart' as db;
import '../../core/db/bundle_seeder.dart';
import '../../core/db/db_provider.dart';
import '../../core/layout/adaptive_two_column.dart';
import '../collection/collected_features_section.dart';
import '../sync/sync_service.dart';
import '../map/map_project_screen.dart';
import '../map/map_providers.dart';
import 'bundle_downloader.dart';
import 'bundle_repository.dart';
import 'form_detail_screen.dart';
import 'local_data_providers.dart';
import 'project_contents_section.dart';
import 'project_model.dart';
import 'project_repository.dart';

enum _BundleStage { idle, requesting, polling, downloading, ready, error }

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  _BundleStage _stage = _BundleStage.idle;
  BundleProgress? _progress;
  BundleReady? _ready;
  String? _error;
  int _downloadedBytes = 0;
  SeedResult? _seedResult;
  Timer? _pollTimer;
  String? _statusMessage;
  /// When true, use legacy single full bundle instead of core + layer packs.
  bool _useLegacyFullBundle = false;
  bool _downloadAllMapLayers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverSyncState();
      _hydrateAoi();
    });
  }

  /// Pull AOI from API Get (list may omit heavy geom) into local project row.
  Future<void> _hydrateAoi() async {
    final repo = ref.read(projectRepositoryProvider);
    final database = ref.read(appDatabaseProvider);
    if (repo == null || database == null) return;
    try {
      final full = await repo.get(widget.project.id);
      if (full.areaOfInterest == null) return;
      await database.upsertProject(
        db.ProjectsCompanion(
          id: Value(full.id),
          name: Value(full.name),
          description: Value(full.description),
          mode: Value(full.mode),
          status: Value(full.status),
          version: Value(full.version),
          areaOfInterest: Value(jsonEncode(full.areaOfInterest)),
        ),
      );
    } catch (e) {
      debugPrint('[project] AOI hydrate skipped: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDownload() async {
    final repo = ref.read(bundleRepositoryProvider);
    if (repo == null) {
      setState(() {
        _stage = _BundleStage.error;
        _error = 'No connection';
      });
      return;
    }

    setState(() {
      _stage = _BundleStage.requesting;
      _progress = null;
      _ready = null;
      _error = null;
      _downloadedBytes = 0;
      _seedResult = null;
      _statusMessage = null;
    });

    if (_useLegacyFullBundle) {
      await _startLegacyDownload(repo);
    } else {
      await _startEfficientDownload(repo);
    }
  }

  Future<void> _startEfficientDownload(BundleRepository repo) async {
    try {
      final downloader = ref.read(bundleDownloaderProvider);
      final outcome = await downloader.downloadEfficient(
        project: widget.project,
        repo: repo,
        downloadReferencePacks: _downloadAllMapLayers,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _statusMessage = p.message;
            _progress = p.jobProgress;
            if (p.jobProgress != null) {
              _stage = _BundleStage.polling;
            } else if (p.message.toLowerCase().contains('download')) {
              _stage = _BundleStage.downloading;
            } else {
              _stage = _BundleStage.requesting;
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _stage = _BundleStage.ready;
        _ready = outcome.ready;
        _seedResult = outcome.seedResult;
        _downloadedBytes = outcome.downloadedBytes;
        _statusMessage = null;
      });
      await _refresh();
    } catch (e) {
      debugPrint('[BUNDLE] efficient download error: $e');
      if (!mounted) return;
      setState(() {
        _stage = _BundleStage.error;
        _error = e.toString();
        _statusMessage = null;
      });
    }
  }

  Future<void> _startLegacyDownload(BundleRepository repo) async {
    try {
      final result = await repo.request(
        projectId: widget.project.id,
        includeReferenceData: true,
      );

      debugPrint('[BUNDLE] legacy request: ready=${result.ready != null}, '
          'jobId=${result.jobId}');

      if (result.ready != null) {
        setState(() {
          _stage = _BundleStage.downloading;
          _ready = result.ready;
          _statusMessage = 'Downloading legacy bundle…';
        });
        await _runLegacyDownload(result.ready!);
        return;
      }

      if (result.jobId != null) {
        setState(() {
          _stage = _BundleStage.polling;
          _statusMessage = 'Building legacy bundle…';
        });
        _startLegacyPolling(result.jobId!);
      }
    } catch (e) {
      debugPrint('[BUNDLE] legacy request error: $e');
      setState(() {
        _stage = _BundleStage.error;
        _error = e.toString();
      });
    }
  }

  void _startLegacyPolling(String jobId) {
    final repo = ref.read(bundleRepositoryProvider);
    if (repo == null) {
      setState(() {
        _stage = _BundleStage.error;
        _error = 'No backend connection';
      });
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final view = await repo.pollJob(
          projectId: widget.project.id,
          jobId: jobId,
        );

        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() => _progress = view.progress);

        if (view.status == 'success' && view.ready != null) {
          timer.cancel();
          setState(() {
            _stage = _BundleStage.downloading;
            _ready = view.ready;
            _statusMessage = 'Downloading legacy bundle…';
          });
          unawaited(_runLegacyDownload(view.ready!));
        } else if (view.status == 'failed') {
          timer.cancel();
          setState(() {
            _stage = _BundleStage.error;
            _error = view.error ?? 'Bundle generation failed';
          });
        }
      } catch (e) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _stage = _BundleStage.error;
          _error = e.toString();
        });
      }
    });
  }

  Future<void> _runLegacyDownload(BundleReady ready) async {
    try {
      final downloader = ref.read(bundleDownloaderProvider);
      await downloader.ensureProjectRow(widget.project);
      final result = await downloader.downloadBundle(ready);

      setState(() {
        _downloadedBytes = result.bytes.length;
      });

      final seedResult = await downloader.seedAndRecord(
        projectId: widget.project.id,
        result: result,
      );

      if (!mounted) return;
      setState(() {
        _stage = _BundleStage.ready;
        _seedResult = seedResult;
        _statusMessage = null;
      });
      await _refresh();
    } catch (e) {
      debugPrint('[BUNDLE] legacy download error: $e');
      if (!mounted) return;
      setState(() {
        _stage = _BundleStage.error;
        _error = 'Download failed: $e';
      });
    }
  }

  void _reset() {
    _pollTimer?.cancel();
    setState(() {
      _stage = _BundleStage.idle;
      _progress = null;
      _ready = null;
      _error = null;
      _downloadedBytes = 0;
      _seedResult = null;
      _statusMessage = null;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(formsForProjectProvider(widget.project.id));
    ref.invalidate(layersForProjectProvider(widget.project.id));
    ref.invalidate(choiceListsForProjectProvider(widget.project.id));
    ref.invalidate(assignmentsForProjectProvider(widget.project.id));
    ref.invalidate(projectDownloadedAtProvider(widget.project.id));
    ref.invalidate(referenceFeatureCountProvider(widget.project.id));
    invalidateProjectMapProviders(ref.invalidate, widget.project.id);
    await Future.delayed(const Duration(milliseconds: 300));
    await _recoverSyncState();
  }

  Future<void> _recoverSyncState() async {
    final sync = ref.read(syncServiceProvider);
    if (sync == null) return;

    try {
      final result = await sync.recoverProject(projectId: widget.project.id);

      if (!mounted) return;

      if (result.featuresSynced > 0 || result.featuresPending > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recovery: ${result.featuresSynced} synced, '
              '${result.featuresPending} reset to pending',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RECOVER] project-screen recovery failed: $e');
    }
  }

  Future<void> _runSync() async {
    final sync = ref.read(syncServiceProvider);
    if (sync == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No connection')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing...')),
    );
    final result = await sync.syncProject(
      projectId: widget.project.id,
      onProgress: (p) {
        debugPrint(
            '[PROGRESS] ${p.processedFeatures}/${p.totalFeatures} — ${p.currentStep}');
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Done: ${result.summary}'),
        duration: Duration(
          seconds: result.featuresOutsideAoi > 0 ? 6 : 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = widget.project;

    // ── Cards extracted so we can arrange them differently on phone vs tablet ──

    final projectHeaderCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                project.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(
                    project.isMapBased ? 'Map-based' : 'Form',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(project.status),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text('v${project.version}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (project.isMapBased) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MapProjectScreen(project: project),
                    ),
                  );
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Map'),
              ),
            ],
          ],
        ),
      ),
    );

    final bundleDownloadCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Project Bundle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Downloads project setup (forms, layers catalog, assignments). '
              'Map tiles download when you open the map (or enable below).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_stage == _BundleStage.idle) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also download all map layers now'),
                subtitle: const Text(
                  'Only for small projects. Large projects should download '
                  'layers on the map.',
                ),
                value: _downloadAllMapLayers,
                onChanged: (v) => setState(() => _downloadAllMapLayers = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Legacy full bundle'),
                subtitle: const Text(
                  'Single archive with all layer reference data. Prefer off.',
                ),
                value: _useLegacyFullBundle,
                onChanged: (v) => setState(() => _useLegacyFullBundle = v),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Download for offline'),
              ),
            ],
            if (_stage == _BundleStage.requesting ||
                _stage == _BundleStage.polling) ...[
              _ProgressView(
                progress: _progress,
                message: _statusMessage,
              ),
            ],
            if (_stage == _BundleStage.downloading) ...[
              _DownloadingView(
                filename: _ready?.filename ?? '...',
                message: _statusMessage,
              ),
            ],
            if (_stage == _BundleStage.ready && _ready != null) ...[
              _ReadyView(
                ready: _ready!,
                downloadedBytes: _downloadedBytes,
                seedResult: _seedResult,
                onReset: _reset,
              ),
            ],
            if (_stage == _BundleStage.error) ...[
              _ErrorView(
                error: _error ?? 'Unknown error',
                onReset: _reset,
              ),
            ],
          ],
        ),
      ),
    );

    final collectedFeaturesCard = CollectedFeaturesSection(
      projectId: project.id,
      onResumeDraft: (feature) async {
        final database = ref.read(appDatabaseProvider);
        if (database == null) return;
        final formRow = await (database.select(database.forms)
              ..where((f) => f.id.equals(feature.formId)))
            .getSingleOrNull();
        if (formRow == null || !mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FormDetailScreen(
              form: formRow,
              existingClientId: feature.clientId,
            ),
          ),
        );
      },
    );

    final projectContentsCard = ProjectContentsSection(projectId: project.id);

    final debugSyncCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '🧪 DEBUG: Run sync',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _runSync,
              icon: const Icon(Icons.sync),
              label: const Text('Run sync now'),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: AdaptiveTwoColumn(
            left: [
              projectHeaderCard,
              const SizedBox(height: 16),
              bundleDownloadCard,
              const SizedBox(height: 16),
              debugSyncCard,
            ],
            right: [
              collectedFeaturesCard,
              const SizedBox(height: 16),
              projectContentsCard,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-views ────────────────────────────────────────────

class _ProgressView extends StatelessWidget {
  final BundleProgress? progress;
  final String? message;
  const _ProgressView({required this.progress, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress?.percent ?? 0;
    final step = message ?? progress?.step ?? 'Preparing…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(step, style: theme.textTheme.bodyMedium)),
            if (progress?.percent != null)
              Text('$percent%', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: percent > 0 ? percent / 100 : null),
      ],
    );
  }
}

class _DownloadingView extends StatelessWidget {
  final String filename;
  final String? message;
  const _DownloadingView({required this.filename, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message ?? 'Downloading…',
                      style: theme.textTheme.bodyMedium),
                  Text(
                    filename,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  final BundleReady ready;
  final int downloadedBytes;
  final SeedResult? seedResult;
  final VoidCallback onReset;

  const _ReadyView({
    required this.ready,
    required this.downloadedBytes,
    required this.seedResult,
    required this.onReset,
  });

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSeeded = seedResult != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Text(
              isSeeded ? 'Ready to use offline' : 'Bundle downloaded',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          ready.filename,
          style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        ),
        Text(
          _formatBytes(downloadedBytes > 0 ? downloadedBytes : ready.sizeBytes),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (seedResult != null)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                avatar: const Icon(Icons.description, size: 16),
                label: Text('${seedResult!.forms} forms'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.layers, size: 16),
                label: Text('${seedResult!.layers} layers'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.list, size: 16),
                label: Text('${seedResult!.choiceLists} choice lists'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.assignment, size: 16),
                label: Text('${seedResult!.assignments} assignments'),
                visualDensity: VisualDensity.compact,
              ),
              if (seedResult!.referenceFeatures > 0)
                Chip(
                  avatar: const Icon(Icons.location_on, size: 16),
                  label: Text('${seedResult!.referenceFeatures} features'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        if (seedResult?.warnings.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          ...seedResult!.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSeeded
                    ? 'All bundle contents extracted to local database.'
                    : 'Saved to local storage (DB not available).',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isSeeded
                    ? 'This project can now be used fully offline.'
                    : 'Run on Android for full offline persistence.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Request fresh bundle'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onReset;
  const _ErrorView({required this.error, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Text(
              'Bundle failed',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(error, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}
