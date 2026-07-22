import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class SelectOneWidget extends StatelessWidget {
  final FormFieldSpec field;
  const SelectOneWidget({super.key, required this.field});

  static const int _radioThreshold = 5;

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final value = ctrl.getValue(field.id)?.toString();
    final error = ctrl.getError(field.id);

    final appearance = field.appearance?.toLowerCase();

    Widget inner;
    if (appearance == 'dropdown') {
      // Admin explicitly picked dropdown
      inner = _Dropdown(
        choices: field.choices,
        value: value,
        onChanged: (v) => ctrl.setValue(field.id, v),
      );
    } else if (appearance == 'radio' || appearance == 'likert') {
      // Admin explicitly picked radio (likert renders as radio for v1)
      inner = _RadioGroup(
        choices: field.choices,
        value: value,
        onChanged: (v) => ctrl.setValue(field.id, v),
      );
    } else {
      // No appearance hint — fall back to the threshold rule for backward compat
      if (field.choices.length <= _radioThreshold) {
        inner = _RadioGroup(
          choices: field.choices,
          value: value,
          onChanged: (v) => ctrl.setValue(field.id, v),
        );
      } else {
        inner = _Dropdown(
          choices: field.choices,
          value: value,
          onChanged: (v) => ctrl.setValue(field.id, v),
        );
      }
    }

    return FieldLabel(field: field, error: error, child: inner);
  }
}

class _RadioGroup extends StatelessWidget {
  final List<Choice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _RadioGroup({
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: choices.map((choice) {
        return RadioListTile<String>(
          value: choice.value,
          groupValue: value,
          onChanged: onChanged,
          title: Text(choice.label.value),
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final List<Choice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: choices.any((c) => c.value == value) ? value : null,
      isExpanded: true,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      items: choices
          .map((c) => DropdownMenuItem(
                value: c.value,
                child: Text(
                  c.label.value,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}
