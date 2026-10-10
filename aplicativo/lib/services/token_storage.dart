import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:mioamoreapp/helpers/constants.dart';

enum SessionEventType {
  tokenRefreshed,
  sessionExpired,
  sessionCleared,
}

class SessionEvent {
  final SessionEventType type;
  final String? accessToken;
  final String? message;

  const SessionEvent(this.type, {this.accessToken, this.message});
}

class PendingFcmRemoval {
  final String token;
  final String? userId;

  const PendingFcmRemoval({required this.token, this.userId});

  Map<String, dynamic> toJson() => {
        "token": token,
        if (userId != null) "userId": userId,
      };
}

/// Guarda tokens, preferências e dados básicos da sessão no Hive.
class TokenStorage {
  TokenStorage._();

  static const _kAccess = "api_access_token";
  static const _kRefresh = "api_refresh_token";
  static const _kEmail = "api_user_email";
  static const _kUserId = "api_user_id";
  static const _kMyPhoto = "api_my_photo";
  static const _kFcmToken = "api_fcm_token";
  static const _kPendingFcmRemovals = "api_pending_fcm_removals";
  static const _kNotificationsEnabled = "notifications_enabled";

  static final StreamController<SessionEvent> _sessionEvents =
      StreamController<SessionEvent>.broadcast(sync: true);
  static Future<void> _mutationQueue = Future<void>.value();
  static bool _expirationNotified = false;
  static int _sessionGeneration = 0;

  static Box get _box => Hive.box(HiveConstants.hiveBox);

  static Stream<SessionEvent> get sessionEvents => _sessionEvents.stream;
  static int get sessionGeneration => _sessionGeneration;

  static Future<T> _mutate<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static bool isCurrentSession(
    int generation, {
    String? accessToken,
    String? refreshToken,
  }) {
    if (_sessionGeneration != generation) return false;
    if (accessToken != null && TokenStorage.accessToken != accessToken) {
      return false;
    }
    return refreshToken == null || TokenStorage.refreshToken == refreshToken;
  }

  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String email,
    String? userId,
  }) {
    if (accessToken.trim().isEmpty || refreshToken.trim().isEmpty) {
      throw ArgumentError("Tokens de sessão inválidos");
    }

    // A geração muda imediatamente para invalidar qualquer refresh em voo.
    final operationGeneration = ++_sessionGeneration;
    _expirationNotified = false;
    return _mutate(() async {
      if (operationGeneration != _sessionGeneration) return;
      await _box.putAll({
        _kAccess: accessToken,
        _kRefresh: refreshToken,
        _kEmail: email,
        if (userId != null) _kUserId: userId,
      });
      if (operationGeneration != _sessionGeneration) return;
      if (userId == null) await _box.delete(_kUserId);
      if (operationGeneration == _sessionGeneration) {
        _expirationNotified = false;
      }
    });
  }

  /// Atualiza tokens somente se o refresh ainda pertencer à mesma sessão.
  static Future<bool> updateTokensIfCurrent({
    required int expectedGeneration,
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
  }) {
    if (accessToken.trim().isEmpty || refreshToken.trim().isEmpty) {
      throw ArgumentError("Tokens renovados inválidos");
    }

    return _mutate(() async {
      if (!isCurrentSession(
        expectedGeneration,
        refreshToken: expectedRefreshToken,
      )) {
        return false;
      }
      await _box.putAll({
        _kAccess: accessToken,
        _kRefresh: refreshToken,
      });
      if (_sessionGeneration != expectedGeneration) return false;
      _expirationNotified = false;
      _sessionEvents.add(
        SessionEvent(
          SessionEventType.tokenRefreshed,
          accessToken: accessToken,
        ),
      );
      return true;
    });
  }

  static String? _readString(String key) {
    final value = _box.get(key);
    return value is String && value.isNotEmpty ? value : null;
  }

  static String? get accessToken => _readString(_kAccess);
  static String? get refreshToken => _readString(_kRefresh);
  static String? get email => _readString(_kEmail);
  static String? get userId => _readString(_kUserId);
  static String? get myPhoto => _readString(_kMyPhoto);
  static String? get fcmToken => _readString(_kFcmToken);

  static List<PendingFcmRemoval> get pendingFcmRemovals {
    final raw = _box.get(_kPendingFcmRemovals);
    if (raw is! List) return const <PendingFcmRemoval>[];

    final result = <PendingFcmRemoval>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final token = item["token"];
      if (token is! String || token.trim().isEmpty) continue;
      final rawUserId = item["userId"];
      final pendingUserId = rawUserId is String && rawUserId.trim().isNotEmpty
          ? rawUserId.trim()
          : null;
      result.add(
        PendingFcmRemoval(token: token.trim(), userId: pendingUserId),
      );
    }
    return List<PendingFcmRemoval>.unmodifiable(result);
  }

  static String? get pendingFcmRemovalToken {
    final pending = pendingFcmRemovals;
    return pending.isEmpty ? null : pending.first.token;
  }

  static String? get pendingFcmRemovalUserId {
    final pending = pendingFcmRemovals;
    return pending.isEmpty ? null : pending.first.userId;
  }

  static bool get notificationsEnabled =>
      _box.get(_kNotificationsEnabled, defaultValue: true) == true;

  static Future<void> setMyPhoto(String? url) async {
    if (url == null || url.isEmpty) {
      await _box.delete(_kMyPhoto);
    } else {
      await _box.put(_kMyPhoto, url);
    }
  }

  static Future<void> setFcmToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _box.delete(_kFcmToken);
    } else {
      await _box.put(_kFcmToken, token);
    }
  }

  static Future<bool> setFcmTokenIfCurrent({
    required int expectedGeneration,
    required String? expectedUserId,
    required String token,
  }) {
    return _mutate(() async {
      if (!isCurrentSession(expectedGeneration) ||
          userId != expectedUserId ||
          token.isEmpty) {
        return false;
      }
      await _box.put(_kFcmToken, token);
      if (!isCurrentSession(expectedGeneration) || userId != expectedUserId) {
        if (fcmToken == token) await _box.delete(_kFcmToken);
        return false;
      }
      return true;
    });
  }

  static Future<bool> clearFcmTokenIfCurrent({
    required int expectedGeneration,
    required String? expectedUserId,
    required String? expectedToken,
  }) {
    return _mutate(() async {
      final currentToken = fcmToken;
      if (!isCurrentSession(expectedGeneration) ||
          userId != expectedUserId ||
          currentToken != expectedToken) {
        return false;
      }
      if (currentToken != null) await _box.delete(_kFcmToken);
      return true;
    });
  }

  static Future<void> _setPendingFcmRemovalWithoutQueue({
    required String token,
    String? userId,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError("Token FCM pendente inválido");
    }
    final normalizedUserId = userId?.trim();
    final owner = normalizedUserId == null || normalizedUserId.isEmpty
        ? null
        : normalizedUserId;
    final pending = pendingFcmRemovals.toList();
    final alreadyStored = pending.any(
      (item) => item.token == normalizedToken && item.userId == owner,
    );
    if (alreadyStored) return;
    pending.add(PendingFcmRemoval(token: normalizedToken, userId: owner));
    await _box.put(
      _kPendingFcmRemovals,
      pending.map((item) => item.toJson()).toList(growable: false),
    );
  }

  static Future<void> _preserveCurrentFcmRemovalWithoutQueue() async {
    final currentToken = fcmToken;
    if (currentToken == null) return;
    await _setPendingFcmRemovalWithoutQueue(
      token: currentToken,
      userId: userId,
    );
  }

  static Future<void> setPendingFcmRemoval({
    required String token,
    String? userId,
  }) {
    return _mutate(
      () => _setPendingFcmRemovalWithoutQueue(token: token, userId: userId),
    );
  }

  static Future<bool> clearPendingFcmRemoval({
    required String token,
    required String? userId,
  }) {
    return _mutate(() async {
      final pending = pendingFcmRemovals.toList();
      final before = pending.length;
      pending.removeWhere(
        (item) => item.token == token && item.userId == userId,
      );
      if (pending.length == before) return false;
      if (pending.isEmpty) {
        await _box.delete(_kPendingFcmRemovals);
      } else {
        await _box.put(
          _kPendingFcmRemovals,
          pending.map((item) => item.toJson()).toList(growable: false),
        );
      }
      return true;
    });
  }

  static Future<void> setNotificationsEnabled(bool enabled) =>
      _box.put(_kNotificationsEnabled, enabled);

  static bool get isLoggedIn => accessToken != null;

  static Future<void> _deleteSessionData() => _box.deleteAll([
        _kAccess,
        _kRefresh,
        _kEmail,
        _kUserId,
        _kMyPhoto,
        _kFcmToken,
      ]);

  /// Limpa somente a sessão capturada, sem atingir um login mais recente.
  static Future<bool> clearIfCurrent({
    required int expectedGeneration,
    required String? expectedAccessToken,
    required String? expectedRefreshToken,
  }) {
    return _mutate(() async {
      if (_sessionGeneration != expectedGeneration ||
          accessToken != expectedAccessToken ||
          refreshToken != expectedRefreshToken) {
        return false;
      }

      final operationGeneration = ++_sessionGeneration;
      _expirationNotified = false;
      final hadSession = accessToken != null || refreshToken != null;

      if (operationGeneration != _sessionGeneration) return false;
      await _preserveCurrentFcmRemovalWithoutQueue();
      if (operationGeneration != _sessionGeneration) return false;
      await _deleteSessionData();
      if (operationGeneration != _sessionGeneration) return false;

      _expirationNotified = false;
      if (hadSession) {
        _sessionEvents.add(const SessionEvent(SessionEventType.sessionCleared));
      }
      return true;
    });
  }

  /// Limpeza explícita (logout). Preferência e remoções FCM são do aparelho.
  static Future<void> clear() async {
    final expectedGeneration = _sessionGeneration;
    final expectedAccessToken = accessToken;
    final expectedRefreshToken = refreshToken;
    await clearIfCurrent(
      expectedGeneration: expectedGeneration,
      expectedAccessToken: expectedAccessToken,
      expectedRefreshToken: expectedRefreshToken,
    );
  }

  /// Expira somente a sessão esperada, sem atingir um login mais recente.
  static Future<bool> expireSession({
    int? expectedGeneration,
    String? expectedAccessToken,
    String? expectedRefreshToken,
    String? message,
  }) {
    if (expectedGeneration != null &&
        !isCurrentSession(
          expectedGeneration,
          accessToken: expectedAccessToken,
          refreshToken: expectedRefreshToken,
        )) {
      return Future<bool>.value(false);
    }

    final operationGeneration = ++_sessionGeneration;
    return _mutate(() async {
      if (operationGeneration != _sessionGeneration) return false;
      final hadSession = accessToken != null || refreshToken != null;
      await _preserveCurrentFcmRemovalWithoutQueue();
      await _deleteSessionData();
      if (operationGeneration != _sessionGeneration) return false;
      if (hadSession && !_expirationNotified) {
        _expirationNotified = true;
        _sessionEvents.add(
          SessionEvent(SessionEventType.sessionExpired, message: message),
        );
      }
      return hadSession;
    });
  }
}
