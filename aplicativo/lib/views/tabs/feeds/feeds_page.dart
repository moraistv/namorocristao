import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/date_formater.dart';
import 'package:mioamoreapp/models/feed_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/feed_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/ads/banner_ads.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/lottie/no_item_found_widget.dart';
import 'package:mioamoreapp/views/custom/subscription_builder.dart';
import 'package:mioamoreapp/views/others/photo_view_page.dart';
import 'package:mioamoreapp/views/tabs/feeds/edit_feed_page.dart';
import 'package:mioamoreapp/views/tabs/feeds/feed_post_page.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_page.dart';

class FeedsPage extends ConsumerWidget {
  const FeedsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
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
              leading:
                  const SizedBox(width: AppConstants.defaultNumericValue * 2),
              title: Center(
                  child: CustomHeadLine(
                text: 'Feeds',
                secondPartColor: AppConstants.primaryColor,
              )),
              trailing: const NotificationButton(),
            ),
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          const Expanded(child: FeedsBody()),
          SubscriptionBuilder(
            builder: (context, isPremiumUser) {
              return isPremiumUser ? const SizedBox() : const MyBannerAd();
            },
          ),
        ],
      ),
    );
  }
}

class FeedsBody extends ConsumerWidget {
  const FeedsBody({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final feedList = ref.watch(getFeedsProvider);
    return ListView(
      children: [
        const CreateNewPostSection(),
        ...feedList.when(
            data: (data) {
              final otherUsers = ref.watch(otherUsersProvider);
              final userProfileProvider = ref.watch(userProfileFutureProvider);

              List<UserProfileModel> feedsUsers = [];

              otherUsers.whenData((value) {
                final users = value.where((element) {
                  return data
                      .map((e) => e.userId)
                      .toList()
                      .contains(element.userId);
                }).toList();

                feedsUsers.addAll(users);
              });

              userProfileProvider.whenData((value) {
                feedsUsers.add(value!);
              });

              return data.isEmpty
                  ? [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.2),
                      const NoItemFoundWidget(text: 'No Feeds Found'),
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.1),
                    ]
                  : data.map((e) {
                      final user = feedsUsers
                          .firstWhere((element) => element.userId == e.userId);
                      return SingleFeedPost(feed: e, user: user);
                    });
            },
            error: (_, __) => [const SizedBox()],
            loading: () => [const SizedBox()]),
      ],
    );
  }
}

class CreateNewPostSection extends ConsumerWidget {
  const CreateNewPostSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final currentUserProfile = ref.watch(userProfileFutureProvider);

    return currentUserProfile.when(
      data: (data) {
        return data == null
            ? const SizedBox()
            : Padding(
                padding: const EdgeInsets.only(
                    top: 0, bottom: 8, left: 16, right: 16),
                child: Row(
                  children: [
                    UserCirlePicture(
                        imageUrl: data.profilePicture,
                        size: AppConstants.defaultNumericValue * 2.5),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (context) => const FeedPostPage()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                width: 1,
                                color: Colors.black.withOpacity(0.87)),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text("Share your thoughts",
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                      ),
                    ),
                  ],
                ),
              );
      },
      error: (_, __) => const SizedBox(),
      loading: () => const SizedBox(),
    );
  }
}

class SingleFeedPost extends ConsumerStatefulWidget {
  final FeedModel feed;
  final UserProfileModel user;
  const SingleFeedPost({
    super.key,
    required this.feed,
    required this.user,
  });

  @override
  ConsumerState<SingleFeedPost> createState() => _SingleFeedPostState();
}

class _SingleFeedPostState extends ConsumerState<SingleFeedPost> {
  final CustomPopupMenuController _moreMenuController =
      CustomPopupMenuController();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              UserCirlePicture(
                  imageUrl: widget.user.profilePicture,
                  size: AppConstants.defaultNumericValue * 2.5),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.fullName,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      DateFormatter.toWholeDateTime(widget.feed.createdAt),
                      textAlign: TextAlign.end,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (widget.feed.userId ==
                  ref.watch(currentUserStateProvider)!.uid)
                CustomPopupMenu(
                  menuBuilder: () => ClipRRect(
                    borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue / 2),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white),
                      child: IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MoreMenuTitle(
                              title: 'Edit',
                              onTap: () async {
                                _moreMenuController.hideMenu();
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (context) =>
                                          EditFeedPage(feed: widget.feed)),
                                );
                              },
                            ),
                            MoreMenuTitle(
                              title: 'Delete',
                              onTap: () {
                                _moreMenuController.hideMenu();

                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Delete Feed"),
                                        content: const Text(
                                            "Are you sure you want to delete this feed?"),
                                        actions: [
                                          TextButton(
                                            child: const Text("Cancel"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          Consumer(
                                            builder: (context, ref, child) {
                                              return TextButton(
                                                child: const Text("Delete"),
                                                onPressed: () async {
                                                  await deleteFeed(
                                                          widget.feed.id)
                                                      .then((value) {
                                                    ref.invalidate(
                                                        getFeedsProvider);
                                                    Navigator.of(context).pop();
                                                  });
                                                },
                                              );
                                            },
                                          )
                                        ],
                                      );
                                    });
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
                  barrierColor: AppConstants.primaryColor.withOpacity(0.1),
                  child: GestureDetector(
                    child: const Icon(CupertinoIcons.ellipsis_vertical),
                  ),
                ),
            ],
          ),
          const SizedBox(
            height: 16,
          ),
          if (widget.feed.caption != null)
            PostText(postText: widget.feed.caption!),
          const SizedBox(
            height: 8,
          ),
          if (widget.feed.images.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PhotoViewPage(images: widget.feed.images),
                  ),
                );
              },
              child: PostImages(post: widget.feed),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class PostText extends StatefulWidget {
  final String postText;
  const PostText({
    super.key,
    required this.postText,
  });

  @override
  State<PostText> createState() => _PostTextState();
}

class _PostTextState extends State<PostText> {
  int _maxLInes = 3;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _maxLInes = _maxLInes > 3 ? 3 : 99999;
        });
      },
      child: Text(
        widget.postText,
        textAlign: TextAlign.start,
        maxLines: _maxLInes,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(fontSize: 16, color: Colors.black.withOpacity(0.87)),
      ),
    );
  }
}

class PostImages extends StatelessWidget {
  final FeedModel post;
  const PostImages({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: post.images.length == 1
          ? PostSingleImage(imageUrl: post.images.first)
          : post.images.length == 2
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: PostSingleImage(imageUrl: post.images.first),
                    ),
                    Expanded(
                      child: PostSingleImage(imageUrl: post.images.last),
                    )
                  ],
                )
              : post.images.length == 3
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: PostSingleImage(
                                imageUrl: post.images[0],
                              )),
                              Expanded(
                                child: PostSingleImage(
                                  imageUrl: post.images[1],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: PostSingleImage(
                            imageUrl: post.images.last,
                          ),
                        )
                      ],
                    )
                  : post.images.length == 4
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      child: PostSingleImage(
                                    imageUrl: post.images[0],
                                  )),
                                  Expanded(
                                    child: PostSingleImage(
                                      imageUrl: post.images[1],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      child: PostSingleImage(
                                    imageUrl: post.images[2],
                                  )),
                                  Expanded(
                                    child: PostSingleImage(
                                      imageUrl: post.images[3],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      child: PostSingleImage(
                                    imageUrl: post.images[0],
                                  )),
                                  Expanded(
                                    child: PostSingleImage(
                                      imageUrl: post.images[1],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                      child: PostSingleImage(
                                    imageUrl: post.images[2],
                                  )),
                                  Expanded(
                                    child: PostSingleImage(
                                      moreNumberOfImages:
                                          "${post.images.length - 3}+",
                                      imageUrl: post.images[3],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
    );
  }
}

class PostSingleImage extends StatelessWidget {
  final String imageUrl;
  final String? moreNumberOfImages;
  const PostSingleImage({
    super.key,
    required this.imageUrl,
    this.moreNumberOfImages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            image: moreNumberOfImages != null
                ? DecorationImage(image: NetworkImage(imageUrl))
                : null,
            color: Colors.white),
        child: moreNumberOfImages == null
            ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
            : Container(
                color: Colors.black.withOpacity(0.47),
                child: Center(
                  child: Text(
                    moreNumberOfImages!,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(color: Colors.white),
                  ),
                ),
              ));
  }
}
