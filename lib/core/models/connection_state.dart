/// Connection lifecycle state for the Windows Bridge client.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  authenticating;

  /// True if the client is currently in an active or establishing state.
  bool get isConnected => this == ConnectionState.connected;

  /// True if a connection or auth handshake is in progress.
  bool get isTransitioning =>
      this == ConnectionState.connecting ||
      this == ConnectionState.authenticating;

  /// Converts a serialized JSON string to [ConnectionState].
  static ConnectionState fromString(String value) {
    return ConnectionState.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ConnectionState.disconnected,
    );
  }

  /// Serializes [ConnectionState] to a string.
  String toJson() => name;
}
