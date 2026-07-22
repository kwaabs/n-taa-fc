import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class NumberFieldWidget extends StatefulWidget {
  final FormFieldSpec field;
  const NumberFieldWidget({super.key, required this.field});

  @override
  State<NumberFieldWidget> createState() => _NumberFieldWidgetState();
}

class _NumberFieldWidgetState extends State<NumberFieldWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _initialized = false;

  bool get _isInteger => widget.field.type == FieldType.integer;

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

  void _handleChange(String v, FormController ctrl) {
    if (v.isEmpty) {
      ctrl.setValue(widget.field.id, null);
      return;
    }
    if (_isInteger) {
      final n = int.tryParse(v);
      ctrl.setValue(widget.field.id, n);
    } else {
      final n = num.tryParse(v);
      ctrl.setValue(widget.field.id, n);
    }
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
        keyboardType: TextInputType.numberWithOptions(
          decimal: !_isInteger,
          signed: true,
        ),
        inputFormatters: _isInteger
            ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))]
            : [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
        onChanged: (v) => _handleChange(v, ctrl),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}