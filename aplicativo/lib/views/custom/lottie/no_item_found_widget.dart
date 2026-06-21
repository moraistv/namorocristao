import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mioamoreapp/helpers/constants.dart';

class NoItemFoundWidget extends StatelessWidget {
  final String? text;
  final bool isSmall;
  const NoItemFoundWidget({
    super.key,
    this.text,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LottieBuilder.asset(
          lottieNoItemFound,
          height: isSmall
              ? MediaQuery.of(context).size.width * 0.3
              : MediaQuery.of(context).size.width * 0.5,
          alignment: Alignment.center,
        ),
        if (text != null)
          Padding(
            padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
            child: Text(
              text!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                shadows: const [
                  Shadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}
