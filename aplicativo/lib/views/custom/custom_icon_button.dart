import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/constants.dart';

class CustomIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? backgroundColor;

  const CustomIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.padding,
    this.margin,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
        splashColor: color?.withOpacity(0.3) ?? Colors.black38,
        onTap: onPressed,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultNumericValue),
            color: backgroundColor ??
                color?.withOpacity(0.1) ??
                Colors.black.withOpacity(0.07),
          ),
          child: Icon(
            icon,
            color: color ?? Colors.black54,
          ),
        ),
      ),
    );
  }
}
