import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PhotoViewPage extends StatefulWidget {
  final List<String> images;
  final String? title;
  final int index;
  const PhotoViewPage({
    super.key,
    required this.images,
    this.title,
    this.index = 0,
  });

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  final _pageController = PageController();
  final _photoViewController = PhotoViewController();

  final List<String> _images = [];

  @override
  void initState() {
    _images.addAll(widget.images);
    Future.delayed(const Duration(milliseconds: 10), () {
      _pageController.jumpToPage(widget.index);
    });
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _photoViewController.dispose();
    _images.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title == null ? 'Image Viewer' : widget.title!),
        actions: const [
          // Tooltip(
          //   message: 'Save Image',
          //   child: CupertinoButton(
          //     padding: EdgeInsets.zero,
          //     child: const Icon(
          //       Icons.download,
          //       color: Colors.white,
          //     ),
          //     onPressed: () {
          //       final String image = _images[_pageController.page!.round()];
          //       final File file = File(image);
          //       final String fileName = file.path.split('/').last;

          //       final String filePath = '${file.parent.path}/$fileName';

          //       final File fileToSave = File(filePath);

          //       if (fileToSave.existsSync()) {
          //         fileToSave.deleteSync();
          //       }
          //       file.copySync(filePath);
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         SnackBar(
          //           content: Text('Image saved to $filePath'),
          //         ),
          //       );
          //     },
          //   ),
          // )
        ],
      ),
      body: PageView(
        controller: _pageController,
        children: _images.map((image) {
          return Uri.parse(image).isAbsolute
              ? PhotoView(
                  controller: _photoViewController,
                  imageProvider: CachedNetworkImageProvider(image),
                )
              : PhotoView(
                  controller: _photoViewController,
                  imageProvider: FileImage(File(image)),
                );
        }).toList(),
      ),
    );
  }
}
