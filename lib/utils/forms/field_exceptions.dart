/// Thrown when one or more form/JSON fields fail validation.
///
/// The [error] map has field names as keys and error messages as values.
class FieldValidationException implements Exception {
  FieldValidationException(
      {required this.error, this.message = 'Validation failed.'});

  final String message;
  final Map<String, dynamic> error;

  @override
  String toString() => '$message $error';
}
