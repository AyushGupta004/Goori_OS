import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;

import '../constants/app_constants.dart';
import '../models/models.dart';
import '../network/config.dart';

/// Service responsible for local network discovery of Windows AI bridge hosts via mDNS/NSD,
/// with manual IP fallback, background health verification, and mock simulation.
class DiscoveryService extends ChangeNotifier {
  final List<WindowsDevice> _discoveredDevices = [];
  bool _isScanning = false;
  nsd.Discovery? _activeNsdDiscovery;
  final http.Client _httpClient;

  final StreamController<List<WindowsDevice>> _devicesStreamController =
      StreamController<List<WindowsDevice>>.broadcast();
  bool _isDisposed = false;

  DiscoveryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

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
        isResponding: true,
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

          String? txtDeviceId;
          if (service.txt != null) {
            try {
              final raw = service.txt!['device_id'] ?? service.txt!['id'];
              if (raw != null) {
                txtDeviceId = utf8.decode(raw);
              }
            } catch (_) {}
          }

          final device = WindowsDevice(
            id: txtDeviceId ?? 'nsd_${host}_$port',
            name: name,
            host: host,
            port: port,
            isPaired: false,
            isResponding: false, // Initially unverified until probe answers
            lastSeen: DateTime.now(),
          );

          final existingIndex =
              _discoveredDevices.indexWhere((d) => d.host == host && d.port == port);
          if (existingIndex < 0) {
            _discoveredDevices.add(device);
            _devicesStreamController.add(List.from(_discoveredDevices));
            notifyListeners();
            _probeDeviceHealth(device);
          } else {
            _probeDeviceHealth(_discoveredDevices[existingIndex]);
          }
        } else if (status == nsd.ServiceStatus.lost) {
          // Task 3: Handle NSD "lost" events and remove stale entries
          final host = service.host;
          final port = service.port;
          final name = service.name;

          _discoveredDevices.removeWhere((d) =>
              (host != null && host.isNotEmpty && d.host == host && (port == null || d.port == port)) ||
              (name != null && name.isNotEmpty && d.name == name));
          _devicesStreamController.add(List.from(_discoveredDevices));
          notifyListeners();
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

  /// Probes the device via /health (2s timeout) in background.
  Future<bool> probeDeviceHealth(WindowsDevice device) async {
    return await _probeDeviceHealth(device);
  }

  Future<bool> _probeDeviceHealth(WindowsDevice device) async {
    if (device.host.isEmpty) return false;

    try {
      final healthUri = Uri.parse('http://${device.host}:${device.port}/health');
      final response =
          await _httpClient.get(healthUri).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        String? updatedName;
        String? updatedDeviceId;
        try {
          final json = jsonDecode(response.body);
          if (json is Map<String, dynamic>) {
            updatedName = json['device_name'] as String? ?? json['name'] as String?;
            updatedDeviceId = json['device_id'] as String? ?? json['deviceId'] as String?;
          }
        } catch (_) {}

        _updateDeviceStatus(
          device.host,
          device.port,
          isResponding: true,
          name: updatedName,
          deviceId: updatedDeviceId,
        );
        return true;
      }

      // Fallback check against /api/status
      final statusUri = Uri.parse('http://${device.host}:${device.port}/api/status');
      final statusResp =
          await _httpClient.get(statusUri).timeout(const Duration(seconds: 1));
      if (statusResp.statusCode == 200) {
        _updateDeviceStatus(device.host, device.port, isResponding: true);
        return true;
      }
    } catch (_) {}

    _updateDeviceStatus(device.host, device.port, isResponding: false);
    return false;
  }

  void _updateDeviceStatus(
    String host,
    int port, {
    required bool isResponding,
    String? name,
    String? deviceId,
  }) {
    if (_isDisposed || _devicesStreamController.isClosed) return;
    final idx = _discoveredDevices.indexWhere((d) => d.host == host && d.port == port);
    if (idx >= 0) {
      final old = _discoveredDevices[idx];
      _discoveredDevices[idx] = old.copyWith(
        isResponding: isResponding,
        name: name ?? old.name,
        id: deviceId ?? old.id,
      );
      _devicesStreamController.add(List.from(_discoveredDevices));
      notifyListeners();
    }
  }

  /// Scans the network to locate the same PC (by deviceId or instance name) at a potentially new IP.
  Future<WindowsDevice?> findDevice({
    required String targetDeviceId,
    String? targetName,
    BridgeMode mode = BridgeMode.dev,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await startDiscovery(mode: mode, timeout: timeout);
    await Future.delayed(timeout);

    for (final d in _discoveredDevices) {
      if ((targetDeviceId.isNotEmpty && d.id == targetDeviceId) ||
          (targetName != null && targetName.isNotEmpty && d.name == targetName)) {
        if (d.isResponding) {
          return d;
        }
      }
    }
    return null;
  }

  /// Adds a manually specified host and port and probes it.
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
      isResponding: true, // Manual entry is tentative
      lastSeen: DateTime.now(),
    );

    _discoveredDevices.removeWhere((d) => d.host == cleanHost && d.port == port);
    _discoveredDevices.insert(0, device);
    _devicesStreamController.add(List.from(_discoveredDevices));
    notifyListeners();

    // Probe in background
    _probeDeviceHealth(device);
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
    if (!_devicesStreamController.isClosed) {
      _devicesStreamController.add([]);
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopDiscovery();
    _devicesStreamController.close();
    super.dispose();
  }
}

