import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:my_app/utils/forms/field_exceptions.dart';
import 'package:my_app/utils/forms/parsers/form_data.dart';
import 'package:shelf/shelf.dart';

/// Describes a single expected field in a form or JSON body.
class FieldValidator<T> {
  FieldValidator({
    required this.name,
    this.isRequired = false,
    this.validator,
    this.parse,
  });

  /// The field name as it appears in the request body.
  final String name;

  /// When `true` a missing or null value is treated as an error.
  final bool isRequired;

  /// Optional custom validation; returns an error string or `null`.
  final String? Function(T value)? validator;

  /// Optional custom parser applied before validation (e.g. string → int).
  final T Function(String value)? parse;

  String? validate(T value) => validator?.call(value);
}

// ---------------------------------------------------------------------------
// Pre-built common validators
// ---------------------------------------------------------------------------

final emailValidator = FieldValidator<String>(
  name: 'email',
  isRequired: true,
  validator: (v) =>
      RegExp(r'.+@.+\..+').hasMatch(v) ? null : 'Enter a valid email address.',
);

final passwordValidator = FieldValidator<String>(
  name: 'password',
  isRequired: true,
  validator: (v) =>
      v.length >= 8 ? null : 'Password must be at least 8 characters.',
);

// ---------------------------------------------------------------------------
// Main form() helper
// ---------------------------------------------------------------------------

/// Parses and validates a JSON or form-data request body.
///
/// Returns a [Map] of validated values keyed by field name.
/// Throws [FieldValidationException] if any required field is missing or any
/// validator returns a non-null error string.
Future<Map<String, dynamic>> form(
  Request request, {
  required List<FieldValidator<dynamic>> fields,
}) async {
  final contentType =
      request.headers[HttpHeaders.contentTypeHeader]?.split(';').first.trim();

  if (contentType == ContentType.json.value) {
    return _parseAndValidate(
      jsonDecode(await request.readAsString()) as Map<String, dynamic>,
      fields,
    );
  }

  if (contentType == 'multipart/form-data' ||
      contentType == 'application/x-www-form-urlencoded') {
    final fd = await parseFormData(
      headers: request.headers,
      body: request.readAsString,
      bytes: request.read,
    );
    return _parseAndValidate({...fd.fields, ...fd.files}, fields);
  }

  return {};
}

Map<String, dynamic> _parseAndValidate(
  Map<String, dynamic> raw,
  List<FieldValidator<dynamic>> fields,
) {
  final errors = <String, dynamic>{};
  final validated = <String, dynamic>{};

  for (final field in fields) {
    final value = raw[field.name];

    if (field.isRequired && value == null) {
      errors[field.name] = 'This field is required.';
      continue;
    }
    if (value == null) continue;

    try {
      final parsed =
          field.parse != null ? field.parse!(value as String) : value;
      final error = field.validate(parsed);
      if (error != null) {
        errors[field.name] = error;
      } else {
        validated[field.name] = parsed;
      }
    } catch (e) {
      errors[field.name] = e.toString();
    }
  }

  if (errors.isNotEmpty) throw FieldValidationException(error: errors);
  return validated;
}
