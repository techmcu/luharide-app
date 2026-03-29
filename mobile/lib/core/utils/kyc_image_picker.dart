import 'package:image_picker/image_picker.dart';

/// Picks a gallery photo sized for KYC uploads (avoids multi‑MB camera originals → HTTP 413).
Future<XFile?> pickKycGalleryPhoto() async {
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 72,
  );
}
