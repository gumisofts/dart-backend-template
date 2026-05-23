import 'package:gisila_orm/gisila.dart';
import 'package:my_app/models/models.dart';
import 'package:shelf/shelf.dart';

extension RequestExtensions on Request {
  /// The authenticated [User], or `null` when the request is anonymous.
  User? get contextUser =>
      context['user'] is bool ? null : context['user'] as User?;

  /// Whether the current request carries a valid JWT for an active user.
  bool get isAuthenticated => context['user'] is User;

  /// A pre-connected [Database] injected by middleware, if any.
  Database? get contextDb => context['db'] as Database?;
}
