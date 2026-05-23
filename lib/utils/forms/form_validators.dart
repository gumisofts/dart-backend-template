import 'package:gisila/gisila.dart';
import 'package:my_app/utils/forms/field_exceptions.dart';

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

/// Parses and validates a JSON, `application/x-www-form-urlencoded`, or
/// `multipart/form-data` request body using gisila's [readBody].
///
/// Returns a [Map] of validated values keyed by field name.
/// Throws [FieldValidationException] if any required field is missing or any
/// validator returns a non-null error string.
Future<Map<String, dynamic>> form(
  Request request, {
  required List<FieldValidator<dynamic>> fields,
}) async {
  final hasRequired = fields.any((f) => f.isRequired);
  final body = await readBody(request, required: hasRequired);

  final Map<String, dynamic> raw;
  if (body is FormData) {
    raw = {...body.fields, ...body.files};
  } else if (body is Map<String, dynamic>) {
    raw = body;
  } else {
    return {};
  }

  return _validate(raw, fields);
}

Map<String, dynamic> _validate(
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
