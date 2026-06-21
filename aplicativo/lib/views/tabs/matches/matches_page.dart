import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/match_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/custom/lottie/no_item_found_widget.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/others/user_image_card.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';

class MatchesConsumerPage extends ConsumerWidget {
  const MatchesConsumerPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final matchedUsersProvider = ref.watch(matchStreamProvider);
    final otherUsers = ref.watch(otherUsersProvider);

    return otherUsers.when(
      data: (data) {
        if (data.isEmpty) {
          return const Center(
            child: NoItemFoundWidget(text: 'No users found'),
          );
        } else {
          return matchedUsersProvider.when(
            data: (matches) {
              final List<MatchedUsersView> matchedViews = [];

              matches.removeWhere((element) => element.isMatched == false);

              for (final user in data) {
                if (matches
                    .any((element) => element.userIds.contains(user.id))) {
                  matchedViews.add(MatchedUsersView(
                      user: user,
                      matchId: matches
                          .firstWhere(
                              (element) => element.userIds.contains(user.id))
                          .id));
                }
              }

              return MatchesPage(matchesView: matchedViews);
            },
            error: (_, __) {
              return const ErrorPage();
            },
            loading: () => const LoadingPage(),
          );
        }
      },
      error: (_, __) => const ErrorPage(),
      loading: () => const LoadingPage(),
    );
  }
}

class MatchesPage extends ConsumerStatefulWidget {
  final List<MatchedUsersView> matchesView;
  const MatchesPage({
    super.key,
    required this.matchesView,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MatchBodyState();
}

class _MatchBodyState extends ConsumerState<MatchesPage> {
  bool _isSearchBarVisible = false;
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final searchedUsers = widget.matchesView.where((element) {
      return element.user.fullName
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
    }).toList();
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
                icon: CupertinoIcons.search,
                onPressed: () {
                  setState(() {
                    _isSearchBarVisible = !_isSearchBarVisible;
                    _searchController.clear();
                  });
                },
                padding: const EdgeInsets.all(
                    AppConstants.defaultNumericValue / 1.5),
              ),
              title: Center(
                  child: CustomHeadLine(
                text: 'Matches',
                secondPartColor: AppConstants.primaryColor,
              )),
              trailing: const NotificationButton(),
            ),
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          Expanded(
            child: Column(
              children: [
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
                              color: AppConstants.primaryColor.withOpacity(0.2),
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
                              ),
                            ),
                          )
                        : const SizedBox(key: Key('noSearchBar')),
                  ),
                ),
                _isSearchBarVisible
                    ? const SizedBox(height: AppConstants.defaultNumericValue)
                    : const SizedBox(height: 0),
                searchedUsers.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: NoItemFoundWidget(text: 'No matches found'),
                        ),
                      )
                    : Expanded(
                        child: GridView(
                          padding: const EdgeInsets.only(
                            left: AppConstants.defaultNumericValue,
                            right: AppConstants.defaultNumericValue,
                            bottom: AppConstants.defaultNumericValue,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: AppConstants.defaultNumericValue,
                            mainAxisSpacing: AppConstants.defaultNumericValue,
                          ),
                          children: searchedUsers.map((match) {
                            return UserImageCard(
                                user: match.user, matchId: match.matchId);
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MatchedUsersView {
  UserProfileModel user;
  String matchId;
  MatchedUsersView({
    required this.user,
    required this.matchId,
  });

  MatchedUsersView copyWith({
    UserProfileModel? user,
    String? matchId,
  }) {
    return MatchedUsersView(
      user: user ?? this.user,
      matchId: matchId ?? this.matchId,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'user': user.toMap()});
    result.addAll({'matchId': matchId});

    return result;
  }

  factory MatchedUsersView.fromMap(Map<String, dynamic> map) {
    return MatchedUsersView(
      user: UserProfileModel.fromMap(map['user']),
      matchId: map['matchId'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory MatchedUsersView.fromJson(String source) =>
      MatchedUsersView.fromMap(json.decode(source));

  @override
  String toString() => 'MatchedUsersView(user: $user, matchId: $matchId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MatchedUsersView &&
        other.user == user &&
        other.matchId == matchId;
  }

  @override
  int get hashCode => user.hashCode ^ matchId.hashCode;
}
