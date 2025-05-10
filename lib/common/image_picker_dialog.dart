import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:retroshare/common/button.dart';

Future<void> imagePickerDialog(
  BuildContext context,
  void Function(File?) callback, {
  double maxWidth = 1200.0,
  double maxHeight = 1200.0,
  int imageQuality = 50,
}) async {
  final picker = ImagePicker();

  Future<void> pickAndCallback(ImageSource source) async {
    File? resultFile;
    try {
      final imageXFile = await picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      resultFile = imageXFile == null ? null : File(imageXFile.path);
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      callback(resultFile);
    }
  }

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('From where do you want to take the photo?'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Button(
                name: 'Gallery',
                buttonIcon: Icons.photo_library,
                labelLargeIcon: Icons.photo_library,
                onPressed: () async {
                  await pickAndCallback(ImageSource.gallery);
                },
              ),
              const Padding(padding: EdgeInsets.all(8)),
              Button(
                name: 'Camera',
                buttonIcon: Icons.camera_alt,
                labelLargeIcon: Icons.camera_alt,
                onPressed: () async {
                  await pickAndCallback(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
