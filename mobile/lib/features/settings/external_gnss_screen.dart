import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gnss/bluetooth_transport.dart';
import '../../core/gnss/gnss_provider.dart';
import '../../core/settings/settings_provider.dart';

import 'gnss_diagnostic_screen.dart';

class ExternalGnssScreen extends ConsumerStatefulWidget {
  const ExternalGnssScreen({super.key});

  @override
  ConsumerState<ExternalGnssScreen> createState() =>
      _ExternalGnssScreenState();
}

class _ExternalGnssScreenState extends ConsumerState<ExternalGnssScreen> {
  final _found = <String, BtDevice>{}; // key: address, keeps uniques
  StreamSubscription<BtDevice>? _scanSub;
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingAddress;

  @override
  void dispose() {
    _scanSub?.cancel();
    ref.read(bluetoothTransportProvider).stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    final transport = ref.read(bluetoothTransportProvider);

    // Check availability + permissions first
    if (!await transport.isAvailable) {
      _snack('Bluetooth is not available on this device.');
      return;
    }
    if (!await transport.isEnabled) {
      final enabled = await transport.requestEnable();
      if (!enabled) {
        _snack('Please enable Bluetooth to scan for devices.');
        return;
      }
    }
    final granted = await transport.requestPermissions();
    if (!granted) {
      _snack('Bluetooth permission is required to scan.');
      return;
    }

    setState(() {
      _isScanning = true;
      _found.clear();
    });

    // Seed with paired devices so user sees them immediately
    final paired = await transport.pairedDevices();
    for (final d in paired) {
      _found[d.address] = d;
    }
    if (mounted) setState(() {});

    _scanSub = transport.scan().listen(
      (dev) {
        _found[dev.address] = dev;
        if (mounted) setState(() {});
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
      onError: (e) {
        _snack('Scan error: $e');
        if (mounted) setState(() => _isScanning = false);
      },
    );
  }

  Future<void> _stopScan() async {
    await ref.read(bluetoothTransportProvider).stopScan();
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connect(BtDevice device) async {
    final transport = ref.read(bluetoothTransportProvider);

    setState(() {
      _isConnecting = true;
      _connectingAddress = device.address;
    });

    try {
      await transport.connect(device);

      // Save to settings
      await ref.read(settingsProvider.notifier).setLocationSource(
            source: 'external',
            deviceAddress: device.address,
            deviceName: device.name,
          );

      if (mounted) {
        _snack('Connected to ${device.name}');
        Navigator.of(context).pop();
      }
    } catch (e) {
      _snack('Failed to connect: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingAddress = null;
        });
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final currentAddress = settings?.externalDeviceAddress;
    final currentName = settings?.externalDeviceName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('External GNSS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (currentAddress != null && currentName != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bluetooth_connected,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Currently paired',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(currentName,
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text(currentAddress,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: Colors.grey.shade600,
                            )),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(bluetoothTransportProvider)
                            .disconnect();
                        await ref
                            .read(settingsProvider.notifier)
                            .setLocationSource(source: 'phone');
                        _snack('Disconnected — using phone GPS');
                      },
                      icon: const Icon(Icons.link_off),
                      label: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isScanning ? _stopScan : _startScan,
            icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
            label: Text(_isScanning ? 'Stop scan' : 'Scan for devices'),
          ),
          const SizedBox(height: 16),
          Text(
            _found.isEmpty
                ? _isScanning
                    ? 'Scanning...'
                    : 'Tap Scan to find nearby devices.'
                : 'Discovered devices',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          for (final device in _found.values)
            _DeviceTile(
              device: device,
              isConnecting: _isConnecting &&
                  _connectingAddress == device.address,
              onConnect: _isConnecting ? null : () => _connect(device),
            ),
          const SizedBox(height: 24),
          Text(
            'Compatible receivers: Bad Elf, Trimble R1/R2, Eos Arrow, '
            'Garmin GLO, Emlid Reach (Bluetooth Classic SPP mode).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BtDevice device;
  final bool isConnecting;
  final VoidCallback? onConnect;

  const _DeviceTile({
    required this.device,
    required this.isConnecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          device.paired ? Icons.bluetooth : Icons.bluetooth_searching,
          color: device.paired
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade600,
        ),
        title: Text(device.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.address,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            if (device.rssi != null)
              Text('Signal: ${device.rssi} dBm',
                  style: const TextStyle(fontSize: 12)),
            if (device.paired)
              const Text('Already paired',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton(
                onPressed: onConnect,
                child: const Text('Connect'),
              ),
      ),
    );
  }
}