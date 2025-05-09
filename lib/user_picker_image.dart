import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class UserPickerImage extends StatefulWidget {
  const UserPickerImage(this.onPickImage, {super.key});
  final void Function(File pickedImage) onPickImage;

  @override
  State<UserPickerImage> createState() => _UserPickerImageState();
}

class _UserPickerImageState extends State<UserPickerImage> {
  File? _pickedImageFile;

  Future<void> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final cameraPermissionStatus = await Permission.camera.request();
        if (cameraPermissionStatus != PermissionStatus.granted) {
          print('Camera permission not granted');
          return;
        }
      } else if (source == ImageSource.gallery) {
        final storagePermissionStatus = await Permission.photos.request();
        if (storagePermissionStatus != PermissionStatus.granted) {
          print('Storage permission not granted');
          return;
        }
      }

      final pickedImage = await ImagePicker().pickImage(
        source: source,
        maxWidth: 50,
        imageQuality: 50,
      );

      if (pickedImage == null) {
        return;
      }

      setState(() {
        _pickedImageFile = File(pickedImage.path);
      });

      widget.onPickImage(_pickedImageFile!);
    } catch (error) {
      print('Error picking image: $error');
    }
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey,
          foregroundImage:
              _pickedImageFile != null ? FileImage(_pickedImageFile!) : null,
        ),
        TextButton.icon(
          onPressed: () {
            _showPicker(context);
          },
          icon: const Icon(Icons.image),
          label: const Text('Add image'),
        ),
      ],
    );
  }
}
