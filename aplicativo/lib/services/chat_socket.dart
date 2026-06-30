import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:mioamoreapp/config/api_config.dart';
import 'package:mioamoreapp/services/token_storage.dart';

/// Conexão Socket.io para o chat em tempo real.
class ChatSocket {
  io.Socket? _socket;

  /// URL base do socket (sem o /api).
  String get _origin => ApiConfig.baseUrl.replaceAll("/api", "");

  void connect({
    required void Function(Map<String, dynamic> message) onMessage,
    required void Function(String matchId, String by) onRead,
    void Function(String matchId, String userId, bool isTyping)? onTyping,
    void Function(Map<String, dynamic> data)? onMatch,
    void Function(Map<String, dynamic> data)? onNotification,
    void Function()? onConfigAds,
    void Function(Map<String, dynamic> data)? onConfigMe,
    void Function()? onConfigStore,
  }) {
    disconnect();
    final socket = io.io(
      _origin,
      io.OptionBuilder()
          // websocket no path /api/socket.io/ (curl confirmou upgrade 101).
          .setTransports(["websocket"])
          .setPath("/api/socket.io/")
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setAuth({"token": TokenStorage.accessToken})
          .build(),
    );

    socket.onConnect((_) => debugPrint("🔌 socket CONECTADO ($_origin)"));
    socket.onConnectError((e) => debugPrint("🔌 socket connect_error: $e"));
    socket.onError((e) => debugPrint("🔌 socket error: $e"));
    socket.onDisconnect((r) => debugPrint("🔌 socket desconectado: $r"));
    socket.on("message:new", (data) {
      if (data is Map) onMessage(Map<String, dynamic>.from(data));
    });
    socket.on("messages:read", (data) {
      if (data is Map) onRead(data["matchId"]?.toString() ?? "", data["by"]?.toString() ?? "");
    });
    socket.on("typing", (data) {
      if (data is Map && onTyping != null) {
        onTyping(
          data["matchId"]?.toString() ?? "",
          data["userId"]?.toString() ?? "",
          data["isTyping"] == true,
        );
      }
    });
    socket.on("match:new", (data) {
      if (data is Map && onMatch != null) onMatch(Map<String, dynamic>.from(data));
    });
    socket.on("notification:new", (data) {
      if (data is Map && onNotification != null) {
        onNotification(Map<String, dynamic>.from(data));
      }
    });
    socket.on("config:ads", (_) {
      if (onConfigAds != null) onConfigAds();
    });
    socket.on("config:me", (data) {
      if (onConfigMe != null) {
        onConfigMe(data is Map ? Map<String, dynamic>.from(data) : {});
      }
    });
    socket.on("config:store", (_) {
      if (onConfigStore != null) onConfigStore();
    });

    socket.connect();
    _socket = socket;
  }

  void joinMatch(String matchId) => _socket?.emit("match:join", {"matchId": matchId});
  void leaveMatch(String matchId) => _socket?.emit("match:leave", {"matchId": matchId});

  void sendMessage(String matchId, String content) =>
      _socket?.emit("message:send", {"matchId": matchId, "content": content});

  void markRead(String matchId) => _socket?.emit("message:read", {"matchId": matchId});

  void setTyping(String matchId, bool isTyping) =>
      _socket?.emit("typing", {"matchId": matchId, "isTyping": isTyping});

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
