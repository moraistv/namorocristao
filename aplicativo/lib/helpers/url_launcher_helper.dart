import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  UrlLauncherHelper._();

  static void launchURL(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      EasyLoading.showToast('Could not launch $url',
          toastPosition: EasyLoadingToastPosition.bottom);
    }
  }
}
