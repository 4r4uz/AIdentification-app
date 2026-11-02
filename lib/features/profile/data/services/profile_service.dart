import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import '/core/network/supabase_service.dart';

class ProfileService {
  final SupabaseService _supabaseService = SupabaseService();

  /// Comprime una imagen y retorna los bytes comprimidos
  Future<Uint8List> compressImage(File imageFile, {int quality = 70}) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('No se pudo leer la imagen seleccionada');
    }

    // Redimensionar si es muy grande (máximo 512x512)
    int width = image.width;
    int height = image.height;
    const maxSize = 512;

    if (width > height && width > maxSize) {
      height = (height * maxSize / width).round();
      width = maxSize;
    } else if (height > maxSize) {
      width = (width * maxSize / height).round();
      height = maxSize;
    }

    final resized = img.copyResize(image, width: width, height: height);

    // Comprimir a JPEG
    final compressedBytes = Uint8List.fromList(
      img.encodeJpg(resized, quality: quality),
    );

    return compressedBytes;
  }

  /// Sube una nueva foto de perfil, eliminando la anterior si existe
  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    String? uploadedPath;
    try {
      final compressedBytes = await compressImage(imageFile, quality: 70);
      final fileName = 'profile_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final filePath = '$userId/$fileName';

      await _supabaseService.client.storage
          .from('profile-picture')
          .uploadBinary(
            filePath,
            compressedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      uploadedPath = filePath;

      final publicUrl = _supabaseService.client.storage
          .from('profile-picture')
          .getPublicUrl(filePath);

      await _supabaseService.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      await _deleteOldProfilePictures(userId, exceptPath: filePath);
      return _addCacheBuster(publicUrl);
    } catch (e) {
      if (uploadedPath != null) {
        try {
          await _supabaseService.client.storage.from('profile-picture').remove([
            uploadedPath,
          ]);
        } catch (cleanupError) {
          debugPrint(
            'Error limpiando la foto de perfil temporal: $cleanupError',
          );
        }
      }
      throw Exception('Error al subir la foto de perfil: $e');
    }
  }

  Future<void> _deleteOldProfilePictures(
    String userId, {
    String? exceptPath,
  }) async {
    try {
      final files = await _supabaseService.client.storage
          .from('profile-picture')
          .list(path: userId);

      final paths = files
          .map((file) => '$userId/${file.name}')
          .where((path) => path != exceptPath)
          .toList();
      if (paths.isNotEmpty) {
        await _supabaseService.client.storage
            .from('profile-picture')
            .remove(paths);
      }
    } catch (e) {
      debugPrint('Error eliminando fotos de perfil anteriores: $e');
    }
  }

  Future<void> deleteProfilePicture(String userId) async {
    try {
      await _deleteOldProfilePictures(userId);

      await _supabaseService.client
          .from('profiles')
          .update({'avatar_url': null})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Error al eliminar la foto de perfil: $e');
    }
  }

  Future<String?> getProfilePictureUrl(String userId) async {
    final response = await _supabaseService.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();
    final url = response?['avatar_url'] as String?;
    return url == null || url.isEmpty ? null : _addCacheBuster(url);
  }

  String _addCacheBuster(String url) {
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'v': DateTime.now().microsecondsSinceEpoch.toString(),
          },
        )
        .toString();
  }
}
