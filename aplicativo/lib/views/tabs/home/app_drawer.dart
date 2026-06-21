import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/providers/version_provider.dart';
import 'package:mioamoreapp/views/company/about_us.dart';
import 'package:mioamoreapp/views/company/contact_us.dart';
import 'package:mioamoreapp/views/company/faq_page.dart';
import 'package:mioamoreapp/views/company/privacy_policy.dart';
import 'package:mioamoreapp/views/company/terms_and_conditions.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/custom/subscription_builder.dart';
import 'package:mioamoreapp/views/security/security_and_privacy_page.dart';
import 'package:mioamoreapp/views/settings/account_settings.dart';
import 'package:mioamoreapp/views/tabs/profile/profile_page.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final userProfileRef = ref.watch(userProfileFutureProvider);
    final versionRef = ref.watch(versionProvider);
    return Drawer(
      backgroundColor: AppConstants.primaryColor,
      child: Column(
        children: [
          userProfileRef.when(
              data: (data) {
                return data == null
                    ? const SizedBox()
                    : DrawerHeader(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CustomIconButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: CupertinoIcons.clear,
                              padding: const EdgeInsets.all(
                                  AppConstants.defaultNumericValue / 2),
                              color: Colors.white70,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              minLeadingWidth: 0,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfilePage()),
                                );
                              },
                              title: Text(
                                data.fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                (data.email == null || data.email!.isEmpty)
                                    ? (data.phoneNumber == null ||
                                            data.phoneNumber!.isEmpty)
                                        ? 'Add Email or Phone Number'
                                        : data.phoneNumber!
                                    : data.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              leading: CircleAvatar(
                                backgroundImage: data.profilePicture != null
                                    ? CachedNetworkImageProvider(
                                        data.profilePicture!)
                                    : null,
                                child: data.profilePicture == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white54)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
              },
              error: (_, __) => const SizedBox(),
              loading: () => const SizedBox()),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const ProfileCompletenessAndGetVerifiedWidget(),
                  SubscriptionBuilder(
                    builder: (context, isPremiumUser) {
                      if (isPremiumUser) {
                        return const SizedBox();
                      } else {
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.all(
                              AppConstants.defaultNumericValue / 2),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppConstants.defaultNumericValue,
                                vertical: AppConstants.defaultNumericValue / 2),
                            leading: const Icon(
                              CupertinoIcons.star_fill,
                              color: Colors.amber,
                            ),
                            minLeadingWidth: 0,
                            title: const Text('Upgrade to Premium'),
                            subtitle: const Text(
                                'Remove ads and get access to premium features'),
                            onTap: () {
                              SubscriptionBuilder.showSubscriptionBottomSheet(
                                  context: context);
                            },
                          ),
                        );
                      }
                    },
                  ),
                  DrawerItem(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AccountSettingsLandingWidget(),
                              fullscreenDialog: true));
                    },
                    title: 'Account Settings',
                    leadingIcon: CupertinoIcons.profile_circled,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue / 2),

                  DrawerItem(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const SecurityAndPrivacyLandingPage(),
                              fullscreenDialog: true));
                    },
                    title: 'Security and Privacy',
                    leadingIcon: CupertinoIcons.lock_circle,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue / 2),
                  // DrawerItem(
                  //   onPressed: () {},
                  //   title: 'Language',
                  //   leadingIcon: CupertinoIcons.globe,
                  //   trailing: const Icon(
                  //     Icons.chevron_right,
                  //     color: Colors.white70,
                  //   ),
                  // ),
                  // const SizedBox(height: AppConstants.defaultNumericValue / 2),
                  // DrawerItem(
                  //   onPressed: () {},
                  //   title: 'Linked Accounts',
                  //   leadingIcon: CupertinoIcons.person_solid,
                  //   trailing: const Icon(
                  //     Icons.chevron_right,
                  //     color: Colors.white70,
                  //   ),
                  // ),
                  // const SizedBox(height: AppConstants.defaultNumericValue / 2),
                  // DrawerItem(
                  //   onPressed: () {},
                  //   title: 'Help Center',
                  //   leadingIcon: CupertinoIcons.question_circle_fill,
                  //   trailing: const Icon(
                  //     Icons.chevron_right,
                  //     color: Colors.white70,
                  //   ),
                  // ),
                  DrawerItem(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const TermsAndConditions(),
                              fullscreenDialog: true));
                    },
                    title: 'Terms And Conditions',
                    leadingIcon: CupertinoIcons.doc_text,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: AppConstants.defaultNumericValue / 2),
                  DrawerItem(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PrivacyPolicy(),
                              fullscreenDialog: true));
                    },
                    title: 'Privacy Policy',
                    leadingIcon: CupertinoIcons.doc_text,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                  ),
                  if (isCompanyHasFAQ)
                    const SizedBox(
                        height: AppConstants.defaultNumericValue / 2),
                  if (isCompanyHasFAQ)
                    DrawerItem(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FaqPage(),
                                fullscreenDialog: true));
                      },
                      title: 'FAQ',
                      leadingIcon: CupertinoIcons.question_circle,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                      ),
                    ),
                  if (isCompanyHasContact)
                    const SizedBox(
                        height: AppConstants.defaultNumericValue / 2),
                  if (isCompanyHasContact)
                    DrawerItem(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ContactUs(),
                                fullscreenDialog: true));
                      },
                      title: 'Contact Us',
                      leadingIcon: CupertinoIcons.phone_circle,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                      ),
                    ),
                  if (isCompanyHasAbout)
                    const SizedBox(
                        height: AppConstants.defaultNumericValue / 2),
                  if (isCompanyHasAbout)
                    DrawerItem(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AboutUs(),
                                fullscreenDialog: true));
                      },
                      title: 'About Us',
                      leadingIcon: CupertinoIcons.info_circle,
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                      ),
                    ),
                  versionRef.when(
                    data: (data) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          data,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                    error: (error, stackTrace) => const SizedBox(),
                    loading: () => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
          DrawerItem(
            leadingIcon: CupertinoIcons.power,
            onPressed: () async {
              EasyLoading.show(status: 'Logging out...');
              final currentUserId = ref.read(currentUserStateProvider)?.uid;

              if (currentUserId != null) {
                await ref
                    .read(userProfileNotifier)
                    .updateOnlineStatus(isOnline: false, userId: currentUserId);
              }
              await ref.read(authProvider).signOut();
              EasyLoading.dismiss();
            },
            title: 'Log Out',
          ),
          // const SizedBox(height: AppConstants.defaultNumericValue / 2),

          const SizedBox(height: AppConstants.defaultNumericValue / 2),
        ],
      ),
    );
  }
}

class DrawerItem extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData leadingIcon;
  final Widget? trailing;
  final String title;
  const DrawerItem({
    super.key,
    required this.onPressed,
    required this.leadingIcon,
    this.trailing,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
      ),
      title: Text(
        title,
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      onTap: onPressed,
      leading: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
        ),
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue / 1.5),
        child: Icon(leadingIcon, color: Colors.white),
      ),
      trailing: trailing,
    );
  }
}
