import 'package:flutter/material.dart';

class CustomHeadLine extends StatelessWidget {
  final String text;
  final Color firstPartColor;
  final Color secondPartColor;
  const CustomHeadLine({
    super.key,
    required this.text,
    this.firstPartColor = Colors.black,
    required this.secondPartColor,
  });

  @override
  Widget build(BuildContext context) {
    final textLength = text.length;
    final firstPart = text.substring(0, textLength ~/ 2);
    final secondPart = text.substring(textLength ~/ 2);

    final textStyle = Theme.of(context)
        .textTheme
        .headlineSmall!
        .copyWith(fontWeight: FontWeight.bold);

    return Text.rich(
      TextSpan(
        text: firstPart,
        style: textStyle.copyWith(color: firstPartColor),
        children: [
          TextSpan(
            text: secondPart,
            style: textStyle.copyWith(color: secondPartColor),
          ),
        ],
      ),
    );
  }
}
