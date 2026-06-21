import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:http/http.dart' as http;
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/get_location_prediction.dart';
import 'package:mioamoreapp/models/location_prediction_model.dart';
import 'package:mioamoreapp/models/user_account_settings_model.dart';
import 'package:mioamoreapp/providers/country_codes_provider.dart';
import 'package:mioamoreapp/providers/get_current_location_provider.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';

class SetUserLocation extends ConsumerStatefulWidget {
  const SetUserLocation({super.key});

  @override
  ConsumerState<SetUserLocation> createState() => _SetUserLocationState();
}

class _SetUserLocationState extends ConsumerState<SetUserLocation> {
  final _searchController = TextEditingController();

  final List<Prediction> _predictions = [];

  @override
  void initState() {
    _searchController.addListener(() async {
      if (_searchController.text.isNotEmpty &&
          _searchController.text.length > 2) {
        final results =
            await getLocationPrediction(_searchController.text.trim());
        if (results != null) {
          setState(() {
            _predictions.clear();
            _predictions.addAll(results);
          });
        }
      } else {
        _predictions.clear();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocationProviderProvider =
        ref.watch(getCurrentLocationProviderProvider);

    final countryCodesData = ref.watch(countryCodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Location"),
      ),
      body: countryCodesData.when(
          data: (data) {
            return currentLocationProviderProvider.when(
                data: (location) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (location != null)
                          ListTile(
                            onTap: () {
                              Navigator.of(context).pop(location);
                            },
                            title: const Text("Current Location"),
                            subtitle: Text(location.addressText),
                            leading: const Icon(Icons.location_on),
                            minLeadingWidth: 0,
                          ),
                        if (location != null) const Divider(height: 0),
                        if (location != null)
                          Padding(
                            padding: const EdgeInsets.all(
                                AppConstants.defaultNumericValue),
                            child: Text(
                              "Or Find another location",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (location == null)
                          const SizedBox(
                              height: AppConstants.defaultNumericValue),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.defaultNumericValue),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: "Search for a location",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(
                                      AppConstants.defaultNumericValue),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_predictions.isEmpty &&
                            _searchController.text.isNotEmpty)
                          const SizedBox(
                            height: 300,
                            child: Center(
                              child: Text("No results found"),
                            ),
                          ),
                        if (_predictions.isEmpty &&
                            _searchController.text.isEmpty)
                          const SizedBox(
                            height: 300,
                            child: Center(
                              child: Text("Find a location"),
                            ),
                          ),
                        ..._predictions.map(
                          (e) {
                            return e.description != null
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        onTap: () async {
                                          EasyLoading.show(
                                              status: "Please wait...");

                                          await getLocationFromPlaceID(
                                                  e.placeId!)
                                              .then((value) {
                                            if (value != null) {
                                              final userLocation = UserLocation(
                                                addressText: e.description!,
                                                latitude: value.lat,
                                                longitude: value.long,
                                              );
                                              EasyLoading.dismiss();

                                              Navigator.of(context)
                                                  .pop(userLocation);
                                            } else {
                                              EasyLoading.dismiss();
                                              Navigator.of(context).pop();
                                            }
                                          });
                                        },
                                        title: Text(e.description!),
                                      ),
                                      const Divider(height: 0),
                                    ],
                                  )
                                : const SizedBox();
                          },
                        )
                      ],
                    ),
                  );
                },
                error: (_, e) {
                  return const ErrorPage();
                },
                loading: () => const LoadingPage());
          },
          error: (_, e) {
            return const ErrorPage();
          },
          loading: () => const LoadingPage()),
    );
  }
}

Future<LocationComponents?> getLocationFromPlaceID(String placeId) async {
  final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=$locationApiKey");

  var response = await http.get(url, headers: {"Accept": "application/json"});

  if (response.statusCode == 200) {
    var data = json.decode(response.body);

    if (data["status"] != "OK") {
      return null;
    } else {
      double? lat = data["result"]["geometry"]["location"]["lat"];
      double? long = data["result"]["geometry"]["location"]["lng"];

      if (lat != null && long != null) {
        return LocationComponents(lat: lat, long: long);
      }
    }
  } else {
    return null;
  }
  return null;
}

class LocationComponents {
  double lat;
  double long;
  LocationComponents({
    required this.lat,
    required this.long,
  });
}
