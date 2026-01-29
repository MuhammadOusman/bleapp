import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// A top-level gate that forces the user to enable Bluetooth before using the app.
///
/// It listens to `FlutterBluePlus.state` and blocks the app with a modal overlay
/// when Bluetooth is not `on`. A small set of actions are provided (Refresh, Open
/// App Settings) to help the user enable Bluetooth.
class BluetoothGate extends StatefulWidget {
  final Widget child;
  const BluetoothGate({required this.child, super.key});

  @override
  State<BluetoothGate> createState() => _BluetoothGateState();
}

class _BluetoothGateState extends State<BluetoothGate> {
  StreamSubscription<dynamic>? _sub;
  bool _isOn = true;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _initStateListener();
  }

  Future<void> _initStateListener() async {
    // Initial check
    await _checkState();

    // Listen for changes; if the plugin doesn't expose the stream on a platform,
    // ignore errors and keep the app usable to avoid locking users out.
    try {
      _sub = FlutterBluePlus.adapterState.listen((s) {
        final on = s.toString().toLowerCase().contains('on');
        if (mounted) {
          setState(() {
            _isOn = on;
            _checked = true;
          });
        }
      });
    } catch (_) {
      // If listening fails, consider Bluetooth enabled to avoid false blocks.
      if (mounted) {
        setState(() {
          _isOn = true;
          _checked = true;
        });
      }
    }
  }

  Future<void> _checkState() async {
    try {
      final s = await FlutterBluePlus.adapterState.first;
      final on = s.toString().toLowerCase().contains('on');
      if (mounted) {
        setState(() {
          _isOn = on;
          _checked = true;
        });
      }
    } catch (e) {
      // If we can't read state treat it as available to avoid blocking platforms
      // where the plugin does not expose state (safer fallback).
      if (mounted) {
        setState(() {
          _isOn = true;
          _checked = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget is intended to be inserted inside the application's
    // MaterialApp (via MaterialApp.builder). Do not create a nested
    // MaterialApp — instead render overlays that use the surrounding
    // Theme/Directionality.
    final child = widget.child;

    return Stack(
      children: [
        child,

        // While we are doing the initial check show a simple progress overlay so
        // users aren't left looking at a blank screen.
        if (!_checked)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Checking Bluetooth state...')
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Block interactions when Bluetooth is not enabled
        if (_checked && !_isOn)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.indigo.shade700),
                          const SizedBox(height: 12),
                          const Text('Bluetooth required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text(
                            'This app requires Bluetooth to be enabled. Please turn on Bluetooth and return to the app.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () async => await _checkState(),
                                child: const Text('Refresh'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async => await openAppSettings(),
                                child: const Text('Open App Settings'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
