import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/cloudinary_config.dart';

class ImageUploadException implements Exception {
  final String message;
  final int? statusCode;
  ImageUploadException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ImageUploadException: $message'
      '${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Wrapper around Cloudinary's unsigned upload endpoint. Uses plain
/// `http` rather than the Cloudinary SDK to keep the dependency
/// footprint small. Nothing is signed client-side — the preset
/// itself is configured as `unsigned` in the Cloudinary dashboard
/// with the format/size constraints that matter.
class ImageUploadService {
  final http.Client _client;

  ImageUploadService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> uploadProfilePhoto(File file, {required String uid}) {
    return _upload(file, folder: '${CloudinaryConfig.profilePhotoFolder}/$uid');
  }

  Future<String> uploadIdDocument(
    File file, {
    required String uid,
    required String slot, // 'front', 'back', 'selfie'
  }) {
    return _upload(
      file,
      folder: '${CloudinaryConfig.idVerificationFolder}/$uid',
      tags: ['id-verification', 'slot:$slot'],
    );
  }

  Future<String> _upload(
    File file, {
    required String folder,
    List<String> tags = const [],
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw ImageUploadException(
        'Cloudinary is not configured. Set cloudName in lib/core/cloudinary_config.dart.',
      );
    }

    final request =
        http.MultipartRequest('POST', CloudinaryConfig.uploadEndpoint)
          ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
          ..fields['folder'] = folder;

    if (tags.isNotEmpty) {
      request.fields['tags'] = tags.join(',');
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw ImageUploadException('No internet connection.');
    } catch (e) {
      throw ImageUploadException('Upload failed: $e');
    }

    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      String message = 'Upload failed';
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          message = err['message'] as String;
        }
      } catch (_) {}
      throw ImageUploadException(message, statusCode: streamed.statusCode);
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final secureUrl = decoded['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw ImageUploadException('Upload response missing secure_url.');
    }
    return secureUrl;
  }

  void dispose() {
    _client.close();
  }
}
