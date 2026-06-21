import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/models/account_delete_request_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/account_delete_request_provider.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/security/blocking_page.dart';
import 'package:mioamoreapp/views/settings/verification/verification_steps.dart';

class SecurityAndPrivacyLandingPage extends ConsumerWidget {
  const SecurityAndPrivacyLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileFutureProvider);

    return user.when(
      data: (data) {
        return data == null
            ? const ErrorPage()
            : SecurityAndPrivacyPage(user: data);
      },
      error: (_, __) => const ErrorPage(),
      loading: () => const LoadingPage(),
    );
  }
}

class SecurityAndPrivacyPage extends ConsumerStatefulWidget {
  final UserProfileModel user;
  const SecurityAndPrivacyPage({super.key, required this.user});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SecurityAndPrivacyPageState();
}

class _SecurityAndPrivacyPageState
    extends ConsumerState<SecurityAndPrivacyPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security and Privacy'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Blocking'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BlockingPage()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('Verification Status'),
                  subtitle: Text(
                    widget.user.isVerified ? "Verified" : "Not Verified",
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            widget.user.isVerified ? Colors.green : Colors.red),
                  ),
                  onTap: (widget.user.isVerified)
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    GetVerifiedPage(user: widget.user)),
                          );
                        },
                ),
                const Divider(),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Danger Zone',
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Deleting your account will permanently delete all your data and you will not be able to recover it.\n\nHowever, You can reactivate your account by logging in again in 30 days of your account deletion request.',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Delete Account'),
                            content: const Text(
                                'Are you sure you want to delete your account?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  // Add delete Request!
                                  final currentUserRef =
                                      ref.read(currentUserStateProvider);

                                  if (currentUserRef != null) {
                                    final userId = currentUserRef.uid;
                                    final requestDate = DateTime.now();
                                    final deleteDate = requestDate
                                        .add(const Duration(days: 30));

                                    final AccountDeleteRequestModel request =
                                        AccountDeleteRequestModel(
                                      userId: userId,
                                      requestDate: requestDate,
                                      deleteDate: deleteDate,
                                    );

                                    EasyLoading.show(
                                        status: 'Deleting Account...');
                                    await AccountDeleteProvider
                                            .requestAccountDelete(request)
                                        .then((value) async {
                                      if (value) {
                                        await EasyLoading.dismiss();
                                        await ref
                                            .read(authProvider)
                                            .signOut()
                                            .then((value) async {
                                          Navigator.pop(context);
                                          Navigator.pop(context);
                                          Navigator.pop(context);
                                        });
                                      } else {
                                        await EasyLoading.showError(
                                            'Error Deleting Account');
                                      }
                                    });
                                  }
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Delete Account'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
