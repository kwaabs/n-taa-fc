import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class TextFieldWidget extends StatefulWidget {
  final FormFieldSpec field;
  const TextFieldWidget({super.key, required this.field});

  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
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

    final isMultiline = widget.field.appearance?.toLowerCase() == 'multiline';

    return FieldLabel(
      field: widget.field,
      error: error,
      child: TextField(
        controller: _controller,
        onChanged: (v) => ctrl.setValue(widget.field.id, v),
        keyboardType:
            isMultiline ? TextInputType.multiline : TextInputType.text,
        minLines: isMultiline ? 3 : 1,
        maxLines: isMultiline ? 8 : 1,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          errorText: error,
        ),
      ),
    );
  }
}