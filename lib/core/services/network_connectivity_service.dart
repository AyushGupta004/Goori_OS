import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Network connection mediums supported by the resilience layer.
enum NetworkType {
  wifi,
  mobile,
  ethernet,
  hotspot,
  vpn,
  other,
  none;

  static NetworkType fromConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.mobile;
      case ConnectivityResult.ethernet:
        return NetworkType.ethernet;
      case ConnectivityResult.vpn:
        return NetworkType.vpn;
      case ConnectivityResult.other:
        return NetworkType.other;
      case ConnectivityResult.none:
        return NetworkType.none;
      default:
        return NetworkType.other;
    }
  }
}

/// Represents a change in network connectivity (e.g. Wi-Fi <-> mobile data <-> hotspot).
class NetworkChangeEvent {
  final NetworkType previousType;
  final NetworkType currentType;
  final String? details;

  const NetworkChangeEvent({
    required this.previousType,
    required this.currentType,
    this.details,
  });

  /// True if the device currently has active network connectivity.
  bool get hasConnection => currentType != NetworkType.none;

  /// True if network transitioned between two valid connection mediums.
  bool get wasNetworkSwitched =>
      previousType != currentType &&
      previousType != NetworkType.none &&
      currentType != NetworkType.none;

  @override
  String toString() =>
      'NetworkChangeEvent($previousType -> $currentType, details: $details)';
}

/// Abstract contract for observing network connectivity lifecycle.
abstract class NetworkConnectivityService {
  /// Stream of network change events.
  Stream<NetworkChangeEvent> get onNetworkChanged;

  /// Current network type.
  NetworkType get currentType;

  /// Checks if network connection is actively established.
  Future<bool> get isConnected;

  /// Releases resources.
  void dispose();
}

/// Production implementation of [NetworkConnectivityService] powered by `connectivity_plus`.
class RealNetworkConnectivityService implements NetworkConnectivityService {
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkType _currentType = NetworkType.none;

  final StreamController<NetworkChangeEvent> _controller =
      StreamController<NetworkChangeEvent>.broadcast();

  RealNetworkConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  void _init() {
    _connectivity.checkConnectivity().then((results) {
      final initial = _mapResults(results);
      _currentType = initial;
    }).catchError((e) {
      debugPrint('[NetworkConnectivityService] Initial check error: $e');
    });

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final newType = _mapResults(results);
        if (newType != _currentType) {
          final event = NetworkChangeEvent(
            previousType: _currentType,
            currentType: newType,
          );
          _currentType = newType;
          _controller.add(event);
        }
      },
      onError: (error) {
        debugPrint('[NetworkConnectivityService] Connectivity stream error: $error');
      },
    );
  }

  NetworkType _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkType.none;
    return NetworkType.fromConnectivityResult(results.first);
  }

  @override
  Stream<NetworkChangeEvent> get onNetworkChanged => _controller.stream;

  @override
  NetworkType get currentType => _currentType;

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _mapResults(results) != NetworkType.none;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Mock implementation of [NetworkConnectivityService] for deterministic unit and widget testing.
class MockNetworkConnectivityService implements NetworkConnectivityService {
  NetworkType _currentType;
  final StreamController<NetworkChangeEvent> _controller =
      StreamController<NetworkChangeEvent>.broadcast();

  MockNetworkConnectivityService({
    NetworkType initialType = NetworkType.wifi,
  }) : _currentType = initialType;

  @override
  Stream<NetworkChangeEvent> get onNetworkChanged => _controller.stream;

  @override
  NetworkType get currentType => _currentType;

  @override
  Future<bool> get isConnected async => _currentType != NetworkType.none;

  /// Simulates a network transition to [newType].
  void emitNetworkChange(NetworkType newType, {String? details}) {
    if (newType != _currentType) {
      final event = NetworkChangeEvent(
        previousType: _currentType,
        currentType: newType,
        details: details,
      );
      _currentType = newType;
      _controller.add(event);
    }
  }

  /// Triggers a simulated network switch (e.g. Wi-Fi <-> mobile data <-> hotspot).
  void triggerNetworkSwitch(NetworkType newType, {String? details}) {
    emitNetworkChange(newType, details: details);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
