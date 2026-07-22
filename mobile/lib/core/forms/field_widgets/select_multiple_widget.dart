import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class SelectMultipleWidget extends StatelessWidget {
  final FormFieldSpec field;
  const SelectMultipleWidget({super.key, required this.field});

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final raw = ctrl.getValue(field.id);
    final selected = <String>{};
    if (raw is List) {
      selected.addAll(raw.map((e) => e.toString()));
    }
    final error = ctrl.getError(field.id);

    return FieldLabel(
      field: field,
      error: error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: field.choices.map((choice) {
          return CheckboxListTile(
            value: selected.contains(choice.value),
            onChanged: (checked) {
              final next = {...selected};
              if (checked == true) {
                next.add(choice.value);
              } else {
                next.remove(choice.value);
              }
              ctrl.setValue(field.id, next.toList());
            },
            title: Text(choice.label.value),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          );
        }).toList(),
      ),
    );
  }
}