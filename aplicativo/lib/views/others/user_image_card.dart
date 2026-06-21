import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/views/others/user_card_widget.dart';
import 'package:mioamoreapp/views/others/user_details_page.dart';

class UserImageCard extends StatelessWidget {
  final String? matchId;
  final UserProfileModel user;
  const UserImageCard({
    super.key,
    this.matchId,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            CupertinoPageRoute(
                builder: (context) =>
                    UserDetailsPage(user: user, matchId: matchId)));
      },
      child: GridTile(
        footer: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.defaultNumericValue / 2,
            horizontal: AppConstants.defaultNumericValue,
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultNumericValue / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(AppConstants.defaultNumericValue / 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                      AppConstants.defaultNumericValue / 2),
                  color: Colors.black38,
                ),
                child: Center(
                  child: Text(
                    '${user.fullName.split(" ").first} ${DateTime.now().difference(user.birthDay).inDays ~/ 365}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        header: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (matchId != null)
                const Icon(CupertinoIcons.heart_solid,
                    color: CupertinoColors.destructiveRed,
                    size: AppConstants.defaultNumericValue * 1.5),
              const Spacer(),
              if (user.isVerified)
                const Icon(Icons.verified_user,
                    color: CupertinoColors.activeGreen,
                    size: AppConstants.defaultNumericValue * 1.5),
              if (user.isOnline) const SizedBox(width: 4),
              if (user.isOnline) const OnlineStatus(),
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(AppConstants.defaultNumericValue),
          ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(AppConstants.defaultNumericValue),
            child: (user.mediaFiles.isEmpty && user.profilePicture == null)
                ? const Center(
                    child: Icon(CupertinoIcons.photo),
                  )
                : (user.profilePicture != null)
                    ? CachedNetworkImage(
                        imageUrl: user.profilePicture!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator.adaptive()),
                        errorWidget: (context, url, error) {
                          return const Center(
                              child: Icon(CupertinoIcons.photo));
                        },
                      )
                    : user.mediaFiles.isEmpty
                        ? const Center(
                            child: Icon(CupertinoIcons.photo),
                          )
                        : CachedNetworkImage(
                            imageUrl: user.mediaFiles.isNotEmpty
                                ? user.mediaFiles.first
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
      ),
    );
  }
}
