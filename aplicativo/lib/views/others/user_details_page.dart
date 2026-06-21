import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/url_launcher_helper.dart';
import 'package:mioamoreapp/models/match_model.dart';
import 'package:mioamoreapp/models/notification_model.dart';
import 'package:mioamoreapp/models/user_interaction_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/app_settings_provider.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/block_user_provider.dart';
import 'package:mioamoreapp/providers/interaction_provider.dart';
import 'package:mioamoreapp/providers/match_provider.dart';
import 'package:mioamoreapp/providers/notifiaction_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/custom/subscription_builder.dart';
import 'package:mioamoreapp/views/others/photo_view_page.dart';
import 'package:mioamoreapp/views/others/report_page.dart';
import 'package:mioamoreapp/views/others/user_card_widget.dart';
import 'package:mioamoreapp/views/tabs/home/explore_page.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_page.dart';

class UserDetailsPage extends ConsumerWidget {
  final UserProfileModel user;
  final String? matchId;
  const UserDetailsPage({
    super.key,
    required this.user,
    this.matchId,
  });

  @override
  Widget build(BuildContext context, ref) {
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

    Future<void> showMatchingDialog({
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
                  insetPadding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue * 2),
                  contentPadding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue * 2),
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
                      child: Text(
                          "You are now matched with ${otherUser.fullName}"),
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

    final currentUserProfile = ref.watch(userProfileFutureProvider);

    final String myUserId = ref.watch(currentUserStateProvider)!.uid;
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

    UserProfileModel? currentUserProfileModel;
    currentUserProfile.whenData((userProfile) {
      currentUserProfileModel = userProfile;
    });

    return SubscriptionBuilder(
      builder: (context, isPremiumUser) {
        // Freemium Limitations
        final List<UserInteractionModel> data = [];
        final interactionProvider = ref.watch(interactionFutureProvider);
        interactionProvider.whenData((value) {
          data.addAll(value);
        });

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final interactionsToday =
            data.where((element) => element.createdAt.isAfter(today)).toList();

        // Check limits

        int totalLiked = interactionsToday
            .where((element) => element.isLike)
            .toList()
            .length;

        int totalSuperLiked = interactionsToday
            .where((element) => element.isSuperLike)
            .toList()
            .length;

        int totalDisliked = interactionsToday
            .where((element) => element.isDislike)
            .toList()
            .length;

        bool canLike = true;
        bool canSuperLike = true;
        bool canDislike = true;

        if (isPremiumUser) {
          if (FreemiumLimitation.maxDailyLikeLimitPremium != 0 &&
              totalLiked >= FreemiumLimitation.maxDailyLikeLimitPremium) {
            canLike = false;
          }

          if (FreemiumLimitation.maxDailySuperLikeLimitPremium != 0 &&
              totalSuperLiked >=
                  FreemiumLimitation.maxDailySuperLikeLimitPremium) {
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
              totalSuperLiked >=
                  FreemiumLimitation.maxDailySuperLikeLimitFree) {
            canSuperLike = false;
          }

          if (FreemiumLimitation.maxDailyDislikeLimitFree != 0 &&
              totalDisliked >= FreemiumLimitation.maxDailyDislikeLimitFree) {
            canDislike = false;
          }
        }

        return Scaffold(
          body: Stack(
            children: [
              DetailsBody(user: user, matchId: matchId, myUserId: myUserId),
              if (matchId != null)
                Positioned(
                  bottom: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.8),
                        padding: const EdgeInsets.only(
                            bottom: AppConstants.defaultNumericValue * 2,
                            top: AppConstants.defaultNumericValue),
                        width: MediaQuery.of(context).size.width,
                        child: Center(
                          child: CustomButton(
                            text: "Send a Message",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    otherUserId: user.userId,
                                    matchId: matchId!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (matchId == null)
                Positioned(
                  bottom: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.8),
                        padding: const EdgeInsets.only(
                            bottom: AppConstants.defaultNumericValue * 2,
                            top: AppConstants.defaultNumericValue),
                        width: MediaQuery.of(context).size.width,
                        child: UserLikeActions(
                          onTapCross: () async {
                            if (canDislike) {
                              final newInteraction = interaction.copyWith(
                                  isDislike: true, createdAt: DateTime.now());
                              await createInteraction(newInteraction)
                                  .then((value) {
                                Navigator.pop(context);
                                ref.invalidate(interactionFutureProvider);
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "You have reached your daily limit of dislikes!"),
                                ),
                              );
                            }
                          },
                          onTapBolt: () async {
                            if (canSuperLike) {
                              final newInteraction = interaction.copyWith(
                                  isSuperLike: true, createdAt: DateTime.now());
                              await createInteraction(newInteraction)
                                  .then((result) async {
                                if (result && currentUserProfileModel != null) {
                                  await getExistingInteraction(
                                          user.id, myUserId)
                                      .then((otherUserInteraction) async {
                                    if (otherUserInteraction != null) {
                                      await showMatchingDialog(
                                              context: context,
                                              currentUser:
                                                  currentUserProfileModel!,
                                              otherUser: user)
                                          .then((value) {
                                        Navigator.pop(context);
                                      });
                                    } else {
                                      createInteractionNotification(
                                          title: "You have a new Interaction!",
                                          body: "Someone has super liked you!",
                                          receiverId: user.userId,
                                          currentUser:
                                              currentUserProfileModel!);
                                      Navigator.pop(context);
                                    }
                                  });
                                }

                                ref.invalidate(interactionFutureProvider);
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "You have reached your daily limit of super likes!"),
                                ),
                              );
                            }
                          },
                          onTapHeart: () async {
                            if (canLike) {
                              final newInteraction = interaction.copyWith(
                                  isLike: true, createdAt: DateTime.now());
                              await createInteraction(newInteraction)
                                  .then((result) async {
                                if (result && currentUserProfileModel != null) {
                                  await getExistingInteraction(
                                          user.id, myUserId)
                                      .then((otherUserInteraction) async {
                                    if (otherUserInteraction != null) {
                                      await showMatchingDialog(
                                              context: context,
                                              currentUser:
                                                  currentUserProfileModel!,
                                              otherUser: user)
                                          .then((value) {
                                        Navigator.pop(context);
                                      });
                                    } else {
                                      createInteractionNotification(
                                          title: "You have a new Interaction!",
                                          body: "Someone has liked you!",
                                          receiverId: user.userId,
                                          currentUser:
                                              currentUserProfileModel!);
                                      Navigator.pop(context);
                                    }
                                  });
                                }

                                ref.invalidate(interactionFutureProvider);
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "You have reached your daily limit of likes!"),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}

class DetailsBody extends ConsumerStatefulWidget {
  const DetailsBody({
    super.key,
    required this.user,
    required this.myUserId,
    required this.matchId,
  });

  final UserProfileModel user;
  final String myUserId;
  final String? matchId;

  @override
  ConsumerState<DetailsBody> createState() => _DetailsBodyState();
}

class _DetailsBodyState extends ConsumerState<DetailsBody> {
  final CustomPopupMenuController _moreMenuController =
      CustomPopupMenuController();

  void _onTapUnmatch() async {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Unmatch"),
            content: const Text("Are you sure you want to unmatch?"),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text("Unmatch"),
                onPressed: () async {
                  EasyLoading.show(status: "Unmatching...");

                  await unMatchUser(
                          widget.matchId!, widget.user.userId, widget.myUserId)
                      .then((value) {
                    EasyLoading.dismiss();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  });
                },
              ),
            ],
          );
        });
  }

  void _onTapSendMessage() async {
    final MatchModel matchModel = MatchModel(
      id: widget.myUserId + widget.user.userId,
      userIds: [widget.myUserId, widget.user.userId],
      isMatched: false,
    );

    EasyLoading.show(status: "Creating conversation...");
    await createConversation(matchModel).then((matchResult) async {
      if (matchResult) {
        EasyLoading.dismiss();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              matchId: matchModel.id,
              otherUserId: widget.user.userId,
            ),
          ),
        );
      } else {
        EasyLoading.showInfo("Something went wrong! Please try again later.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsRef = ref.watch(appSettingsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: AppConstants.defaultNumericValue * 28,
                    width: MediaQuery.of(context).size.width,
                    child: (widget.user.profilePicture == null &&
                            widget.user.mediaFiles.isEmpty)
                        ? const Center(
                            child: Icon(CupertinoIcons.photo),
                          )
                        : GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PhotoViewPage(
                                    images: [
                                      widget.user.profilePicture != null
                                          ? widget.user.profilePicture!
                                          : widget.user.mediaFiles.isNotEmpty
                                              ? widget.user.mediaFiles.first
                                              : ''
                                    ],
                                    title: "Photos",
                                  ),
                                ),
                              );
                            },
                            child: CachedNetworkImage(
                              imageUrl: widget.user.profilePicture != null
                                  ? widget.user.profilePicture!
                                  : widget.user.mediaFiles.isNotEmpty
                                      ? widget.user.mediaFiles.first
                                      : '',
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator.adaptive()),
                              errorWidget: (context, url, error) {
                                return const Center(
                                    child: Icon(CupertinoIcons.photo));
                              },
                            ),
                          ),
                  ),
                  Container(
                      height: 2,
                      color: Theme.of(context).scaffoldBackgroundColor)
                ],
              ),
              //Top Bar
              Positioned(
                top: AppConstants.defaultNumericValue * 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultNumericValue),
                  width: MediaQuery.of(context).size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CustomIconButton(
                        icon: CupertinoIcons.chevron_back,
                        color: Colors.white,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        padding: const EdgeInsets.all(
                            AppConstants.defaultNumericValue / 1.5),
                      ),
                      CustomPopupMenu(
                        menuBuilder: () => ClipRRect(
                          borderRadius: BorderRadius.circular(
                              AppConstants.defaultNumericValue / 2),
                          child: Container(
                            decoration:
                                const BoxDecoration(color: Colors.white),
                            child: IntrinsicWidth(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  widget.matchId != null
                                      ? MoreMenuTitle(
                                          title: 'Unmatch',
                                          onTap: () async {
                                            _moreMenuController.hideMenu();
                                            _onTapUnmatch();
                                          },
                                        )
                                      : widget.user.userAccountSettingsModel
                                                  .allowAnonymousMessages ==
                                              true
                                          ? appSettingsRef.when(
                                              data: (data) {
                                                if (data?.isChattingEnabledBeforeMatch ==
                                                    true) {
                                                  return MoreMenuTitle(
                                                    title: 'Send Message',
                                                    onTap: _onTapSendMessage,
                                                  );
                                                } else {
                                                  return const SizedBox();
                                                }
                                              },
                                              error: (error, stackTrace) =>
                                                  const SizedBox(),
                                              loading: () => const SizedBox(),
                                            )
                                          : const SizedBox(),
                                  MoreMenuTitle(
                                    title: 'Report',
                                    onTap: () {
                                      _moreMenuController.hideMenu();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReportPage(
                                              userProfileModel: widget.user),
                                        ),
                                      );
                                    },
                                  ),
                                  MoreMenuTitle(
                                    title: 'Block',
                                    onTap: () async {
                                      _moreMenuController.hideMenu();
                                      showBlockDialog(context,
                                          widget.user.userId, widget.myUserId);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        pressType: PressType.singleClick,
                        verticalMargin: 0,
                        controller: _moreMenuController,
                        showArrow: true,
                        arrowColor: Colors.white,
                        barrierColor:
                            AppConstants.primaryColor.withOpacity(0.1),
                        child: CustomIconButton(
                          icon: CupertinoIcons.ellipsis,
                          color: Colors.white,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          onPressed: () {
                            _moreMenuController.showMenu();
                          },
                          padding: const EdgeInsets.all(
                              AppConstants.defaultNumericValue / 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: AppConstants.defaultNumericValue,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft:
                          Radius.circular(AppConstants.defaultNumericValue * 2),
                      topRight:
                          Radius.circular(AppConstants.defaultNumericValue * 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue / 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(widget.user.fullName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
                                        .copyWith(fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(
                                  width: AppConstants.defaultNumericValue / 4),
                              if (widget.user.isVerified)
                                const Icon(Icons.verified_user,
                                    color: CupertinoColors.activeGreen),
                              widget.user.isOnline
                                  ? const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 4),
                                      child: OnlineStatus(),
                                    )
                                  : const SizedBox(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppConstants.defaultNumericValue / 2),
                    Visibility(
                      visible:
                          widget.user.userAccountSettingsModel.showAge != false,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue,
                            vertical: AppConstants.defaultNumericValue / 2),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppConstants.defaultNumericValue),
                          ),
                          gradient: AppConstants.defaultGradient,
                        ),
                        child: Text(
                            "${DateTime.now().difference(widget.user.birthDay).inDays ~/ 365} Years",
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue,
                    vertical: AppConstants.defaultNumericValue / 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: AppConstants.primaryColor),
                    const SizedBox(width: AppConstants.defaultNumericValue / 4),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final myProfile =
                              ref.watch(userProfileFutureProvider);
                          return myProfile.when(
                            data: (data) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.user.userAccountSettingsModel
                                          .showLocation !=
                                      false)
                                    Text(
                                      widget.user.userAccountSettingsModel
                                          .location.addressText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall!
                                          .copyWith(
                                              color: AppConstants.primaryColor,
                                              fontWeight: FontWeight.bold),
                                    ),
                                  if (data != null)
                                    Text(
                                      '${(Geolocator.distanceBetween(widget.user.userAccountSettingsModel.location.latitude, widget.user.userAccountSettingsModel.location.longitude, widget.user.userAccountSettingsModel.location.latitude, widget.user.userAccountSettingsModel.location.longitude) / 1000).toStringAsFixed(2)} km away',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              fontWeight: FontWeight.bold),
                                    )
                                ],
                              );
                            },
                            error: (_, __) => const SizedBox(),
                            loading: () => const SizedBox(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              widget.user.userAccountSettingsModel.allowAnonymousMessages ==
                      true
                  ? appSettingsRef.when(
                      data: (data) {
                        if (data?.isChattingEnabledBeforeMatch == true) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.defaultNumericValue,
                              vertical: AppConstants.defaultNumericValue / 4,
                            ),
                            child: Text(
                              "Anonymous messages are allowed",
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold),
                            ),
                          );
                        } else {
                          return const SizedBox();
                        }
                      },
                      error: (error, stackTrace) => const SizedBox(),
                      loading: () => const SizedBox(),
                    )
                  : const SizedBox(),
              const Divider(),
              const SizedBox(height: AppConstants.defaultNumericValue / 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: Text(
                  "About",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue / 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: Text(
                    widget.user.about == null || widget.user.about!.isEmpty
                        ? "Not Available"
                        : widget.user.about!),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: Text(
                  "Why I'm Here",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue / 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: Text(widget.user.myPurpose == null ||
                        widget.user.myPurpose!.isEmpty
                    ? "Not Mentioned!"
                    : widget.user.myPurpose!),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Interests",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Builder(
                      builder: (context) {
                        final myProfile = ref.watch(userProfileFutureProvider);
                        return myProfile.when(
                          data: (data) {
                            if (data != null) {
                              return InterestsSimilarityWidget(
                                otherUser: widget.user,
                                myProfile: data,
                                color: AppConstants.primaryColor,
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                          error: (_, __) => const SizedBox(),
                          loading: () => const SizedBox(),
                        );
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: widget.user.interests.isEmpty
                    ? const Text("Not Found!")
                    : Wrap(
                        spacing: AppConstants.defaultNumericValue / 2,
                        runSpacing: AppConstants.defaultNumericValue / 2,
                        alignment: WrapAlignment.start,
                        children: widget.user.interests.map((interest) {
                          int? index;
                          for (var element in AppConfig.interests) {
                            if (element.toLowerCase().trim() ==
                                interest.toLowerCase().trim()) {
                              index = AppConfig.interests.indexOf(element);
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              if (index != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ExplorePage(index: index),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text("The interest is not available!"),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(
                                      AppConstants.defaultNumericValue / 2),
                                ),
                                color:
                                    AppConstants.primaryColor.withOpacity(0.1),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.defaultNumericValue,
                                  vertical:
                                      AppConstants.defaultNumericValue / 2),
                              child: Text(interest[0].toUpperCase() +
                                  interest.substring(1)),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              ListTile(
                title: Text(
                  "Social Accounts",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(
                      top: AppConstants.defaultNumericValue / 2),
                  child: Wrap(
                    spacing: AppConstants.defaultNumericValue / 2,
                    children: [
                      if (widget.user.instagramUsername != null &&
                          widget.user.instagramUsername!.isNotEmpty)
                        ActionChip(
                          onPressed: () async {
                            UrlLauncherHelper.launchURL(Uri.parse(
                                "https://www.instagram.com/${widget.user.instagramUsername}"));
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          backgroundColor:
                              AppConstants.primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultNumericValue * 2),
                            side: BorderSide(
                                color: AppConstants.primaryColor, width: 1),
                          ),
                          avatar: Image.asset(
                            instagramIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: Text(
                              widget.user.instagramUsername![0].toUpperCase() +
                                  widget.user.instagramUsername!.substring(1)),
                        )
                      else
                        ActionChip(
                          onPressed: () {},
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          avatar: Image.asset(
                            instagramIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: const Text("Not Set!"),
                        ),
                      if (widget.user.snapchatUsername != null &&
                          widget.user.snapchatUsername!.isNotEmpty)
                        ActionChip(
                          onPressed: () async {
                            UrlLauncherHelper.launchURL(Uri.parse(
                                "https://www.snapchat.com/add/${widget.user.snapchatUsername}"));
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          backgroundColor:
                              AppConstants.primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultNumericValue * 2),
                            side: BorderSide(
                                color: AppConstants.primaryColor, width: 1),
                          ),
                          avatar: Image.asset(
                            snapchatIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: Text(
                              widget.user.snapchatUsername![0].toUpperCase() +
                                  widget.user.snapchatUsername!.substring(1)),
                        )
                      else
                        ActionChip(
                          onPressed: () {},
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          avatar: Image.asset(
                            snapchatIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: const Text("Not Set!"),
                        ),
                      if (widget.user.twitterUsername != null &&
                          widget.user.twitterUsername!.isNotEmpty)
                        ActionChip(
                          onPressed: () async {
                            UrlLauncherHelper.launchURL(Uri.parse(
                                "https://www.twitter.com/${widget.user.twitterUsername}"));
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          backgroundColor:
                              AppConstants.primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultNumericValue * 2),
                            side: BorderSide(
                                color: AppConstants.primaryColor, width: 1),
                          ),
                          avatar: Image.asset(
                            twitterIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: Text(
                              widget.user.twitterUsername![0].toUpperCase() +
                                  widget.user.twitterUsername!.substring(1)),
                        )
                      else
                        ActionChip(
                          onPressed: () {},
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          avatar: Image.asset(
                            twitterIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: const Text("Not Set!"),
                        ),
                      if (widget.user.facebookUsername != null &&
                          widget.user.facebookUsername!.isNotEmpty)
                        ActionChip(
                          onPressed: () async {
                            UrlLauncherHelper.launchURL(Uri.parse(
                                "https://www.facebook.com/${widget.user.facebookUsername}"));
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          backgroundColor:
                              AppConstants.primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultNumericValue * 2),
                            side: BorderSide(
                                color: AppConstants.primaryColor, width: 1),
                          ),
                          avatar: Image.asset(
                            facebookIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: Text(
                              widget.user.facebookUsername![0].toUpperCase() +
                                  widget.user.facebookUsername!.substring(1)),
                        )
                      else
                        ActionChip(
                          onPressed: () {},
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          avatar: Image.asset(
                            facebookIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: const Text("Not Set!"),
                        ),
                      if (widget.user.tiktokUsername != null &&
                          widget.user.tiktokUsername!.isNotEmpty)
                        ActionChip(
                          onPressed: () async {
                            UrlLauncherHelper.launchURL(Uri.parse(
                                "https://www.tiktok.com/@${widget.user.tiktokUsername}"));
                          },
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          backgroundColor:
                              AppConstants.primaryColor.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppConstants.defaultNumericValue * 2),
                            side: BorderSide(
                                color: AppConstants.primaryColor, width: 1),
                          ),
                          avatar: Image.asset(
                            tiktokIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: Text(
                              widget.user.tiktokUsername![0].toUpperCase() +
                                  widget.user.tiktokUsername!.substring(1)),
                        )
                      else
                        ActionChip(
                          onPressed: () {},
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.defaultNumericValue / 2,
                            vertical: AppConstants.defaultNumericValue / 4,
                          ),
                          avatar: Image.asset(
                            tiktokIcon,
                            width: AppConstants.defaultNumericValue * 2,
                            height: AppConstants.defaultNumericValue * 2,
                          ),
                          label: const Text("Not Set!"),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: Text(
                  "Photos",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue / 2),
              widget.user.mediaFiles.isEmpty
                  ? const SizedBox(
                      height: 200,
                      child: Center(
                          child: Text(
                        "No Photos Found!",
                        textAlign: TextAlign.center,
                      )),
                    )
                  : GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: AppConstants.defaultNumericValue,
                        right: AppConstants.defaultNumericValue,
                        bottom: AppConstants.defaultNumericValue,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1,
                        crossAxisSpacing: AppConstants.defaultNumericValue,
                        mainAxisSpacing: AppConstants.defaultNumericValue,
                      ),
                      children: widget.user.mediaFiles.map((e) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PhotoViewPage(
                                  images: widget.user.mediaFiles,
                                  title: "Photos",
                                  index: widget.user.mediaFiles.indexOf(e),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.defaultNumericValue),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.defaultNumericValue),
                              child: CachedNetworkImage(
                                  imageUrl: e,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                      child:
                                          CircularProgressIndicator.adaptive()),
                                  errorWidget: (context, url, error) {
                                    return const Center(
                                        child: Icon(Icons.image_not_supported));
                                  }),
                            ),
                          ),
                        );
                      }).toList()),
              const SizedBox(height: AppConstants.defaultNumericValue * 7),
            ],
          ),
        ],
      ),
    );
  }
}

// class _AddToFavButton extends ConsumerWidget {
//   final UserProfileModel user;
//   const _AddToFavButton({
//     Key? key,
//     required this.user,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context, ref) {
//     final _favouriteUsersStreamProvider =
//         ref.watch(favouriteUsersStreamProvider);
//     return _favouriteUsersStreamProvider.when(
//         data: (data) {
//           bool _isFavorite = widget.user.contains(user.id);

//           return CustomIconButton(
//             icon:
//                 _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
//             color: _isFavorite ? CupertinoColors.systemRed : Colors.white,
//             onPressed: () {
//               if (_isFavorite) {
//                 ref.read(favouriteUsersProvider).removeFromFavourite(user.id);
//               } else {
//                 ref.read(favouriteUsersProvider).addToFavourite(user.id);
//               }
//             },
//             padding:
//                 const EdgeInsets.all(AppConstants.defaultNumericValue / 1.5),
//           );
//         },
//         error: (_, __) => const SizedBox(),
//         loading: () => const SizedBox());
//   }
// }

Future<void> showBlockDialog(
    BuildContext context, String userId, String myUserId) async {
  await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Block"),
          content: const Text("Are you sure you want to block this user?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            Consumer(builder: (context, ref, child) {
              return TextButton(
                child: const Text("Block"),
                onPressed: () async {
                  EasyLoading.show(status: "Blocking...");

                  await blockUser(userId, myUserId).then((value) {
                    ref.invalidate(otherUsersProvider);
                    ref.invalidate(blockedUsersFutureProvider);
                    EasyLoading.dismiss();
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  });
                },
              );
            }),
          ],
        );
      });
}
