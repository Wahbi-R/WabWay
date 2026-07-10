import '../../data/share_data.dart';

/// Single source of truth for every file extension WabWay accepts.
///
/// Add a new type here and it propagates automatically to:
///   - FilePicker allowed-extension lists
///   - ShareContentType detection (share intents + in-app picker)
///
/// The AndroidManifest intent-filter MIME types must still be updated
/// manually — see android/app/src/main/AndroidManifest.xml and keep
/// the MIME list in sync with [shareExtensions].
abstract final class FileTypeRegistry {
  /// Accepted by the share / import file picker (IncomingShareScreen).
  static const shareExtensions = [
    'pdf',
    'jpg', 'jpeg', 'png', 'webp', 'heic',
    'csv',
    'docx', 'xlsx',
  ];

  /// Accepted by the add-document file picker (AddDocSheet).
  static const docExtensions = [
    'pdf',
    'jpg', 'jpeg', 'png', 'webp', 'heic',
    'docx', 'xlsx',
  ];

  /// Map a file extension → [ShareContentType].
  static ShareContentType contentTypeFromExt(String? ext) =>
      switch (ext?.toLowerCase()) {
        'pdf'                                => ShareContentType.pdfFile,
        'jpg' || 'jpeg' || 'png' ||
        'webp' || 'heic' || 'bmp'           => ShareContentType.screenshot,
        'csv'                               => ShareContentType.csvFile,
        _                                   => ShareContentType.blogArticle,
      };

  /// True when [ext] represents an image the app can display or thumbnail.
  static bool isImage(String ext) => const {
    'jpg', 'jpeg', 'png', 'webp', 'heic', 'bmp',
  }.contains(ext.toLowerCase());
}
