import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/country_code.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/country_codes_provider.dart';
import 'package:mioamoreapp/providers/get_current_location_provider.dart';
import 'package:mioamoreapp/providers/version_provider.dart';
import 'package:mioamoreapp/views/auth/email_auth_page.dart';
import 'package:mioamoreapp/views/auth/login_with_phone_page.dart';
import 'package:mioamoreapp/views/auth/people_orbit.dart';
import 'package:mioamoreapp/views/auth/select_country_page.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final versionRef = ref.watch(versionProvider);
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue * 2),
          height: MediaQuery.of(context).size.height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: PeopleOrbit(
                      size: MediaQuery.of(context).size.width * 0.78,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue),
                  const Text(
                    "Namoro Cristão",
                    style: TextStyle(
                      color: Color(0xFF111D40),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue / 3),
                  Text(
                    "Conexões com propósito e fé",
                    style: TextStyle(
                      color: const Color(0xFF111D40).withOpacity(0.6),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: AppConstants.defaultNumericValue),

              //Google
              if (isGoogleAuthAvailable)
                LoginButton(
                  icon: Image.asset(googleLogo,
                      width: AppConstants.defaultNumericValue * 2),
                  onPressed: () async {
                    if (!kBackendReady) {
                      EasyLoading.showInfo(
                          'Login chega na próxima fase (API da VPS).');
                      return;
                    }
                    EasyLoading.show(status: 'Logging in...');
                    await ref.read(authProvider).signInWithGoogle();
                    EasyLoading.dismiss();
                  },
                  text: "Entrar com Google",
                ),
              if (isGoogleAuthAvailable)
                const SizedBox(height: AppConstants.defaultNumericValue),

              //E-mail (senha + código) — conectado à nossa API
              LoginButton(
                icon: Icon(
                  Icons.email_outlined,
                  color: AppConstants.primaryColor,
                  size: AppConstants.defaultNumericValue * 2,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmailAuthPage(),
                    ),
                  );
                },
                text: "Entrar com e-mail",
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),

              // //Twitter
              // if (isTwitterAuthAvailable)
              //   LoginButton(
              //     icon: Image.asset(twitterLogo,
              //         width: AppConstants.defaultNumericValue * 2),
              //     onPressed: () {
              //       EasyLoading.showInfo('Coming soon...');
              //     },
              //     text: "Log in with twitter",
              //   ),
              // if (isTwitterAuthAvailable)
              //   const SizedBox(height: AppConstants.defaultNumericValue),

              // //Apple
              // if (isAppleAuthAvailable)
              //   if (Platform.isIOS)
              //     LoginButton(
              //       icon: Image.asset(appleLogo,
              //           width: AppConstants.defaultNumericValue * 2),
              //       onPressed: () {
              //         EasyLoading.showInfo('Coming soon...');
              //       },
              //       text: "Log in with apple",
              //     ),
              // if (isAppleAuthAvailable)
              //   if (Platform.isIOS)
              //     const SizedBox(height: AppConstants.defaultNumericValue),

              //Phone
              if (isPhoneAuthAvailable)
                LoginButton(
                  icon: Icon(
                    CupertinoIcons.phone_circle_fill,
                    color: AppConstants.primaryColor,
                    size: AppConstants.defaultNumericValue * 2,
                  ),
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PhoneLoginLandingWidget(),
                      ),
                    );
                  },
                  text: "Log in with phone",
                ),
              if (isPhoneAuthAvailable)
                const SizedBox(height: AppConstants.defaultNumericValue),

              // Criar conta
              Padding(
                padding: const EdgeInsets.only(
                    top: AppConstants.defaultNumericValue / 2),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Não tem conta? ",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      TextSpan(
                        text: "Criar conta",
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(
                              color: AppConstants.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const EmailAuthPage(startInRegister: true),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppConstants.defaultNumericValue),
              versionRef.when(
                data: (data) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      data,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
                error: (error, stackTrace) => const SizedBox(),
                loading: () => const SizedBox(),
              ),

              // //
              //   TextButton(
              //     onPressed: () {},
              //     child: const Text(
              //       "Trouble logging in?",
              //       style:
              //           TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              //     ),
              //   ),
              //   const SizedBox(height: AppConstants.defaultNumericValue),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneLoginLandingWidget extends ConsumerWidget {
  const PhoneLoginLandingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countryCodesData = ref.watch(countryCodesProvider);
    final currentLocationProviderProvider =
        ref.watch(getCurrentLocationProviderProvider);

    return countryCodesData.when(
        data: (data) {
          return currentLocationProviderProvider.when(
              data: (location) {
                if (location != null) {
                  final List<CountryCode> countryCodes = data
                      .where((element) =>
                          location.addressText.contains(element.name))
                      .toList();

                  return countryCodes.isEmpty
                      ? const SelectCountryPage()
                      : LoginWithPhoneNumberPage(
                          countryCode: countryCodes.first);
                } else {
                  return const SelectCountryPage();
                }
              },
              error: (_, e) {
                return const ErrorPage();
              },
              loading: () => const LoadingPage());
        },
        error: (_, e) {
          return const ErrorPage();
        },
        loading: () => const LoadingPage());
  }
}

class LoginButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String text;
  const LoginButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      onPressed: onPressed,
      isWhite: true,
      borderColor: AppConstants.primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          icon,
          Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: AppConstants.defaultNumericValue),
        ],
      ),
    );
  }
}
