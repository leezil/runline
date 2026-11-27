import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../shared/media/runline_api.dart';

class ClubAttachmentFile {
  const ClubAttachmentFile(this.name, this.contentType, this.bytes);
  final String name;
  final String contentType;
  final Uint8List bytes;
}

class ClubFiles {
  const ClubFiles();
  static const maxBytes = 5 * 1024 * 1024;
  static const types = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
  Future<ClubAttachmentFile?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: '공지 첨부파일 선택',
      type: FileType.custom,
      allowedExtensions: types.keys.toList(),
    );
    if (file == null) return null;
    final length = await file.length();
    if (length == null || length < 1 || length > maxBytes) {
      throw const RunlineApiException('첨부파일은 1바이트~5MB까지 올릴 수 있어요.');
    }
    final mime = types[file.extension?.toLowerCase()];
    if (mime == null || file.name.length > 200) {
      throw const RunlineApiException(
        'PDF·TXT·DOCX·XLSX 파일과 200자 이하의 파일명을 사용해주세요.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const RunlineApiException('5MB 이하의 파일을 선택해주세요.');
    }
    return ClubAttachmentFile(file.name, mime, bytes);
  }

  Future<Uri?> save(String name, String contentType, Uint8List bytes) =>
      FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: contentType,
        dialogTitle: '첨부파일 저장',
      );
}
