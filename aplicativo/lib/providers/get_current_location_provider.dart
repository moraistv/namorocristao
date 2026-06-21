import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/models/location_result_model.dart';
import 'package:mioamoreapp/models/user_account_settings_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

String getLocationApiString(double lat, double long) {
  return "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$long&key=$locationApiKey";
}

final getCurrentLocationProviderProvider =
    FutureProvider<UserLocation?>((ref) async {
  try {
    final Position position = await _determineCurrentPosition();

    final api =
        Uri.parse(getLocationApiString(position.latitude, position.longitude));

    final response = await http.get(api);

    if (response.statusCode == 200) {
      final LocationResultModel resultModel =
          LocationResultModel.fromJson(response.body);

      if (resultModel.status == "OK" && resultModel.results.isNotEmpty) {
        final Result addressResult = resultModel.results.first;

        String? country;
        String? administrativeAreaLevel1;
        String? administrativeAreaLevel2;

        if (addressResult.addressComponents != null) {
          for (var component in addressResult.addressComponents!) {
            if (component.types.contains("country")) {
              country = component.longName;
            } else if (component.types
                .contains("administrative_area_level_1")) {
              administrativeAreaLevel1 = component.longName;
            } else if (component.types
                .contains("administrative_area_level_2")) {
              administrativeAreaLevel2 = component.longName;
            }
          }

          final String formattedAddress = getFormattedAddress(
              country, administrativeAreaLevel1, administrativeAreaLevel2);

          final UserLocation userLocation = UserLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              addressText: formattedAddress);

          debugPrint(formattedAddress);

          return userLocation;
        }
        return null;
      } else {
        return null;
      }
    } else {
      return null;
    }
  } catch (e) {
    EasyLoading.showToast(e.toString(),
        duration: const Duration(seconds: 3),
        toastPosition: EasyLoadingToastPosition.bottom);
    return null;
  }
});

Future<Position> _determineCurrentPosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.low,
    ),
  );
}

String getFormattedAddress(String? country, String? administrativeAreaLevel1,
    String? administrativeAreaLevel2) {
  String formattedAddress = "";

  if (administrativeAreaLevel2 != null) {
    formattedAddress += "$administrativeAreaLevel2, ";
  }
  if (administrativeAreaLevel1 != null) {
    formattedAddress += "$administrativeAreaLevel1, ";
  }
  if (country != null) {
    formattedAddress += country;
  }

  return formattedAddress;
}
