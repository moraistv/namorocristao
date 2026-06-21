import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/feed_model.dart';
import 'package:mioamoreapp/providers/feed_provider.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';

class EditFeedPage extends ConsumerStatefulWidget {
  final FeedModel feed;
  const EditFeedPage({
    super.key,
    required this.feed,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditFeedPageState();
}

class _EditFeedPageState extends ConsumerState<EditFeedPage> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    _captionController.text = widget.feed.caption ?? "";
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Feed"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _captionController,
              maxLines: 9,
              decoration: InputDecoration(
                labelText: "Caption",
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultNumericValue),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue),
            CustomButton(
              text: "Save",
              onPressed: () async {
                final FeedModel newFeed = widget.feed.copyWith(
                  caption: _captionController.text,
                );
                await updateFeed(newFeed).then((value) {
                  ref.invalidate(getFeedsProvider);
                  Navigator.pop(context);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
