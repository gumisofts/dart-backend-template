import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

final _formUrlEncoded = ContentType('application', 'x-www-form-urlencoded');
final _multipartFormData = ContentType('multipart', 'form-data');

/// Parses a `multipart/form-data` or `application/x-www-form-urlencoded` body
/// into a [FormData] containing typed fields and uploaded files.
Future<FormData> parseFormData({
  required Map<String, String> headers,
  required Future<String> Function() body,
  required Stream<List<int>> Function() bytes,
}) async {
  final ct = _contentType(headers);

  if (_isUrlEncoded(ct)) {
    return FormData(fields: Uri.splitQueryString(await body()), files: {});
  }

  if (_isMultipart(ct)) {
    return _parseMultipart(headers: headers, bytes: bytes());
  }

  throw StateError(
    'Cannot parse body: expected '
    '"${_formUrlEncoded.mimeType}" or "${_multipartFormData.mimeType}", '
    'got "${ct?.mimeType ?? "(none)"}".',
  );
}

ContentType? _contentType(Map<String, String> headers) {
  final v = headers[HttpHeaders.contentTypeHeader];
  return v == null ? null : ContentType.parse(v);
}

bool _isUrlEncoded(ContentType? ct) => ct?.mimeType == _formUrlEncoded.mimeType;

bool _isMultipart(ContentType? ct) =>
    ct?.mimeType == _multipartFormData.mimeType;

final _kvRe = RegExp('(?:(?<key>[a-zA-Z0-9-_]+)="(?<value>.*?)";*)+');

Future<FormData> _parseMultipart({
  required Map<String, String> headers,
  required Stream<List<int>> bytes,
}) async {
  final mediaType = MediaType.parse(headers[HttpHeaders.contentTypeHeader]!);
  final boundary = mediaType.parameters['boundary']!;
  final transformer = MimeMultipartTransformer(boundary);

  final fields = <String, String>{};
  final files = <String, UploadedFile>{};

  await for (final part in transformer.bind(bytes)) {
    final cd = part.headers['content-disposition'];
    if (cd == null || !cd.startsWith('form-data;')) continue;

    final kv = _kvRe.allMatches(cd).fold(<String, String>{}, (m, match) {
      return m..[match.namedGroup('key')!] = match.namedGroup('value')!;
    });

    final name = kv['name']!;
    final fileName = kv['filename'];

    if (fileName != null) {
      files[name] = UploadedFile(
        fileName,
        ContentType.parse(
            part.headers['content-type'] ?? 'application/octet-stream'),
        part,
      );
    } else {
      final chunks = await part.toList();
      fields[name] = utf8.decode(chunks.fold(<int>[], (p, e) => p..addAll(e)));
    }
  }

  return FormData(fields: fields, files: files);
}

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// Holds parsed form fields (strings) and uploaded files.
class FormData with MapMixin<String, String> {
  const FormData({
    required Map<String, String> fields,
    required Map<String, UploadedFile> files,
  })  : _fields = fields,
        _files = files;

  final Map<String, String> _fields;
  final Map<String, UploadedFile> _files;

  Map<String, String> get fields => Map.unmodifiable(_fields);
  Map<String, UploadedFile> get files => Map.unmodifiable(_files);

  @override
  String? operator [](Object? key) => _fields[key];

  @override
  Iterable<String> get keys => _fields.keys;

  @override
  void operator []=(String key, String value) => _fields[key] = value;

  @override
  void clear() => _fields.clear();

  @override
  String? remove(Object? key) => _fields.remove(key);
}

/// A single file received as part of a multipart form upload.
class UploadedFile {
  const UploadedFile(this.name, this.contentType, this._stream);

  final String name;
  final ContentType contentType;
  final Stream<List<int>> _stream;

  Future<List<int>> readAsBytes() async {
    final List<List<int>> chunks = await _stream.toList();
    return chunks.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
  }

  Stream<List<int>> openRead() => _stream;

  @override
  String toString() => '{name: $name, contentType: $contentType}';
}
