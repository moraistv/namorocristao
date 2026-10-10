import 'package:geolocator/geolocator.dart';
import 'package:mioamoreapp/services/app_api.dart';

class LocationCoordinates {
  final double latitude;
  final double longitude;

  const LocationCoordinates(this.latitude, this.longitude);
}

/// Pede permissão de localização e sincroniza coordenadas reais com a API.
class LocationService {
  LocationService._();

  static Future<LocationCoordinates?> coordinates({bool ask = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 12));
      return LocationCoordinates(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Tenta atualizar a localização. Retorna true se conseguiu.
  static Future<bool> refresh({
    bool ask = true,
    String? addressText,
  }) async {
    final current = await coordinates(ask: ask);
    if (current == null) return false;
    try {
      await AppApi.updateLocation(
        current.latitude,
        current.longitude,
        addressText: addressText,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Só checa se já temos permissão (sem perguntar).
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
