// import 'package:flutter/material.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:mioamoreapp/config/config.dart';
// import 'package:mioamoreapp/helpers/constants.dart';
// import 'package:mioamoreapp/models/user_account_settings_model.dart';
// import 'package:mioamoreapp/models/user_profile_model.dart';
// import 'package:mioamoreapp/providers/user_profile_provider.dart';
// import 'package:mioamoreapp/views/custom/custom_button.dart';
// import 'package:mioamoreapp/views/others/set_user_location_page.dart';

// class LanguageSelection extends ConsumerStatefulWidget {
//   final UserProfileModel user;
//   const LanguageSelection({Key? key, required this.user}) : super(key: key);

//   @override
//   ConsumerState<ConsumerStatefulWidget> createState() =>
//       _LanguageSelectionState();
// }

// class _LanguageSelectionState extends ConsumerState<LanguageSelection> {
//   late UserLocation _userLocation;
//   late double _distanceInKm;
//   late double _maxDistanceInKm;
//   late double _minimumAge;
//   late double _maximumAge;
//   String? _interestedIn;

//   @override
//   void initState() {
//     _distanceInKm = widget.user.userAccountSettingsModel.distanceInKm;
//     _interestedIn = widget.user.userAccountSettingsModel.interestedIn;

//     _userLocation = widget.user.userAccountSettingsModel.location;
//     _minimumAge = widget.user.userAccountSettingsModel.minimumAge.toDouble();
//     _maximumAge = widget.user.userAccountSettingsModel.maximumAge.toDouble();

//     _maxDistanceInKm = AppConfig.initialMaximumDistanceInKM;

//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Language Selection'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const SizedBox(height: AppConstants.defaultNumericValue),
//             GestureDetector(
//               onTap: () async {
//                 final newLocation = await Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) => const SetUserLocation()));

//                 if (newLocation != null) {
//                   setState(() {
//                     _userLocation = newLocation;
//                   });
//                 }
//               },
//               child: Container(
//                 padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
//                 decoration: BoxDecoration(
//                   border: Border.all(
//                     color: Theme.of(context).primaryColor,
//                   ),
//                   borderRadius: BorderRadius.circular(
//                     AppConstants.defaultNumericValue,
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.location_on,
//                       color: AppConstants.primaryColor,
//                     ),
//                     const SizedBox(width: AppConstants.defaultNumericValue / 2),
//                     Text(
//                       _userLocation.addressText,
//                       style: Theme.of(context)
//                           .textTheme
//                           .bodyLarge!
//                           .copyWith(fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: AppConstants.defaultNumericValue),
//             Slider(
//               value: _distanceInKm,
//               min: 1,
//               max: _maxDistanceInKm,
//               onChanged: (value) {
//                 setState(() {
//                   _distanceInKm = value;
//                 });
//               },
//             ),
//             const SizedBox(height: AppConstants.defaultNumericValue * 2),
//             Text("Interested In",
//                 style: Theme.of(context)
//                     .textTheme
//                     .headline6!
//                     .copyWith(fontWeight: FontWeight.bold)),
//             const SizedBox(height: AppConstants.defaultNumericValue),
//             const SizedBox(height: AppConstants.defaultNumericValue * 2),
//             Row(
//               children: [
//                 Expanded(
//                   child: Text("Age Range",
//                       style: Theme.of(context)
//                           .textTheme
//                           .headline6!
//                           .copyWith(fontWeight: FontWeight.bold)),
//                 ),
//                 const SizedBox(width: AppConstants.defaultNumericValue),
//                 Text(
//                   '${_minimumAge.toInt()} - ${_maximumAge.toInt()}',
//                   style: Theme.of(context).textTheme.headline6!.copyWith(
//                       fontWeight: FontWeight.bold,
//                       color: AppConstants.primaryColor),
//                 ),
//               ],
//             ),
//             const SizedBox(height: AppConstants.defaultNumericValue),
//             RangeSlider(
//               values:
//                   RangeValues(_minimumAge.toDouble(), _maximumAge.toDouble()),
//               min: AppConfig.minimumAgeRequired.toDouble(),
//               max: 70.0,
//               onChanged: (RangeValues values) {
//                 setState(() {
//                   _minimumAge = values.start;
//                   _maximumAge = values.end;
//                 });
//               },
//             ),
//             const SizedBox(height: AppConstants.defaultNumericValue * 2),
//             CustomButton(
//               onPressed: () async {
//                 final UserAccountSettingsModel userAccountSettingsModel =
//                     UserAccountSettingsModel(
//                   distanceInKm: _distanceInKm.toInt().toDouble(),
//                   interestedIn: _interestedIn,
//                   minimumAge: _minimumAge.toInt(),
//                   maximumAge: _maximumAge.toInt(),
//                   location: _userLocation,
//                 );

//                 final userProfileModel = widget.user.copyWith(
//                   userAccountSettingsModel: userAccountSettingsModel,
//                 );
//                 EasyLoading.show(status: 'Updating...');

//                 await ref
//                     .read(userProfileProvider)
//                     .updateUserProfile(userProfileModel)
//                     .then((value) {
//                   ref.invalidate(userProfileFutureProvider);
//                   EasyLoading.dismiss();
//                   Navigator.pop(context);
//                 });
//               },
//               text: 'Apply',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
