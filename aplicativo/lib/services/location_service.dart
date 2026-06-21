import 'package:geolocator/geolocator.dart';
import 'package:mioamoreapp/services/app_api.dart';

/// Pede permissão de localização, obtém o GPS e atualiza no servidor
/// para refinar a distância entre os usuários.
class LocationService {
  LocationService._();

  /// Tenta atualizar a localização. Retorna true se conseguiu.
  /// [ask] = true pede a permissão ao usuário se ainda não tiver.
  static Future<bool> refresh({bool ask = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 12));

      await AppApi.updateLocation(pos.latitude, pos.longitude);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Só checa se já temos permissão (sem perguntar).
  static Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }
}
