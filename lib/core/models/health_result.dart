/// Enumeration of classified health probe outcomes per Task 2 spec.
enum HealthResultKind {
  ok,
  timeout,
  refused,
  noRoute,
  notABridge, // 404 or non-JSON / foreign server
  versionMismatch,
  serverError,
  unknown,
}

/// Diagnosable reachability and preflight health check result.
class HealthResult {
  final bool ok;
  final HealthResultKind kind;
  final Duration? elapsedTime;
  final String? deviceName;
  final List<String> wsUrls;
  final String? protocolVersion;
  final String? deviceId;
  final String? details;
  final String? subnetHint;

  const HealthResult({
    required this.ok,
    required this.kind,
    this.elapsedTime,
    this.deviceName,
    this.wsUrls = const [],
    this.protocolVersion,
    this.deviceId,
    this.details,
    this.subnetHint,
  });

  factory HealthResult.success({
    Duration? elapsedTime,
    String? deviceName,
    List<String> wsUrls = const [],
    String? protocolVersion,
    String? deviceId,
  }) {
    return HealthResult(
      ok: true,
      kind: HealthResultKind.ok,
      elapsedTime: elapsedTime,
      deviceName: deviceName,
      wsUrls: wsUrls,
      protocolVersion: protocolVersion,
      deviceId: deviceId,
    );
  }

  factory HealthResult.failure({
    required HealthResultKind kind,
    Duration? elapsedTime,
    String? details,
    String? subnetHint,
    String? protocolVersion,
  }) {
    return HealthResult(
      ok: false,
      kind: kind,
      elapsedTime: elapsedTime,
      details: details,
      subnetHint: subnetHint,
      protocolVersion: protocolVersion,
    );
  }

  /// User-friendly headline for reachability failure.
  String get friendlyHeadline {
    switch (kind) {
      case HealthResultKind.ok:
        return 'Bridge is reachable';
      case HealthResultKind.timeout:
        return "Can't reach your PC";
      case HealthResultKind.refused:
        return 'Connection refused by your PC';
      case HealthResultKind.noRoute:
        return 'Unable to find route to your PC';
      case HealthResultKind.notABridge:
        return "Something answered, but it isn't the Windows bridge. Make sure the latest bridge is running.";
      case HealthResultKind.versionMismatch:
        return 'Bridge version incompatible';
      case HealthResultKind.serverError:
        return 'Windows bridge error';
      case HealthResultKind.unknown:
        return "Can't reach your PC";
    }
  }

  /// Full diagnostic summary suitable for copying to clipboard.
  String toDiagnosticString({String? host, int? port}) {
    final buffer = StringBuffer();
    buffer.writeln('=== Windows Bridge Diagnostics ===');
    if (host != null) buffer.writeln('Target: $host:${port ?? 7890}');
    buffer.writeln('Outcome: ${kind.name}');
    buffer.writeln('Is Healthy: $ok');
    if (elapsedTime != null) {
      buffer.writeln('Elapsed: ${elapsedTime!.inMilliseconds}ms');
    }
    if (details != null) {
      buffer.writeln('Details: $details');
    }
    if (subnetHint != null) {
      buffer.writeln('Network Hint: $subnetHint');
    }
    if (protocolVersion != null) {
      buffer.writeln('Protocol Version: $protocolVersion');
    }
    if (deviceName != null) {
      buffer.writeln('Device Name: $deviceName');
    }
    if (wsUrls.isNotEmpty) {
      buffer.writeln('WebSocket URLs: ${wsUrls.join(', ')}');
    }
    return buffer.toString().trim();
  }
}
