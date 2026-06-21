// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/interaction_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';
import 'package:mioamoreapp/views/custom/custom_app_bar.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';
import 'package:mioamoreapp/views/custom/custom_icon_button.dart';
import 'package:mioamoreapp/views/custom/lottie/no_item_found_widget.dart';
import 'package:mioamoreapp/views/custom/subscription_builder.dart';
import 'package:mioamoreapp/views/others/user_image_card.dart';

class ExploreFilterModel {
  String? gender;
  String? location;
  int? minAge;
  int? maxAge;
  ExploreFilterModel({
    this.gender,
    this.location,
    this.minAge,
    this.maxAge,
  });

  ExploreFilterModel copyWith({
    String? gender,
    String? location,
    int? minAge,
    int? maxAge,
  }) {
    return ExploreFilterModel(
      gender: gender ?? this.gender,
      location: location ?? this.location,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
    );
  }

  void reset() {
    gender = null;
    location = null;
    minAge = null;
    maxAge = null;
  }
}

class ExplorePage extends ConsumerStatefulWidget {
  final int? index;
  const ExplorePage({
    super.key,
    this.index,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;
  ExploreFilterModel _filterModel = ExploreFilterModel();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
                    icon: CupertinoIcons.back,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    padding: const EdgeInsets.all(
                        AppConstants.defaultNumericValue / 1.5)),
                title: Center(
                  child: CustomHeadLine(
                    text: 'Explore Users',
                    secondPartColor: AppConstants.primaryColor,
                  ),
                ),
                trailing: CustomIconButton(
                  icon: CupertinoIcons.search,
                  onPressed: () {
                    setState(() {
                      _isSearchBarVisible = !_isSearchBarVisible;
                      _searchController.clear();
                      _filterModel.reset();
                    });
                  },
                  padding: const EdgeInsets.all(
                      AppConstants.defaultNumericValue / 1.5),
                ),
              ),
            ),
            _isSearchBarVisible
                ? const SizedBox(height: AppConstants.defaultNumericValue)
                : const SizedBox(height: 0),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.defaultNumericValue),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(sizeFactor: animation, child: child);
                },
                child: _isSearchBarVisible
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            key: const Key('searchBar'),
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryColor
                                        .withOpacity(0.2),
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
                                ),
                              ),
                              const SizedBox(
                                  width: AppConstants.defaultNumericValue),
                              CustomIconButton(
                                icon: Icons.filter_alt_outlined,
                                onPressed: () {
                                  // Open Bottom Sheet
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return ExploreFilterDialog(
                                        filterModel: _filterModel,
                                      );
                                    },
                                  ).then((value) {
                                    if (value == null) {
                                      setState(() {
                                        _filterModel.reset();
                                      });
                                    } else {
                                      if (value is ExploreFilterModel) {
                                        setState(() {
                                          _filterModel = value;
                                        });
                                      }
                                    }
                                  });
                                },
                                padding: const EdgeInsets.all(
                                    AppConstants.defaultNumericValue / 1.5),
                              ),
                            ],
                          ),
                          const SizedBox(
                              height: AppConstants.defaultNumericValue / 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              children: [
                                if (_filterModel.gender != null)
                                  Text(
                                    "Gender: ${_filterModel.gender!.toUpperCase()},",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                if (_filterModel.gender != null)
                                  const SizedBox(
                                      width:
                                          AppConstants.defaultNumericValue / 2),
                                if (_filterModel.location != null)
                                  Text(
                                    "Location: ${_filterModel.location!},",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                if (_filterModel.location != null)
                                  const SizedBox(
                                      width:
                                          AppConstants.defaultNumericValue / 2),
                                if (_filterModel.minAge != null)
                                  Text(
                                    "Min Age: ${_filterModel.minAge},",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                if (_filterModel.minAge != null)
                                  const SizedBox(
                                      width:
                                          AppConstants.defaultNumericValue / 2),
                                if (_filterModel.maxAge != null)
                                  Text(
                                    "Max Age: ${_filterModel.maxAge},",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(fontWeight: FontWeight.bold),
                                  ),
                                if (_filterModel.maxAge != null)
                                  const SizedBox(
                                      width:
                                          AppConstants.defaultNumericValue / 2),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(key: Key('noSearchBar')),
              ),
            ),
            _isSearchBarVisible
                ? const SizedBox(height: AppConstants.defaultNumericValue)
                : const SizedBox(height: 0),
            Expanded(
              child: SubscriptionBuilder(
                builder: (context, isPremiumUser) {
                  return ExploreUsersBody(
                    index: widget.index,
                    query: _searchController.text,
                    isPremiumUser: isPremiumUser,
                    filterModel: _filterModel,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExploreFilterDialog extends StatefulWidget {
  final ExploreFilterModel filterModel;
  const ExploreFilterDialog({super.key, required this.filterModel});

  @override
  State<ExploreFilterDialog> createState() => _ExploreFilterDialogState();
}

class _ExploreFilterDialogState extends State<ExploreFilterDialog> {
  final TextEditingController _minAgeController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String? _selectedGender;

  @override
  void initState() {
    _minAgeController.text = widget.filterModel.minAge?.toString() ?? '';
    _maxAgeController.text = widget.filterModel.maxAge?.toString() ?? '';
    _locationController.text = widget.filterModel.location ?? '';
    _selectedGender = widget.filterModel.gender;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomHeadLine(
            text: 'Filter',
            secondPartColor: AppConstants.primaryColor,
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAgeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: 'Min Age',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.defaultNumericValue),
              Expanded(
                child: TextField(
                  controller: _maxAgeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: 'Max Age',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.defaultNumericValue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'Location',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppConstants.defaultNumericValue,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.defaultNumericValue),
          // Gender
          Wrap(
            runSpacing: AppConstants.defaultNumericValue / 2,
            spacing: AppConstants.defaultNumericValue / 2,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGender = _selectedGender == AppConfig.maleText
                        ? null
                        : AppConfig.maleText;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.defaultNumericValue / 2,
                    horizontal: AppConstants.defaultNumericValue,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedGender == AppConfig.maleText
                        ? AppConstants.primaryColor.withOpacity(0.4)
                        : null,
                    border:
                        Border.all(color: AppConstants.primaryColor, width: 2),
                    borderRadius:
                        BorderRadius.circular(AppConstants.defaultNumericValue),
                  ),
                  child: Text(
                    AppConfig.maleText.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedGender = _selectedGender == AppConfig.femaleText
                        ? null
                        : AppConfig.femaleText;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppConstants.defaultNumericValue / 2,
                    horizontal: AppConstants.defaultNumericValue,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedGender == AppConfig.femaleText
                        ? AppConstants.primaryColor.withOpacity(0.4)
                        : null,
                    border:
                        Border.all(color: AppConstants.primaryColor, width: 2),
                    borderRadius:
                        BorderRadius.circular(AppConstants.defaultNumericValue),
                  ),
                  child: Text(
                    AppConfig.femaleText.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (AppConfig.allowTransGender)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedGender = _selectedGender == AppConfig.transText
                          ? null
                          : AppConfig.transText;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.defaultNumericValue / 2,
                      horizontal: AppConstants.defaultNumericValue,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedGender == AppConfig.transText
                          ? AppConstants.primaryColor.withOpacity(0.4)
                          : null,
                      border: Border.all(
                          color: AppConstants.primaryColor, width: 2),
                      borderRadius: BorderRadius.circular(
                          AppConstants.defaultNumericValue),
                    ),
                    child: Text(
                      AppConfig.transText.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _locationController.clear();
              _minAgeController.clear();
              _maxAgeController.clear();
              _selectedGender = null;
            });
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () {
            final ExploreFilterModel filter = ExploreFilterModel(
              gender: _selectedGender,
              location: _locationController.text.trim() == ''
                  ? null
                  : _locationController.text.trim(),
              maxAge: _maxAgeController.text.trim().isEmpty
                  ? null
                  : int.parse(_maxAgeController.text.trim()),
              minAge: _minAgeController.text.trim().isEmpty
                  ? null
                  : int.parse(_minAgeController.text.trim()),
            );

            Navigator.of(context).pop(filter);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class ExploreUsersBody extends ConsumerStatefulWidget {
  final String? query;
  final bool isPremiumUser;
  final ExploreFilterModel filterModel;
  final int? index;
  const ExploreUsersBody({
    super.key,
    this.query,
    required this.isPremiumUser,
    required this.filterModel,
    this.index,
  });

  @override
  ConsumerState<ExploreUsersBody> createState() => _ExploreUsersBodyState();
}

class _ExploreUsersBodyState extends ConsumerState<ExploreUsersBody> {
  int? _index;
  @override
  void initState() {
    _index = widget.index;
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
    final filteredUsers = ref.watch(filteredOtherUsersProvider);

    return filteredUsers.when(
      data: (users) {
        final interactionProvider = ref.watch(interactionFutureProvider);

        return interactionProvider.when(
          data: (data) {
            final List<UserProfileModel> filteredUsers = [];

            for (final user in users) {
              if (!data.any(
                  (element) => element.intractToUserId.contains(user.userId))) {
                filteredUsers.add(user);
              }
            }

            return DefaultTabController(
              initialIndex: _index ?? 0,
              length: AppConfig.interests.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    labelColor: AppConstants.primaryColor,
                    tabs: AppConfig.interests
                        .map((e) => Tab(text: e.toUpperCase()))
                        .toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: AppConfig.interests.map((e) {
                        final filteredUsers = users
                            .where((element) => element.interests.contains(e))
                            .toList();

                        if (widget.query != null && widget.query!.isNotEmpty) {
                          filteredUsers.retainWhere((element) => element
                              .fullName
                              .toLowerCase()
                              .contains(widget.query!.toLowerCase()));
                        }

                        if (widget.filterModel.gender != null) {
                          filteredUsers.retainWhere((element) => element.gender
                              .toLowerCase()
                              .contains(
                                  widget.filterModel.gender!.toLowerCase()));
                        }

                        if (widget.filterModel.location != null) {
                          filteredUsers.retainWhere((element) => element
                              .userAccountSettingsModel.location.addressText
                              .toLowerCase()
                              .contains(
                                  widget.filterModel.location!.toLowerCase()));
                        }

                        if (widget.filterModel.minAge != null) {
                          filteredUsers.retainWhere((element) {
                            final age =
                                DateTime.now().year - element.birthDay.year;
                            return age >= widget.filterModel.minAge!;
                          });
                        }

                        if (widget.filterModel.maxAge != null) {
                          filteredUsers.retainWhere((element) {
                            final age =
                                DateTime.now().year - element.birthDay.year;
                            return age <= widget.filterModel.maxAge!;
                          });
                        }

                        return filteredUsers.isEmpty
                            ? const NoItemFoundWidget()
                            : GridView(
                                padding: const EdgeInsets.all(
                                    AppConstants.defaultNumericValue),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing:
                                      AppConstants.defaultNumericValue,
                                  mainAxisSpacing:
                                      AppConstants.defaultNumericValue,
                                ),
                                children: filteredUsers.map((user) {
                                  return UserImageCard(user: user);
                                }).toList(),
                              );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
          error: (_, __) => const Center(
            child: Text("Something Went Wrong!"),
          ),
          loading: () => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
        );
      },
      error: (_, __) => const Center(
        child: Text("Something Went Wrong!"),
      ),
      loading: () => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}
