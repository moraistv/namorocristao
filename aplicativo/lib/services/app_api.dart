import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mioamoreapp/config/api_config.dart';
import 'package:mioamoreapp/services/token_storage.dart';

class AppApiException implements Exception {
  final String message;
  final int statusCode;
  AppApiException(this.message, [this.statusCode = 0]);
  @override
  String toString() => message;
}

/// Cliente autenticado da API (perfil, descoberta, match, chat).
class AppApi {
  AppApi._();

  static const _timeout = Duration(seconds: 20);
  static Uri _u(String path) => Uri.parse("${ApiConfig.baseUrl}$path");

  static Map<String, String> _headers() => {
        "Content-Type": "application/json",
        if (TokenStorage.accessToken != null)
          "Authorization": "Bearer ${TokenStorage.accessToken}",
      };

  static Future<bool> _tryRefresh() async {
    final refresh = TokenStorage.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await http
          .post(_u("/auth/refresh"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"refreshToken": refresh}))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        await TokenStorage.updateTokens(j["accessToken"], j["refreshToken"]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    http.Response res;
    try {
      final uri = _u(path);
      final headers = _headers();
      final encoded = body != null ? jsonEncode(body) : null;
      switch (method) {
        case "GET":
          res = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case "POST":
          res = await http.post(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case "PUT":
          res = await http.put(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case "DELETE":
          res = await http.delete(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        default:
          throw AppApiException("Método inválido");
      }
    } catch (e) {
      throw AppApiException("Falha de conexão com o servidor");
    }

    if (res.statusCode == 401 && retry) {
      if (await _tryRefresh()) {
        return _request(method, path, body: body, retry: false);
      }
    }

    final json = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    throw AppApiException(
        (json["error"] ?? "Erro ${res.statusCode}").toString(), res.statusCode);
  }

  // ── Perfil ──
  static Future<Map<String, dynamic>?> getMyProfile() async {
    final j = await _request("GET", "/me/profile");
    return j["profile"] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> upsertProfile(Map<String, dynamic> data) async {
    final j = await _request("PUT", "/me/profile", body: data);
    return j["profile"] as Map<String, dynamic>;
  }

  /// Envia uma foto (base64) e retorna a URL pública.
  static Future<String> uploadPhoto(String base64, {String ext = "jpg"}) async {
    final j = await _request("POST", "/me/photos", body: {"image": base64, "ext": ext});
    return (j["url"] ?? "").toString();
  }

  // ── Descoberta / Match ──
  static Future<Map<String, dynamic>> getDiscovery(
      [Map<String, String>? filters]) async {
    var path = "/discovery";
    if (filters != null && filters.isNotEmpty) {
      final q = filters.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => "${e.key}=${Uri.encodeQueryComponent(e.value)}")
          .join("&");
      if (q.isNotEmpty) path = "$path?$q";
    }
    return await _request("GET", path) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> swipe(String toUserId, String type,
      {String? note}) async {
    return await _request("POST", "/swipe", body: {
      "toUserId": toUserId,
      "type": type,
      if (note != null && note.trim().isNotEmpty) "note": note.trim(),
    }) as Map<String, dynamic>;
  }

  /// Desfaz o último swipe (Rewind). Lança AppApiException 403 se for premium-only.
  static Future<Map<String, dynamic>> undoSwipe() async {
    return await _request("POST", "/swipe/undo") as Map<String, dynamic>;
  }

  /// Ativa o Turbo/Boost (consome 1 boost).
  static Future<Map<String, dynamic>> activateBoost() async {
    return await _request("POST", "/me/boost") as Map<String, dynamic>;
  }

  /// Liga/desliga o modo incógnito.
  static Future<Map<String, dynamic>> setIncognito(bool enabled) async {
    return await _request("POST", "/me/incognito", body: {"enabled": enabled})
        as Map<String, dynamic>;
  }

  /// Resgata/concede um produto comprado (Google Play).
  static Future<Map<String, dynamic>> purchase(String productId) async {
    return await _request("POST", "/me/purchase", body: {"productId": productId})
        as Map<String, dynamic>;
  }

  /// Verso do dia (público).
  static Future<Map<String, dynamic>?> getDailyVerse() async {
    final j = await _request("GET", "/config/verse");
    return (j["verse"] as Map?)?.cast<String, dynamic>();
  }

  /// Configuração de anúncios (AdMob) — pública, lida em tempo real.
  static Future<Map<String, dynamic>> getAdsConfig() async {
    return await _request("GET", "/config/ads") as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getMatches() async {
    final j = await _request("GET", "/matches");
    return (j["matches"] as List<dynamic>?) ?? [];
  }

  // ── Curtidas (matches + quem te curtiu, gated por premium) ──
  static Future<Map<String, dynamic>> getLikes() async {
    return await _request("GET", "/likes") as Map<String, dynamic>;
  }

  /// Top Picks — melhores perfis por compatibilidade.
  static Future<List<dynamic>> getTopPicks() async {
    final j = await _request("GET", "/top-picks");
    return (j["picks"] as List<dynamic>?) ?? [];
  }

  /// Card público de um usuário (para abrir o perfil pelo chat).
  static Future<Map<String, dynamic>?> getUserCard(String userId) async {
    final j = await _request("GET", "/users/$userId/profile");
    return (j["user"] as Map?)?.cast<String, dynamic>();
  }

  static Future<bool> setPremium(bool active) async {
    final j = await _request("POST", "/me/premium", body: {"active": active});
    return j["isPremium"] == true;
  }

  /// Assina um plano VIP (monthly | quarterly | yearly).
  static Future<Map<String, dynamic>> subscribePlan(String plan) async {
    return await _request("POST", "/me/premium", body: {"plan": plan})
        as Map<String, dynamic>;
  }

  /// Estado premium + limites de super like + planos disponíveis.
  static Future<Map<String, dynamic>> getStats() async {
    return await _request("GET", "/me/stats") as Map<String, dynamic>;
  }

  // ── Device / Push (FCM) ──
  static Future<void> registerDevice(String token,
      {String platform = "android"}) async {
    try {
      await _request("POST", "/devices",
          body: {"token": token, "platform": platform});
    } catch (_) {}
  }

  static Future<void> removeDevice(String token) async {
    try {
      await _request("DELETE", "/devices", body: {"token": token});
    } catch (_) {}
  }

  /// Registra que o usuário tocou numa notificação de campanha (estatística do painel).
  static Future<void> reportNotificationClick(String broadcastId) async {
    try {
      await _request("POST", "/notifications/click",
          body: {"broadcastId": broadcastId});
    } catch (_) {}
  }

  static Future<void> setOnline(bool online) async {
    try {
      await _request("POST", "/me/online", body: {"isOnline": online});
    } catch (_) {}
  }

  /// Atualiza a localização (GPS) do usuário para refinar a distância.
  static Future<void> updateLocation(
      double lat, double lng, {String? addressText}) async {
    try {
      await _request("PUT", "/me/location", body: {
        "latitude": lat,
        "longitude": lng,
        if (addressText != null) "addressText": addressText,
      });
    } catch (_) {}
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
    await _request("POST", "/reports",
        body: {"reportedId": reportedId, "reason": reason});
  }

  // ── Chat (REST; tempo real via socket) ──
  static Future<List<dynamic>> getHistory(String matchId) async {
    final j = await _request("GET", "/matches/$matchId/messages");
    return (j["messages"] as List<dynamic>?) ?? [];
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
    final j = await _request("POST", "/matches/$matchId/messages",
        body: {"content": content, "type": type});
    return (j["message"] as Map).cast<String, dynamic>();
  }

  // ── Loja / Presentes ──
  /// Catálogo público (planos, pacotes, presentes e valor do crédito).
  static Future<Map<String, dynamic>> getStore() async {
    return await _request("GET", "/config/store") as Map<String, dynamic>;
  }

  /// Lista de presentes ativos.
  static Future<List<dynamic>> getGifts() async {
    final j = await _request("GET", "/config/store");
    return (j["gifts"] as List<dynamic>?) ?? [];
  }

  /// Envia um presente no chat (debita créditos). Retorna {message, credits}.
  static Future<Map<String, dynamic>> sendGift(String matchId, String giftId) async {
    return await _request("POST", "/matches/$matchId/gifts",
        body: {"giftId": giftId}) as Map<String, dynamic>;
  }

  // ── Fotos privadas ──
  static Future<void> requestPhotoAccess(String ownerId) async {
    await _request("POST", "/photo-access/request", body: {"ownerId": ownerId});
  }

  static Future<void> decidePhotoAccess(String requestId, bool approve) async {
    await _request("POST", "/photo-access/$requestId/decide", body: {"approve": approve});
  }

  static Future<String?> canSeePhotos(String ownerId) async {
    final j = await _request("GET", "/photo-access/can-see/$ownerId");
    return j["canSee"] == true ? "APPROVED" : j["status"]?.toString();
  }

  static Future<List<String>> getLockedPhotos(String ownerId) async {
    final j = await _request("GET", "/users/$ownerId/locked-photos");
    return ((j["photos"] as List?) ?? []).map((e) => e.toString()).toList();
  }
}
