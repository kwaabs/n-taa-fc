import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart' as db;
import '../../core/forms/field_widgets/field_widget.dart';
import '../../core/forms/form_controller.dart';
import '../../core/forms/form_progress_indicator.dart';
import '../../core/forms/form_schema.dart';
import '../../core/forms/form_schema_provider.dart';
import '../../core/forms/field_widgets/photo_widget.dart';
import '../../core/layout/responsive_form_fields.dart';
import '../../core/layout/adaptive_two_column.dart';
import '../../core/forms/form_validation_summary.dart';
import '../collection/feature_repository.dart';
import '../collection/feature_save_buttons.dart';

class FormDetailScreen extends ConsumerWidget {
  final db.Form form;
  final String? existingClientId;
  final Map<String, dynamic>? initialGeometry;
  final String? initialLayerId;

  // ── D0.3: when editing a reference feature, these are populated so the
  // save flow can record source linkage + original snapshots.
  final Map<String, dynamic>? initialAttributes;
  final String? referenceSourceRef;
  final String? referenceDataSourceId;
  final Map<String, dynamic>? referenceOriginalAttributes;
  final Map<String, dynamic>? referenceOriginalGeometry;

  const FormDetailScreen({
    super.key,
    required this.form,
    this.existingClientId,
    this.initialGeometry,
    this.initialLayerId,
    this.initialAttributes, // 👈 NEW
    this.referenceSourceRef, // 👈 NEW
    this.referenceDataSourceId, // 👈 NEW
    this.referenceOriginalAttributes, // 👈 NEW
    this.referenceOriginalGeometry, // 👈 NEW
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schemaAsync = ref.watch(formSchemaProvider(form.id));

    return Scaffold(
      appBar: AppBar(title: Text(form.name)),
      body: schemaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 8),
                Text(
                  'Could not load form',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (schema) {
          if (schema == null || schema.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.help_outline,
                        size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      schema == null ? 'Form not found' : 'Form has no fields',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return _FormPreview(
            form: form,
            schema: schema,
            existingClientId: existingClientId,
            initialGeometry: initialGeometry,
            initialLayerId: initialLayerId,
            // 👇 D0.3 forwarding
            initialAttributes: initialAttributes,
            referenceSourceRef: referenceSourceRef,
            referenceDataSourceId: referenceDataSourceId,
            referenceOriginalAttributes: referenceOriginalAttributes,
            referenceOriginalGeometry: referenceOriginalGeometry,
          );
        },
      ),
    );
  }
}

class _FormPreview extends ConsumerStatefulWidget {
  final db.Form form;
  final FormSchema schema;
  final String? existingClientId;

  final Map<String, dynamic>? initialGeometry;
  final String? initialLayerId;

  // ── D0.3: reference-edit linkage ──
  final Map<String, dynamic>? initialAttributes;
  final String? referenceSourceRef;
  final String? referenceDataSourceId;
  final Map<String, dynamic>? referenceOriginalAttributes;
  final Map<String, dynamic>? referenceOriginalGeometry;

  const _FormPreview({
    required this.form,
    required this.schema,
    this.existingClientId,
    this.initialGeometry,
    this.initialLayerId,
    this.initialAttributes,
    this.referenceSourceRef,
    this.referenceDataSourceId,
    this.referenceOriginalAttributes,
    this.referenceOriginalGeometry,
  });

  @override
  ConsumerState<_FormPreview> createState() => _FormPreviewState();
}

class _FormPreviewState extends ConsumerState<_FormPreview> {
  FormController? _ctrl;
  bool _loadingInitial = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.existingClientId != null) {
      _loadingInitial = true;
      _loadDraftAndInit();
    } else {
      _ctrl = FormController(
        schema: widget.schema,
        initialResponses: widget.initialAttributes, // 👈 NEW
      );
    }
  }

  Future<void> _loadDraftAndInit() async {
    final repo = ref.read(collectedFeatureRepoProvider);
    Map<String, dynamic>? initialResponses;
    if (repo != null && widget.existingClientId != null) {
      initialResponses = await repo.loadResponses(widget.existingClientId!);
    }
    if (!mounted) return;
    setState(() {
      _ctrl = FormController(
        schema: widget.schema,
        initialResponses: initialResponses,
      );
      _loadingInitial = false;
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Confirm before discarding unsaved changes.
  Future<bool> _confirmDiscard() async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.touched) return true;

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  /// Scroll to the first error field after validation fails.
  void _scrollToFirstError() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final firstErrId = ctrl.firstErrorFieldId;
    if (firstErrId == null) return;
    final key = ctrl.keyFor(firstErrId);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
  }

  // ── D6.1: Edit-location banner for reference-feature edits ──

  Widget _editLocationBanner(BuildContext context) {
    final coords = _formatPointCoords(widget.initialGeometry);

    return Material(
      color: Colors.blue.shade50,
      child: InkWell(
        onTap: () {
          // ── D6.2: return a special payload so the map screen can enter edit mode ──
          Navigator.of(context).pop(<String, dynamic>{
            '__edit_geometry__': true,
            'source_ref': widget.referenceSourceRef,
            'original_geometry': widget.initialGeometry,
            'existing_client_id': widget.existingClientId,
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.edit_location_alt_outlined,
                  size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit location',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    if (coords != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          coords,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: Colors.blue.shade400),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatPointCoords(Map<String, dynamic>? geom) {
    if (geom == null) return null;
    final coords = geom['coordinates'];
    if (coords is List && coords.length >= 2) {
      final lon = coords[0];
      final lat = coords[1];
      if (lon is num && lat is num) {
        return '${lon.toStringAsFixed(6)}, ${lat.toStringAsFixed(6)} · ${geom['type'] ?? 'geom'}';
      }
    }
    return geom['type']?.toString();
  }

  bool _isFullWidthField(FormFieldSpec field) {
    // Multi-line text → full width
    if (field.type == FieldType.text && field.appearance == 'multiline') {
      return true;
    }
    // These types always want full row
    const alwaysFullWidth = {
      FieldType.selectMultiple,
      FieldType.photo,
      FieldType.geoPoint,
      FieldType.note,
      FieldType.group,
    };
    return alwaysFullWidth.contains(field.type);
  }

  bool _isFullWidthAtIndex(List<FormFieldSpec> fields, int i) {
    // If the field itself is full-width, done.
    if (_isFullWidthField(fields[i])) return true;

    // Short field — check if it would be lonely on its row.
    // It's lonely if the previous field was full-width (or this is index 0)
    // AND the next field is full-width (or this is the last field).
    final prevIsFull = i == 0 || _isFullWidthField(fields[i - 1]);
    final nextIsFull =
        i == fields.length - 1 || _isFullWidthField(fields[i + 1]);

    // If prev row ended on a full-width and next is also full-width,
    // this short field is stuck alone → let it stretch.
    return prevIsFull && nextIsFull;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial || _ctrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final ctrl = _ctrl!;

    return PopScope(
      canPop: !ctrl.touched,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ProjectIdScope(
        projectId: widget.form.projectId,
        child: FormControllerScope(
          controller: ctrl,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // D6.1: Edit location banner (spans full width above the two-column split)
                      if (widget.referenceSourceRef != null) ...[
                        _editLocationBanner(context),
                        const SizedBox(height: 12),
                      ],

                      // ── Two-pane layout: form on left, context on right (tablet landscape only) ──
                      AdaptiveTwoColumn(
                        leftFlex: 3,
                        rightFlex: 2,
                        left: [
                          // 👇 NEW — validation summary banner
                          FormValidationSummary(
                            controller: ctrl,
                            onTapFirstError: _scrollToFirstError,
                          ),

                          // Form fields card
                          AnimatedBuilder(
                            animation: ctrl,
                            builder: (context, _) {
                              final visibleFields = [
                                for (final f in widget.schema.fields)
                                  if (ctrl.isFieldVisible(f)) f,
                              ];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final field in visibleFields)
                                        FieldWidget(field: field),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        right: [
                          // Header + progress card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.description_outlined,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.form.name,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (widget.existingClientId != null)
                                        Chip(
                                          label: const Text('Draft'),
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: theme
                                              .colorScheme.secondaryContainer,
                                        ),
                                    ],
                                  ),
                                  AnimatedBuilder(
                                    animation: ctrl,
                                    builder: (context, _) =>
                                        FormProgressIndicator(
                                      schema: widget.schema,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Room for future context widgets (location preview, photo thumbs, etc.)
                        ],
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FeatureSaveButtons(
                    projectId: widget.form.projectId,
                    form: widget.form,
                    existingClientId: widget.existingClientId,
                    onValidationFailed: _scrollToFirstError,
                    initialGeometry: widget.initialGeometry,
                    initialLayerId: widget.initialLayerId,
                    // 👇 D0.3
                    referenceSourceRef: widget.referenceSourceRef,
                    referenceDataSourceId: widget.referenceDataSourceId,
                    referenceOriginalAttributes:
                        widget.referenceOriginalAttributes,
                    referenceOriginalGeometry: widget.referenceOriginalGeometry,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
