import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class ImageHelper {
  /// Compresses a picked image to WebP format to save disk space.
  /// Standard clinical checkup photos are resized to 800x800 and compressed at 60% quality.
  static Future<XFile?> compressToWebP(XFile file, {int quality = 60, int maxWidth = 800, int maxHeight = 800}) async {
    if (kIsWeb) {
      return file;
    }
    try {
      final String originalPath = file.path;
      final Directory tempDir = Directory.systemTemp;
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String targetPath = p.join(tempDir.path, 'img_$timestamp.webp');

      debugPrint('[ImageHelper] Compressing: $originalPath');
      final originalSize = await File(originalPath).length();
      debugPrint('[ImageHelper] Original size: ${(originalSize / 1024).toStringAsFixed(1)} KB');

      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        format: CompressFormat.webp,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
      );

      if (compressedFile != null) {
        final compressedSize = await File(compressedFile.path).length();
        debugPrint('[ImageHelper] Compressed size: ${(compressedSize / 1024).toStringAsFixed(1)} KB');
        debugPrint('[ImageHelper] Space saved: ${((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1)}%');
        return compressedFile;
      }
      
      return file;
    } catch (e) {
      debugPrint('[ImageHelper] Compression failed: $e');
      return file; // Fallback to original if compression encounters an error
    }
  }

  static String? globalFileToken;

  /// Appends the PocketBase file token to a file URL to access protected files securely.
  /// PocketBase 0.20+ strictly requires a File Token in the `?token=` parameter.
  static String getSecureUrl(String url) {
    if (url.isEmpty) return url;
    // Only append to actual pocketbase file urls
    if (!url.contains('/api/files/')) return url;
    // Don't append if it already has a token
    if (url.contains('token=')) return url;
    if (globalFileToken == null || globalFileToken!.isEmpty) return url;
    
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}token=$globalFileToken';
  }
}
