import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/date_formater.dart';
import 'package:mioamoreapp/helpers/encrypt_helper.dart';
import 'package:mioamoreapp/models/chat_item_model.dart';
import 'package:mioamoreapp/models/match_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/chat_provider.dart';
import 'package:mioamoreapp/providers/match_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/views/ads/banner_ads.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/custom/lottie/no_item_found_widget.dart';
import 'package:mioamoreapp/views/custom/subscription_builder.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/others/user_card_widget.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_page.dart';

class MessageConsumerPage extends ConsumerWidget {
  const MessageConsumerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchStreamProvider);

    return matches.when(
      data: (data) {
        final List<MessageViewModel> messages = [];

        messages.addAll(getAllMessages(ref, data));

        // return MessagesPage(messages: messages);
        return SubscriptionBuilder(
          builder: (context, isPremiumUser) {
            return MessagesPage(
                messages: messages, isPremiumUser: isPremiumUser);
          },
        );
      },
      error: (_, __) => const ErrorPage(),
      loading: () => const LoadingPage(),
    );
  }
}

class MessagesPage extends ConsumerStatefulWidget {
  final List<MessageViewModel> messages;
  final bool isPremiumUser;
  const MessagesPage({
    super.key,
    required this.messages,
    required this.isPremiumUser,
  });

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  bool _isSearchBarVisible = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    if (!widget.isPremiumUser && isAdmobAvailable) {
      InterstitialAd.load(
        adUnitId: Platform.isAndroid
            ? AndroidAdUnits.interstitialId
            : IOSAdUnits.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) async {
            debugPrint('InterstitialAd loaded.');

            await Future.delayed(const Duration(seconds: 4)).then((value) {
              ad.show();
            });
          },
          onAdFailedToLoad: (error) {},
        ),
      );
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final searchedMessages = widget.messages.where((element) {
      return element.matchedUser.fullName
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
    }).toList();

    searchedMessages.sort((a, b) {
      return b.lastMessageDate.compareTo(a.lastMessageDate);
    });

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
                  text: 'Messages',
                  secondPartColor: AppConstants.primaryColor,
                ),
              ),
              trailing: const NotificationButton(),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.defaultNumericValue),
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
                Expanded(
                  child: searchedMessages.isEmpty
                      ? const Center(
                          child: NoItemFoundWidget(text: 'No messages found'),
                        )
                      : ListView.builder(
                          itemCount: searchedMessages.length,
                          itemBuilder: (context, index) {
                            final message = searchedMessages[index];
                            return ConversationTile(messageViewModel: message);
                          },
                        ),
                ),
                SubscriptionBuilder(
                  builder: (context, isPremiumUser) {
                    return isPremiumUser
                        ? const SizedBox()
                        : const MyBannerAd();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends ConsumerWidget {
  final MessageViewModel messageViewModel;
  const ConversationTile({
    super.key,
    required this.messageViewModel,
  });

  @override
  Widget build(BuildContext context, ref) {
    return Column(
      children: [
        ListTile(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => ChatPage(
                  otherUserId: messageViewModel.matchedUser.userId,
                  matchId: messageViewModel.matchId,
                ),
              ),
            );
          },
          title: Row(
            children: [
              Text(
                messageViewModel.matchedUser.fullName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              if (messageViewModel.unreadCount > 0)
                const SizedBox(width: AppConstants.defaultNumericValue / 2),
              if (messageViewModel.unreadCount > 0)
                Badge(
                  backgroundColor: AppConstants.primaryColor,
                  label: Text(messageViewModel.unreadCount.toString()),
                ),
              if (messageViewModel.matchedUser.isOnline)
                const SizedBox(width: AppConstants.defaultNumericValue / 2),
              if (messageViewModel.matchedUser.isOnline) const OnlineStatus()
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormatter.toTime(messageViewModel.lastMessageDate),
                style: Theme.of(context).textTheme.bodySmall!,
              ),
              Text(
                DateFormatter.toYearMonthDay2(messageViewModel.lastMessageDate),
                style: Theme.of(context).textTheme.bodySmall!,
              ),
            ],
          ),
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (messageViewModel.lastMessage.userId ==
                  ref.watch(currentUserStateProvider)!.uid)
                const Text('You: '),
              if (messageViewModel.lastMessage.image != null)
                Icon(
                  Icons.image,
                  color: AppConstants.primaryColor,
                ),
              if (messageViewModel.lastMessage.image != null)
                const SizedBox(width: AppConstants.defaultNumericValue / 2),
              if (messageViewModel.lastMessage.video != null)
                Icon(
                  Icons.movie,
                  color: AppConstants.primaryColor,
                ),
              if (messageViewModel.lastMessage.video != null)
                const SizedBox(width: AppConstants.defaultNumericValue / 2),
              Text(
                decryptText(messageViewModel.lastMessage.message ?? ""),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          leading: UserCirlePicture(
              imageUrl: messageViewModel.matchedUser.profilePicture,
              size: AppConstants.defaultNumericValue * 3),
        ),
        const Divider(
          height: 0,
          indent: AppConstants.defaultNumericValue,
          endIndent: AppConstants.defaultNumericValue,
        ),
      ],
    );
  }
}

class MessageViewModel {
  UserProfileModel matchedUser;
  String matchId;
  ChatItemModel lastMessage;
  DateTime lastMessageDate;
  int unreadCount;
  MessageViewModel({
    required this.matchedUser,
    required this.matchId,
    required this.lastMessage,
    required this.lastMessageDate,
    required this.unreadCount,
  });

  MessageViewModel copyWith({
    UserProfileModel? matchedUser,
    String? matchId,
    ChatItemModel? lastMessage,
    DateTime? lastMessageDate,
    int? unreadCount,
  }) {
    return MessageViewModel(
      matchedUser: matchedUser ?? this.matchedUser,
      matchId: matchId ?? this.matchId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'matchedUser': matchedUser.toMap()});
    result.addAll({'matchId': matchId});
    result.addAll({'lastMessage': lastMessage.toMap()});
    result.addAll({'lastMessageDate': lastMessageDate.millisecondsSinceEpoch});
    result.addAll({'unreadCount': unreadCount});

    return result;
  }

  factory MessageViewModel.fromMap(Map<String, dynamic> map) {
    return MessageViewModel(
      matchedUser: UserProfileModel.fromMap(map['matchedUser']),
      matchId: map['matchId'] ?? '',
      lastMessage: ChatItemModel.fromMap(map['lastMessage']),
      lastMessageDate:
          DateTime.fromMillisecondsSinceEpoch(map['lastMessageDate']),
      unreadCount: map['unreadCount']?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory MessageViewModel.fromJson(String source) =>
      MessageViewModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'MessageViewModel(matchedUser: $matchedUser, matchId: $matchId, lastMessage: $lastMessage, lastMessageDate: $lastMessageDate, unreadCount: $unreadCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MessageViewModel &&
        other.matchedUser == matchedUser &&
        other.matchId == matchId &&
        other.lastMessage == lastMessage &&
        other.lastMessageDate == lastMessageDate &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode {
    return matchedUser.hashCode ^
        matchId.hashCode ^
        lastMessage.hashCode ^
        lastMessageDate.hashCode ^
        unreadCount.hashCode;
  }
}

List<MessageViewModel> getAllMessages(WidgetRef ref, List<MatchModel> data) {
  final otherUserIds = data.map((e) {
    return e.userIds.any(
            (element) => element != ref.watch(currentUserStateProvider)!.uid)
        ? e.userIds.firstWhere(
            (element) => element != ref.watch(currentUserStateProvider)!.uid)
        : null;
  }).toList();

  final otherUsers = ref.watch(otherUsersProvider);
  List<UserProfileModel> matchedUsers = [];
  otherUsers.whenData((value) {
    matchedUsers = value.where((element) {
      return otherUserIds.contains(element.userId);
    }).toList();
  });

  List<MessageViewModel> messages = [];

  for (var match in data) {
    final chatProvider = ref.watch(chatStreamProviderProvider(match.id));
    chatProvider.whenData((value) {
      final UserProfileModel otherUser = matchedUsers.firstWhere((element) =>
          element.userId ==
          match.userIds.firstWhere((element) =>
              element != ref.watch(currentUserStateProvider)!.uid));

      int unreadCount = 0;
      for (var message in value) {
        if (message.userId != ref.watch(currentUserStateProvider)!.uid) {
          if (message.isRead == false) {
            unreadCount++;
          }
        }
      }

      if (value.isNotEmpty) {
        MessageViewModel message = MessageViewModel(
          matchedUser: otherUser,
          lastMessage: value.first,
          lastMessageDate: value.first.createdAt,
          matchId: match.id,
          unreadCount: unreadCount,
        );

        messages.add(message);
      }
    });
  }

  return messages;
}
