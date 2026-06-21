import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/date_formater.dart';
import 'package:mioamoreapp/models/banned_user_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';

class UserIsBannedPage extends ConsumerWidget {
  final BannedUserModel bannedUserModel;
  const UserIsBannedPage({super.key, required this.bannedUserModel});

  @override
  Widget build(BuildContext context, ref) {
    final int daysOfBan =
        bannedUserModel.bannedUntil.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banned!'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You are banned!',
              style: TextStyle(fontSize: 30),
            ),
            bannedUserModel.isLifetimeBan
                ? const Column(
                    children: [
                      SizedBox(height: 24),
                      Text(
                        'You are banned for life!\n'
                        'You can contact us to appeal the ban.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                    ],
                  )
                : Column(
                    children: [
                      const SizedBox(height: 24),
                      Text('You are banned for $daysOfBan days'),
                      const SizedBox(height: 8),
                      Text(
                          "Try again on ${DateFormatter.toYearMonthDay2(bannedUserModel.bannedUntil)}"),
                      const SizedBox(height: 24),
                    ],
                  ),
            CustomButton(
              text: "Logout",
              onPressed: () async {
                EasyLoading.show(status: 'Logging out...');
                await ref.read(authProvider).signOut();
                EasyLoading.dismiss();
              },
            )
          ],
        ),
      ),
    );
  }
}
