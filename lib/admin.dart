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
  GisilaStudio? studio;

  return (Request req) async {
    studio ??= await _buildStudio();
    return studio!.handler()(req);
  };
}

Future<GisilaStudio> _buildStudio() async {
  final db = await Database.connect(databaseConfig);

  final studio = GisilaStudio(
    db: db,
    title: 'My App Admin',
    username: env.getOrElse('STUDIO_USERNAME', () => 'admin'),
    password: env.getOrElse('STUDIO_PASSWORD', () => 'admin'),
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
