import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/country_code.dart';
import 'package:mioamoreapp/views/auth/otp_page.dart';
import 'package:mioamoreapp/views/auth/select_country_page.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';

class LoginWithPhoneNumberPage extends ConsumerStatefulWidget {
  final CountryCode countryCode;
  const LoginWithPhoneNumberPage({
    super.key,
    required this.countryCode,
  });

  @override
  ConsumerState<LoginWithPhoneNumberPage> createState() =>
      _LoginWithPhoneNumberPageState();
}

class _LoginWithPhoneNumberPageState
    extends ConsumerState<LoginWithPhoneNumberPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  late CountryCode _countryCode;

  @override
  void initState() {
    _countryCode = widget.countryCode;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Login With Phone".toUpperCase()),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.defaultNumericValue),
                CustomHeadLine(
                    text: "My phone number is",
                    secondPartColor: AppConstants.primaryColor),
                const SizedBox(height: AppConstants.defaultNumericValue),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value!.isEmpty) {
                      return "Phone number is required";
                    }
                    return null;
                  },
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "Phone Number",
                    prefixIcon: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SelectCountryPage()),
                        );
                      },
                      child: Text(
                        getFormattedCountryCode(_countryCode),
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: AppConstants.primaryColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
                const SizedBox(height: AppConstants.defaultNumericValue),
                const Text("We'll send you a code to verify your phone number"),
                const SizedBox(height: AppConstants.defaultNumericValue * 2),
                CustomButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => OtpPage(
                                    phoneNumber: _countryCode.dialCode +
                                        _phoneController.text)));
                      }
                    },
                    text: "Next")
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String getFormattedCountryCode(CountryCode country) {
  return "${country.code} ${country.dialCode} ";
}
