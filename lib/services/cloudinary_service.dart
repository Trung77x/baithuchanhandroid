import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // Cloudinary config
  static const String _cloudName = 'dnisefe4z';
  static const String _uploadPreset = 'trung123';
  static const String _folder = 'trung123';

  /// Upload image bytes to Cloudinary, returns the secure URL
  Future<String?> uploadImage(Uint8List imageBytes, {String? fileName}) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = _folder
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename:
                fileName ??
                'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );

      debugPrint('Uploading image to Cloudinary folder: $_folder ...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = jsonData['secure_url'] as String?;
        debugPrint('Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
          'Cloudinary upload failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  /// Upload base64 string to Cloudinary, returns the secure URL
  Future<String?> uploadBase64(String base64Image, {String? fileName}) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final response = await http.post(
        uri,
        body: {
          'file': 'data:image/jpeg;base64,$base64Image',
          'upload_preset': _uploadPreset,
          'folder': _folder,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = jsonData['secure_url'] as String?;
        debugPrint('Cloudinary base64 upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
          'Cloudinary base64 upload failed: ${response.statusCode} ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary base64 upload error: $e');
      return null;
    }
  }
}
