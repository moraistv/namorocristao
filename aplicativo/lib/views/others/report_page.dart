import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/media_picker_helper.dart';
import 'package:mioamoreapp/models/report_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/report_provider.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';
import 'package:mioamoreapp/views/others/user_details_page.dart';
import 'package:mioamoreapp/views/tabs/home/home_page.dart';

class ReportPage extends ConsumerStatefulWidget {
  final UserProfileModel userProfileModel;
  const ReportPage({
    super.key,
    required this.userProfileModel,
  });

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _imagesScrollcontroller = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final List<String> _imagePaths = [];

  void onTapAddImage() async {
    final image = await pickMedia();
    if (image == null) {
      return;
    } else {
      setState(() {
        _imagePaths.add(image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                  "You can report this user if you find him/her offensive or if you think he/she is a bot. We will review your report and if we find it to be true, we will block the user from using the app. Thank you for your cooperation."),
              const SizedBox(height: AppConstants.defaultNumericValue),
              Card(
                child: ListTile(
                  leading: UserCirlePicture(
                      imageUrl: widget.userProfileModel.profilePicture,
                      size: 35),
                  title: Text(widget.userProfileModel.fullName),
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              TextFormField(
                controller: _reasonController,
                maxLines: 9,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Please enter your reason for reporting this user',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.defaultNumericValue),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              const Text(
                'Add some images to support your report',
                style: TextStyle(fontSize: AppConstants.defaultNumericValue),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              _imagePaths.isEmpty
                  ? AddNewImageWidget(
                      onPressed: onTapAddImage,
                    )
                  : SingleChildScrollView(
                      controller: _imagesScrollcontroller,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: _imagePaths.map((imagePath) {
                          return Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    height:
                                        MediaQuery.of(context).size.width * 0.5,
                                    margin: const EdgeInsets.only(
                                        right:
                                            AppConstants.defaultNumericValue),
                                    child: Image.file(
                                      File(imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: CupertinoButton(
                                      padding: const EdgeInsets.all(0),
                                      color: Colors.red,
                                      child: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          _imagePaths.remove(imagePath);
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_imagePaths.indexOf(imagePath) ==
                                  _imagePaths.length - 1)
                                const SizedBox(
                                    width: AppConstants.defaultNumericValue),
                              if (_imagePaths.indexOf(imagePath) ==
                                  _imagePaths.length - 1)
                                AddNewImageWidget(
                                  onPressed: onTapAddImage,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              CustomButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final ReportModel reportModel = ReportModel(
                      id: "${widget.userProfileModel.id}report${DateTime.now().millisecondsSinceEpoch}",
                      createdAt: DateTime.now(),
                      images: _imagePaths,
                      reason: _reasonController.text,
                      reportedByUserId:
                          ref.watch(currentUserStateProvider)!.uid,
                      reportingUserId: widget.userProfileModel.id,
                    );

                    EasyLoading.show(status: 'Sending report...');
                    await reportUser(reportModel).then((value) {
                      EasyLoading.dismiss();
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Report sent!'),
                              content: const Text(
                                  'Do you want to block this user as well?'),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('No')),
                                TextButton(
                                    onPressed: () async {
                                      await showBlockDialog(
                                              context,
                                              widget.userProfileModel.userId,
                                              ref
                                                  .watch(
                                                      currentUserStateProvider)!
                                                  .uid)
                                          .then((value) {
                                        Navigator.pop(context);
                                        Navigator.of(context).pop();
                                      });
                                    },
                                    child: const Text('Yes')),
                              ],
                            );
                          });
                    });
                  }
                },
                text: 'Submit',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddNewImageWidget extends StatelessWidget {
  final VoidCallback onPressed;
  const AddNewImageWidget({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.3,
        height: MediaQuery.of(context).size.width * 0.5,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(AppConstants.defaultNumericValue),
        ),
        child: const Center(child: Icon(Icons.add)),
      ),
    );
  }
}
