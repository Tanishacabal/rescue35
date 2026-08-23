import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer = TextRecognizer();

  static const _cloudName = 'eaxfy6jh';
  static const _uploadPreset = 'citizen_proofs';

  // ── Pick image from camera ─────────────────────────────
  Future<File?> pickImageFromCamera() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,   // 90% quality — balance ng size at clarity
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  // ── Pick image from gallery (for testing) ──────────────
  Future<File?> pickImageFromGallery() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return File(photo.path);
  }

  // ── Extract text from image using ML Kit ───────────────
  Future<String> extractText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText result =
        await _recognizer.processImage(inputImage);

      // result.text contains all extracted text
      return result.text;
    } catch (e) {
      return 'Error extracting text: $e';
    }
  }

  // ── Upload scanned image to Cloudinary ─────────────────
  Future<String> uploadImage(File imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'pcr_scans/${uid}_$timestamp';

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['public_id'] = publicId
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        return ''; // Return empty if upload fails
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    } catch (e) {
      return ''; // Return empty if upload fails
    }
  }

  // ── Dispose recognizer when done ───────────────────────
  void dispose() {
    _recognizer.close();
  }
}