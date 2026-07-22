import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/gnss/active_location_provider.dart';

class GnssDiagnosticScreen extends ConsumerStatefulWidget {
  const GnssDiagnosticScreen({super.key});

  @override
  ConsumerState<GnssDiagnosticScreen> createState() =>
      _GnssDiagnosticScreenState();
}

class _GnssDiagnosticScreenState extends ConsumerState<GnssDiagnosticScreen> {
  StreamSubscription<Position>? _sub;
  Position? _last;
  int _count = 0;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final provider = ref.read(activeLocationProvider);
    try {
      await provider.start();
      _sub = provider.positionStream.listen(
        (pos) {
          setState(() {
            _last = pos;
            _count++;
            _errorMessage = '';
          });
        },
        onError: (e) {
          setState(() => _errorMessage = e.toString());
        },
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.read(activeLocationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GNSS diagnostic')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: ${provider.name}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Positions received: $_count'),
            const Divider(),
            if (_last != null) ...[
              _kv('Latitude', _last!.latitude.toStringAsFixed(7)),
              _kv('Longitude', _last!.longitude.toStringAsFixed(7)),
              _kv('Accuracy', '${_last!.accuracy.toStringAsFixed(2)} m'),
              _kv('Altitude', '${_last!.altitude.toStringAsFixed(2)} m'),
              _kv('Speed', '${_last!.speed.toStringAsFixed(2)} m/s'),
              _kv('Timestamp', _last!.timestamp.toString()),
            ] else
              const Text('Waiting for first position…'),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage,
                    style: TextStyle(color: Colors.red.shade900)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(k, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(v, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}