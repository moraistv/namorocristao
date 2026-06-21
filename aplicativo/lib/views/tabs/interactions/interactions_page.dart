import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_interaction_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/interaction_provider.dart';
import 'package:mioamoreapp/providers/match_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/custom/lottie/no_item_found_widget.dart';
import 'package:mioamoreapp/views/others/user_image_card.dart';

class InteractionsPage extends ConsumerStatefulWidget {
  const InteractionsPage({super.key});

  @override
  ConsumerState<InteractionsPage> createState() => _InteractionsPageState();
}

class _InteractionsPageState extends ConsumerState<InteractionsPage> {
  final _searchController = TextEditingController();

  bool _isSearchBarVisible = false;

  void onLongPressUserCard(String id) async {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Interaction'),
            content: const Text(
                'Are you sure you want to delete this user from your interactions?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await deleteInteraction(id).then((value) {
                    ref.invalidate(interactionFutureProvider);
                  });
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final interactions = ref.watch(interactionFutureProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                trailing: CustomIconButton(
                  icon: CupertinoIcons.question_circle,
                  onPressed: () {
                    EasyLoading.showInfo(
                        "Long press on a user to remove from your interactions.",
                        duration: const Duration(seconds: 4),
                        dismissOnTap: true);
                  },
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 1.5),
                ),
                title: Center(
                  child: CustomHeadLine(
                    text: 'Interactions',
                    secondPartColor: AppConstants.primaryColor,
                  ),
                ),
                leading: CustomIconButton(
                  icon: CupertinoIcons.search,
                  onPressed: () {
                    setState(() {
                      _isSearchBarVisible = !_isSearchBarVisible;
                      if (_isSearchBarVisible) {
                        _searchController.clear();
                      }
                    });
                  },
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue / 2),
            const Divider(height: 0),
            Expanded(
              child: interactions.when(
                data: (data) {
                  final otherUsers = ref.watch(otherUsersProvider);
                  final matchedUsersProvider = ref.watch(matchStreamProvider);

                  final List<UserProfileModel> usersWithoutMatched = [];

                  otherUsers.whenData((value) {
                    matchedUsersProvider.whenData((matchedUsers) {
                      matchedUsers
                          .removeWhere((element) => element.isMatched == false);

                      for (var user in value) {
                        if (!matchedUsers.any(
                            (element) => element.userIds.contains(user.id))) {
                          usersWithoutMatched.add(user);
                        }
                      }
                    });
                  });

                  final List<UserProfileModel> searchedUsers = [];

                  for (var value in usersWithoutMatched) {
                    if (value.fullName
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase())) {
                      searchedUsers.add(value);
                    }
                  }

                  final List<UserInteractionViewModel> likedUsers = [];
                  final List<UserInteractionViewModel> superLikedUsers = [];
                  final List<UserInteractionViewModel> dislikedUsers = [];

                  for (var user in searchedUsers) {
                    if (data.any((element) =>
                        element.intractToUserId == user.id &&
                        element.isLike == true)) {
                      final UserInteractionViewModel userInteractionViewModel =
                          UserInteractionViewModel(
                        user: user,
                        interaction: data.firstWhere((element) =>
                            element.intractToUserId == user.id &&
                            element.isLike == true),
                      );
                      likedUsers.add(userInteractionViewModel);
                    } else if (data.any((element) =>
                        element.intractToUserId == user.id &&
                        element.isSuperLike == true)) {
                      final UserInteractionViewModel userInteractionViewModel =
                          UserInteractionViewModel(
                        user: user,
                        interaction: data.firstWhere((element) =>
                            element.intractToUserId == user.id &&
                            element.isSuperLike == true),
                      );
                      superLikedUsers.add(userInteractionViewModel);
                    } else if (data.any((element) =>
                        element.intractToUserId == user.id &&
                        element.isDislike == true)) {
                      final UserInteractionViewModel userInteractionViewModel =
                          UserInteractionViewModel(
                        user: user,
                        interaction: data.firstWhere((element) =>
                            element.intractToUserId == user.id &&
                            element.isDislike == true),
                      );
                      dislikedUsers.add(userInteractionViewModel);
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TabBar(
                        labelColor: AppConstants.primaryColor,
                        tabs: [
                          Tab(
                            icon: const Icon(CupertinoIcons.heart_fill),
                            text: "Liked (${likedUsers.length})",
                          ),
                          Tab(
                            icon: const Icon(Icons.bolt),
                            text: "Superliked (${superLikedUsers.length})",
                          ),
                          Tab(
                            icon: const Icon(Icons.clear),
                            text: "Disliked (${dislikedUsers.length})",
                          ),
                        ],
                      ),
                      _isSearchBarVisible
                          ? const SizedBox(
                              height: AppConstants.defaultNumericValue / 2)
                          : const SizedBox(height: 0),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return SizeTransition(
                                sizeFactor: animation, child: child);
                          },
                          child: _isSearchBarVisible
                              ? Container(
                                  key: const Key('searchBar'),
                                  padding: const EdgeInsets.all(
                                      AppConstants.defaultNumericValue / 3),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryColor
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.defaultNumericValue,
                                    ),
                                  ),
                                  child: TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      onChanged: (_) {
                                        setState(() {});
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Search here...',
                                        border: InputBorder.none,
                                        prefixIcon: Icon(
                                          CupertinoIcons.search,
                                          color: AppConstants.primaryColor,
                                        ),
                                      )),
                                )
                              : const SizedBox(key: Key('noSearchBar')),
                        ),
                      ),
                      _isSearchBarVisible
                          ? const SizedBox(
                              height: AppConstants.defaultNumericValue / 2)
                          : const SizedBox(height: 0),
                      Expanded(
                        child: TabBarView(
                          // physics: const NeverScrollableScrollPhysics(),
                          children: [
                            likedUsers.isEmpty
                                ? const Center(
                                    child: NoItemFoundWidget(
                                        text: 'No liked user found!'),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () async {
                                      ref.invalidate(interactionFutureProvider);
                                    },
                                    child: GridView.builder(
                                      itemCount: likedUsers.length,
                                      padding: const EdgeInsets.all(
                                          AppConstants.defaultNumericValue / 2),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.8,
                                        crossAxisSpacing:
                                            AppConstants.defaultNumericValue /
                                                2,
                                        mainAxisSpacing:
                                            AppConstants.defaultNumericValue /
                                                2,
                                      ),
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onLongPress: () {
                                            onLongPressUserCard(
                                                likedUsers[index]
                                                    .interaction
                                                    .id);
                                          },
                                          child: UserImageCard(
                                              user: likedUsers[index].user),
                                        );
                                      },
                                    ),
                                  ),
                            superLikedUsers.isEmpty
                                ? const Center(
                                    child: NoItemFoundWidget(
                                        text: 'No superliked user found!'),
                                  )
                                : RefreshIndicator(
                                    onRefresh: () async {
                                      ref.invalidate(interactionFutureProvider);
                                    },
                                    child: GridView.builder(
                                      itemCount: superLikedUsers.length,
                                      padding: const EdgeInsets.all(
                                          AppConstants.defaultNumericValue / 2),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.8,
                                        crossAxisSpacing:
                                            AppConstants.defaultNumericValue /
                                                2,
                                        mainAxisSpacing:
                                            AppConstants.defaultNumericValue /
                                                2,
                                      ),
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onLongPress: () {
                                            onLongPressUserCard(
                                                superLikedUsers[index]
                                                    .interaction
                                                    .id);
                                          },
                                          child: UserImageCard(
                                              user:
                                                  superLikedUsers[index].user),
                                        );
                                      },
                                    ),
                                  ),
                            dislikedUsers.isEmpty
                                ? const Center(
                                    child: NoItemFoundWidget(
                                        text: 'No disliked user found!'))
                                : RefreshIndicator(
                                    onRefresh: () async {
                                      ref.invalidate(interactionFutureProvider);
                                    },
                                    child: GridView.builder(
                                      itemCount: dislikedUsers.length,
                                      padding: const EdgeInsets.all(
                                          AppConstants.defaultNumericValue / 2),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.8,
                                        crossAxisSpacing:
                                            AppConstants.defaultNumericValue /
                                                2,
                                        mainAxisSpacing:
                                            AppConstants.defaultNumericValue /
                                                2,
                                      ),
                                      itemBuilder: (context, index) {
                                        return GestureDetector(
                                          onLongPress: () {
                                            onLongPressUserCard(
                                                dislikedUsers[index]
                                                    .interaction
                                                    .id);
                                          },
                                          child: UserImageCard(
                                              user: dislikedUsers[index].user),
                                        );
                                      },
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                error: (_, __) => const Center(
                  child: Text('Something went wrong!'),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserInteractionViewModel {
  UserInteractionModel interaction;
  UserProfileModel user;
  UserInteractionViewModel({
    required this.interaction,
    required this.user,
  });
}
