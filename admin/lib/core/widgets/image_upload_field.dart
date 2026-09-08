import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import '../network/media_upload_service.dart';
import '../theme/admin_colors.dart';

/// A URL text field plus a "Browse" button that uploads an image via
/// [MediaUploadService] and fills the URL in automatically. The URL stays
/// editable directly too, for pasting an already-hosted image.
class ImageUploadField extends StatefulWidget {
  const ImageUploadField({
    super.key,
    required this.controller,
    required this.label,
    required this.folder,
  });

  final TextEditingController controller;
  final String label;

  /// "stores", "offers", or "categories" — matches the backend's accepted
  /// folder hints.
  final String folder;

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final _uploadService = MediaUploadService();
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _uploadService.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null || file.bytes == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final url = await _uploadService.upload(
        bytes: file.bytes!,
        fileName: file.name,
        contentType: _contentTypeFor(file.extension),
        folder: widget.folder,
      );
      widget.controller.text = url;
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _contentTypeFor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                decoration: InputDecoration(labelText: widget.label),
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _pickAndUpload,
                    child: const Text('Browse'),
                  ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: const TextStyle(color: AdminColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
