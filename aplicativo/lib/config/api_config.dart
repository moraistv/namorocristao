/// Configuração de acesso à API do Namoro Cristão.
class ApiConfig {
  ApiConfig._();

  /// URL pública da API (VPS, atrás do domínio com HTTPS).
  static const String baseUrl = "https://api.mypair.app/api";

  /// Web Client ID do OAuth (Google), usado como serverClientId no login Google.
  /// Pega no google-services.json (client com client_type 3) OU no Google Cloud
  /// Console após adicionar o SHA-1 no Firebase. Deixe "" para desabilitar.
  static const String googleServerClientId = "";
}
