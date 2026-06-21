import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/date_formater.dart';
import 'package:mioamoreapp/models/verification_form_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/verification_provider.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/settings/verification/photo_id_page.dart';
import 'package:mioamoreapp/views/settings/verification/selfie_page.dart';

class GetVerifiedPage extends ConsumerStatefulWidget {
  final UserProfileModel user;

  const GetVerifiedPage({super.key, required this.user});

  @override
  ConsumerState<GetVerifiedPage> createState() => _GetVerifiedPageState();
}

class _GetVerifiedPageState extends ConsumerState<GetVerifiedPage> {
  bool _submitAgain = false;
  @override
  Widget build(BuildContext context) {
    final verificationData = ref.watch(verificationProvider);
    final currentUserRef = ref.watch(currentUserStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
      ),
      body: _submitAgain
          ? const _NotVerifiedPart(submitAgain: true)
          : widget.user.isVerified
              ? const Center(
                  child: Text('You are verified'),
                )
              : FutureBuilder<VerificationFormModel?>(
                  future:
                      verificationData.getVerifiedStatus(currentUserRef!.uid),
                  builder: (BuildContext context,
                      AsyncSnapshot<VerificationFormModel?> snapshot) {
                    return snapshot.hasError
                        ? const Center(
                            child: Text('Error'),
                          )
                        : snapshot.data == null
                            ? const _NotVerifiedPart(submitAgain: false)
                            : _VerifiedPart(
                                data: snapshot.data!,
                                onPressedSubmitAgain: () {
                                  setState(() {
                                    _submitAgain = true;
                                  });
                                },
                              );
                  },
                ),
    );
  }
}

class _VerifiedPart extends StatelessWidget {
  final VerificationFormModel data;
  final VoidCallback onPressedSubmitAgain;
  const _VerifiedPart({
    required this.data,
    required this.onPressedSubmitAgain,
  });

  @override
  Widget build(BuildContext context) {
    bool isNotApproved = data.isPending == false && data.isApproved == false;

    bool isVerified = data.isPending == false && data.isApproved == true;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
      child: Center(
        child: isVerified
            ? const Text(
                "Your account is verified\nRestart the app to see the changes!",
                textAlign: TextAlign.center,
              )
            : Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        isNotApproved
                            ? Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: MediaQuery.of(context).size.width * 0.15,
                              )
                            : Icon(
                                Icons.hourglass_bottom,
                                color: Colors.blue,
                                size: MediaQuery.of(context).size.width * 0.15,
                              ),
                        const SizedBox(
                            height: AppConstants.defaultNumericValue),
                        Text(
                          isNotApproved
                              ? 'Not Approved'
                              : 'Your account is pending verification',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                            height: AppConstants.defaultNumericValue),
                        Text(
                          isNotApproved
                              ? data.statusMessage ??
                                  "Your account is not approved. Please submit your documents again to verify your account."
                              : "You have submitted your documents.\nWe will verify your documents and update the status of your account.",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(
                            height: AppConstants.defaultNumericValue),
                        isNotApproved
                            ? CustomButton(
                                text: "Submit again",
                                onPressed: onPressedSubmitAgain,
                              )
                            : const SizedBox(),
                        const Divider(height: AppConstants.defaultNumericValue),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          "Submitted at: ${DateFormatter.toWholeDate(data.createdAt)}",
                          style:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  )),
                      const SizedBox(
                          height: AppConstants.defaultNumericValue / 4),
                      Text(
                          "Last Updated at: ${DateFormatter.toWholeDate(data.updatedAt)}",
                          style:
                              Theme.of(context).textTheme.bodySmall!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  )),
                    ],
                  )
                ],
              ),
      ),
    );
  }
}

class _NotVerifiedPart extends ConsumerStatefulWidget {
  final bool submitAgain;
  const _NotVerifiedPart({
    required this.submitAgain,
  });

  @override
  ConsumerState<_NotVerifiedPart> createState() => _NotVerifiedPartState();
}

class _NotVerifiedPartState extends ConsumerState<_NotVerifiedPart> {
  File? _photoIdFrontView;
  File? _photoIdBackView;
  File? _selfie;

  void _onSubmit() async {
    final verificationData = ref.read(verificationProvider);

    EasyLoading.show(status: 'Uploading...');
    String? photoIdFrontPath =
        await _savePictures(_photoIdFrontView!, "photoIdFront");
    String? photoIdBackPath =
        await _savePictures(_photoIdBackView!, "photoIdBack");
    String? selfiePath = await _savePictures(_selfie!, "selfie");

    if (photoIdFrontPath == null ||
        photoIdBackPath == null ||
        selfiePath == null) {
      EasyLoading.showInfo("Something went wrong. Please try again later.");
      return;
    } else {
      VerificationFormModel form = VerificationFormModel(
        id: ref.watch(currentUserStateProvider)!.uid,
        userId: ref.watch(currentUserStateProvider)!.uid,
        photoIdFrontViewUrl: photoIdFrontPath,
        photoIdBackViewUrl: photoIdBackPath,
        selfieUrl: selfiePath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPending: true,
        isApproved: false,
      );
      if (widget.submitAgain) {
        await verificationData.updateVerificationForm(form);
      } else {
        await verificationData.submitVerificationForm(form);
      }
    }
  }

  Future<String?> _savePictures(File file, String title) async {
    Reference storageReference = FirebaseStorage.instance
        .ref()
        .child(ref.watch(currentUserStateProvider)!.uid)
        .child("Verification Pictures")
        .child(title);

    String? url;

    UploadTask uploadTask = storageReference.putFile(file);
    await uploadTask.whenComplete(() async =>
        await storageReference.getDownloadURL().then((value) => url = value));
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Are you sure to discard verification?'),
              actions: [
                TextButton(
                  child: const Text('Yes'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                TextButton(
                  child: const Text('No'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            );
          },
        );
      },
      child: Scaffold(
        body: Container(
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Submit documents",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppConstants.defaultNumericValue / 2),
              Text(
                "We need to verify your information.\n Please submit the documents below.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 4),
              VerificationSingleStep(
                leadingIcon: Icons.credit_card,
                onTap: () async {
                  final List<File>? results = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoIdPage(
                        frontView: _photoIdFrontView,
                        backView: _photoIdBackView,
                      ),
                    ),
                  );
                  setState(() {
                    _photoIdFrontView = results?.first;
                    _photoIdBackView = results?.last;
                  });
                },
                title: "Photo ID",
                trailingIcon:
                    _photoIdFrontView != null && _photoIdBackView != null
                        ? Icons.check
                        : Icons.arrow_forward,
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              VerificationSingleStep(
                leadingIcon: Icons.camera_alt,
                onTap: () async {
                  final File? result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelfiePage(selfie: _selfie),
                    ),
                  );
                  setState(() {
                    _selfie = result;
                  });
                },
                title: "Take a selfie",
                trailingIcon:
                    _selfie != null ? Icons.check : Icons.arrow_forward,
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
              _photoIdBackView != null &&
                      _photoIdFrontView != null &&
                      _selfie != null
                  ? CustomButton(text: "Submit", onPressed: _onSubmit)
                  : const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}

class VerificationSingleStep extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final IconData trailingIcon;
  final VoidCallback onTap;
  const VerificationSingleStep({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      contentPadding: const EdgeInsets.all(16),
      title: Text(title),
      leading: Icon(leadingIcon),
      trailing: CircleAvatar(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          child: Icon(trailingIcon)),
      onTap: onTap,
    );
  }
}
