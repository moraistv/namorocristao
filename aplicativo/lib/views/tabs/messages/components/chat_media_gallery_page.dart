import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/models/chat_item_model.dart';
import 'package:mioamoreapp/providers/chat_provider.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/others/photo_view_page.dart';
import 'package:mioamoreapp/views/others/video_player_page.dart';

class ChatMediaGalleryConsumerPage extends ConsumerWidget {
  final String matchId;
  const ChatMediaGalleryConsumerPage({
    super.key,
    required this.matchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatStreams = ref.watch(chatStreamProviderProvider(matchId));

    return chatStreams.when(
        data: (data) {
          final List<ChatItemModel> chatsWithImagesOrVideos = [];
          for (var chat in data) {
            if (chat.image != null || chat.video != null) {
              chatsWithImagesOrVideos.add(chat);
            }
          }
          return ChatMediaGalleryPage(chats: chatsWithImagesOrVideos);
        },
        error: (_, __) => const ErrorPage(),
        loading: () => const LoadingPage());
  }
}

class ChatMediaGalleryPage extends StatefulWidget {
  final List<ChatItemModel> chats;
  const ChatMediaGalleryPage({
    super.key,
    required this.chats,
  });

  @override
  State<ChatMediaGalleryPage> createState() => _ChatMediaGalleryPageState();
}

class _ChatMediaGalleryPageState extends State<ChatMediaGalleryPage> {
  @override
  Widget build(BuildContext context) {
    widget.chats.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    List<ChatItemModel> chatsWithImages =
        widget.chats.where((chat) => chat.image != null).toList();
    List<ChatItemModel> chatsWithVideos =
        widget.chats.where((chat) => chat.video != null).toList();

    //Tab View with images and videos
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media Gallery'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Images'),
              Tab(text: 'Videos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            chatsWithImages.isEmpty
                ? const Center(child: Text('No images'))
                : GridView.builder(
                    itemCount: chatsWithImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PhotoViewPage(
                                      images: chatsWithImages
                                          .map((e) => e.image!)
                                          .toList(),
                                      index: index,
                                    )),
                          );
                        },
                        child: CachedNetworkImage(
                            imageUrl: chatsWithImages[index].image!),
                      );
                    },
                  ),
            chatsWithVideos.isEmpty
                ? const Center(child: Text('No videos'))
                : GridView.builder(
                    itemCount: chatsWithVideos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: VideoPlayerThumbNail(onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerPage(
                                  videoUrl: chatsWithVideos[index].video!,
                                  isNetwork: true),
                            ),
                          );
                        }),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
