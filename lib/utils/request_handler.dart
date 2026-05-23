import 'dart:async';
import 'dart:io';

import 'package:gisila/gisila.dart' show jsonResponse;
import 'package:my_app/config.dart';
import 'package:my_app/utils/exceptions.dart';
import 'package:my_app/utils/forms/field_exceptions.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

/// Wraps an endpoint handler with consistent error handling.
///
/// Usage:
/// ```dart
/// Future<Response> myEndpoint(Request request) => handleRequest(
///   request,
///   permission: () {
///     if (!request.isAuthenticated) throw unauthorizedException;
///   },
///   endpoint: () async {
///     return jsonResponse(body: {'hello': 'world'});
///   },
/// );
/// ```
Future<Response> handleRequest(
  Request request, {
  required void Function() permission,
  required Future<Response> Function() endpoint,
}) async {
  try {
    permission();
    return await endpoint();
  } on EndpointException catch (e) {
    logger.w(e.error);
    return jsonResponse(statusCode: e.statusCode, body: e.error);
  } on FieldValidationException catch (e) {
    logger.w(e.error);
    return jsonResponse(statusCode: HttpStatus.badRequest, body: e.error);
  } on ServerException catch (e) {
    logger.e(e);
    // PostgreSQL constraint violations
    final constraintErrors = {
      '23503': e.detail ?? 'Foreign key violation.',
      '23505': e.detail ?? 'A record with this value already exists.',
      '23502': e.detail ?? 'A required field was null.',
      '23514': e.detail ?? 'Check constraint violation.',
    };
    if (constraintErrors.containsKey(e.code)) {
      return jsonResponse(
        statusCode: HttpStatus.badRequest,
        body: {'detail': constraintErrors[e.code]},
      );
    }
    return jsonResponse(
      statusCode: HttpStatus.badRequest,
      body: {'detail': e.toString()},
    );
  } catch (e, st) {
    logger.e(e, stackTrace: st);
    return jsonResponse(
      statusCode: HttpStatus.internalServerError,
      body: {'detail': 'An unexpected error occurred.'},
    );
  }
}
