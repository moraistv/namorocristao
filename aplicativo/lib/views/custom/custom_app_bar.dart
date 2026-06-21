import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/constants.dart';

class CustomAppBar extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? trailing;
  const CustomAppBar({
    super.key,
    this.leading,
    this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (leading != null) leading!,
        const SizedBox(width: AppConstants.defaultNumericValue),
        if (title != null) Expanded(child: title!),
        const SizedBox(width: AppConstants.defaultNumericValue),
        if (trailing != null) trailing!,
      ],
    );
  }
}
