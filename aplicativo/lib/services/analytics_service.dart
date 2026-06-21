import 'package:firebase_analytics/firebase_analytics.dart';

/// Google Analytics (via Firebase). Fica PRONTO mas seguro: só registra eventos
/// quando o Firebase estiver inicializado (precisa do google-services.json e do
/// Firebase.initializeApp — ligar quando publicar). Sem isso, é no-op silencioso.
class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics? _fa;
  static bool get ready => _fa != null;

  /// Chamado no boot. Se o Firebase não estiver configurado, fica desativado.
  static Future<void> init() async {
    try {
      _fa = FirebaseAnalytics.instance;
      await _fa!.logAppOpen();
    } catch (_) {
      _fa = null; // Firebase não inicializado → analytics desligado
    }
  }

  static void log(String name, [Map<String, Object>? params]) {
    try {
      _fa?.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  // Eventos-chave do app
  static void login(String method) => log("login", {"method": method});
  static void signUp(String method) => log("sign_up", {"method": method});
  static void swipe(String type) => log("swipe", {"type": type});
  static void match() => log("match");
  static void messageSent() => log("message_sent");
  static void giftSent(String giftId) => log("gift_sent", {"gift_id": giftId});
  static void purchase(String productId, String kind) =>
      log("purchase", {"product_id": productId, "kind": kind});
  static void boost() => log("boost_activated");
  static void superLike() => log("super_like");
  static void screen(String name) {
    try {
      _fa?.logScreenView(screenName: name);
    } catch (_) {}
  }
}
