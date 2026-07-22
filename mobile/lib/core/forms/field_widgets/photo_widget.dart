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
import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class PhotoWidget extends ConsumerStatefulWidget {
  final FormFieldSpec field;
  const PhotoWidget({super.key, required this.field});

  @override
  ConsumerState<PhotoWidget> createState() => _PhotoWidgetState();
}

class _PhotoWidgetState extends ConsumerState<PhotoWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _picking = false;
  db.FeatureAttachment? _attachment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCurrentAttachment();
  }

  /// If the form response already holds an attachment marker, load the row.
  Future<void> _loadCurrentAttachment() async {
    final ctrl = FormControllerScope.maybeOf(context);
    if (ctrl == null) return;

    final value = ctrl.getValue(widget.field.id);
    if (value is! String) return;
    if (!value.startsWith('att:')) return;
    final clientId = value.substring(4);

    final database = ref.read(appDatabaseProvider);
    if (database == null) return;

    final attachment = await database.getAttachment(clientId);
    if (mounted && attachment != null) {
      setState(() => _attachment = attachment);
    }
  }

  String _generateClientId() {
    final r = Random.secure();
    String hex(int n) =>
        List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-'
        '${(8 + r.nextInt(4)).toRadixString(16)}${hex(3)}-'
        '${hex(12)}';
  }

  Future<void> _pickFrom(ImageSource source, FormController ctrl) async {
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy from cache to permanent storage so OS can't delete it on us
      final permanentPath = await _copyToPermanentStorage(picked.path);
      final fileSize = await File(permanentPath).length();

      final database = ref.read(appDatabaseProvider);
      if (database == null) {
        // No DB → fall back to path-only behaviour (web target)
        ctrl.setValue(widget.field.id, permanentPath);
        return;
      }

      // Determine feature client_id — set when the form is first edited.
      // For new features it doesn't exist yet, so we store NULL and the
      // sync service will resolve it later.
      String? featureClientId;

      // Decide on a new attachment client_id, OR reuse existing if replacing
      String clientId;
      if (_attachment != null) {
        // Replacing existing → reuse client_id, delete old file
        clientId = _attachment!.clientId;
        await _safeDelete(_attachment!.localPath);
      } else {
        clientId = _generateClientId();
      }

      // Upsert the row
      await database.upsertAttachment(
        db.FeatureAttachmentsCompanion(
          clientId: Value(clientId),
          featureClientId: Value(featureClientId ?? ''),
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
      if (!mounted) return;
      setState(() => _attachment = saved);

      // Store reference in form responses
      ctrl.setValue(widget.field.id, 'att:$clientId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo capture failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Reads the project_id from inherited context, or empty string.
  /// We can't reliably know this from FormController alone — set by parent.
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
    } catch (_) {/* best-effort */}
  }

  Future<void> _clearAttachment(FormController ctrl) async {
    final database = ref.read(appDatabaseProvider);
    if (_attachment != null && database != null) {
      // Best-effort: delete file + row
      await _safeDelete(_attachment!.localPath);
      await database.deleteAttachment(_attachment!.clientId);
    }
    if (mounted) setState(() => _attachment = null);
    ctrl.setValue(widget.field.id, null);
  }

  void _chooseSource(FormController ctrl) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFrom(ImageSource.camera, ctrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFrom(ImageSource.gallery, ctrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final error = ctrl.getError(widget.field.id);
    final theme = Theme.of(context);

    final hasAttachment = _attachment != null;
    final fileExists =
        hasAttachment && File(_attachment!.localPath).existsSync();

    return FieldLabel(
      field: widget.field,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasAttachment && fileExists) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_attachment!.localPath),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _brokenThumbnail(theme),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _AttachmentStatusBadge(status: _attachment!.status),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Replace',
                  onPressed: _picking ? null : () => _chooseSource(ctrl),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove',
                  onPressed: _picking ? null : () => _clearAttachment(ctrl),
                ),
              ],
            ),
          ] else if (hasAttachment && !fileExists) ...[
            _brokenThumbnail(theme),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Photo file is missing. Retake to fix.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _clearAttachment(ctrl),
                  child: const Text('Remove'),
                ),
                FilledButton.tonal(
                  onPressed: () => _chooseSource(ctrl),
                  child: const Text('Retake'),
                ),
              ],
            ),
          ] else
            FilledButton.icon(
              onPressed: _picking ? null : () => _chooseSource(ctrl),
              icon: _picking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              label: const Text('Capture photo'),
            ),
        ],
      ),
    );
  }

  Widget _brokenThumbnail(ThemeData theme) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(Icons.broken_image,
            size: 48, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// ── Status badge ─────────────────────────────────────

class _AttachmentStatusBadge extends StatelessWidget {
  final String status;
  const _AttachmentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (status) {
      'pending' => (
          Icons.schedule,
          'Pending upload',
          theme.colorScheme.secondary
        ),
      'uploading' => (
          Icons.cloud_upload_outlined,
          'Uploading...',
          theme.colorScheme.secondary
        ),
      'uploaded' => (
          Icons.cloud_done_outlined,
          'Uploaded',
          theme.colorScheme.tertiary
        ),
      'confirmed' => (
          Icons.check_circle_outline,
          'Synced',
          theme.colorScheme.tertiary
        ),
      'failed' => (
          Icons.error_outline,
          'Upload failed',
          theme.colorScheme.error
        ),
      _ => (Icons.help_outline, status, theme.colorScheme.onSurfaceVariant),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

// ── Project ID Scope ─────────────────────────────────
//
// Lets the photo widget know what project it belongs to when writing
// the attachment row, without threading it through every field constructor.

class _ProjectIdScope extends InheritedWidget {
  final String projectId;

  const _ProjectIdScope({
    required this.projectId,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ProjectIdScope oldWidget) =>
      oldWidget.projectId != projectId;
}

/// Public wrapper for the inherited widget — wrap the form preview in this.
/// Public wrapper for the inherited widget — wrap the form preview in this.
class ProjectIdScope extends StatelessWidget {
  final String projectId;
  final Widget child;

  const ProjectIdScope({
    super.key,
    required this.projectId,
    required this.child,
  });

  /// Read the current projectId from context, or null if none.
  /// Use this from field widgets that need the projectId (e.g. to store
  /// attachments against the right project).
  static String? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ProjectIdScope>();
    return scope?.projectId;
  }

  @override
  Widget build(BuildContext context) {
    return _ProjectIdScope(projectId: projectId, child: child);
  }
}
