import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/url_launcher_helper.dart';
import 'package:mioamoreapp/providers/feed_provider.dart';
import 'package:mioamoreapp/views/settings/verification/verification_steps.dart';
import 'package:mioamoreapp/views/tabs/feeds/feeds_page.dart';
import 'package:mioamoreapp/views/tabs/profile/edit_profile_page.dart';
import 'package:intl/intl.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final userProfileRef = ref.watch(userProfileFutureProvider);
    return Scaffold(
      backgroundColor: AppConstants.primaryColor,
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: AppConstants.primaryColor,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: AppConstants.defaultNumericValue),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue),
                child: CustomAppBar(
                  leading: CustomIconButton(
                      icon: CupertinoIcons.back,
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      padding: const EdgeInsets.all(
                          AppConstants.defaultNumericValue / 1.5)),
                  title: const Center(
                    child: CustomHeadLine(
                      text: 'Profile',
                      secondPartColor: Colors.white,
                    ),
                  ),
                  trailing: userProfileRef.when(
                      data: (data) => data == null
                          ? const SizedBox()
                          : CustomIconButton(
                              icon: Icons.edit,
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => EditProfilePage(
                                            userProfileModel: data),
                                        fullscreenDialog: true));
                              },
                              padding: const EdgeInsets.all(
                                  AppConstants.defaultNumericValue / 1.5),
                            ),
                      error: (_, __) => const SizedBox(),
                      loading: () => const SizedBox()),
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
            ],
          ),
          Expanded(
            child: userProfileRef.when(
              data: (data) {
                return data == null
                    ? const Center(child: Text("Not Available"))
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Column(
                                  children: [
                                    const SizedBox(
                                        height:
                                            AppConstants.defaultNumericValue *
                                                4),
                                    Center(
                                      child: ClipRRect(
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 10, sigmaY: 10),
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.8,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppConstants
                                                          .defaultNumericValue),
                                              color: Colors.white12,
                                            ),
                                            padding: const EdgeInsets.all(
                                                AppConstants
                                                    .defaultNumericValue),
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  const SizedBox(
                                                      height: AppConstants
                                                              .defaultNumericValue *
                                                          4),
                                                  Text(
                                                    data.fullName,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: AppConstants
                                                              .defaultNumericValue *
                                                          1.2,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      height: AppConstants
                                                              .defaultNumericValue /
                                                          2),
                                                  Text(
                                                    data.email ?? "",
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall!
                                                        .copyWith(
                                                            color:
                                                                Colors.white70),
                                                  ),
                                                  const SizedBox(
                                                      height: AppConstants
                                                          .defaultNumericValue),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.defaultNumericValue *
                                              10),
                                      border: Border.all(
                                          color: AppConstants.primaryColor,
                                          width:
                                              AppConstants.defaultNumericValue /
                                                  2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.defaultNumericValue *
                                              10),
                                      child: SizedBox(
                                        width:
                                            AppConstants.defaultNumericValue *
                                                7,
                                        height:
                                            AppConstants.defaultNumericValue *
                                                7,
                                        child: data.profilePicture == null ||
                                                data.profilePicture!.isEmpty
                                            ? CircleAvatar(
                                                backgroundColor: Theme.of(
                                                        context)
                                                    .scaffoldBackgroundColor,
                                                child: Icon(
                                                  CupertinoIcons.person_fill,
                                                  color:
                                                      AppConstants.primaryColor,
                                                  size: AppConstants
                                                          .defaultNumericValue *
                                                      5,
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: data.profilePicture!,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                        child:
                                                            CircularProgressIndicator
                                                                .adaptive()),
                                                errorWidget: (context, url,
                                                        error) =>
                                                    const Center(
                                                        child:
                                                            Icon(Icons.error)),
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: AppConstants.defaultNumericValue * 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppConstants.primaryColor,
                                    Theme.of(context).scaffoldBackgroundColor,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0.9, 1],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                      child: SizedBox(
                                    height:
                                        AppConstants.defaultNumericValue * 2,
                                  )),
                                  Expanded(
                                    child: Container(
                                      height:
                                          AppConstants.defaultNumericValue * 2,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(
                                              AppConstants.defaultNumericValue *
                                                  10),
                                          topRight: Radius.circular(
                                              AppConstants.defaultNumericValue *
                                                  10),
                                        ),
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            ProfileBottomPart(data: data),
                          ],
                        ),
                      );
              },
              error: (_, e) =>
                  const Center(child: Text("Something went wrong!")),
              loading: () => const Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileBottomPart extends StatefulWidget {
  final UserProfileModel data;
  const ProfileBottomPart({
    super.key,
    required this.data,
  });

  @override
  State<ProfileBottomPart> createState() => _ProfileBottomPartState();
}

class _ProfileBottomPartState extends State<ProfileBottomPart> {
  final List<String> _tabs = ['About', 'Gallery', "Feeds"];
  int _selectedTabIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppConstants.defaultNumericValue),
          bottomRight: Radius.circular(AppConstants.defaultNumericValue),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.defaultNumericValue * 2),
            child: Wrap(
                alignment: WrapAlignment.start,
                spacing: AppConstants.defaultNumericValue,
                runSpacing: AppConstants.defaultNumericValue,
                children: _tabs.map((e) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTabIndex = _tabs.indexOf(e);
                      });
                    },
                    child: Text(
                      e,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            color: _selectedTabIndex == _tabs.indexOf(e)
                                ? AppConstants.primaryColor
                                : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  );
                }).toList()),
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          getProfileBodyView(_selectedTabIndex, widget.data),
        ],
      ),
    );
  }
}

Widget getProfileBodyView(int index, UserProfileModel data) {
  switch (index) {
    case 0:
      return UserAboutView(data: data);
    case 1:
      return UserGalleryView(data: data);
    case 2:
      return UserFeedsView(user: data);
    default:
      return UserAboutView(data: data);
  }
}

class UserAboutView extends StatelessWidget {
  final UserProfileModel data;
  const UserAboutView({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileCompletenessAndGetVerifiedWidget(),
        ListTile(
          title: const Text("Phone Number"),
          subtitle: Text(data.phoneNumber == null || data.phoneNumber!.isEmpty
              ? "Not Set!"
              : data.phoneNumber!),
        ),
        // My Purpose
        ListTile(
          title: const Text("My Purpose"),
          subtitle: Text(data.myPurpose == null || data.myPurpose!.isEmpty
              ? "Not Set!"
              : data.myPurpose!),
        ),
        ListTile(
          title: const Text("About Me"),
          subtitle: Text(data.about == null || data.about!.isEmpty
              ? "Not Set!"
              : data.about!),
        ),
        ListTile(
          title: const Text("Birthday"),
          subtitle: Text(DateFormat("MM/dd/yyyy").format(data.birthDay)),
        ),
        ListTile(
          title: const Text("Gender"),
          subtitle: Text(data.gender.toUpperCase()),
        ),
        ListTile(
          title: const Text("Social Accounts"),
          subtitle: Wrap(
            spacing: AppConstants.defaultNumericValue / 2,
            children: [
              if (data.instagramUsername != null &&
                  data.instagramUsername!.isNotEmpty)
                ActionChip(
                  onPressed: () async {
                    UrlLauncherHelper.launchURL(Uri.parse(
                        "https://www.instagram.com/${data.instagramUsername}"));
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue / 2,
                    vertical: AppConstants.defaultNumericValue / 4,
                  ),
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue * 2),
                    side:
                        BorderSide(color: AppConstants.primaryColor, width: 1),
                  ),
                  avatar: Image.asset(
                    instagramIcon,
                    width: AppConstants.defaultNumericValue * 2,
                    height: AppConstants.defaultNumericValue * 2,
                  ),
                  label: Text(data.instagramUsername![0].toUpperCase() +
                      data.instagramUsername!.substring(1)),
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
              if (data.snapchatUsername != null &&
                  data.snapchatUsername!.isNotEmpty)
                ActionChip(
                  onPressed: () async {
                    UrlLauncherHelper.launchURL(Uri.parse(
                        "https://www.snapchat.com/add/${data.snapchatUsername}"));
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue / 2,
                    vertical: AppConstants.defaultNumericValue / 4,
                  ),
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue * 2),
                    side:
                        BorderSide(color: AppConstants.primaryColor, width: 1),
                  ),
                  avatar: Image.asset(
                    snapchatIcon,
                    width: AppConstants.defaultNumericValue * 2,
                    height: AppConstants.defaultNumericValue * 2,
                  ),
                  label: Text(data.snapchatUsername![0].toUpperCase() +
                      data.snapchatUsername!.substring(1)),
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
              if (data.twitterUsername != null &&
                  data.twitterUsername!.isNotEmpty)
                ActionChip(
                  onPressed: () async {
                    UrlLauncherHelper.launchURL(Uri.parse(
                        "https://www.twitter.com/${data.twitterUsername}"));
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue / 2,
                    vertical: AppConstants.defaultNumericValue / 4,
                  ),
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue * 2),
                    side:
                        BorderSide(color: AppConstants.primaryColor, width: 1),
                  ),
                  avatar: Image.asset(
                    twitterIcon,
                    width: AppConstants.defaultNumericValue * 2,
                    height: AppConstants.defaultNumericValue * 2,
                  ),
                  label: Text(data.twitterUsername![0].toUpperCase() +
                      data.twitterUsername!.substring(1)),
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
              if (data.facebookUsername != null &&
                  data.facebookUsername!.isNotEmpty)
                ActionChip(
                  onPressed: () async {
                    UrlLauncherHelper.launchURL(Uri.parse(
                        "https://www.facebook.com/${data.facebookUsername}"));
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue / 2,
                    vertical: AppConstants.defaultNumericValue / 4,
                  ),
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue * 2),
                    side:
                        BorderSide(color: AppConstants.primaryColor, width: 1),
                  ),
                  avatar: Image.asset(
                    facebookIcon,
                    width: AppConstants.defaultNumericValue * 2,
                    height: AppConstants.defaultNumericValue * 2,
                  ),
                  label: Text(data.facebookUsername![0].toUpperCase() +
                      data.facebookUsername!.substring(1)),
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
              if (data.tiktokUsername != null &&
                  data.tiktokUsername!.isNotEmpty)
                ActionChip(
                  onPressed: () async {
                    UrlLauncherHelper.launchURL(Uri.parse(
                        "https://www.tiktok.com/@${data.tiktokUsername}"));
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.defaultNumericValue / 2,
                    vertical: AppConstants.defaultNumericValue / 4,
                  ),
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue * 2),
                    side:
                        BorderSide(color: AppConstants.primaryColor, width: 1),
                  ),
                  avatar: Image.asset(
                    tiktokIcon,
                    width: AppConstants.defaultNumericValue * 2,
                    height: AppConstants.defaultNumericValue * 2,
                  ),
                  label: Text(data.tiktokUsername![0].toUpperCase() +
                      data.tiktokUsername!.substring(1)),
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
        ListTile(
          title: const Text("Interests"),
          subtitle: data.interests.isEmpty
              ? const Text("Nothing Found!")
              : Wrap(
                  spacing: AppConstants.defaultNumericValue / 2,
                  children: data.interests
                      .map((interest) => Chip(
                            backgroundColor:
                                AppConstants.primaryColor.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppConstants.defaultNumericValue * 2),
                              side: BorderSide(
                                  color: AppConstants.primaryColor, width: 1),
                            ),
                            label: Text(interest[0].toUpperCase() +
                                interest.substring(1)),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: AppConstants.defaultNumericValue * 8),
      ],
    );
  }
}

class UserGalleryView extends StatelessWidget {
  final UserProfileModel data;
  const UserGalleryView({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return data.mediaFiles.isEmpty
        ? SizedBox(
            height: MediaQuery.of(context).size.height / 2,
            child: const Center(child: Text("Nothing Found!")),
          )
        : GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppConstants.defaultNumericValue,
              right: AppConstants.defaultNumericValue,
              bottom: AppConstants.defaultNumericValue,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: AppConstants.defaultNumericValue,
              mainAxisSpacing: AppConstants.defaultNumericValue,
            ),
            children: data.mediaFiles.map((e) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultNumericValue),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultNumericValue),
                  child: CachedNetworkImage(
                      imageUrl: e,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator.adaptive()),
                      errorWidget: (context, url, error) {
                        return const Center(
                            child: Icon(Icons.image_not_supported));
                      }),
                ),
              );
            }).toList(),
          );
  }
}

class UserFeedsView extends ConsumerWidget {
  final UserProfileModel user;
  const UserFeedsView({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedList = ref.watch(getFeedsProvider);
    return feedList.when(
      data: (data) {
        final myFeeds =
            data.where((element) => element.userId == user.userId).toList();

        if (myFeeds.isEmpty) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: const Center(child: Text('No Feeds Yet')),
          );
        } else {
          return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final feed = myFeeds[index];

                return SingleFeedPost(feed: feed, user: user);
              },
              itemCount: myFeeds.length);
        }
      },
      error: (_, __) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
      ),
      loading: () => SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
      ),
    );
  }
}

class ProfileCompletenessAndGetVerifiedWidget extends ConsumerWidget {
  const ProfileCompletenessAndGetVerifiedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileFutureProvider);
    return user.when(
      data: (data) {
        int percentageComplete = _getProfilePercentageComplete(data!);

        debugPrint('USer verificaitons status:${data.isVerified}');

        return percentageComplete == 100
            ? data.isVerified
                ? const SizedBox()
                : Card(
                    elevation: 0,
                    margin: const EdgeInsets.all(
                        AppConstants.defaultNumericValue / 2),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultNumericValue,
                          vertical: AppConstants.defaultNumericValue / 2),
                      dense: true,
                      title: Text("You are almost there!",
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text("Get yourself as a verified user!",
                          style: Theme.of(context).textTheme.bodySmall),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.defaultNumericValue / 2,
                              vertical: AppConstants.defaultNumericValue / 4),
                          textStyle:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => GetVerifiedPage(user: data),
                            ),
                          );
                        },
                        child: const Text("Get Verified"),
                      ),
                    ),
                  )
            : Card(
                elevation: 0,
                margin:
                    const EdgeInsets.all(AppConstants.defaultNumericValue / 2),
                child: ListTile(
                  dense: true,
                  title: Text("Profile Completeness:",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                          child: LinearProgressIndicator(
                              value: percentageComplete / 100)),
                      const SizedBox(
                          width: AppConstants.defaultNumericValue / 2),
                      Text(
                        "$percentageComplete%",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(
                          width: AppConstants.defaultNumericValue / 2),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.defaultNumericValue / 2,
                          vertical: AppConstants.defaultNumericValue / 4),
                      textStyle:
                          Theme.of(context).textTheme.bodySmall!.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              EditProfilePage(userProfileModel: data),
                        ),
                      );
                    },
                    child: const Text("Complete"),
                  ),
                ),
              );
      },
      error: (error, stackTrace) => const SizedBox(),
      loading: () => const SizedBox(),
    );
  }
}

int _getProfilePercentageComplete(UserProfileModel profile) {
  // int total = 100;

  // if (profile.about == null || profile.about!.isEmpty) {
  //   total -= 10;
  // }

  // if ((profile.phoneNumber == null || profile.phoneNumber!.isEmpty) &&
  //     (profile.email == null || profile.email!.isEmpty)) {
  //   total -= 10;
  // }

  // // Images
  // if (profile.mediaFiles.isEmpty) {
  //   total -= 10;
  // }

  // // Interests
  // if (profile.interests.isEmpty) {
  //   total -= 10;
  // }

  // //Profile Picture
  // if (profile.profilePicture == null || profile.profilePicture!.isEmpty) {
  //   total -= 10;
  // }

  // return total;

  int totalItems = 7;

  int totalFilled = 0;

  if (profile.about != null && profile.about!.isNotEmpty) {
    totalFilled++;
  }

  if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) {
    totalFilled++;
  }

  if (profile.email != null && profile.email!.isNotEmpty) {
    totalFilled++;
  }

  if (profile.mediaFiles.isNotEmpty) {
    totalFilled++;
  }

  if (profile.interests.isNotEmpty) {
    totalFilled++;
  }

  if (profile.profilePicture != null && profile.profilePicture!.isNotEmpty) {
    totalFilled++;
  }

  bool isInsta = profile.instagramUsername != null &&
      profile.instagramUsername!.isNotEmpty;
  bool isSnap =
      profile.snapchatUsername != null && profile.snapchatUsername!.isNotEmpty;
  bool isTwitter =
      profile.twitterUsername != null && profile.twitterUsername!.isNotEmpty;
  bool isFacebook =
      profile.facebookUsername != null && profile.facebookUsername!.isNotEmpty;
  bool isTiktok =
      profile.tiktokUsername != null && profile.tiktokUsername!.isNotEmpty;

  bool isAnySocial = isInsta || isSnap || isTwitter || isFacebook || isTiktok;

  if (isAnySocial) {
    totalFilled++;
  }

  double percentage = (totalFilled / totalItems) * 100;

  return percentage.toInt();
}
