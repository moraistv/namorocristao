import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/others/webview_page.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppConstants.defaultNumericValue),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultNumericValue),
            child: CustomAppBar(
              leading: CustomIconButton(
                  icon: CupertinoIcons.back,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 1.5)),
              title: Center(
                  child: CustomHeadLine(
                text: 'FAQ',
                secondPartColor: AppConstants.primaryColor,
              )),
              trailing:
                  const SizedBox(width: AppConstants.defaultNumericValue * 2),
            ),
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          const Expanded(child: WebViewPage(url: faqUrl)),
        ],
      ),
    );
  }
}
