import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/main.dart';
import 'package:mioamoreapp/models/country_code.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/custom/custom_headline.dart';

class OtpPage extends ConsumerStatefulWidget {
  final String phoneNumber;
  const OtpPage({
    super.key,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _verificationId = "";

  Future<void> _phoneSignIn() async {
    await _auth.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onCodeTimeout);
  }

  _onVerificationCompleted(PhoneAuthCredential authCredential) async {}

  _onVerificationFailed(FirebaseAuthException exception) {
    if (exception.code == 'invalid-phone-number') {
      EasyLoading.showError('Invalid phone number.');
    }
  }

  _onCodeSent(String verificationId, int? forceResendingToken) {
    setState(() {
      _verificationId = verificationId;
    });
    EasyLoading.showSuccess('Code is Sent');
  }

  _onCodeTimeout(String timeout) {
    return null;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    _phoneSignIn();
    super.initState();
  }

  // void _onSubmitOtp(value) async {
  //   // if (value.length == 6) {
  //   //   try {
  //   //     PhoneAuthCredential credential = PhoneAuthProvider.credential(
  //   //       verificationId: _verificationId,
  //   //       smsCode: value,
  //   //     );
  //   //     await _auth
  //   //         .signInWithCredential(credential)
  //   //         .then((userCredential) async {
  //   //       await FirebaseConstants.userCollection.get().then(
  //   //         (querySnapshot) async {
  //   //           final List<QueryDocumentSnapshot<Map<String, dynamic>>>
  //   //               _userList = querySnapshot.docs;
  //   //           final List<String> _userUidList = [];
  //   //           for (var element in _userList) {
  //   //             _userUidList.add(element.id);
  //   //           }

  //   //           if (!_userUidList.contains(userCredential.user!.uid)) {
  //   //             await FirebaseConstants.userCollection
  //   //                 .doc(userCredential.user!.uid)
  //   //                 .set(
  //   //                   UserModel(
  //   //                           firstName: userCredential.user!.displayName,
  //   //                           phone: userCredential.user!.phoneNumber,
  //   //                           email: userCredential.user!.email,
  //   //                           firstTimeLogin: true,
  //   //                           id: userCredential.user!.uid,
  //   //                           userType: userTypes[0])
  //   //                       .toMap(),
  //   //                 )
  //   //                 .then((value) {});
  //   //           }
  //   //         },
  //   //       );

  //   //       Navigator.pop(context);
  //   //     });
  //   //   } on FirebaseAuthException {
  //   //     EasyLoading.showError("Something went wrong!");
  //   //   }
  //   // }
  // }

  void _onOtpVerification() async {
    if (_formKey.currentState!.validate()) {
      EasyLoading.show(status: "Verifying OTP");
      await ref
          .read(authProvider)
          .signInWithPhoneNumber(_otpController.text.trim(), _verificationId)
          .then((value) {
        if (value != null) {
          EasyLoading.showSuccess("Login Successful");
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LandingWidget()),
              (route) => false);
        } else {
          EasyLoading.showError("Something went wrong!");
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Login With Phone".toUpperCase()),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppConstants.defaultNumericValue),
                CustomHeadLine(
                    text: "Enter The Code",
                    secondPartColor: AppConstants.primaryColor),
                const SizedBox(height: AppConstants.defaultNumericValue),
                const SizedBox(height: 140),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: "******"),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return "Please enter the code";
                    } else if (value.length != 6) {
                      return "Please enter the correct code";
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.length == 6) {
                      _onOtpVerification();
                    }
                  },
                ),
                const SizedBox(height: AppConstants.defaultNumericValue),
                const Text(
                    "We have sent you an OTP code on your phone number. Please enter it below. If you did not receive an OTP, please resend it."),
                const SizedBox(height: AppConstants.defaultNumericValue * 2),
                CustomButton(
                  onPressed: _onOtpVerification,
                  text: "Verify",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String getFormattedCountryCode(CountryCode country) {
  return "${country.code} ${country.dialCode} ";
}
