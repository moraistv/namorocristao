import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/others/user_details_page.dart';

class UserCardWidget extends StatefulWidget {
  final UserProfileModel user;
  final VoidCallback onTapCross;
  final VoidCallback onTapHeart;
  final VoidCallback onTapBolt;
  final VoidCallback? onNavigateBack;
  const UserCardWidget({
    super.key,
    required this.user,
    required this.onTapCross,
    required this.onTapHeart,
    required this.onTapBolt,
    this.onNavigateBack,
  });

  @override
  State<UserCardWidget> createState() => _UserCardWidgetState();
}

class _UserCardWidgetState extends State<UserCardWidget> {
  final List<String> _images = [];
  final PageController _pageController = PageController();

  @override
  void initState() {
    if (widget.user.profilePicture != null) {
      _images.add(widget.user.profilePicture!);
    }
    for (var image in widget.user.mediaFiles) {
      _images.add(image);
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GridTile(
      header: widget.user.isOnline
          ? const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: OnlineStatus(),
              ),
            )
          : const SizedBox(),
      footer: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => UserDetailsPage(user: widget.user),
            ),
          ).then((value) {
            widget.onNavigateBack?.call();
          });
        },
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppConstants.defaultNumericValue),
            bottomRight: Radius.circular(AppConstants.defaultNumericValue),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.black45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppConstants.defaultNumericValue),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.defaultNumericValue),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${widget.user.fullName} ',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 21,
                                  ),
                                ),
                                if (widget.user.userAccountSettingsModel
                                        .showAge !=
                                    false)
                                  TextSpan(
                                    text: (DateTime.now()
                                                .difference(
                                                    widget.user.birthDay)
                                                .inDays ~/
                                            365)
                                        .toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      widget.user.isVerified
                          ? GestureDetector(
                              onTap: () {
                                EasyLoading.showToast('Verified User!');
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        AppConstants.defaultNumericValue),
                                child: Icon(Icons.verified_user,
                                    color: CupertinoColors.activeGreen),
                              ),
                            )
                          : const SizedBox(),
                    ],
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final myProfile = ref.watch(userProfileFutureProvider);
                      return myProfile.when(
                          data: (data) {
                            if (data != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(
                                      height:
                                          AppConstants.defaultNumericValue / 4),
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: AppConstants
                                                    .defaultNumericValue /
                                                1.2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.location_on_outlined,
                                                size: 16,
                                                color: Colors.white),
                                            const SizedBox(
                                                width: AppConstants
                                                        .defaultNumericValue /
                                                    4),
                                            Text(
                                              '${(Geolocator.distanceBetween(data.userAccountSettingsModel.location.latitude, data.userAccountSettingsModel.location.longitude, widget.user.userAccountSettingsModel.location.latitude, widget.user.userAccountSettingsModel.location.longitude) / 1000).toStringAsFixed(2)} km away',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: AppConstants
                                                    .defaultNumericValue /
                                                1.2),
                                        child: InterestsSimilarityWidget(
                                          otherUser: widget.user,
                                          myProfile: data,
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(
                                      height: AppConstants.defaultNumericValue),
                                  UserLikeActions(
                                    onTapCross: widget.onTapCross,
                                    onTapBolt: widget.onTapBolt,
                                    onTapHeart: widget.onTapHeart,
                                    showShadow: true,
                                  ),
                                  const SizedBox(
                                      height: AppConstants.defaultNumericValue),
                                ],
                              );
                            } else {
                              return const SizedBox();
                            }
                          },
                          error: (_, __) => const SizedBox(),
                          loading: () => const SizedBox());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: _images.isEmpty
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultNumericValue),
                border: Border.all(color: Colors.grey, width: 2),
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultNumericValue),
                child: const Center(child: Icon(CupertinoIcons.photo)),
              ),
            )
          : PageView(
              controller: _pageController,
              onPageChanged: (_) {
                setState(() {});
              },
              physics: const NeverScrollableScrollPhysics(),
              children: _images.map((e) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                            AppConstants.defaultNumericValue),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            AppConstants.defaultNumericValue),
                        child: Image.network(
                          e,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator.adaptive());
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                                child: Icon(CupertinoIcons.photo));
                          },
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _pageController.previousPage(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut);
                              },
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _pageController.nextPage(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut);
                              },
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class InterestsSimilarityWidget extends StatelessWidget {
  final UserProfileModel otherUser;
  final UserProfileModel myProfile;
  final Color? color;
  const InterestsSimilarityWidget({
    super.key,
    required this.otherUser,
    required this.myProfile,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final myInterests = myProfile.interests;
    final otherInterests = otherUser.interests;

    double similarity = 0;
    for (final interest in myInterests) {
      if (otherInterests.contains(interest)) {
        similarity++;
      }
    }

    double percentage = (similarity / myInterests.length) * 100;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.join_inner,
          size: 16,
          color: color ?? Colors.white,
        ),
        const SizedBox(width: AppConstants.defaultNumericValue / 4),
        Text(
          '${percentage.toStringAsFixed(0)}% similarity',
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }
}

class UserLikeActions extends StatelessWidget {
  final VoidCallback onTapCross;
  final VoidCallback onTapBolt;
  final VoidCallback onTapHeart;
  final bool showShadow;
  const UserLikeActions({
    super.key,
    required this.onTapCross,
    required this.onTapBolt,
    required this.onTapHeart,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    List<BoxShadow> boxShadow = showShadow
        ? const [
            BoxShadow(
              color: Colors.black45,
              spreadRadius: 4,
              blurRadius: 8,
              offset: Offset(0, 2), // changes position of shadow
            ),
          ]
        : [];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultNumericValue),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onTapCross,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppConfig.dislikeButtonColor, width: 2),
                    boxShadow: boxShadow,
                  ),
                  child: const Icon(Icons.clear,
                      color: AppConfig.dislikeButtonColor),
                ),
                if (AppConfig.showInteractionButtonText)
                  const SizedBox(height: AppConstants.defaultNumericValue / 3),
                if (AppConfig.showInteractionButtonText)
                  Text(AppConfig.dislikeButtonText,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppConfig.dislikeButtonColor,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTapBolt,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: AppConfig.superLikeButtonColor, width: 2),
                    boxShadow: boxShadow,
                  ),
                  child: const Icon(Icons.bolt,
                      color: AppConfig.superLikeButtonColor, size: 32),
                ),
                if (AppConfig.showInteractionButtonText)
                  const SizedBox(height: AppConstants.defaultNumericValue / 3),
                if (AppConfig.showInteractionButtonText)
                  Text(AppConfig.superLikeButtonText,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppConfig.superLikeButtonColor,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTapHeart,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border:
                        Border.all(color: AppConfig.likeButtonColor, width: 2),
                    boxShadow: boxShadow,
                  ),
                  child: const Icon(Icons.favorite,
                      color: AppConfig.likeButtonColor),
                ),
                if (AppConfig.showInteractionButtonText)
                  const SizedBox(height: AppConstants.defaultNumericValue / 3),
                if (AppConfig.showInteractionButtonText)
                  Text(AppConfig.likeButtonText,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: AppConfig.likeButtonColor,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnlineStatus extends StatelessWidget {
  const OnlineStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 3, 200, 10),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            spreadRadius: 0,
            blurRadius: 2,
            offset: Offset(0, 1), // changes position of shadow
          ),
        ],
      ),
      child: Text(
        'Online',
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          shadows: [
            const Shadow(
              blurRadius: 2.0,
              color: Colors.black26,
              offset: Offset(1.0, 1.0),
            ),
          ],
        ),
      ),
    );
  }
}
