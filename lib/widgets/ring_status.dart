import 'dart:async';

import 'package:fahrplan/models/r08/ring.dart';
import 'package:fahrplan/models/r08/tap_event.dart';
import 'package:fahrplan/services/ring_manager.dart';
import 'package:flutter/material.dart';

class RingStatus extends StatefulWidget {
  const RingStatus({super.key});

  @override
  State<RingStatus> createState() => _RingStatusState();
}

class _RingStatusState extends State<RingStatus> {
  final RingManager _ringManager = RingManager();

  R08ConnectionState _state = R08ConnectionState.disconnected;
  StreamSubscription<R08ConnectionState>? _connectionSubscription;
  StreamSubscription<R08TapEvent>? _tapSubscription;

  @override
  void initState() {
    super.initState();
    _state = _ringManager.connectionState;
    _connectionSubscription =
        _ringManager.connectionStateStream.listen(_onConnectionStateChanged);
    _tapSubscription = _ringManager.tapEvents.listen(_onTapEvent);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _tapSubscription?.cancel();
    super.dispose();
  }

  void _onConnectionStateChanged(R08ConnectionState state) {
    if (!mounted) return;
    setState(() {
      _state = state;
    });
  }

  void _onTapEvent(R08TapEvent event) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(event.label)),
    );
  }

  Future<void> _connectOrDisconnect() async {
    if (_ringManager.isConnected) {
      await _ringManager.disconnect();
    } else {
      try {
        await _ringManager.connectOrScan();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('R08 error: $e')),
        );
      }
    }
  }

  String get _buttonLabel {
    switch (_state) {
      case R08ConnectionState.disconnected:
        return 'Connect to ring';
      case R08ConnectionState.scanning:
        return 'Scanning for ring';
      case R08ConnectionState.connecting:
        return 'Connecting to ring';
      case R08ConnectionState.connected:
        return 'Disconnect ring';
    }
  }

  bool get _isBusy =>
      _state == R08ConnectionState.scanning ||
      _state == R08ConnectionState.connecting;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _state == R08ConnectionState.connected
                ? const Text(
                    'Connected to R08 ring',
                    style: TextStyle(color: Colors.green),
                  )
                : ElevatedButton(
                    onPressed: _isBusy ? null : _connectOrDisconnect,
                    child: _isBusy
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Scanning for ring'),
                            ],
                          )
                        : Text(_buttonLabel),
                  ),
          ],
        ),
      ),
    );
  }
}
