import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_account_settings_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/app_settings_provider.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/others/set_user_location_page.dart';

class AccountSettingsLandingWidget extends ConsumerWidget {
  final Widget Function(UserProfileModel data)? builder;
  const AccountSettingsLandingWidget({
    super.key,
    this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileFutureProvider);

    return user.when(
      data: (data) {
        return data == null
            ? const ErrorPage()
            : builder == null
                ? AccountSettingsPage(user: data)
                : builder!(data);
      },
      error: (_, __) => const ErrorPage(),
      loading: () => const LoadingPage(),
    );
  }
}

class AccountSettingsPage extends ConsumerStatefulWidget {
  final UserProfileModel user;
  const AccountSettingsPage({super.key, required this.user});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  late UserLocation _userLocation;
  late double _distanceInKm;
  late bool _isWorldWide;
  late double _maxDistanceInKm;
  late double _minimumAge;
  late double _maximumAge;
  String? _interestedIn;
  bool? _showAge;
  bool? _showLocation;
  bool? _showOnlineStatus;
  bool? _showOnlyToPremiumUsers;
  bool? _allowAnonymousMessages;

  @override
  void initState() {
    _distanceInKm = widget.user.userAccountSettingsModel.distanceInKm ??
        AppConfig.initialMaximumDistanceInKM;
    _isWorldWide = widget.user.userAccountSettingsModel.distanceInKm == null;
    _interestedIn = widget.user.userAccountSettingsModel.interestedIn;

    _userLocation = widget.user.userAccountSettingsModel.location;
    _minimumAge = widget.user.userAccountSettingsModel.minimumAge.toDouble();
    _maximumAge = widget.user.userAccountSettingsModel.maximumAge.toDouble();

    _maxDistanceInKm = AppConfig.initialMaximumDistanceInKM;

    _showAge = widget.user.userAccountSettingsModel.showAge;
    _showLocation = widget.user.userAccountSettingsModel.showLocation;
    _showOnlineStatus = widget.user.userAccountSettingsModel.showOnlineStatus;

    _showOnlyToPremiumUsers =
        widget.user.userAccountSettingsModel.showOnlyToPremiumUsers;

    _allowAnonymousMessages =
        widget.user.userAccountSettingsModel.allowAnonymousMessages;

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final appSettingsRef = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // const SizedBox(height: AppConstants.defaultNumericValue),
            Text(
              'Location',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: AppConstants.defaultNumericValue / 2),
            Text(
                'This is your location. Other users will be able to see you if they are within this range.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppConstants.defaultNumericValue),
            GestureDetector(
              onTap: () async {
                final newLocation = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SetUserLocation()));

                if (newLocation != null) {
                  setState(() {
                    _userLocation = newLocation;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppConstants.defaultNumericValue,
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppConstants.primaryColor,
                      ),
                      const SizedBox(
                          width: AppConstants.defaultNumericValue / 2),
                      Text(
                        _userLocation.addressText,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue * 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Radius',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: AppConstants.defaultNumericValue),
                if (!_isWorldWide)
                  Text(
                    '${_distanceInKm.toInt()} km',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultNumericValue / 2),
            Text('This radius is used to find other users within this range.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppConstants.defaultNumericValue),
            if (!_isWorldWide)
              Slider(
                value: _distanceInKm,
                min: 1,
                max: _maxDistanceInKm,
                onChanged: (value) {
                  setState(() {
                    _distanceInKm = value;
                  });
                },
              ),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.defaultNumericValue),
              ),
              borderOnForeground: true,
              child: CheckboxListTile(
                value: _isWorldWide,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    _isWorldWide = value!;
                    _distanceInKm = value
                        ? AppConfig.initialMaximumDistanceInKM
                        : widget.user.userAccountSettingsModel.distanceInKm ??
                            AppConfig.initialMaximumDistanceInKM;
                  });
                },
                title: Text(
                  "Anywhere",
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue * 2),
            Text("Interested In",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppConstants.defaultNumericValue / 2),
            Text('This is the type of people you are interested in.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppConstants.defaultNumericValue),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppConstants.defaultNumericValue / 2,
              runSpacing: AppConstants.defaultNumericValue / 2,
              children: [
                _GenderButton(
                  text: AppConfig.maleText.toUpperCase(),
                  isSelected: _interestedIn == AppConfig.maleText,
                  onPressed: () {
                    setState(() {
                      _interestedIn = AppConfig.maleText;
                    });
                  },
                ),
                _GenderButton(
                  text: AppConfig.femaleText.toUpperCase(),
                  isSelected: _interestedIn == AppConfig.femaleText,
                  onPressed: () {
                    setState(() {
                      _interestedIn = AppConfig.femaleText;
                    });
                  },
                ),
                if (AppConfig.allowTransGender)
                  _GenderButton(
                    text: AppConfig.transText.toUpperCase(),
                    isSelected: _interestedIn == AppConfig.transText,
                    onPressed: () {
                      setState(() {
                        _interestedIn = AppConfig.transText;
                      });
                    },
                  ),
                _GenderButton(
                  text: AppConfig.allowTransGender
                      ? "all".toUpperCase()
                      : "both".toUpperCase(),
                  isSelected: _interestedIn == null,
                  onPressed: () {
                    setState(() {
                      _interestedIn = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultNumericValue * 2),
            Row(
              children: [
                Expanded(
                  child: Text("Age Range",
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge!
                          .copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: AppConstants.defaultNumericValue),
                Text(
                  '${_minimumAge.toInt()} - ${_maximumAge.toInt()}',
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.defaultNumericValue / 2),
            Text('This is the age range you are interested in.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppConstants.defaultNumericValue),
            RangeSlider(
              values:
                  RangeValues(_minimumAge.toDouble(), _maximumAge.toDouble()),
              min: AppConfig.minimumAgeRequired.toDouble(),
              max: AppConfig.maximumUserAge.toDouble(),
              onChanged: (RangeValues values) {
                setState(() {
                  _minimumAge = values.start;
                  _maximumAge = values.end;
                });
              },
            ),
            const SizedBox(height: AppConstants.defaultNumericValue),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Show Age",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.bold)),
                Switch.adaptive(
                  value: _showAge ?? true,
                  onChanged: (value) {
                    setState(() {
                      _showAge = value;
                    });
                  },
                ),
              ],
            ),
            Text('If not enabled, your age will be hidden from others.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppConstants.defaultNumericValue * 2),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Show Location",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.bold)),
                Switch.adaptive(
                  value: _showLocation ?? true,
                  onChanged: (value) {
                    setState(() {
                      _showLocation = value;
                    });
                  },
                ),
              ],
            ),
            Text('If not enabled, your location will be hidden from others.',
                style: Theme.of(context).textTheme.bodySmall),

            const SizedBox(height: AppConstants.defaultNumericValue * 2),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Show Online Status",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.bold)),
                Switch.adaptive(
                  value: _showOnlineStatus ?? true,
                  onChanged: (value) {
                    setState(() {
                      _showOnlineStatus = value;
                    });
                  },
                ),
              ],
            ),
            Text(
                'If not enabled, your online status will be hidden from others.',
                style: Theme.of(context).textTheme.bodySmall),

            const SizedBox(height: AppConstants.defaultNumericValue * 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Show only to Premium Users",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(fontWeight: FontWeight.bold)),
                Switch.adaptive(
                  value: _showOnlyToPremiumUsers ?? false,
                  onChanged: (value) {
                    setState(() {
                      _showOnlyToPremiumUsers = value;
                    });
                  },
                ),
              ],
            ),
            Text(
                'If enabled, your profile will be visible only to premium users.',
                style: Theme.of(context).textTheme.bodySmall),

            appSettingsRef.when(
              data: (data) {
                bool isAnonymousMessagesEnabled =
                    data?.isChattingEnabledBeforeMatch ?? false;
                if (isAnonymousMessagesEnabled) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                          height: AppConstants.defaultNumericValue * 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Allow anonymous messages",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge!
                                  .copyWith(fontWeight: FontWeight.bold)),
                          Switch.adaptive(
                            value: _allowAnonymousMessages ?? false,
                            onChanged: (value) {
                              setState(() {
                                _allowAnonymousMessages = value;
                              });
                            },
                          ),
                        ],
                      ),
                      Text(
                          'If enabled, any user can send you messages without revealing their identity.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
              error: (error, stackTrace) => const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppConstants.defaultNumericValue * 2),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
          child: CustomButton(
            onPressed: () async {
              final UserAccountSettingsModel userAccountSettingsModel =
                  UserAccountSettingsModel(
                distanceInKm:
                    _isWorldWide ? null : _distanceInKm.toInt().toDouble(),
                interestedIn: _interestedIn,
                minimumAge: _minimumAge.toInt(),
                maximumAge: _maximumAge.toInt(),
                location: _userLocation,
                showAge: _showAge,
                showLocation: _showLocation,
                showOnlineStatus: _showOnlineStatus,
                showOnlyToPremiumUsers: _showOnlyToPremiumUsers,
                allowAnonymousMessages: _allowAnonymousMessages,
              );

              final userProfileModel = widget.user.copyWith(
                userAccountSettingsModel: userAccountSettingsModel,
                isOnline: _showOnlineStatus == false ? false : true,
              );
              EasyLoading.show(status: 'Updating...');

              await ref
                  .read(userProfileNotifier)
                  .updateUserProfile(userProfileModel)
                  .then((value) {
                ref.invalidate(userProfileFutureProvider);
                EasyLoading.dismiss();
                Navigator.pop(context);
              });
            },
            text: 'Apply',
          ),
        ),
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final bool isSelected;
  const _GenderButton({
    required this.onPressed,
    required this.text,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.defaultNumericValue * 1.5,
          vertical: AppConstants.defaultNumericValue,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppConstants.primaryColor
              : AppConstants.primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(
            AppConstants.defaultNumericValue,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppConstants.primaryColor.withOpacity(0.2),
                    blurRadius: AppConstants.defaultNumericValue,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: isSelected ? Colors.white : Colors.black,
              ),
        ),
      ),
    );
  }
}
