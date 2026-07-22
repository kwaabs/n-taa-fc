import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_state.dart';
import 'search_repository.dart';

/// A single row in the query builder — one condition.
///
/// Layout:
///   [attribute ▾]  [operator ▾]  [value...]  [ 🗑 ]
///
/// For BETWEEN operator, shows two value inputs separated by "and".
/// For IS EMPTY / IS NOT EMPTY, hides the value input.
class ConditionRow extends ConsumerWidget {
  final String projectId;
  final String layerId;
  final QueryCondition condition;
  final ValueChanged<QueryCondition> onChanged;
  final VoidCallback onRemove;

  const ConditionRow({
    super.key,
    required this.projectId,
    required this.layerId,
    required this.condition,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attrsAsync = ref.watch(searchAttributesProvider(
      (projectId: projectId, layerId: layerId),
    ));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: attribute + delete button
          Row(
            children: [
              Expanded(
                child: attrsAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => Text(
                    'Load failed',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  data: (attributes) => _attributePicker(context, attributes),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove condition',
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: operator + value(s)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: _operatorPicker(context),
              ),
              const SizedBox(width: 8),
              if (condition.operator.needsValue)
                Expanded(child: _valueInputs(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attributePicker(BuildContext context, List<String> attributes) {
    final theme = Theme.of(context);

    if (attributes.isEmpty) {
      return Text(
        'No attributes discovered yet',
        style: theme.textTheme.bodySmall,
      );
    }

    return DropdownButtonFormField<String>(
      value: condition.attribute,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Attribute',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      hint: const Text('Pick attribute…'),
      items: attributes.map((attr) {
        return DropdownMenuItem(
          value: attr,
          child: Text(
            attr,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (v) => onChanged(condition.copyWith(attribute: v)),
    );
  }

  Widget _operatorPicker(BuildContext context) {
    return DropdownButtonFormField<QueryOperator>(
      value: condition.operator,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      items: QueryOperator.values.map((op) {
        return DropdownMenuItem(
          value: op,
          child: Text(
            op.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) {
          // Clear value2 if changing away from BETWEEN
          if (!v.needsTwoValues) {
            onChanged(condition.copyWith(operator: v, value2: ''));
          } else {
            onChanged(condition.copyWith(operator: v));
          }
        }
      },
    );
  }

  Widget _valueInputs(BuildContext context) {
    if (condition.operator.needsTwoValues) {
      return Row(
        children: [
          Expanded(
            child: _valueField(
              context,
              value: condition.value,
              hint: 'from',
              onChanged: (v) => onChanged(condition.copyWith(value: v)),
            ),
          ),
          const SizedBox(width: 4),
          Text('and', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 4),
          Expanded(
            child: _valueField(
              context,
              value: condition.value2,
              hint: 'to',
              onChanged: (v) => onChanged(condition.copyWith(value2: v)),
            ),
          ),
        ],
      );
    }

    return _valueField(
      context,
      value: condition.value,
      hint: 'Value',
      onChanged: (v) => onChanged(condition.copyWith(value: v)),
    );
  }

  Widget _valueField(
    BuildContext context, {
    required String value,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      key: ValueKey('val-${condition.id}-$hint'),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
      onChanged: onChanged,
    );
  }
}