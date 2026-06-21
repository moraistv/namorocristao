import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final isPremiumUserProvider = FutureProvider<bool>((ref) async {
  if (AppConstants.isTestMode) {
    return true;
  } else {
    final CustomerInfo customerInfo = await Purchases.getCustomerInfo();

    debugPrint("Customer Info: $customerInfo");

    if (customerInfo.entitlements.all[SubscriptionConstants.entitlementId] !=
            null &&
        customerInfo.entitlements.all[SubscriptionConstants.entitlementId]!
                .isActive ==
            true) {
      return true;
    } else {
      return false;
    }
  }
});

final premiumCustomerInfoProvider = FutureProvider<CustomerInfo>((ref) async {
  final CustomerInfo customerInfo = await Purchases.getCustomerInfo();

  debugPrint("Customer Info: $customerInfo");

  return customerInfo;
});
