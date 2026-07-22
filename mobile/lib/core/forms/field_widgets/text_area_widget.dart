import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class TextAreaWidget extends StatefulWidget {
  final FormFieldSpec field;
  const TextAreaWidget({super.key, required this.field});

  @override
  State<TextAreaWidget> createState() => _TextAreaWidgetState();
}

class _TextAreaWidgetState extends State<TextAreaWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final initial =
          FormControllerScope.of(context).getValue(widget.field.id);
      _controller.text = initial?.toString() ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final error = ctrl.getError(widget.field.id);

    return FieldLabel(
      field: widget.field,
      error: error,
      child: TextField(
        controller: _controller,
        onChanged: (v) => ctrl.setValue(widget.field.id, v),
        maxLines: 4,
        minLines: 3,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}