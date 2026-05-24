import 'package:gisila/gisila.dart' show FieldValidator, emailFieldValidator;

export 'package:gisila/gisila.dart'
    show
        Field,
        FieldValidationException,
        FieldValidator,
        emailFieldValidator,
        form,
        jsonResponse,
        nameFieldValidator;

export 'exceptions.dart';
export 'extensions.dart';
export 'jwt.dart';
export 'request_handler.dart';
// FormData, UploadedFile, readBody, readFormBody, readJsonBody
// are all re-exported here via package:gisila/gisila.dart already.

/// Validates that a password is at least 8 characters long.
final passwordValidator = FieldValidator<String>(
  name: 'password',
  isRequired: true,
  validator: (value) =>
      value.length >= 8 ? null : 'Password must be at least 8 characters.',
);

/// Convenience alias — same as [emailFieldValidator] but named to match
/// common usage patterns within this template.
final emailValidator = emailFieldValidator;
