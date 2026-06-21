// import 'dart:async';
// import 'package:awesome_notifications/awesome_notifications.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:mioamoreapp/config/config.dart';

// Future<void> checkNotificationPermission(BuildContext context) async {
//   await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
//     if (!isAllowed) {
//       await showCupertinoDialog(
//         context: context,
//         builder: (context) {
//           return CupertinoAlertDialog(
//             title: const Text("Notifications"),
//             content: const Text(
//                 "${AppConfig.appName} needs to access your notifications to show you reminders for your routines and events."),
//             actions: <Widget>[
//               CupertinoDialogAction(
//                 child: const Text("Cancel"),
//                 onPressed: () {
//                   Navigator.of(context).pop();
//                 },
//               ),
//               CupertinoDialogAction(
//                 child: const Text("Allow"),
//                 onPressed: () {
//                   AwesomeNotifications().requestPermissionToSendNotifications();
//                   Navigator.of(context).pop();
//                 },
//               ),
//             ],
//           );
//         },
//       );
//     }
//   });
// }

// StreamSubscription<ReceivedAction> listenToNotification({
//   required void Function(ReceivedAction)? onData,
//   required void Function()? onDone,
// }) {
//   return AwesomeNotifications().actionStream.listen(
//         onData,
//         onDone: onDone,
//       );
// }

// // void createQuoteNotification() async {
// //   debugPrint("Creating notification for quote");
// //   await AwesomeNotifications().createNotification(
// //     content: NotificationContent(
// //       id: DateTime.now().millisecondsSinceEpoch ~/ 100000,
// //       channelKey: 'quotes_channel',
// //       title: 'Notification ${Random().nextInt(100)}',
// //       body:
// //           'This notification was schedule to repeat at every single minute at clock.',
// //       category: NotificationCategory.Reminder,
// //       wakeUpScreen: true,
// //     ),
// //     schedule: NotificationCalendar(
// //       second: 0,
// //       timeZone: await AwesomeNotifications().getLocalTimeZoneIdentifier(),
// //       repeats: true,
// //     ),
// //   );
// // }

// // void cancelQuoteNotifications() async {
// //   debugPrint("Cancelling quote notifications");
// //   await AwesomeNotifications()
// //       .cancelNotificationsByChannelKey("quotes_channel");
// // }
