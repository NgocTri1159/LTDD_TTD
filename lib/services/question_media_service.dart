import 'package:file_picker/file_picker.dart';

import 'backend_service.dart';

class QuestionMediaService {
  static const int maxFileSize = 20 * 1024 * 1024;

  static const Map<String, String> _imageMimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };

  static const Map<String, String> _audioMimeTypes = {
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'webm': 'audio/webm',
  };

  static Future<Map<String, dynamic>?> pickAndUploadImage() async {
    return _pickAndUpload(
      allowedExtensions: _imageMimeTypes.keys.toList(),
      mimeTypes: _imageMimeTypes,
      fileDescription: 'ảnh',
    );
  }

  static Future<Map<String, dynamic>?> pickAndUploadAudio() async {
    return _pickAndUpload(
      allowedExtensions: _audioMimeTypes.keys.toList(),
      mimeTypes: _audioMimeTypes,
      fileDescription: 'âm thanh',
    );
  }

  static Future<Map<String, dynamic>?> _pickAndUpload({
    required List<String> allowedExtensions,
    required Map<String, String> mimeTypes,
    required String fileDescription,
  }) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (files.isEmpty) {
      return null;
    }

    final file = files.first;
    final extension = file.extension?.toLowerCase();

    if (extension == null || !mimeTypes.containsKey(extension)) {
      throw Exception('Định dạng $fileDescription không được hỗ trợ');
    }

    final fileSize = await file.length();

    if (fileSize == null) {
      throw Exception('Không thể xác định dung lượng file');
    }

    if (fileSize == 0) {
      throw Exception('File $fileDescription đang trống');
    }

    if (fileSize > maxFileSize) {
      throw Exception(
        'File $fileDescription vượt quá dung lượng tối đa 20 MB',
      );
    }

    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('Không thể đọc dữ liệu file đã chọn');
    }

    return BackendService.uploadFile(
      bytes: bytes,
      filename: file.name,
      mimeType: mimeTypes[extension]!,
    );
  }
}
