import 'package:flutter/material.dart';

import '../form_controller.dart';
import '../form_schema.dart';
import 'field_label.dart';

class DateFieldWidget extends StatelessWidget {
  final FormFieldSpec field;
  const DateFieldWidget({super.key, required this.field});

  bool get _isDate => field.type == FieldType.date;
  bool get _isTime => field.type == FieldType.time;
  bool get _isDateTime => field.type == FieldType.dateTime;

  Future<void> _pick(BuildContext context, FormController ctrl) async {
    DateTime? current;
    final raw = ctrl.getValue(field.id);
    if (raw is String) {
      current = DateTime.tryParse(raw);
    }
    final now = DateTime.now();

    if (_isTime) {
      final picked = await showTimePicker(
        context: context,
        initialTime: current != null
            ? TimeOfDay(hour: current.hour, minute: current.minute)
            : TimeOfDay.fromDateTime(now),
      );
      if (picked == null) return;
      // Store as ISO string with today's date
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      ctrl.setValue(field.id, dt.toIso8601String());
      return;
    }

    final dateInit = current ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: dateInit,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    if (_isDate) {
      // Date only — strip time
      final d = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      ctrl.setValue(field.id, d.toIso8601String().substring(0, 10));
      return;
    }

    if (_isDateTime) {
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: current != null
            ? TimeOfDay(hour: current.hour, minute: current.minute)
            : TimeOfDay.fromDateTime(now),
      );
      if (pickedTime == null) return;
      final dt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      ctrl.setValue(field.id, dt.toIso8601String());
    }
  }

  String _display(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (_isTime) {
      final dt = DateTime.tryParse(s);
      if (dt == null) return s;
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (_isDate) return s.length >= 10 ? s.substring(0, 10) : s;
    if (_isDateTime) {
      final dt = DateTime.tryParse(s);
      if (dt == null) return s;
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = FormControllerScope.of(context);
    final raw = ctrl.getValue(field.id);
    final error = ctrl.getError(field.id);

    final icon = _isTime
        ? Icons.access_time
        : _isDateTime
            ? Icons.event_note
            : Icons.calendar_today;

    return FieldLabel(
      field: field,
      error: error,
      child: InkWell(
        onTap: () => _pick(context, ctrl),
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          child: Row(
            children: [
              Icon(icon, size: 20,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _display(raw).isEmpty ? 'Tap to select' : _display(raw),
                  style: TextStyle(
                    color: raw == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
              ),
              if (raw != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => ctrl.setValue(field.id, null),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}