import 'package:gisila/gisila.dart';
import 'package:gisila_orm/gisila.dart';

/// A [DatabaseProvider] that hands out a process-wide [Database] for
/// every request.
///
/// The underlying [Database] manages a connection pool internally, so
/// nothing needs to be opened/closed per request — each query borrows
/// a connection from the pool through [Database.context] and releases
/// it on completion.
class GisilaOrmDatabaseProvider extends DatabaseProvider<Database> {
  GisilaOrmDatabaseProvider(this._database);

  final Database _database;

  @override
  Future<Database> open(Request request) async => _database;

  @override
  Future<void> close(Database session, {required bool ok}) async {}
}
