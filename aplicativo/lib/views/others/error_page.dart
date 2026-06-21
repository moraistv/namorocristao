import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/main.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';

class ErrorPage extends ConsumerWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue * 2),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset(
                AppConstants.logo,
                width: MediaQuery.of(context).size.width * 0.4,
              ),
              const Spacer(),
              Text(
                "Something went wrong!",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: Colors.black87),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
              CustomButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LandingWidget(),
                    ),
                    (route) => false,
                  );
                },
                text: "Try again",
                icon: Icons.sync,
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
            ],
          ),
        ),
      ),
    );
  }
}
