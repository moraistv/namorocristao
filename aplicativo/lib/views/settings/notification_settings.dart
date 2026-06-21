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

// class NotificationSettings extends ConsumerStatefulWidget {
//   final UserProfileModel user;
//   const NotificationSettings({Key? key, required this.user}) : super(key: key);

//   @override
//   ConsumerState<ConsumerStatefulWidget> createState() =>
//       _NotificationSettingsState();
// }

// class _NotificationSettingsState extends ConsumerState<NotificationSettings> {
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
//         title: const Text('Notification Settings'),
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
//             const SizedBox(height: AppConstants.defaultNumericValue),
//             Wrap(
//               alignment: WrapAlignment.center,
//               spacing: AppConstants.defaultNumericValue / 2,
//               runSpacing: AppConstants.defaultNumericValue / 2,
//               children: [
//                 _GenderButton(
//                   text: AppConfig.maleText.toUpperCase(),
//                   isSelected: _interestedIn == AppConfig.maleText,
//                   onPressed: () {
//                     setState(() {
//                       _interestedIn = AppConfig.maleText;
//                     });
//                   },
//                 ),
//                 _GenderButton(
//                   text: AppConfig.femaleText.toUpperCase(),
//                   isSelected: _interestedIn == AppConfig.femaleText,
//                   onPressed: () {
//                     setState(() {
//                       _interestedIn = AppConfig.femaleText;
//                     });
//                   },
//                 ),
//                 if (AppConfig.allowTransGender)
//                   _GenderButton(
//                     text: AppConfig.transText.toUpperCase(),
//                     isSelected: _interestedIn == AppConfig.transText,
//                     onPressed: () {
//                       setState(() {
//                         _interestedIn = AppConfig.transText;
//                       });
//                     },
//                   ),
//                 _GenderButton(
//                   text: AppConfig.allowTransGender
//                       ? "all".toUpperCase()
//                       : "both".toUpperCase(),
//                   isSelected: _interestedIn == null,
//                   onPressed: () {
//                     setState(() {
//                       _interestedIn = null;
//                     });
//                   },
//                 ),
//               ],
//             ),
//             const SizedBox(height: AppConstants.defaultNumericValue * 2),
//             Row(
//               children: [
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
//                   EasyLoading.dismiss();
//                   ref.invalidate(userProfileFutureProvider);
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

// class _GenderButton extends StatelessWidget {
//   final VoidCallback onPressed;
//   final String text;
//   final bool isSelected;
//   const _GenderButton({
//     Key? key,
//     required this.onPressed,
//     required this.text,
//     required this.isSelected,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onPressed,
//       child: Container(
//         padding: const EdgeInsets.symmetric(
//           horizontal: AppConstants.defaultNumericValue * 1.5,
//           vertical: AppConstants.defaultNumericValue,
//         ),
//         decoration: BoxDecoration(
//           color: isSelected
//               ? AppConstants.primaryColor
//               : AppConstants.primaryColor.withOpacity(0.2),
//           borderRadius: BorderRadius.circular(
//             AppConstants.defaultNumericValue,
//           ),
//           boxShadow: isSelected
//               ? [
//                   BoxShadow(
//                     color: AppConstants.primaryColor.withOpacity(0.2),
//                     blurRadius: AppConstants.defaultNumericValue,
//                     offset: const Offset(0, 8),
//                   ),
//                 ]
//               : null,
//         ),
//         child: Text(
//           text,
//           style: Theme.of(context).textTheme.bodyText1!.copyWith(
//                 color: isSelected ? Colors.white : Colors.black,
//               ),
//         ),
//       ),
//     );
//   }
// }
