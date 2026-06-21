import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/constants.dart';

class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? text;
  final IconData? icon;
  final Widget? child;
  final bool isWhite;
  final Color? borderColor;

  const CustomButton({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.isWhite = false,
    this.borderColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final buttonTextStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
          color: isWhite ? Colors.black : Colors.white,
        );
    return InkWell(
      borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
      onTap: onPressed,
      splashColor: AppConstants.primaryColor,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
          gradient: !isWhite ? AppConstants.defaultGradient : null,
          color: isWhite ? Colors.white : null,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
          boxShadow: isWhite
              ? null
              : [
                  BoxShadow(
                    color: AppConstants.primaryColor.withOpacity(0.2),
                    blurRadius: AppConstants.defaultNumericValue * 2,
                    spreadRadius: AppConstants.defaultNumericValue / 4,
                    offset: const Offset(0, AppConstants.defaultNumericValue),
                  ),
                ],
        ),
        child: child ??
            (text == null && icon == null
                ? Text(
                    "Button",
                    textAlign: TextAlign.center,
                    style: buttonTextStyle,
                  )
                : text != null && icon != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            color: isWhite ? Colors.black : Colors.white,
                          ),
                          const SizedBox(
                              width: AppConstants.defaultNumericValue),
                          Text(
                            text!,
                            textAlign: TextAlign.center,
                            style: buttonTextStyle,
                          ),
                          const SizedBox(
                              width: AppConstants.defaultNumericValue),
                        ],
                      )
                    : text != null
                        ? Text(
                            text!,
                            textAlign: TextAlign.center,
                            style: buttonTextStyle,
                          )
                        : Icon(
                            icon!,
                            color: isWhite ? Colors.black : Colors.white,
                          )),
      ),
    );
  }
}
