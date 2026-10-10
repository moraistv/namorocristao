import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  UrlLauncherHelper._();

  static Future<void> launchURL(Uri url) async {
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return;
      }
    } catch (_) {}
    EasyLoading.showToast(
      'Não foi possível abrir $url',
      toastPosition: EasyLoadingToastPosition.bottom,
    );
  }
}
