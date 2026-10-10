import 'package:mioamoreapp/config/api_config.dart';

/// URLs públicas derivadas da base REST sem alterar hostname ou outros paths.
class PublicUrl {
  PublicUrl._();

  /// Origem usada por mídia e Socket.IO. Remove somente o sufixo de path `/api`.
  static Uri get apiOriginUri {
    final base = Uri.parse(ApiConfig.baseUrl);
    var path = base.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('/api')) {
      path = path.substring(0, path.length - '/api'.length);
    }
    return base.replace(path: path, query: null, fragment: null);
  }

  static String get apiOrigin => apiOriginUri.toString();

  /// Resolve mídia relativa na origem pública e corrige hosts antigos de uploads.
  static String media(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;

    final uri = Uri.tryParse(value);
    if (uri == null) return value;

    final uploadsIndex = uri.path.indexOf('/uploads/');
    if (uploadsIndex >= 0) {
      return apiOriginUri
          .replace(
            path: uri.path.substring(uploadsIndex),
            query: uri.hasQuery ? uri.query : null,
            fragment: uri.hasFragment ? uri.fragment : null,
          )
          .toString();
    }

    if (uri.hasScheme || uri.hasAuthority) return value;

    final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
    return apiOriginUri
        .replace(
          path: path,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  static String? maybeMedia(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return media(raw);
  }
}
