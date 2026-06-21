import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/providers/subscriptions/is_subscribed_provider.dart';
import 'package:mioamoreapp/providers/subscriptions/offerings_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionBuilder extends ConsumerWidget {
  final Widget Function(BuildContext context, bool isPremiumUser) builder;

  const SubscriptionBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremiumUserRef = ref.watch(isPremiumUserProvider);

    return isPremiumUserRef.when(
      data: (data) {
        return builder(context, data);
      },
      error: (error, stackTrace) {
        return builder(context, false);
      },
      loading: () {
        return const SizedBox();
      },
    );
  }

  static Future<void> showSubscriptionBottomSheet({
    required BuildContext context,
    String? message,
  }) async {
    await showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return SubscriptionBottomSheet(message: message);
      },
    );
  }
}

class SubscriptionBottomSheet extends ConsumerWidget {
  final String? message;
  const SubscriptionBottomSheet({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offeringsRef = ref.watch(subscriptionOfferingsProvider);

    return CupertinoActionSheet(
      title: const Text("Upgrade to Premium"),
      message: Text(
          message ?? "Subscribe to remove ads and unlock premium features!"),
      actions: offeringsRef.when(
        data: (data) {
          return data.map(
            (element) {
              return CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  EasyLoading.show(status: "Processing...");
                  await Purchases.purchasePackage(element).then((value) {
                    EasyLoading.dismiss();
                    ref.invalidate(isPremiumUserProvider);
                    ref.invalidate(premiumCustomerInfoProvider);
                  }).onError((error, stackTrace) {
                    debugPrint(error.toString());
                    debugPrint(stackTrace.toString());

                    EasyLoading.showInfo("Purchase Failed!");
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.defaultNumericValue),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              element.storeProduct.title,
                              textAlign: TextAlign.start,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              element.storeProduct.description,
                              textAlign: TextAlign.start,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.defaultNumericValue),
                      Text(
                        element.storeProduct.priceString,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ).toList();
        },
        error: (error, stackTrace) {
          print(error);
          return [
            CupertinoActionSheetAction(
              onPressed: () {},
              child: const Text("Error loading offers!"),
            ),
          ];
        },
        loading: () => [],
      ),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Text("Cancel"),
      ),
    );
  }
}
