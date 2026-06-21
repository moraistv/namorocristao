import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/constants.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              CircularProgressIndicator.adaptive(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
            ],
          ),
        ),
      ),
    );
  }
}
