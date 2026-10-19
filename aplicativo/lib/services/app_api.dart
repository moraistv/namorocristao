import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mioamoreapp/config/api_config.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';

enum AppApiErrorType {
  invalidRequest,
  connection,
  timeout,
  invalidResponse,
  unauthorized,
  client,
  server,
  unexpected,
}

const _terminalAccountCodes = <String>{
  "ACCOUNT_UNAVAILABLE",
  "ACCOUNT_BANNED",
  "ACCOUNT_SUSPENDED",
};

class AppApiException implements Exception {
  final String message;
  final int statusCode;
  final AppApiErrorType type;
  final Object? cause;
  final String? code;
  final Object? details;

  AppApiException(
    this.message, [
    this.statusCode = 0,
    this.type = AppApiErrorType.client,
    this.cause,
    this.code,
    this.details,
  ]);

  bool get terminatesSession =>
      code != null && _terminalAccountCodes.contains(code!.toUpperCase());

  bool get retryable =>
      !terminatesSession &&
      switch (type) {
        AppApiErrorType.connection ||
        AppApiErrorType.timeout ||
        AppApiErrorType.invalidResponse ||
        AppApiErrorType.server ||
        AppApiErrorType.unexpected =>
          true,
        AppApiErrorType.client => statusCode == 429,
        AppApiErrorType.invalidRequest || AppApiErrorType.unauthorized => false,
      };

  @override
  String toString() => message;
}

class _RefreshFlight {
  final int generation;
  final String refreshToken;
  final Future<void> future;

  const _RefreshFlight(this.generation, this.refreshToken, this.future);
}

/// Cliente autenticado da API (perfil, descoberta, match, chat).
class AppApi {
  AppApi._();

  static const _timeout = Duration(seconds: 20);
  static _RefreshFlight? _refreshInFlight;

  static Uri _u(String path) => Uri.parse("${ApiConfig.baseUrl}$path");

  static Map<String, String> _headers(String? accessToken) => {
        "Content-Type": "application/json",
        if (accessToken != null) "Authorization": "Bearer $accessToken",
      };

  static Future<void> _refreshOnce() {
    final generation = TokenStorage.sessionGeneration;
    final accessToken = TokenStorage.accessToken;
    final refreshToken = TokenStorage.refreshToken;
    if (refreshToken == null) {
      return _expireMissingRefresh(generation, accessToken);
    }

    final running = _refreshInFlight;
    if (running != null &&
        running.generation == generation &&
        running.refreshToken == refreshToken) {
      return running.future;
    }

    final future = _performRefresh(generation, accessToken, refreshToken);
    final flight = _RefreshFlight(generation, refreshToken, future);
    _refreshInFlight = flight;
    future.then<void>(
      (_) {
        if (identical(_refreshInFlight, flight)) _refreshInFlight = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_refreshInFlight, flight)) _refreshInFlight = null;
      },
    );
    return future;
  }

  static Future<void> _expireMissingRefresh(
    int generation,
    String? accessToken,
  ) async {
    await _expireCapturedSession(
      generation: generation,
      accessToken: accessToken,
      refreshToken: null,
      message: "Sua sessão expirou. Entre novamente para continuar.",
    );
    throw AppApiException(
      "Sua sessão expirou. Entre novamente para continuar.",
      401,
      AppApiErrorType.unauthorized,
    );
  }

  static AppApiException _sessionChanged() => AppApiException(
        "A sessão mudou durante a requisição. Tente novamente.",
        401,
        AppApiErrorType.unauthorized,
      );

  static Future<void> _expireCapturedSession({
    required int generation,
    required String? accessToken,
    required String? refreshToken,
    required String message,
  }) async {
    final expired = await TokenStorage.expireSession(
      expectedGeneration: generation,
      expectedAccessToken: accessToken,
      expectedRefreshToken: refreshToken,
      message: message,
    );
    if (!expired) throw _sessionChanged();
  }

  static Future<void> _performRefresh(
    int generation,
    String? accessToken,
    String refreshToken,
  ) async {
    late final http.Response response;
    try {
      response = await http
          .post(
            _u("/auth/refresh"),
            headers: const {"Content-Type": "application/json"},
            body: jsonEncode({"refreshToken": refreshToken}),
          )
          .timeout(_timeout);
    } on TimeoutException catch (error) {
      throw AppApiException(
        "O servidor demorou para renovar a sessão",
        0,
        AppApiErrorType.timeout,
        error,
      );
    } on http.ClientException catch (error) {
      throw AppApiException(
        "Falha de conexão ao renovar a sessão",
        0,
        AppApiErrorType.connection,
        error,
      );
    } catch (error) {
      throw AppApiException(
        "Não foi possível renovar a sessão agora",
        0,
        AppApiErrorType.unexpected,
        error,
      );
    }

    if (!TokenStorage.isCurrentSession(
      generation,
      accessToken: accessToken,
      refreshToken: refreshToken,
    )) {
      throw _sessionChanged();
    }

    final statusCode = response.statusCode;
    final successful = statusCode >= 200 && statusCode < 300;
    if (!successful) {
      final json = _decodeResponse(response, successful: false);
      final exception = _exceptionFromError(json, statusCode);
      final invalidRefresh =
          statusCode == 400 || statusCode == 401 || statusCode == 403;
      if (exception.terminatesSession || invalidRefresh) {
        await _expireCapturedSession(
          generation: generation,
          accessToken: accessToken,
          refreshToken: refreshToken,
          message: _terminalSessionMessage(exception.code),
        );
        if (exception.terminatesSession) throw exception;
        throw AppApiException(
          exception.message,
          statusCode,
          AppApiErrorType.unauthorized,
          exception.cause,
          exception.code,
          exception.details,
        );
      }
      throw exception;
    }

    // JSON inválido (por exemplo, página de gateway) é transitório e não apaga
    // credenciais. Somente JSON 2xx válido com tokens ausentes/vazios é terminal.
    final json = _decodeResponse(response, successful: true);
    final access = json["accessToken"];
    final refresh = json["refreshToken"];
    if (access is! String ||
        access.trim().isEmpty ||
        refresh is! String ||
        refresh.trim().isEmpty) {
      const message = "O servidor retornou credenciais de sessão inválidas";
      await _expireCapturedSession(
        generation: generation,
        accessToken: accessToken,
        refreshToken: refreshToken,
        message: "Sua sessão expirou. Entre novamente para continuar.",
      );
      throw AppApiException(
        message,
        statusCode,
        AppApiErrorType.unauthorized,
      );
    }

    try {
      final updated = await TokenStorage.updateTokensIfCurrent(
        expectedGeneration: generation,
        expectedRefreshToken: refreshToken,
        accessToken: access,
        refreshToken: refresh,
      );
      if (!updated) throw _sessionChanged();
    } on AppApiException {
      rethrow;
    } catch (error) {
      throw AppApiException(
        "Não foi possível salvar a sessão renovada",
        0,
        AppApiErrorType.unexpected,
        error,
      );
    }
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    if (method != "GET" &&
        method != "POST" &&
        method != "PUT" &&
        method != "DELETE") {
      throw AppApiException(
        "Método inválido",
        0,
        AppApiErrorType.invalidRequest,
      );
    }

    late final Uri uri;
    late final String? encoded;
    try {
      uri = _u(path);
      encoded = body == null ? null : jsonEncode(body);
    } catch (error) {
      throw AppApiException(
        "Não foi possível preparar a requisição",
        0,
        AppApiErrorType.invalidRequest,
        error,
      );
    }

    final sentGeneration = TokenStorage.sessionGeneration;
    final sentAccessToken = TokenStorage.accessToken;
    final sentRefreshToken = TokenStorage.refreshToken;
    late final http.Response response;
    try {
      final headers = _headers(sentAccessToken);
      switch (method) {
        case "GET":
          response = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case "POST":
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        case "PUT":
          response = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
        case "DELETE":
          response = await http
              .delete(uri, headers: headers, body: encoded)
              .timeout(_timeout);
          break;
      }
    } on TimeoutException catch (error) {
      throw AppApiException(
        "O servidor demorou para responder",
        0,
        AppApiErrorType.timeout,
        error,
      );
    } on http.ClientException catch (error) {
      throw AppApiException(
        "Falha de conexão com o servidor",
        0,
        AppApiErrorType.connection,
        error,
      );
    } catch (error) {
      throw AppApiException(
        "Não foi possível concluir a requisição",
        0,
        AppApiErrorType.unexpected,
        error,
      );
    }

    final statusCode = response.statusCode;
    final successful = statusCode >= 200 && statusCode < 300;
    if (successful) {
      return _decodeResponse(response, successful: true);
    }

    final json = _decodeResponse(response, successful: false);
    final exception = _exceptionFromError(json, statusCode);
    if (exception.terminatesSession) {
      await _expireCapturedSession(
        generation: sentGeneration,
        accessToken: sentAccessToken,
        refreshToken: sentRefreshToken,
        message: _terminalSessionMessage(exception.code),
      );
      throw exception;
    }

    if (statusCode == 401 && retry) {
      final currentGeneration = TokenStorage.sessionGeneration;
      final currentAccessToken = TokenStorage.accessToken;
      if (currentGeneration != sentGeneration) {
        throw _sessionChanged();
      }

      final tokenWasAlreadyRenewed = sentAccessToken != null &&
          currentAccessToken != null &&
          currentAccessToken != sentAccessToken;
      if (!tokenWasAlreadyRenewed) {
        await _refreshOnce();
      }
      if (!TokenStorage.isCurrentSession(sentGeneration)) {
        throw _sessionChanged();
      }
      return _request(method, path, body: body, retry: false);
    }

    if (statusCode == 401) {
      await _expireCapturedSession(
        generation: sentGeneration,
        accessToken: sentAccessToken,
        refreshToken: sentRefreshToken,
        message: "Sua sessão expirou. Entre novamente para continuar.",
      );
    }
    throw exception;
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required bool successful,
  }) {
    final raw = response.body.trim();
    if (raw.isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      if (successful) {
        throw AppApiException(
          "O servidor retornou uma resposta inválida",
          response.statusCode,
          AppApiErrorType.invalidResponse,
          error,
        );
      }
      return <String, dynamic>{};
    }

    if (successful) {
      throw AppApiException(
        "O servidor retornou uma resposta inválida",
        response.statusCode,
        AppApiErrorType.invalidResponse,
      );
    }
    return <String, dynamic>{};
  }

  static String _errorMessage(Map<String, dynamic> json, int statusCode) {
    final error = json["error"];
    if (error is Map) {
      final nested = error["message"] ?? error["error"];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString();
      }
    } else if (error != null && error.toString().trim().isNotEmpty) {
      return error.toString();
    }

    final message = json["message"];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }
    return "Erro $statusCode";
  }

  static String? _errorCode(Map<String, dynamic> json) {
    final direct = json["code"];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final error = json["error"];
    if (error is Map) {
      final nested = error["code"];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString().trim();
      }
    }
    return null;
  }

  static Object? _errorDetails(Map<String, dynamic> json) {
    if (json.containsKey("details")) return json["details"];
    final error = json["error"];
    if (error is Map && error.containsKey("details")) {
      return error["details"];
    }
    return null;
  }

  static AppApiException _exceptionFromError(
    Map<String, dynamic> json,
    int statusCode,
  ) {
    return AppApiException(
      _errorMessage(json, statusCode),
      statusCode,
      _errorTypeForStatus(statusCode),
      null,
      _errorCode(json),
      _errorDetails(json),
    );
  }

  static String _terminalSessionMessage(String? code) {
    switch (code?.toUpperCase()) {
      case "ACCOUNT_BANNED":
        return "Sua conta foi banida. Entre em contato com o suporte se precisar de ajuda.";
      case "ACCOUNT_SUSPENDED":
        return "Sua conta está suspensa temporariamente. Entre com outra conta ou tente novamente após o período de suspensão.";
      case "ACCOUNT_UNAVAILABLE":
        return "Esta conta está indisponível. Entre com outra conta para continuar.";
      default:
        return "Sua sessão expirou. Entre novamente para continuar.";
    }
  }

  static AppApiErrorType _errorTypeForStatus(int statusCode) {
    if (statusCode == 401) return AppApiErrorType.unauthorized;
    if (statusCode >= 500) return AppApiErrorType.server;
    return AppApiErrorType.client;
  }

  static Map<String, dynamic>? _optionalMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw AppApiException(
      "O servidor retornou '$key' em formato inválido",
      0,
      AppApiErrorType.invalidResponse,
    );
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = _optionalMap(json, key);
    if (value != null) return value;
    throw AppApiException(
      "O servidor não retornou '$key'",
      0,
      AppApiErrorType.invalidResponse,
    );
  }

  static List<dynamic> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return <dynamic>[];
    if (value is List) return List<dynamic>.from(value);
    throw AppApiException(
      "O servidor retornou '$key' em formato inválido",
      0,
      AppApiErrorType.invalidResponse,
    );
  }

  // ── Perfil ──
  static Future<Map<String, dynamic>?> getMyProfile() async {
    final json = await _request("GET", "/me/profile");
    return _optionalMap(json, "profile");
  }

  static Future<Map<String, dynamic>> upsertProfile(
    Map<String, dynamic> data,
  ) async {
    final json = await _request("PUT", "/me/profile", body: data);
    return _requiredMap(json, "profile");
  }

  /// Envia uma foto (base64) e retorna a URL pública.
  static Future<String> uploadPhoto(String base64, {String ext = "jpg"}) async {
    final json = await _request(
      "POST",
      "/me/photos",
      body: {"image": base64, "ext": ext},
    );
    return (json["url"] ?? "").toString();
  }

  // ── Descoberta / Match ──
  static Future<Map<String, dynamic>> getDiscovery(
      [Map<String, String>? filters]) async {
    var path = "/discovery";
    if (filters != null && filters.isNotEmpty) {
      final query = filters.entries
          .where((entry) => entry.value.isNotEmpty)
          .map(
            (entry) => "${entry.key}=${Uri.encodeQueryComponent(entry.value)}",
          )
          .join("&");
      if (query.isNotEmpty) path = "$path?$query";
    }
    return _request("GET", path);
  }

  static Future<Map<String, dynamic>> swipe(
    String toUserId,
    String type, {
    String? note,
  }) {
    return _request(
      "POST",
      "/swipe",
      body: {
        "toUserId": toUserId,
        "type": type,
        if (note != null && note.trim().isNotEmpty) "note": note.trim(),
      },
    );
  }

  /// Desfaz o último swipe (Rewind). Lança AppApiException 403 se for premium-only.
  static Future<Map<String, dynamic>> undoSwipe() =>
      _request("POST", "/swipe/undo");

  /// Ativa o Turbo/Boost (consome 1 boost).
  static Future<Map<String, dynamic>> activateBoost() =>
      _request("POST", "/me/boost");

  /// Liga/desliga o modo incógnito.
  static Future<Map<String, dynamic>> setIncognito(bool enabled) => _request(
        "POST",
        "/me/incognito",
        body: {"enabled": enabled},
      );

  /// Verso do dia (público).
  static Future<Map<String, dynamic>?> getDailyVerse() async {
    final json = await _request("GET", "/config/verse");
    return _optionalMap(json, "verse");
  }

  /// Lista de versos ativos (público) — usada para rotacionar no app.
  static Future<List<Map<String, dynamic>>> getVerses() async {
    try {
      final json = await _request("GET", "/config/verses");
      return _list(json, "verses")
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Configuração de anúncios (AdMob) — pública, lida em tempo real.
  static Future<Map<String, dynamic>> getAdsConfig() =>
      _request("GET", "/config/ads");

  static Future<List<dynamic>> getMatches() async {
    final json = await _request("GET", "/matches");
    return _list(json, "matches");
  }

  // ── Curtidas (matches + quem te curtiu, gated por premium) ──
  static Future<Map<String, dynamic>> getLikes() => _request("GET", "/likes");

  /// Top Picks — melhores perfis por compatibilidade.
  static Future<List<dynamic>> getTopPicks() async {
    final json = await _request("GET", "/top-picks");
    return _list(json, "picks");
  }

  /// Card público de um usuário (para abrir o perfil pelo chat).
  static Future<Map<String, dynamic>?> getUserCard(String userId) async {
    final json = await _request("GET", "/users/$userId/profile");
    return _optionalMap(json, "user");
  }

  /// Estado VIP, limites de Super Like, saldos (Super Likes extras, Boosts,
  /// créditos), se o usuário está sem anúncios e o estado real do incógnito.
  static Future<Map<String, dynamic>> getStats() async {
    final stats = await _request("GET", "/me/stats");
    // O servidor desligou o incógnito agora (o VIP acabou): o app avisa.
    if (stats["incognitoDisabled"] == true) RealtimeBus.incognitoTurnedOff();
    return stats;
  }

  // ── Recompensas por anúncio premiado ──
  /// Ofertas ativas + uso do dia (limites, espera e disponibilidade).
  static Future<Map<String, dynamic>> getRewards() =>
      _request("GET", "/me/rewards");

  /// Reserva a recompensa antes de exibir o anúncio. Retorna
  /// {claimId, expiresAt, reward, ssv: {userId, customData}}.
  static Future<Map<String, dynamic>> startReward(String rewardId) =>
      _request("POST", "/me/rewards/$rewardId/claims");

  /// Avisa que o anúncio terminou (e consulta o andamento). Retorna
  /// {status: PENDING | GRANTED | EXPIRED, kind, amount}.
  static Future<Map<String, dynamic>> completeReward(String claimId) =>
      _request("POST", "/me/rewards/claims/$claimId/complete");

  // ── Device / Push (FCM) ──
  static Future<void> registerDevice(
    String token, {
    String platform = "android",
  }) async {
    await _request(
      "POST",
      "/devices",
      body: {"token": token, "platform": platform},
    );
  }

  static Future<void> removeDevice(String token) async {
    await _request("DELETE", "/devices", body: {"token": token});
  }

  /// DELETE isolado para logout: usa a credencial capturada e nunca renova ou
  /// altera a sessão enquanto uma requisição tardia termina em background.
  static Future<void> removeDeviceForCleanup(
    String token, {
    required String accessToken,
  }) async {
    final normalizedToken = token.trim();
    final normalizedAccessToken = accessToken.trim();
    if (normalizedToken.isEmpty || normalizedAccessToken.isEmpty) {
      throw AppApiException(
        "Token de device ou credencial inválida",
        0,
        AppApiErrorType.invalidRequest,
      );
    }

    late final http.Response response;
    try {
      response = await http
          .delete(
            _u("/devices"),
            headers: _headers(normalizedAccessToken),
            body: jsonEncode({"token": normalizedToken}),
          )
          .timeout(_timeout);
    } on TimeoutException catch (error) {
      throw AppApiException(
        "O servidor demorou para remover o device",
        0,
        AppApiErrorType.timeout,
        error,
      );
    } on http.ClientException catch (error) {
      throw AppApiException(
        "Falha de conexão ao remover o device",
        0,
        AppApiErrorType.connection,
        error,
      );
    } catch (error) {
      throw AppApiException(
        "Não foi possível remover o device",
        0,
        AppApiErrorType.unexpected,
        error,
      );
    }

    final successful = response.statusCode >= 200 && response.statusCode < 300;
    if (successful) {
      _decodeResponse(response, successful: true);
      return;
    }
    final json = _decodeResponse(response, successful: false);
    throw _exceptionFromError(json, response.statusCode);
  }

  /// Registra que o usuário tocou numa notificação de campanha (estatística do painel).
  static Future<void> reportNotificationClick(String broadcastId) async {
    await _request(
      "POST",
      "/notifications/click",
      body: {"broadcastId": broadcastId},
    );
  }

  static Future<void> setOnline(bool online) async {
    await _request("POST", "/me/online", body: {"isOnline": online});
  }

  /// Atualiza a localização (GPS) do usuário para refinar a distância.
  static Future<void> updateLocation(
    double lat,
    double lng, {
    String? addressText,
  }) async {
    await _request(
      "PUT",
      "/me/location",
      body: {
        "latitude": lat,
        "longitude": lng,
        if (addressText != null) "addressText": addressText,
      },
    );
  }

  /// Solicita exclusão da conta (LGPD).
  static Future<void> requestAccountDeletion() async {
    await _request("POST", "/me/delete-request");
  }

  /// Bloqueia um usuário.
  static Future<void> blockUser(String blockedId) async {
    await _request("POST", "/blocks", body: {"blockedId": blockedId});
  }

  /// Denuncia um usuário.
  static Future<void> reportUser(String reportedId, String reason) async {
    await _request(
      "POST",
      "/reports",
      body: {"reportedId": reportedId, "reason": reason},
    );
  }

  // ── Chat (REST; tempo real via socket) ──
  static Future<List<dynamic>> getHistory(
    String matchId, {
    String? after,
  }) async {
    final query = after != null ? "?after=${Uri.encodeComponent(after)}" : "";
    final json = await _request(
      "GET",
      "/matches/$matchId/messages$query",
    );
    return _list(json, "messages");
  }

  static Future<void> markRead(String matchId) async {
    await _request("POST", "/matches/$matchId/messages/read");
  }

  /// Envia uma mensagem via REST (confiável) e retorna a mensagem criada.
  static Future<Map<String, dynamic>> sendMessage(
    String matchId,
    String content, {
    String type = "TEXT",
  }) async {
    final json = await _request(
      "POST",
      "/matches/$matchId/messages",
      body: {"content": content, "type": type},
    );
    return _requiredMap(json, "message");
  }

  // ── Presentes ──
  /// Catálogo público de presentes ativos ({gifts}).
  static Future<Map<String, dynamic>> getStore() =>
      _request("GET", "/config/store");

  /// Lista de presentes ativos.
  static Future<List<dynamic>> getGifts() async {
    final json = await _request("GET", "/config/store");
    return _list(json, "gifts");
  }

  /// Envia um presente no chat (debita créditos). Retorna {message, credits}.
  static Future<Map<String, dynamic>> sendGift(
    String matchId,
    String giftId,
  ) =>
      _request(
        "POST",
        "/matches/$matchId/gifts",
        body: {"giftId": giftId},
      );

  // ── Fotos privadas ──
  static Future<void> requestPhotoAccess(String ownerId) async {
    await _request(
      "POST",
      "/photo-access/request",
      body: {"ownerId": ownerId},
    );
  }

  static Future<void> decidePhotoAccess(
    String requestId,
    bool approve,
  ) async {
    await _request(
      "POST",
      "/photo-access/$requestId/decide",
      body: {"approve": approve},
    );
  }

  static Future<String?> canSeePhotos(String ownerId) async {
    final json = await _request("GET", "/photo-access/can-see/$ownerId");
    return json["canSee"] == true ? "APPROVED" : json["status"]?.toString();
  }

  static Future<List<String>> getLockedPhotos(String ownerId) async {
    final json = await _request("GET", "/users/$ownerId/locked-photos");
    return _list(json, "photos").map((item) => item.toString()).toList();
  }
}
