import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mioamoreapp/services/public_url.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef _MessageHandler = void Function(Map<String, dynamic> message);
typedef _ReadHandler = void Function(String matchId, String by);
typedef _TypingHandler = void Function(
  String matchId,
  String userId,
  bool isTyping,
);
typedef _MapHandler = void Function(Map<String, dynamic> data);

/// Conexão Socket.io para o chat em tempo real.
class ChatSocket {
  io.Socket? _socket;
  StreamSubscription<SessionEvent>? _sessionSubscription;
  final Set<String> _joinedMatches = <String>{};

  _MessageHandler? _onMessage;
  _ReadHandler? _onRead;
  _TypingHandler? _onTyping;
  _MapHandler? _onMatch;
  _MapHandler? _onNotification;
  VoidCallback? _onConfigAds;
  _MapHandler? _onConfigMe;
  VoidCallback? _onConfigStore;
  bool _configured = false;

  /// URL base do socket, removendo somente o sufixo de path `/api`.
  String get _origin => PublicUrl.apiOrigin;

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
    _onMessage = onMessage;
    _onRead = onRead;
    _onTyping = onTyping;
    _onMatch = onMatch;
    _onNotification = onNotification;
    _onConfigAds = onConfigAds;
    _onConfigMe = onConfigMe;
    _onConfigStore = onConfigStore;
    _configured = true;
    _sessionSubscription = TokenStorage.sessionEvents.listen((event) {
      switch (event.type) {
        case SessionEventType.tokenRefreshed:
          reconnectWithLatestToken();
          break;
        case SessionEventType.sessionExpired:
        case SessionEventType.sessionCleared:
          _disconnectTransport();
          break;
      }
    });
    _connectTransport();
  }

  void _connectTransport() {
    if (!_configured || TokenStorage.accessToken == null) return;
    _disconnectTransport();

    final socket = io.io(
      _origin,
      io.OptionBuilder()
          .setTransports(["websocket"])
          .setPath("/api/socket.io/")
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setAuth({"token": TokenStorage.accessToken})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      if (!identical(_socket, socket)) return;
      debugPrint("🔌 socket CONECTADO ($_origin)");
      for (final matchId in _joinedMatches) {
        socket.emit("match:join", {"matchId": matchId});
      }
    });
    socket.onConnectError(
      (error) => debugPrint("🔌 socket connect_error: $error"),
    );
    socket.onError((error) => debugPrint("🔌 socket error: $error"));
    socket.onDisconnect(
      (reason) => debugPrint("🔌 socket desconectado: $reason"),
    );
    socket.on("message:new", (data) {
      if (data is Map) {
        _onMessage?.call(Map<String, dynamic>.from(data));
      }
    });
    socket.on("messages:read", (data) {
      if (data is Map) {
        _onRead?.call(
          data["matchId"]?.toString() ?? "",
          data["by"]?.toString() ?? "",
        );
      }
    });
    socket.on("typing", (data) {
      if (data is Map) {
        _onTyping?.call(
          data["matchId"]?.toString() ?? "",
          data["userId"]?.toString() ?? "",
          data["isTyping"] == true,
        );
      }
    });
    socket.on("match:new", (data) {
      if (data is Map) _onMatch?.call(Map<String, dynamic>.from(data));
    });
    socket.on("notification:new", (data) {
      if (data is Map) {
        _onNotification?.call(Map<String, dynamic>.from(data));
      }
    });
    socket.on("config:ads", (_) => _onConfigAds?.call());
    socket.on("config:me", (data) {
      _onConfigMe?.call(
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
      );
    });
    socket.on("config:store", (_) => _onConfigStore?.call());
    socket.connect();
  }

  /// Reconstrói o transporte para enviar o token atual no handshake.
  void reconnectWithLatestToken() => _connectTransport();

  void joinMatch(String matchId) {
    if (matchId.isEmpty) return;
    _joinedMatches.add(matchId);
    if (_socket?.connected == true) {
      _socket?.emit("match:join", {"matchId": matchId});
    }
  }

  void leaveMatch(String matchId) {
    _joinedMatches.remove(matchId);
    if (_socket?.connected == true) {
      _socket?.emit("match:leave", {"matchId": matchId});
    }
  }

  void sendMessage(String matchId, String content) =>
      _socket?.emit("message:send", {"matchId": matchId, "content": content});

  void markRead(String matchId) =>
      _socket?.emit("message:read", {"matchId": matchId});

  void setTyping(String matchId, bool isTyping) => _socket?.emit(
        "typing",
        {"matchId": matchId, "isTyping": isTyping},
      );

  void _disconnectTransport() {
    _socket?.dispose();
    _socket = null;
  }

  Future<void> _cancelSessionSubscription(
    StreamSubscription<SessionEvent> subscription,
  ) async {
    try {
      await subscription.cancel();
    } catch (error) {
      debugPrint(
          "Não foi possível cancelar listener de sessão do socket: $error");
    }
  }

  void disconnect() {
    _configured = false;
    _disconnectTransport();
    final sessionSubscription = _sessionSubscription;
    _sessionSubscription = null;
    if (sessionSubscription != null) {
      unawaited(_cancelSessionSubscription(sessionSubscription));
    }
    _joinedMatches.clear();
    _onMessage = null;
    _onRead = null;
    _onTyping = null;
    _onMatch = null;
    _onNotification = null;
    _onConfigAds = null;
    _onConfigMe = null;
    _onConfigStore = null;
  }
}
