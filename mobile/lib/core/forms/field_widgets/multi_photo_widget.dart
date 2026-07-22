import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/app_database.dart' as db;
import '../../db/db_provider.dart';
import '../../layout/responsive_layout.dart';
import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';
import 'photo_widget.dart' show ProjectIdScope;


/// Multi-photo widget — captures a list of photos for a single field.
///
/// Used for all [FieldType.photo] fields. Stores form value as
/// `att:<id1>,<id2>,…` — same prefix as legacy single-photo mode.
///
/// Configurable via schema:
///   - constraints.max_length / validation.max_length → max photos (default 10)
///   - constraints.min_length / validation.min_length → min photos required
class MultiPhotoWidget extends ConsumerStatefulWidget {
  final FormFieldSpec field;
  const MultiPhotoWidget({super.key, required this.field});

  @override
  ConsumerState<MultiPhotoWidget> createState() => _MultiPhotoWidgetState();
}

class _MultiPhotoWidgetState extends ConsumerState<MultiPhotoWidget> {
  final ImagePicker _picker = ImagePicker();
  final List<db.FeatureAttachment> _attachments = [];
  bool _picking = false;

  int get _maxPhotos {
    final max = widget.field.validation.maxLength ?? 10;
    if (max < 1) return 1;
    if (max > 10) return 10;
    return max;
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final ctrl = FormControllerScope.of(context);
    final raw = ctrl.getValue(widget.field.id);
    if (raw is! String || !raw.startsWith('att:')) return;

    final ids = raw
        .substring(4)
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    final database = ref.read(appDatabaseProvider);
    if (database == null) return;

    final loaded = <db.FeatureAttachment>[];
    for (final id in ids) {
      final a = await database.getAttachment(id);
      if (a != null) loaded.add(a);
    }
    if (mounted) {
      setState(() {
        _attachments
          ..clear()
          ..addAll(loaded);
      });
    }
  }

  Future<void> _pickFrom(ImageSource source, FormController ctrl) async {
    if (_attachments.length >= _maxPhotos) return;

    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      final permanentPath = await _copyToPermanentStorage(picked.path);
      final fileSize = await File(permanentPath).length();

      final database = ref.read(appDatabaseProvider);
      if (database == null) return;

      final clientId = _generateClientId();

      await database.upsertAttachment(
        db.FeatureAttachmentsCompanion(
          clientId: Value(clientId),
          featureClientId: const Value(''),
          projectId: Value(_projectIdFromContext()),
          fieldId: Value(widget.field.id),
          kind: const Value('photo'),
          localPath: Value(permanentPath),
          mimeType: Value(_mimeFromPath(permanentPath)),
          sizeBytes: Value(fileSize),
          status: const Value('pending'),
          serverId: const Value.absent(),
          uploadAttempts: const Value(0),
          lastError: const Value(null),
        ),
      );

      final saved = await database.getAttachment(clientId);
      if (!mounted || saved == null) return;

      setState(() => _attachments.add(saved));
      _writeFormValue(ctrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo capture failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _deleteAt(int index, FormController ctrl) async {
    if (index < 0 || index >= _attachments.length) return;
    final target = _attachments[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text('The photo will be deleted from this submission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final database = ref.read(appDatabaseProvider);
    if (database != null) {
      await _safeDelete(target.localPath);
      await database.deleteAttachment(target.clientId);
    }
    if (!mounted) return;
    setState(() => _attachments.removeAt(index));
    _writeFormValue(ctrl);
  }

  void _writeFormValue(FormController ctrl) {
    if (_attachments.isEmpty) {
      ctrl.setValue(widget.field.id, null);
    } else {
      final ids = _attachments.map((a) => a.clientId).join(',');
      ctrl.setValue(widget.field.id, 'att:$ids');
    }
  }

  void _viewFullscreen(int index, FormController ctrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenPhotoViewer(
          attachments: _attachments,
          initialIndex: index,
          onDelete: (i) async {
            Navigator.of(context).pop();
            await _deleteAt(i, ctrl);
          },
        ),
      ),
    );
  }

  void _chooseSource(FormController ctrl) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFrom(ImageSource.camera, ctrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFrom(ImageSource.gallery, ctrl);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers duplicated from PhotoWidget ──

  String _generateClientId() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-'
        '${hex(12)}';
  }

  String _projectIdFromContext() {
    return ProjectIdScope.maybeOf(context) ?? '';
  }

  Future<String> _copyToPermanentStorage(String sourcePath) async {
    final docs = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(docs.path, 'attachments'));
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
    final ext = p.extension(sourcePath);
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${_randomShort()}$ext';
    final newPath = p.join(attachmentsDir.path, filename);
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  String _randomShort() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  String _mimeFromPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final error = ctrl.getError(widget.field.id);
    final theme = Theme.of(context);
    final layout = LayoutOf(context);

    final crossAxisCount = layout.isTabletLandscape || layout.isWideTablet
        ? 6
        : (layout.isTabletPortrait ? 5 : 4);

    final canAddMore = _attachments.length < _maxPhotos;
    final tileCount = _attachments.length + (canAddMore ? 1 : 0);

    return FieldLabel(
      field: widget.field,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: tileCount,
            itemBuilder: (context, index) {
              if (index >= _attachments.length) {
                return _AddTile(
                  onTap: _picking ? null : () => _chooseSource(ctrl),
                  busy: _picking,
                );
              }
              final att = _attachments[index];
              return _PhotoTile(
                attachment: att,
                index: index + 1,
                onTap: () => _viewFullscreen(index, ctrl),
                onLongPress: () => _deleteAt(index, ctrl),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            '${_attachments.length} of $_maxPhotos photos',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Photo tile ────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  final db.FeatureAttachment attachment;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.attachment,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(attachment.localPath);
    final exists = file.existsSync();

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (exists)
              Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Center(
                child: Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.error,
                ),
              ),
            // Index badge
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Status dot
            Positioned(
              top: 4,
              right: 4,
              child: _StatusDot(status: attachment.status),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      'pending' => Colors.orange,
      'uploading' => Colors.blue,
      'uploaded' => Colors.green,
      'confirmed' => Colors.green,
      'failed' => theme.colorScheme.error,
      _ => Colors.grey,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

// ── Add tile ──────────────────────────────────────────────

class _AddTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;
  const _AddTile({required this.onTap, required this.busy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
              style: BorderStyle.solid,
              width: 1.2,
            ),
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.add_a_photo_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Fullscreen viewer ─────────────────────────────────────

class _FullscreenPhotoViewer extends StatefulWidget {
  final List<db.FeatureAttachment> attachments;
  final int initialIndex;
  final void Function(int index) onDelete;

  const _FullscreenPhotoViewer({
    required this.attachments,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_FullscreenPhotoViewer> createState() =>
      _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Photo ${_currentIndex + 1} of ${widget.attachments.length}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => widget.onDelete(_currentIndex),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.attachments.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final att = widget.attachments[i];
          final file = File(att.localPath);
          if (!file.existsSync()) {
            return const Center(
              child: Icon(Icons.broken_image, color: Colors.white70, size: 96),
            );
          }
          return InteractiveViewer(
            child: Center(
              child: Image.file(file),
            ),
          );
        },
      ),
    );
  }
}