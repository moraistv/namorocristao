import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/providers/block_user_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';

class BlockingPage extends ConsumerWidget {
  const BlockingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersFuture = ref.watch(blockedUsersFutureProvider);
    final allOtherUsersFuture = ref.watch(otherUsersWithoutBlockedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocking'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
              padding: EdgeInsets.all(AppConstants.defaultNumericValue),
              child: Text("This is the list of all the users you've blocked.")),
          const Divider(),
          Expanded(
            child: blockedUsersFuture.when(
              data: (data) {
                if (data.isEmpty) {
                  return const Center(
                    child: Text("You haven't blocked anyone yet."),
                  );
                } else {
                  return allOtherUsersFuture.when(
                    data: (users) {
                      return ListView.separated(
                        itemBuilder: (context, index) {
                          final blockedModel = data[index];
                          final user = users.firstWhere(
                              (user) => user.id == blockedModel.blockedUserId);

                          return ListTile(
                            title: Text(user.fullName),
                            leading: UserCirlePicture(
                                imageUrl: user.profilePicture, size: 35),
                            trailing: TextButton(
                              onPressed: () async {
                                await unblockUser(blockedModel.id)
                                    .then((value) {
                                  ref.invalidate(blockedUsersFutureProvider);
                                  ref.invalidate(otherUsersProvider);
                                });
                              },
                              child: const Text('Unblock'),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(),
                        itemCount: data.length,
                      );
                    },
                    error: (_, __) => const ErrorPage(),
                    loading: () => const LoadingPage(),
                  );
                }
              },
              error: (_, __) => const ErrorPage(),
              loading: () => const LoadingPage(),
            ),
          ),
        ],
      ),
    );
  }
}
