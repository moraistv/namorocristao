import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/country_code.dart';

final countryCodesProvider = FutureProvider<List<CountryCode>>((ref) async {
  final response = await rootBundle.loadString(countryCodeJson);
  return countryCodeFromJson(response);
});
