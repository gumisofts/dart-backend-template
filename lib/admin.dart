import 'package:gisila_orm/gisila.dart';
import 'package:gisila_studio/gisila_studio.dart';
import 'package:my_app/config.dart';
import 'package:my_app/models/models.dart';
import 'package:shelf/shelf.dart';

/// Returns a lazy Shelf [Handler] that mounts GisilaStudio at `/studio`.
///
/// The [Database] connection is created on the first request so the studio
/// shares the same lifecycle as the rest of the application.
Handler adminHandler() {
  Handler? handler;

  return (Request req) async {
    // Must match the mount path in my_app.dart, or links, redirects and the
    // login cookie point at the wrong place.
    handler ??= (await _buildStudio()).handler(prefix: '/studio');
    return handler!(req);
  };
}

Future<GisilaStudio> _buildStudio() async {
  final db = await Database.connect(databaseConfig);

  // No defaults: without STUDIO_USERNAME / STUDIO_PASSWORD (or with a weak
  // password) the studio serves a "disabled" page and the API keeps running.
  final studio = GisilaStudio(
    db: db,
    title: 'My App Admin',
    username: env['STUDIO_USERNAME'],
    password: env['STUDIO_PASSWORD'],
    // Stateless JWTs, so logins work across the server's isolates. The key
    // differs from JWT_SECRET, so a studio token is never a valid API token
    // or the other way round.
    secret: '$jwtSecret:gisila-studio',
  );

  studio.register<User>(
    UserTable.metadata,
    displayName: 'User',
    listDisplay: [
      'id',
      'firstName',
      'lastName',
      'email',
      'isActive',
      'isStaff',
      'createdAt'
    ],
    searchFields: ['firstName', 'lastName', 'email'],
    readonlyFields: ['id', 'createdAt'],
    excludeFields: ['password'],
    ordering: ['-createdAt'],
  );

  return studio;
}
