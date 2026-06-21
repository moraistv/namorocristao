/// Configuração de acesso à API do Namoro Cristão.
class ApiConfig {
  ApiConfig._();

  /// IP do PC (servidor da API) na rede local. O celular acessa por aqui.
  /// Em produção, trocar pela URL pública da VPS (https).
  static const String baseUrl = "http://192.168.3.253:3333/api";
}
