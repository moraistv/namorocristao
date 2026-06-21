import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/models/match_model.dart';
import 'package:mioamoreapp/models/notification_model.dart';
import 'package:mioamoreapp/models/user_account_settings_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/match_provider.dart';
import 'package:mioamoreapp/providers/notifiaction_provider.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/custom/lottie/no_item_found_widget.dart';
import 'package:mioamoreapp/views/custom/subscription_builder.dart';
import 'package:mioamoreapp/views/tabs/home/explore_page.dart';
import 'package:mioamoreapp/views/tabs/home/notification_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_page.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_interaction_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/interaction_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/others/user_card_widget.dart';
import 'package:mioamoreapp/views/settings/account_settings.dart';
import 'package:mioamoreapp/views/tabs/home/app_drawer.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _menuKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _notificationKey = GlobalKey();
  final _exploreKey = GlobalKey();

  final List<TargetFocus> _targets = [];

  bool _showLoading = false;

  @override
  void initState() {
    final showGuidedTour = Hive.box(HiveConstants.hiveBox)
        .get(HiveConstants.guidedTour, defaultValue: true) as bool;

    if (showGuidedTour) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        _showTutorials();
        await setShowGuidedTour(false);
      });
    }

    super.initState();
  }

  void _showTutorials() {
    _targets.clear();
    _targets.add(
      TargetFocus(
        identify: "Menu",
        keyTarget: _menuKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Menu",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "This is the app menu.\n\nClick here to open the menu.\n\nYou will find your profile, account settings, and other options here.\n\nYou can also logout from here.",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );

    _targets.add(
      TargetFocus(
        identify: "Location",
        keyTarget: _locationKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Location",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "This is your current location.\n\nYou can change your location here.\n\nYou can also change your location from the app menu.\n\nTapping here will take you to the account settings page.",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );

    _targets.add(
      TargetFocus(
        identify: "Notification",
        keyTarget: _notificationKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notifications",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "This is the notification icon.\n\nYou will get notifications here.\n\nTapping here will take you to the notification page.",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );

    _targets.add(
      TargetFocus(
        identify: "Explore",
        keyTarget: _exploreKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Explore",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 10.0),
                  child: Text(
                    "This is the explore icon.\n\nTapping here will take you to the explore page.\n\nYou can explore other users based on interests. You can also search for users here.",
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );

    TutorialCoachMark(
      targets: _targets,
      colorShadow: AppConstants.primaryColor,
      onClickTarget: (target) {
        debugPrint(target.toString());
      },
      onClickTargetWithTapPosition: (target, tapDetails) {
        debugPrint("target: $target");
        debugPrint(
            "clicked at position local: ${tapDetails.localPosition} - global: ${tapDetails.globalPosition}");
      },
      onClickOverlay: (target) {
        debugPrint(target.toString());
      },
      onSkip: () {
        debugPrint("skip");
        return false;
      },
      onFinish: () {
        debugPrint("finish");
      },
    ).show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: const SizedBox(),
        toolbarHeight: 0,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultNumericValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.defaultNumericValue),
            CustomAppBar(
              leading: CustomIconButton(
                key: _menuKey,
                icon: CupertinoIcons.square_grid_2x2_fill,
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                padding: const EdgeInsets.all(
                    AppConstants.defaultNumericValue / 1.5),
              ),
              title: Consumer(
                key: _locationKey,
                builder: (context, ref, _) {
                  final user = ref.watch(userProfileFutureProvider);
                  return user.when(
                      data: (data) {
                        debugPrint("Online Status: ${data?.isOnline}");

                        if (data?.userAccountSettingsModel.showOnlineStatus !=
                            false) {
                          if (data?.isOnline == false) {
                            debugPrint("Updating online status to true");
                            ref.read(userProfileNotifier).updateUserProfile(
                                data!.copyWith(isOnline: true));
                          }
                        }

                        return data == null
                            ? const SizedBox()
                            : GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AccountSettingsLandingWidget(),
                                    ),
                                  );
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.location_solid,
                                      color: AppConstants.primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(
                                        width:
                                            AppConstants.defaultNumericValue /
                                                3),
                                    Flexible(
                                      child: Text(
                                        data.userAccountSettingsModel.location
                                            .addressText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                      },
                      error: (_, __) => const SizedBox(),
                      loading: () => const SizedBox());
                },
              ),
              trailing: Row(
                children: [
                  CustomIconButton(
                    key: _exploreKey,
                    icon: Icons.explore,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExplorePage(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(
                        AppConstants.defaultNumericValue / 1.5),
                  ),
                  const SizedBox(width: AppConstants.defaultNumericValue / 2),
                  NotificationButton(key: _notificationKey),
                ],
              ),
            ),
            Expanded(
              child: _showLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : Consumer(
                      builder: (context, ref, child) {
                        final filteredUsers =
                            ref.watch(filteredOtherUsersProvider);

                        return filteredUsers.when(
                          data: (data) {
                            debugPrint("Filtered Users: ${data.length}");

                            return data.isEmpty
                                ? const HomePageNoUsersFoundWidget()
                                : SubscriptionBuilder(
                                    builder: (context, isPremiumUser) {
                                      return FilterInteraction(
                                        isPremiumUser: isPremiumUser,
                                        users: data,
                                        onNavigateBack: () async {
                                          setState(() {
                                            _showLoading = true;
                                          });
                                          await Future.delayed(const Duration(
                                              milliseconds: 500));
                                          setState(() {
                                            _showLoading = false;
                                          });
                                        },
                                      );
                                    },
                                  );
                          },
                          error: (_, __) => const Center(
                            child: Text("Something Went Wrong!"),
                          ),
                          loading: () => const Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationButton extends ConsumerWidget {
  const NotificationButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final matchingNotifications = ref.watch(notificationsStreamProvider);

    int count = 0;

    matchingNotifications.whenData((value) {
      for (var element in value) {
        if (element.isRead == false) {
          count++;
        }
      }
    });

    return Stack(
      children: [
        CustomIconButton(
          icon: CupertinoIcons.bell_solid,
          margin: count > 0
              ? const EdgeInsets.only(
                  right: AppConstants.defaultNumericValue / 3)
              : null,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationPage(),
              ),
            );
          },
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue / 1.5),
        ),
        if (count > 0)
          Positioned(
            bottom: 0,
            right: 0,
            child: Badge(
              backgroundColor: AppConstants.primaryColor,
              label: Text(
                count.toString(),
              ),
            ),
          ),
      ],
    );
  }
}

class FilterInteraction extends ConsumerWidget {
  final bool isPremiumUser;
  final List<UserProfileModel> users;
  final VoidCallback? onNavigateBack;
  const FilterInteraction({
    super.key,
    required this.isPremiumUser,
    required this.users,
    this.onNavigateBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactionProvider = ref.watch(interactionFutureProvider);

    return interactionProvider.when(
      data: (data) {
        final List<UserProfileModel> filteredUsers = [];

        for (final user in users) {
          if (!data.any(
              (element) => element.intractToUserId.contains(user.userId))) {
            filteredUsers.add(user);
          }
        }

        debugPrint("Filtered Users: ${filteredUsers.length}");

        // Freemium Limitations
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final interactionsToday =
            data.where((element) => element.createdAt.isAfter(today)).toList();

        return filteredUsers.isEmpty
            ? const NoItemFoundWidget(text: "No users found")
            : HomeBody(
                users: filteredUsers,
                isPremiumUser: isPremiumUser,
                interactionsToday: interactionsToday,
                onNavigateBack: onNavigateBack,
              );
      },
      error: (_, __) => const Center(
        child: Text("Something Went Wrong!"),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}

class HomeBody extends ConsumerStatefulWidget {
  final List<UserProfileModel> users;
  final List<UserInteractionModel> interactionsToday;
  final bool isPremiumUser;
  final VoidCallback? onNavigateBack;
  const HomeBody({
    super.key,
    required this.isPremiumUser,
    required this.users,
    required this.interactionsToday,
    this.onNavigateBack,
  });

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody> {
  late MatchEngine _matchEngine;
  final List<SwipeItem> _swipeItems = [];

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  @override
  void initState() {
    final users = widget.users;
    users.shuffle();

    for (var user in widget.users) {
      _swipeItems.add(
        SwipeItem(
          content: user,
          likeAction: () {},
          nopeAction: () {},
          superlikeAction: () {},
        ),
      );
    }

    _matchEngine = MatchEngine(swipeItems: _swipeItems);

    if (!widget.isPremiumUser && isAdmobAvailable) {
      InterstitialAd.load(
        adUnitId: Platform.isAndroid
            ? AndroidAdUnits.interstitialId
            : IOSAdUnits.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            setState(() {
              _interstitialAd = ad;
              _isInterstitialAdLoaded = true;
            });
          },
          onAdFailedToLoad: (error) {},
        ),
      );
    }

    super.initState();
  }

  @override
  void dispose() {
    _matchEngine.dispose();
    super.dispose();
  }

  void createInteractionNotification(
      {required String title,
      required String body,
      required String receiverId,
      required UserProfileModel currentUser}) async {
    final currentTime = DateTime.now();
    final id = currentTime.millisecondsSinceEpoch.toString();
    final NotificationModel notificationModel = NotificationModel(
      id: id,
      userId: currentUser.userId,
      receiverId: receiverId,
      title: title,
      body: body,
      image: currentUser.profilePicture,
      createdAt: currentTime,
      isRead: false,
      isMatchingNotification: false,
      isInteractionNotification: true,
    );

    await addNotification(notificationModel);
  }

  void showMatchingDialog({
    required BuildContext context,
    required UserProfileModel currentUser,
    required UserProfileModel otherUser,
  }) async {
    final MatchModel matchModel = MatchModel(
      id: currentUser.userId + otherUser.userId,
      userIds: [currentUser.userId, otherUser.userId],
      isMatched: true,
    );

    await createConversation(matchModel).then((matchResult) async {
      if (matchResult) {
        final currentTime = DateTime.now();
        final id =
            matchModel.id + currentTime.millisecondsSinceEpoch.toString();
        final NotificationModel notificationModel = NotificationModel(
          id: id,
          userId: currentUser.userId,
          receiverId: otherUser.userId,
          matchId: matchModel.id,
          title: currentUser.fullName,
          body: "You have a new match",
          image: currentUser.profilePicture,
          createdAt: currentTime,
          isRead: false,
          isMatchingNotification: true,
          isInteractionNotification: false,
        );

        await addNotification(notificationModel).then((value) async {
          await showDialog(
            context: context,
            builder: (context) {
              return SimpleDialog(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultNumericValue),
                ),
                insetPadding:
                    const EdgeInsets.all(AppConstants.defaultNumericValue * 2),
                contentPadding:
                    const EdgeInsets.all(AppConstants.defaultNumericValue * 2),
                title: const Center(child: Text("Matched")),
                children: [
                  const SizedBox(height: AppConstants.defaultNumericValue),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      UserCirlePicture(
                          imageUrl: otherUser.profilePicture, size: 40),
                      const SizedBox(
                          width: AppConstants.defaultNumericValue / 4),
                      UserCirlePicture(
                          imageUrl: currentUser.profilePicture, size: 40),
                    ],
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue),
                  Center(
                    child:
                        Text("You are now matched with ${otherUser.fullName}"),
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text("Not Now"))),
                      const SizedBox(width: AppConstants.defaultNumericValue),
                      Expanded(
                        child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    matchId: matchModel.id,
                                    otherUserId: otherUser.userId,
                                  ),
                                ),
                              );
                            },
                            child: const Text("Start Chat")),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check limits

    int totalLiked = widget.interactionsToday
        .where((element) => element.isLike)
        .toList()
        .length;

    int totalSuperLiked = widget.interactionsToday
        .where((element) => element.isSuperLike)
        .toList()
        .length;

    int totalDisliked = widget.interactionsToday
        .where((element) => element.isDislike)
        .toList()
        .length;

    bool canLike = true;
    bool canSuperLike = true;
    bool canDislike = true;

    if (widget.isPremiumUser) {
      if (FreemiumLimitation.maxDailyLikeLimitPremium != 0 &&
          totalLiked >= FreemiumLimitation.maxDailyLikeLimitPremium) {
        canLike = false;
      }

      if (FreemiumLimitation.maxDailySuperLikeLimitPremium != 0 &&
          totalSuperLiked >= FreemiumLimitation.maxDailySuperLikeLimitPremium) {
        canSuperLike = false;
      }

      if (FreemiumLimitation.maxDailyDislikeLimitPremium != 0 &&
          totalDisliked >= FreemiumLimitation.maxDailyDislikeLimitPremium) {
        canDislike = false;
      }
    } else {
      if (FreemiumLimitation.maxDailyLikeLimitFree != 0 &&
          totalLiked >= FreemiumLimitation.maxDailyLikeLimitFree) {
        canLike = false;
      }

      if (FreemiumLimitation.maxDailySuperLikeLimitFree != 0 &&
          totalSuperLiked >= FreemiumLimitation.maxDailySuperLikeLimitFree) {
        canSuperLike = false;
      }

      if (FreemiumLimitation.maxDailyDislikeLimitFree != 0 &&
          totalDisliked >= FreemiumLimitation.maxDailyDislikeLimitFree) {
        canDislike = false;
      }
    }

    final currentUserProfile = ref.watch(userProfileFutureProvider);

    return currentUserProfile.when(
      data: (data) {
        if (data == null) {
          return const SizedBox();
        } else {
          return Center(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              width: MediaQuery.of(context).size.width * 0.95,
              child: SwipeCards(
                upSwipeAllowed: false,
                matchEngine: _matchEngine,
                itemChanged: (p0, p1) {
                  if (_isInterstitialAdLoaded) {
                    _interstitialAd?.show();
                    _isInterstitialAdLoaded = false;
                  }
                },
                onStackFinished: () {
                  ref.invalidate(interactionFutureProvider);
                },
                itemBuilder: (context, index) {
                  final user = _swipeItems[index].content as UserProfileModel;

                  final String myUserId =
                      ref.watch(currentUserStateProvider)!.uid;
                  final String id = myUserId + user.id;

                  final UserInteractionModel interaction = UserInteractionModel(
                    id: id,
                    userId: myUserId,
                    intractToUserId: user.id,
                    isSuperLike: false,
                    isLike: false,
                    isDislike: false,
                    createdAt: DateTime.now(),
                  );

                  return UserCardWidget(
                    onNavigateBack: widget.onNavigateBack,
                    user: _swipeItems[index].content,
                    onTapBolt: () async {
                      if (canSuperLike) {
                        _matchEngine.currentItem?.superLike();
                        final newInteraction = interaction.copyWith(
                            isSuperLike: true, createdAt: DateTime.now());

                        await createInteraction(newInteraction)
                            .then((result) async {
                          if (result) {
                            await getExistingInteraction(user.id, myUserId)
                                .then((otherUserInteraction) {
                              if (otherUserInteraction != null) {
                                showMatchingDialog(
                                    context: context,
                                    currentUser: data,
                                    otherUser: user);
                              } else {
                                createInteractionNotification(
                                    title: "You have a new Interaction!",
                                    body:
                                        "${user.fullName} has super liked you!",
                                    receiverId: user.id,
                                    currentUser: data);
                              }
                            });
                          }
                        });

                        if (_isInterstitialAdLoaded) {
                          _interstitialAd?.show();
                          _isInterstitialAdLoaded = false;
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "You have reached your daily super like limit",
                            ),
                          ),
                        );
                      }
                    },
                    onTapCross: () async {
                      if (canDislike) {
                        _matchEngine.currentItem?.nope();
                        final newInteraction = interaction.copyWith(
                            isDislike: true, createdAt: DateTime.now());
                        await createInteraction(newInteraction);

                        if (_isInterstitialAdLoaded) {
                          _interstitialAd?.show();
                          _isInterstitialAdLoaded = false;
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "You have reached your daily dislike limit",
                            ),
                          ),
                        );
                      }
                    },
                    onTapHeart: () async {
                      if (canLike) {
                        _matchEngine.currentItem?.like();
                        final newInteraction = interaction.copyWith(
                            isLike: true, createdAt: DateTime.now());
                        await createInteraction(newInteraction)
                            .then((result) async {
                          if (result) {
                            await getExistingInteraction(user.id, myUserId)
                                .then((otherUserInteraction) {
                              if (otherUserInteraction != null) {
                                showMatchingDialog(
                                    context: context,
                                    currentUser: data,
                                    otherUser: user);
                              } else {
                                createInteractionNotification(
                                    title: "You have a new Interaction!",
                                    body: "${user.fullName} has liked you!",
                                    receiverId: user.id,
                                    currentUser: data);
                              }
                            });
                          }
                        });

                        if (_isInterstitialAdLoaded) {
                          _interstitialAd?.show();
                          _isInterstitialAdLoaded = false;
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "You have reached your daily like limit",
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          );
        }
      },
      error: (_, __) => const SizedBox(),
      loading: () => const SizedBox(),
    );
  }
}

class UserCirlePicture extends StatelessWidget {
  final String? imageUrl;
  final double? size;
  const UserCirlePicture({
    super.key,
    required this.imageUrl,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final newSize = size ?? AppConstants.defaultNumericValue * 5;
    return Container(
      width: newSize,
      height: newSize,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(AppConstants.defaultNumericValue * 10),
        border: Border.all(color: AppConstants.primaryColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(AppConstants.defaultNumericValue * 10),
        child: imageUrl == null || imageUrl!.isEmpty
            ? CircleAvatar(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                child: Icon(
                  CupertinoIcons.person_fill,
                  color: AppConstants.primaryColor,
                  size: newSize * 0.8,
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.error)),
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}

class HomePageNoUsersFoundWidget extends ConsumerWidget {
  const HomePageNoUsersFoundWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactions = ref.watch(interactionFutureProvider);
    final closestUsers = ref.watch(closestUsersProvider);

    return interactions.when(
      data: (data) {
        final users = closestUsers
            .where((element) => !data.any((interaction) =>
                interaction.intractToUserId == element.user.id))
            .toList();

        users.sort((a, b) => a.distance.compareTo(b.distance));

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultNumericValue * 2),
            child: users.isEmpty
                ? const NoItemFoundWidget(
                    text: "No users found with your preferences")
                : AccountSettingsLandingWidget(
                    builder: (data) {
                      return ChangeRadiusFromHomePageWidget(
                        closestUsersDistanceInKM: users.first.distance / 1000,
                        user: data,
                      );
                    },
                  ),
          ),
        );
      },
      error: (_, __) => const SizedBox(),
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}

class ChangeRadiusFromHomePageWidget extends ConsumerStatefulWidget {
  final double closestUsersDistanceInKM;
  final UserProfileModel user;
  const ChangeRadiusFromHomePageWidget({
    super.key,
    required this.closestUsersDistanceInKM,
    required this.user,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ChangeRadiusFromHomePageWidgetState();
}

class _ChangeRadiusFromHomePageWidgetState
    extends ConsumerState<ChangeRadiusFromHomePageWidget> {
  late double _distanceInKm;
  late bool _isWorldWide;
  late double _maxDistanceInKm;

  @override
  void initState() {
    _distanceInKm = widget.user.userAccountSettingsModel.distanceInKm ??
        AppConfig.initialMaximumDistanceInKM;
    _isWorldWide = widget.user.userAccountSettingsModel.distanceInKm == null;
    _maxDistanceInKm = AppConfig.initialMaximumDistanceInKM;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const NoItemFoundWidget(
              text: "No users found in your area right now", isSmall: true),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text:
                      "But you can change your radius to find more users. There are lots of users are waiting for you in just ",
                ),
                TextSpan(
                  text:
                      "${widget.closestUsersDistanceInKM.toStringAsFixed(0)} km",
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const TextSpan(text: " away!"),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultNumericValue),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Radius',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isWorldWide)
                  Text(
                    '${_distanceInKm.toInt()} km',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor),
                  ),
              ],
            ),
          ),
          if (_isWorldWide)
            const SizedBox(height: AppConstants.defaultNumericValue / 2),
          if (!_isWorldWide)
            Slider(
              value: _distanceInKm,
              min: 1,
              max: _maxDistanceInKm,
              onChanged: (value) {
                setState(() {
                  _distanceInKm = value;
                });
              },
            ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.defaultNumericValue),
            ),
            borderOnForeground: true,
            child: CheckboxListTile(
              value: _isWorldWide,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _isWorldWide = value!;
                  _distanceInKm = value
                      ? AppConfig.initialMaximumDistanceInKM
                      : widget.user.userAccountSettingsModel.distanceInKm ??
                          AppConfig.initialMaximumDistanceInKM;
                });
              },
              title: Text(
                "Anywhere",
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          CustomButton(
            onPressed: () async {
              final UserAccountSettingsModel newSettingsModel =
                  widget.user.userAccountSettingsModel.copyWith(
                distanceInKm:
                    _isWorldWide ? null : _distanceInKm.toInt().toDouble(),
              );

              final userProfileModel = widget.user
                  .copyWith(userAccountSettingsModel: newSettingsModel);

              EasyLoading.show(status: 'Updating...');

              await ref
                  .read(userProfileNotifier)
                  .updateUserProfile(userProfileModel)
                  .then((value) {
                ref.invalidate(userProfileFutureProvider);
                EasyLoading.dismiss();
              });
            },
            text: 'Apply',
          ),
        ],
      ),
    );
  }
}
