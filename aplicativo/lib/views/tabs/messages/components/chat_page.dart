import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_pop_up_menu/custom_pop_up_menu.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/date_formater.dart';
import 'package:mioamoreapp/helpers/encrypt_helper.dart';
import 'package:mioamoreapp/helpers/media_picker_helper.dart';
import 'package:mioamoreapp/models/chat_item_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/block_user_provider.dart';
import 'package:mioamoreapp/providers/chat_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/views/others/photo_view_page.dart';
import 'package:mioamoreapp/views/others/report_page.dart';
import 'package:mioamoreapp/views/others/user_card_widget.dart';
import 'package:mioamoreapp/views/others/user_details_page.dart';
import 'package:mioamoreapp/views/others/video_player_page.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_media_gallery_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_page_background.dart';
import 'package:social_media_recorder/audio_encoder_type.dart';
import 'package:social_media_recorder/screen/social_media_recorder.dart';


class ChatPage extends ConsumerStatefulWidget {
  final String otherUserId;
  final String matchId;
  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.matchId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _chatController = TextEditingController();
  bool emojiShowing = false;
  String? _imagePath;
  String? _videoPath;
  String? _audioPath;
  String? _filePath;

  String? _searchQuery;

  void _onSendMessage() async {
    final chatData = ref.read(chatProvider);

    if (_chatController.text.isNotEmpty ||
        _imagePath != null ||
        _videoPath != null ||
        _audioPath != null ||
        _filePath != null) {
      final currentTime = DateTime.now();

      String? imageUrl;
      String? videoUrl;
      String? audioUrl;
      String? fileUrl;

      if (_imagePath != null) {
        EasyLoading.show(status: 'Uploading image...');
        imageUrl = await chatData.uploadFile(
            file: File(_imagePath!), matchId: widget.matchId);
        EasyLoading.dismiss();
      }

      if (_videoPath != null) {
        EasyLoading.show(status: 'Uploading video...');
        videoUrl = await chatData.uploadFile(
            file: File(_videoPath!), matchId: widget.matchId);
        EasyLoading.dismiss();
      }

      if (_audioPath != null) {
        EasyLoading.show(status: 'Uploading audio...');
        audioUrl = await chatData.uploadFile(
            file: File(_audioPath!), matchId: widget.matchId);
        EasyLoading.dismiss();
      }

      if (_filePath != null) {
        EasyLoading.show(status: 'Uploading file...');
        fileUrl = await chatData.uploadFile(
            file: File(_filePath!), matchId: widget.matchId);
        EasyLoading.dismiss();
      }

      final String? message = _chatController.text.isEmpty
          ? null
          : encryptText(_chatController.text);

      ChatItemModel chatItem = ChatItemModel(
        message: message,
        createdAt: currentTime,
        id: currentTime.millisecondsSinceEpoch.toString(),
        userId: ref.watch(currentUserStateProvider)!.uid,
        matchId: widget.matchId,
        isRead: false,
        image: imageUrl,
        video: videoUrl,
        audio: audioUrl,
        file: fileUrl,
      );

      chatData.createChatItem(widget.matchId, chatItem);
      _chatController.clear();
      setState(() {
        _imagePath = null;
        _videoPath = null;
        _audioPath = null;
        _filePath = null;
      });
    }
  }

  _onEmojiSelected(Emoji emoji) {
    setState(() {
      _chatController
        ..text += emoji.emoji
        ..selection = TextSelection.fromPosition(
            TextPosition(offset: _chatController.text.length));
    });
  }

  _onBackspacePressed() {
    setState(() {
      _chatController
        ..text = _chatController.text.characters.skipLast(1).toString()
        ..selection = TextSelection.fromPosition(
            TextPosition(offset: _chatController.text.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    final otherUsers = ref.watch(otherUsersProvider);
    UserProfileModel? otherUser;
    otherUsers.whenData((value) {
      otherUser = value
          .where((element) {
            return element.userId == widget.otherUserId;
          })
          .toList()
          .first;
    });

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
        setState(() {
          emojiShowing = false;
        });
      },
      child: ChatPageBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            toolbarHeight: 0,
            backgroundColor: AppConstants.primaryColor.withOpacity(0.8),
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (otherUser != null)
                  ChatTopBar(
                    otherUser: otherUser!,
                    myUserId: ref.watch(currentUserStateProvider)!.uid,
                    matchId: widget.matchId,
                    onSearch: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                    },
                  ),
                Expanded(
                  child: ChatBody(
                    matchId: widget.matchId,
                    searchQuery: _searchQuery,
                    onSearchClear: () {
                      setState(() {
                        _searchQuery = null;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppConstants.defaultNumericValue / 2),
                ChatTextFieldAndOthers(
                  chatController: _chatController,
                  onChangeText: () {
                    setState(() {});
                  },
                  onTapEmoji: () {
                    setState(() {
                      emojiShowing = !emojiShowing;
                    });
                    FocusScope.of(context).requestFocus(FocusNode());
                  },
                  onTapVoice: () {
                    showModalBottomSheet(
                      context: context,
                      isDismissible: false,
                      enableDrag: false,
                      backgroundColor: Colors.transparent,
                      builder: (_) => VoiceRecorder(matchId: widget.matchId),
                    );
                  },
                  onTapTextField: () {
                    setState(() {
                      emojiShowing = false;
                    });
                  },
                  imageUrl: _imagePath,
                  videoUrl: _videoPath,
                  audioUrl: _audioPath,
                  fileUrl: _filePath,
                  onImageSelected: (String? path) {
                    setState(() {
                      _imagePath = path;
                    });
                  },
                  onVideoSelected: (String? path) {
                    setState(() {
                      _videoPath = path;
                    });
                  },
                  onAudioSelected: (String? path) {
                    setState(() {
                      _audioPath = path;
                    });
                  },
                  onFileSelected: (String? path) {
                    setState(() {
                      _filePath = path;
                    });
                  },
                  onTapSend: _onSendMessage,
                ),
                const SizedBox(height: AppConstants.defaultNumericValue / 2),
                Offstage(
                  offstage: !emojiShowing,
                  child: SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (Category? category, Emoji emoji) {
                        _onEmojiSelected(emoji);
                      },
                      onBackspacePressed: _onBackspacePressed,
                      config: Config(
                        categoryViewConfig: CategoryViewConfig(
                          iconColorSelected: AppConstants.primaryColor,
                          indicatorColor: AppConstants.primaryColor,
                        ),
                        bottomActionBarConfig:
                            const BottomActionBarConfig(enabled: false),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatBody extends ConsumerStatefulWidget {
  final String matchId;
  final String? searchQuery;
  final VoidCallback onSearchClear;
  const ChatBody({
    super.key,
    required this.matchId,
    required this.searchQuery,
    required this.onSearchClear,
  });

  @override
  ConsumerState<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<ChatBody> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final chatStreams = ref.watch(chatStreamProviderProvider(widget.matchId));

    return chatStreams.when(
        data: (data) {
          return Column(
            children: [
              if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty)
                ListTile(
                  title: Text(
                    "Searching for",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  leading: const Icon(Icons.search),
                  minLeadingWidth: 0,
                  subtitle: Text(
                    widget.searchQuery!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: widget.onSearchClear,
                      ),
                      IconButton(
                          onPressed: () {
                            //Move to a specific chat item
                            _scrollController.animateTo(
                              _scrollController.position.minScrollExtent,
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_downward)),
                      IconButton(
                          onPressed: () {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_upward)),
                    ],
                  ),
                ),
              if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty)
                const Divider(height: 0),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final bool isSearching = widget.searchQuery != null &&
                        widget.searchQuery!.isNotEmpty &&
                        item.message != null &&
                        decryptText(item.message!)
                            .toLowerCase()
                            .contains(widget.searchQuery!.toLowerCase());

                    return MessageSingleTile(
                      key: ValueKey(item.id),
                      chat: item,
                      matchId: widget.matchId,
                      isSearching: isSearching,
                    );
                  },
                ),
              ),
            ],
          );
        },
        error: (_, __) => const SizedBox(),
        loading: () => const SizedBox());
  }
}

class ChatTopBar extends ConsumerStatefulWidget {
  final UserProfileModel otherUser;
  final String myUserId;
  final Function(String?) onSearch;

  final String matchId;
  const ChatTopBar({
    super.key,
    required this.otherUser,
    required this.myUserId,
    required this.onSearch,
    required this.matchId,
  });

  @override
  ConsumerState<ChatTopBar> createState() => _ChatTopBarState();
}

class _ChatTopBarState extends ConsumerState<ChatTopBar> {
  final CustomPopupMenuController _moreMenuController =
      CustomPopupMenuController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppConstants.defaultNumericValue),
            bottomRight: Radius.circular(AppConstants.defaultNumericValue),
          ),
          gradient: AppConstants.defaultGradient),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => UserDetailsPage(
                user: widget.otherUser,
                matchId: widget.matchId,
              ),
            ),
          );
        },
        contentPadding: const EdgeInsets.only(bottom: 4),
        title: Row(
          children: [
            Text(
              widget.otherUser.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            if (widget.otherUser.isOnline)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: OnlineStatus(),
              ),
          ],
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BackButton(color: Colors.white),
            UserCirlePicture(
              imageUrl: widget.otherUser.profilePicture,
              size: AppConstants.defaultNumericValue * 3,
            )
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CupertinoButton(
            //   padding: EdgeInsets.zero,
            //   child:
            //       const Icon(CupertinoIcons.phone_solid, color: Colors.white),
            //   onPressed: () {},
            // ),
            // CupertinoButton(
            //   padding: EdgeInsets.zero,
            //   child: const Icon(CupertinoIcons.video_camera_solid,
            //       color: Colors.white),
            //   onPressed: () {},
            // ),
            CustomPopupMenu(
              menuBuilder: () => ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultNumericValue / 2),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MoreMenuTitle(
                          title: 'View Profile',
                          onTap: () {
                            _moreMenuController.hideMenu();
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) => UserDetailsPage(
                                  user: widget.otherUser,
                                  matchId: widget.matchId,
                                ),
                              ),
                            );
                          },
                        ),
                        MoreMenuTitle(
                          title: 'Media Gallery',
                          onTap: () {
                            _moreMenuController.hideMenu();
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) =>
                                    ChatMediaGalleryConsumerPage(
                                        matchId: widget.matchId),
                              ),
                            );
                          },
                        ),
                        MoreMenuTitle(
                          title: 'Search',
                          onTap: () async {
                            _moreMenuController.hideMenu();
                            final String? query = await showDialog(
                                context: context,
                                builder: (context) {
                                  final searchController =
                                      TextEditingController();
                                  return AlertDialog(
                                    title: const Text('Search Keyword'),
                                    content: TextField(
                                      controller: searchController,
                                      autofocus: true,
                                      onChanged: (_) {
                                        setState(() {});
                                      },
                                      decoration: const InputDecoration(
                                          hintText: 'Search here...'),
                                    ),
                                    actions: [
                                      OutlinedButton(
                                        child: const Text('Cancel'),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop(
                                              searchController.text.isEmpty
                                                  ? null
                                                  : searchController.text);
                                        },
                                        child: const Text("Search"),
                                      )
                                    ],
                                  );
                                });

                            widget.onSearch(query);
                          },
                        ),
                        MoreMenuTitle(
                          title: 'Background',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ChatWallpaperPage()),
                            );
                            _moreMenuController.hideMenu();
                          },
                        ),
                        // MoreMenuTitle(
                        //   title: 'Clear Chat',
                        //   onTap: () async {
                        //     _moreMenuController.hideMenu();
                        //     await ref
                        //         .read(chatProvider)
                        //         .clearChat(widget.matchId)
                        //         .then((value) {
                        //       if (value) {
                        //         Navigator.of(context).pop();
                        //       }
                        //     });
                        //   },
                        // ),
                        MoreMenuTitle(
                          title: 'Report',
                          onTap: () {
                            _moreMenuController.hideMenu();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportPage(
                                    userProfileModel: widget.otherUser),
                              ),
                            );
                          },
                        ),
                        MoreMenuTitle(
                          title: 'Block',
                          onTap: () {
                            _moreMenuController.hideMenu();
                            showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("Block"),
                                    content: const Text(
                                        "Are you sure you want to block this user?"),
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
                                            EasyLoading.show(
                                                status: "Blocking...");

                                            await blockUser(
                                                    widget.otherUser.userId,
                                                    widget.myUserId)
                                                .then((value) {
                                              ref.invalidate(
                                                  otherUsersProvider);
                                              ref.invalidate(
                                                  blockedUsersFutureProvider);
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
              child: const CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: null,
                child:
                    Icon(CupertinoIcons.ellipsis_vertical, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatTextFieldAndOthers extends StatefulWidget {
  final TextEditingController chatController;
  final VoidCallback onTapEmoji;
  final VoidCallback onTapVoice;
  final VoidCallback onTapSend;
  final VoidCallback onChangeText;
  final VoidCallback onTapTextField;
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final String? fileUrl;
  final Function(String?) onImageSelected;
  final Function(String?) onVideoSelected;
  final Function(String?) onAudioSelected;
  final Function(String?) onFileSelected;

  const ChatTextFieldAndOthers({
    super.key,
    required this.chatController,
    required this.onTapEmoji,
    required this.onTapVoice,
    required this.onTapSend,
    required this.onChangeText,
    required this.onTapTextField,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    this.fileUrl,
    required this.onImageSelected,
    required this.onVideoSelected,
    required this.onAudioSelected,
    required this.onFileSelected,
  });

  @override
  State<ChatTextFieldAndOthers> createState() => _ChatTextFieldAndOthersState();
}

class _ChatTextFieldAndOthersState extends State<ChatTextFieldAndOthers> {
  final CustomPopupMenuController _addMenuController =
      CustomPopupMenuController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.imageUrl != null)
          Stack(
            children: [
              Image.file(
                File(widget.imageUrl!),
                fit: BoxFit.cover,
                height: 300,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: AppConstants.primaryColor,
                  onPressed: () {
                    widget.onImageSelected(null);
                  },
                ),
              ),
            ],
          ),
        if (widget.videoUrl != null)
          Stack(
            children: [
              VideoPlayerThumbNail(onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => VideoPlayerPage(
                      isNetwork: false, videoUrl: widget.videoUrl!),
                ));
              }),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  color: AppConstants.primaryColor,
                  onPressed: () {
                    widget.onVideoSelected(null);
                  },
                ),
              ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CustomPopupMenu(
              menuBuilder: () => ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultNumericValue / 2),
                child: Container(
                  decoration: BoxDecoration(color: AppConstants.primaryColor),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChatAddMenuItem(
                          icon: CupertinoIcons.photo_camera_solid,
                          title: 'Camera',
                          onTap: () async {
                            _addMenuController.hideMenu();
                            pickMedia(isCamera: true).then((value) {
                              widget.onImageSelected(value);
                            });
                          },
                        ),
                        ChatAddMenuItem(
                          icon: CupertinoIcons.photo_fill,
                          title: 'Gallery',
                          onTap: () {
                            _addMenuController.hideMenu();
                            pickMedia(isCamera: false).then((value) {
                              widget.onImageSelected(value);
                            });
                          },
                        ),
                        // ChatAddMenuItem(
                        //   icon: CupertinoIcons.mic_solid,
                        //   title: 'Audio',
                        //   onTap: () {
                        //     _addMenuController.hideMenu();
                        //     widget.onAudioSelected(null);
                        //   },
                        // ),
                        ChatAddMenuItem(
                          icon: CupertinoIcons.video_camera_solid,
                          title: 'Video',
                          onTap: () {
                            _addMenuController.hideMenu();
                            pickMedia(isVideo: true).then((value) {
                              widget.onVideoSelected(value);
                            });
                          },
                        ),
                        // ChatAddMenuItem(
                        //   icon: CupertinoIcons.paperclip,
                        //   title: 'File',
                        //   onTap: () {
                        //     _addMenuController.hideMenu();
                        //     widget.onFileSelected(null);
                        //   },
                        // ),
                      ],
                    ),
                  ),
                ),
              ),
              pressType: PressType.singleClick,
              verticalMargin: -10,
              controller: _addMenuController,
              arrowColor: AppConstants.primaryColor,
              barrierColor: AppConstants.primaryColor.withOpacity(0.1),
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: null,
                child: Icon(CupertinoIcons.add_circled_solid,
                    color: AppConstants.primaryColor),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(
                    left: AppConstants.defaultNumericValue),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultNumericValue),
                  color: AppConfig.chatTextFieldAndOtherText,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.chatController,
                        keyboardType: TextInputType.text,
                        minLines: null,
                        onTap: widget.onTapTextField,
                        onSubmitted: (value) {
                          widget.onTapSend();
                        },
                        onChanged: (_) {
                          widget.onChangeText();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Type here...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    //Emoji
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: widget.onTapEmoji,
                      child: const Icon(CupertinoIcons.smiley),
                    ),
                  ],
                ),
              ),
            ),

            //TODO: Send Voice Message
            widget.chatController.text.isEmpty &&
                    widget.imageUrl == null &&
                    widget.videoUrl == null &&
                    widget.audioUrl == null &&
                    widget.fileUrl == null
                // ? CupertinoButton(
                //     padding: EdgeInsets.zero,
                //     onPressed: widget.onTapVoice,
                //     child: const Icon(CupertinoIcons.mic_circle_fill),
                //   )
                ? const CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: null,
                    child: Icon(CupertinoIcons.paperplane_fill),
                  )
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onTapSend,
                    child: const Icon(CupertinoIcons.paperplane_fill),
                  ),
          ],
        ),
      ],
    );
  }
}

class MoreMenuTitle extends StatelessWidget {
  final VoidCallback onTap;

  final String title;
  const MoreMenuTitle({
    super.key,
    required this.onTap,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultNumericValue,
            vertical: AppConstants.defaultNumericValue / 1.2),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(color: Colors.black87)),
      ),
    );
  }
}

class ChatAddMenuItem extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  const ChatAddMenuItem({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultNumericValue,
            vertical: AppConstants.defaultNumericValue / 1.2),
        child: Row(
          children: [
            Icon(
              icon,
              size: Theme.of(context).textTheme.titleSmall!.fontSize,
              color: Colors.white,
            ),
            const SizedBox(width: AppConstants.defaultNumericValue),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageSingleTile extends ConsumerWidget {
  final ChatItemModel chat;
  final String matchId;
  final bool isSearching;
  const MessageSingleTile({
    super.key,
    required this.chat,
    required this.matchId,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool? isNotMe = chat.userId == null
        ? null
        : chat.userId != ref.watch(currentUserStateProvider)?.uid;

    if (isNotMe == null) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
            child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultNumericValue,
            vertical: AppConstants.defaultNumericValue / 2,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(
              AppConstants.defaultNumericValue,
            ),
          ),
          child: Text(decryptText(chat.message ?? "")),
        )),
      );
    } else {
      if (!chat.isRead) {
        if (isNotMe) {
          ref
              .read(chatProvider)
              .updateChatItem(matchId, chat.copyWith(isRead: true));
        }
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: isNotMe ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              margin:
                  const EdgeInsets.all(AppConstants.defaultNumericValue / 4),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              decoration: BoxDecoration(
                color: isNotMe
                    ? AppConfig.chatTextFieldAndOtherText
                    : AppConfig.chatMyTextColor,
                borderRadius: BorderRadius.only(
                  topLeft:
                      const Radius.circular(AppConstants.defaultNumericValue),
                  topRight:
                      const Radius.circular(AppConstants.defaultNumericValue),
                  bottomLeft: isNotMe
                      ? Radius.zero
                      : const Radius.circular(AppConstants.defaultNumericValue),
                  bottomRight: isNotMe
                      ? const Radius.circular(AppConstants.defaultNumericValue)
                      : Radius.zero,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(
                    AppConstants.defaultNumericValue / 1.3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isNotMe
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    if (chat.image != null)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => PhotoViewPage(
                                images: [chat.image!],
                                title: chat.message,
                              ),
                            ));
                          },
                          child: CachedNetworkImage(
                            imageUrl: chat.image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (chat.image != null && chat.message != null)
                      const SizedBox(height: 8),
                    if (chat.video != null)
                      VideoPlayerThumbNail(onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => VideoPlayerPage(
                              isNetwork: true, videoUrl: chat.video!),
                        ));
                      }),
                    if (chat.video != null && chat.message != null)
                      const SizedBox(height: 8),
                    // if (chat.audio != null)
                    //   VoiceMessageView(
                    //     audioSrc: chat.audio!,
                    //     me: !isNotMe,
                    //     contactBgColor: Colors.white,
                    //     meBgColor: AppConstants.primaryColor,
                    //     contactFgColor: AppConstants.primaryColor,
                    //     contactPlayIconColor: Colors.white,
                    //     mePlayIconColor: AppConstants.primaryColor,
                    //   ),
                    // if (chat.audio != null && chat.message != null)
                    //   const SizedBox(height: 8),
                    if (chat.message != null)
                      Text(
                        decryptText(chat.message!),
                        style: TextStyle(
                          fontSize: 16,
                          backgroundColor: isSearching ? Colors.white : null,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormatter.toWholeDateTime(chat.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!isNotMe) const SizedBox(width: 8),
                        if (!isNotMe)
                          Icon(
                            Icons.done_all,
                            size: 12,
                            color: chat.isRead
                                ? AppConstants.primaryColor
                                : Colors.black,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          isNotMe
              ? const SizedBox(height: AppConstants.defaultNumericValue / 8)
              : const SizedBox()
        ],
      );
    }
  }
}

class VoiceRecorder extends ConsumerWidget {
  final String matchId;
  const VoiceRecorder({super.key, required this.matchId});

  @override
  Widget build(BuildContext context, ref) {
    return Container(
      margin: const EdgeInsets.all(AppConstants.defaultNumericValue),
      // height: MediaQuery.of(context).size.height * 0.2,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
      ),
      padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Record your voice message"),
            trailing: IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close)),
            subtitle: const Text("Press and hold the button to record"),
          ),
          const Divider(height: 0),
          const SizedBox(height: AppConstants.defaultNumericValue),
          Align(
            alignment: Alignment.centerRight,
            child: SocialMediaRecorder(
              recordIconWhenLockBackGroundColor: AppConstants.primaryColor,
              recordIconBackGroundColor: AppConstants.primaryColor,
              recordIcon: const Icon(
                CupertinoIcons.mic_circle_fill,
                color: Colors.white,
                size: 30,
              ),
              backGroundColor: AppConstants.primaryColor,
              radius: BorderRadius.circular(8),
              sendRequestFunction: (soundFile, _) async {
                final chatData = ref.read(chatProvider);
                final currentTime = DateTime.now();

                EasyLoading.show(status: 'Sending voice message...');

                await chatData
                    .uploadFile(file: soundFile, matchId: matchId)
                    .then((audioUrl) {
                  EasyLoading.dismiss();

                  if (audioUrl == null) {
                    EasyLoading.showError('Failed to send voice message');
                  } else {
                    ChatItemModel chatItem = ChatItemModel(
                      createdAt: currentTime,
                      id: currentTime.millisecondsSinceEpoch.toString(),
                      userId: ref.watch(currentUserStateProvider)!.uid,
                      matchId: matchId,
                      isRead: false,
                      audio: audioUrl,
                    );

                    chatData.createChatItem(matchId, chatItem);
                  }
                  Navigator.of(context).pop();
                });
              },
              encode: AudioEncoderType.AAC_LD,
            ),
          ),
        ],
      ),
    );
  }
}
