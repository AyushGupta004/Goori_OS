/// Represents a Windows machine running the AI automation bridge software.
class WindowsDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool isPaired;
  final DateTime? lastSeen;
  final String? osVersion;
  final String? fingerprint;
  final bool isResponding;

  const WindowsDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.isPaired = false,
    this.isResponding = true,
    this.lastSeen,
    this.osVersion,
    this.fingerprint,
  });

  /// Factory constructor to deserialize [WindowsDevice] from JSON map.
  factory WindowsDevice.fromJson(Map<String, dynamic> json) {
    return WindowsDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      isPaired: json['isPaired'] as bool? ?? false,
      isResponding: json['isResponding'] as bool? ?? true,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      osVersion: json['osVersion'] as String?,
      fingerprint: json['fingerprint'] as String?,
    );
  }

  /// Serializes [WindowsDevice] into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'isPaired': isPaired,
      'isResponding': isResponding,
      if (lastSeen != null) 'lastSeen': lastSeen!.toIso8601String(),
      if (osVersion != null) 'osVersion': osVersion,
      if (fingerprint != null) 'fingerprint': fingerprint,
    };
  }

  /// Creates a copy of [WindowsDevice] with updated fields.
  WindowsDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? isPaired,
    bool? isResponding,
    DateTime? lastSeen,
    String? osVersion,
    String? fingerprint,
  }) {
    return WindowsDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      isPaired: isPaired ?? this.isPaired,
      isResponding: isResponding ?? this.isResponding,
      lastSeen: lastSeen ?? this.lastSeen,
      osVersion: osVersion ?? this.osVersion,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowsDevice &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => id.hashCode ^ host.hashCode ^ port.hashCode;

  @override
  String toString() =>
      'WindowsDevice(id: $id, name: $name, host: $host, port: $port, paired: $isPaired, responding: $isResponding)';
}

