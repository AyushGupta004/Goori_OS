import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../network/config.dart';

/// Service responsible for local network discovery of Windows AI bridge hosts via mDNS/NSD,
/// with manual IP fallback and mock simulation.
class DiscoveryService extends ChangeNotifier {
  final List<WindowsDevice> _discoveredDevices = [];
  bool _isScanning = false;
  nsd.Discovery? _activeNsdDiscovery;

  final StreamController<List<WindowsDevice>> _devicesStreamController =
      StreamController<List<WindowsDevice>>.broadcast();

  /// Stream of discovered devices updated in real-time.
  Stream<List<WindowsDevice>> get discoveredDevicesStream =>
      _devicesStreamController.stream;

  /// Current list of discovered devices.
  List<WindowsDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// True if an active discovery scan is in progress.
  bool get isScanning => _isScanning;

  /// Starts network discovery.
  /// In [BridgeMode.mock], simulates discovering "My Windows PC".
  /// In live modes, queries local network via native NSD/mDNS.
  Future<void> startDiscovery({
    BridgeMode mode = BridgeMode.dev,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_isScanning) return;

    _isScanning = true;
    _discoveredDevices.clear();
    _devicesStreamController.add([]);
    notifyListeners();

    if (mode == BridgeMode.mock) {
      await Future.delayed(const Duration(milliseconds: 350));
      final mockDevice = WindowsDevice(
        id: 'mock-win-pc-01',
        name: 'My Windows PC',
        host: '127.0.0.1',
        port: AppConstants.defaultHttpPort,
        isPaired: false,
        lastSeen: DateTime.now(),
        osVersion: 'Windows 11 Pro (AI Bridge v1.0)',
      );

      _discoveredDevices.add(mockDevice);
      _devicesStreamController.add(List.from(_discoveredDevices));
      _isScanning = false;
      notifyListeners();
      return;
    }

    try {
      _activeNsdDiscovery = await nsd.startDiscovery(
        AppConstants.mdnsServiceType,
        ipLookupType: nsd.IpLookupType.v4,
      );

      _activeNsdDiscovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
          final host = service.host ?? '';
          final port = service.port ?? AppConstants.defaultHttpPort;
          final name = service.name ?? 'Windows Bridge';

          final device = WindowsDevice(
            id: 'nsd_${host}_$port',
            name: name,
            host: host,
            port: port,
            isPaired: false,
            lastSeen: DateTime.now(),
          );

          if (!_discoveredDevices.any((d) => d.host == host && d.port == port)) {
            _discoveredDevices.add(device);
            _devicesStreamController.add(List.from(_discoveredDevices));
            notifyListeners();
          }
        }
      });

      // Automatically stop discovery after timeout
      Future.delayed(timeout, () {
        if (_isScanning) {
          stopDiscovery();
        }
      });
    } catch (_) {
      // In environments where NSD is unavailable (e.g. desktop/unit tests),
      // stop scanning gracefully and allow manual entry
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Adds a manually specified host and port.
  void addManualDevice(String host, int port, {String? name}) {
    final cleanHost = host.trim();
    final device = WindowsDevice(
      id: 'manual_${cleanHost}_$port',
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'Windows Host ($cleanHost)',
      host: cleanHost,
      port: port,
      isPaired: false,
      lastSeen: DateTime.now(),
    );

    _discoveredDevices.removeWhere((d) => d.host == cleanHost && d.port == port);
    _discoveredDevices.insert(0, device);
    _devicesStreamController.add(List.from(_discoveredDevices));
    notifyListeners();
  }

  /// Stops any active network scan.
  Future<void> stopDiscovery() async {
    if (!_isScanning) return;
    try {
      if (_activeNsdDiscovery != null) {
        await nsd.stopDiscovery(_activeNsdDiscovery!);
        _activeNsdDiscovery = null;
      }
    } catch (_) {}
    _isScanning = false;
    notifyListeners();
  }

  /// Clears discovered devices list.
  void clearDiscovered() {
    _discoveredDevices.clear();
    _devicesStreamController.add([]);
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    _devicesStreamController.close();
    super.dispose();
  }
}
