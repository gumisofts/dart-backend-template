import 'dart:io';

/// Thrown from endpoint handlers to short-circuit with an HTTP error response.
class EndpointException implements Exception {
  EndpointException({required this.error, required this.statusCode});

  final Map<String, dynamic> error;
  final int statusCode;

  @override
  String toString() => '$statusCode: $error';
}

/// 401 Unauthorized — user is not logged in.
final unauthorizedException = EndpointException(
  error: {'detail': 'Authentication required.'},
  statusCode: HttpStatus.unauthorized,
);

/// 403 Forbidden — user is logged in but lacks the required permission.
final forbiddenException = EndpointException(
  error: {'detail': "You don't have permission to perform this action."},
  statusCode: HttpStatus.forbidden,
);
