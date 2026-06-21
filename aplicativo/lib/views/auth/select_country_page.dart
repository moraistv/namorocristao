import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/providers/country_codes_provider.dart';
import 'package:mioamoreapp/views/auth/login_with_phone_page.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';

class SelectCountryPage extends ConsumerStatefulWidget {
  const SelectCountryPage({super.key});

  @override
  ConsumerState<SelectCountryPage> createState() => _SelectCountryPageState();
}

class _SelectCountryPageState extends ConsumerState<SelectCountryPage> {
  final _searchController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final countryCodesData = ref.watch(countryCodesProvider);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Select Country".toUpperCase()),
        ),
        body: countryCodesData.when(
          data: (data) {
            final filteredData = data
                .where((e) => e.name
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.defaultNumericValue),
                Container(
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 3),
                  margin: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultNumericValue),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(
                      AppConstants.defaultNumericValue,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'Search Country',
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.defaultNumericValue * 1.5),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultNumericValue),
                  child: CustomHeadLine(
                      text: "Countries",
                      secondPartColor: AppConstants.primaryColor),
                ),
                Expanded(
                  child: Scrollbar(
                    child: ListView(
                      children: filteredData
                          .map((e) => ListTile(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          LoginWithPhoneNumberPage(
                                              countryCode: e),
                                    ),
                                  );
                                },
                                title: Text(e.name),
                                trailing: Text(getFormattedCountryCode(e)),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (_, __) => const Center(child: Text("Error")),
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
    );
  }
}
