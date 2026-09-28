import 'dart:io';

/// Utility to inspect local network interfaces and detect subnet mismatches.
class SubnetUtil {
  SubnetUtil._();

  /// Checks if the current device's IPv4 /24 subnet differs from the [targetHost] /24 subnet.
  /// Returns a friendly diagnostic hint if they differ, or null if on the same subnet or non-IPv4.
  static Future<String?> checkSubnetMismatch(String targetHost) async {
    final cleanHost = targetHost.trim();
    if (cleanHost.isEmpty || cleanHost == '127.0.0.1' || cleanHost == 'localhost') {
      return null;
    }

    final targetParts = cleanHost.split('.');
    if (targetParts.length != 4) {
      // Host is likely a domain name or IPv6, skip /24 IPv4 check
      return null;
    }

    for (final part in targetParts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return null;
      }
    }

    final targetSubnet = '${targetParts[0]}.${targetParts[1]}.${targetParts[2]}';

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      final localIpv4s = <String>[];
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            localIpv4s.add(addr.address);
          }
        }
      }

      if (localIpv4s.isEmpty) return null;

      // Check if any local interface matches target /24
      for (final localIp in localIpv4s) {
        final localParts = localIp.split('.');
        if (localParts.length == 4) {
          final localSubnet = '${localParts[0]}.${localParts[1]}.${localParts[2]}';
          if (localSubnet == targetSubnet) {
            // Same /24 subnet found!
            return null;
          }
        }
      }

      // No interface shares the same /24 subnet
      final primaryLocal = localIpv4s.first;
      final localParts = primaryLocal.split('.');
      final localSubnet = '${localParts[0]}.${localParts[1]}.${localParts[2]}';

      return 'Your phone is on $localSubnet.x but the PC is on $targetSubnet.x: they are on different networks.';
    } catch (_) {
      // Gracefully ignore network interface listing failures
      return null;
    }
  }
}
