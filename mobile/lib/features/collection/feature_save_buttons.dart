import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart' as db;
import '../../core/forms/form_controller.dart';
import 'feature_repository.dart';

class FeatureSaveButtons extends ConsumerStatefulWidget {
  final String projectId;
  final db.Form form;
  final String? existingClientId;
  final VoidCallback? onSaved;
  final VoidCallback? onValidationFailed;
  final Map<String, dynamic>? initialGeometry;
  final String? initialLayerId;

  // ── D0.3: reference-edit linkage ──
  final String? referenceSourceRef;
  final String? referenceDataSourceId;
  final Map<String, dynamic>? referenceOriginalAttributes;
  final Map<String, dynamic>? referenceOriginalGeometry;

  const FeatureSaveButtons({
    super.key,
    required this.projectId,
    required this.form,
    this.existingClientId,
    this.onSaved,
    this.onValidationFailed,
    this.initialGeometry,
    this.initialLayerId,
    this.referenceSourceRef,
    this.referenceDataSourceId,
    this.referenceOriginalAttributes,
    this.referenceOriginalGeometry,
  });

  @override
  ConsumerState<FeatureSaveButtons> createState() => _FeatureSaveButtonsState();
}

class _FeatureSaveButtonsState extends ConsumerState<FeatureSaveButtons> {
  bool _saving = false;

  Future<void> _saveDraft() async {
    final repo = ref.read(collectedFeatureRepoProvider);
    if (repo == null) return;

    final ctrl = FormControllerScope.of(context);
    setState(() => _saving = true);

    try {
      final geometry = _extractGeometry(ctrl.responses);

      await repo.saveDraft(
        projectId: widget.projectId,
        formId: widget.form.id,
        formVersion: widget.form.version,
        responses: ctrl.responses,
        clientId: widget.existingClientId,
        geometry: geometry,
        layerId: widget.initialLayerId,
      );

      if (!mounted) return;

      // Mark form clean so back button doesn't trigger "discard" dialog
      ctrl.markClean();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    debugPrint('[SUBMIT] starting');
    final repo = ref.read(collectedFeatureRepoProvider);
    if (repo == null) {
      debugPrint('[SUBMIT] repo is null — aborting');
      return;
    }

    final ctrl = FormControllerScope.of(context);

    debugPrint('[SUBMIT] running validation');
    final errors = ctrl.validateAll();
    debugPrint('[SUBMIT] validation found ${errors.length} errors');
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${errors.length} field${errors.length == 1 ? "" : "s"} need attention',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      widget.onValidationFailed?.call();
      return;
    }

    setState(() => _saving = true);
    debugPrint('[SUBMIT] _saving=true, responses=${ctrl.responses}');

    try {
      debugPrint('[SUBMIT] extracting geometry');
      final geometry = _extractGeometry(ctrl.responses);
      debugPrint('[SUBMIT] geometry=$geometry');

      debugPrint('[SUBMIT] calling repo.submit');
      final id = await repo.submit(
        projectId: widget.projectId,
        formId: widget.form.id,
        formVersion: widget.form.version,
        responses: ctrl.responses,
        clientId: widget.existingClientId,
        geometry: geometry,
        layerId: widget.initialLayerId,
        
  // 👇 D0.3 — pass reference linkage
  sourceRef: widget.referenceSourceRef,
  dataSourceId: widget.referenceDataSourceId,
  originalAttributes: widget.referenceOriginalAttributes,
  originalGeometry: widget.referenceOriginalGeometry,

      );
      debugPrint('[SUBMIT] submitted with id=$id');

      if (!mounted) return;

      // Mark form clean so PopScope allows the pop without confirmation
      ctrl.markClean();
      debugPrint('[SUBMIT] markClean called, touched=${ctrl.touched}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitted — pending sync'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onSaved?.call();

      // Defer the pop so PopScope can re-evaluate its canPop state
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      debugPrint(
          '[SUBMIT] popping screen, canPop=${Navigator.canPop(context)}');
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e, stack) {
      debugPrint('[SUBMIT] error: $e');
      debugPrint('[SUBMIT] stack: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      debugPrint('[SUBMIT] finally — _saving=false');
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? _extractGeometry(Map<String, dynamic> responses) {
    // If the form was opened from map capture, prefer that geometry.
    if (widget.initialGeometry != null) {
      return widget.initialGeometry;
    }

    // Otherwise, scan responses for any geopoint-style value
    for (final value in responses.values) {
      if (value is Map &&
          value['type'] is String &&
          value['coordinates'] is List) {
        return {
          'type': value['type'],
          'coordinates': value['coordinates'],
        };
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _saveDraft,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Draft'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}
