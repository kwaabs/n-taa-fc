import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Decode a reference-pack ZIP off the UI isolate (used via [compute]).
Map<String, Uint8List> decodeZipEntries(Uint8List zipBytes) {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final files = <String, Uint8List>{};
  for (final file in archive.files) {
    if (file.isFile) {
      files[file.name] = file.content as Uint8List;
    }
  }
  return files;
}
