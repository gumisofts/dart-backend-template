import 'package:gisila/gisila.dart' hide Query;
import 'package:gisila_orm/gisila.dart';
import 'package:my_app/models/models.dart';

/// User-management business logic. Pure persistence + invariants —
/// authorization belongs on the controllers via gisila guards.
class UsersService extends Service {
  Database get _database => db<Database>();

  Future<List<User>> listAll() =>
      Query<User>(UserTable.metadata).all(_database.context());

  Future<User> findById(String id) async {
    final parsedId = int.tryParse(id);
    if (parsedId == null) {
      throw BadRequest('Invalid user id.', code: 'invalid_user_id');
    }
    final user = await Query<User>(UserTable.metadata)
        .where(UserTable.id.eq(parsedId))
        .first(_database.context());
    if (user == null) {
      throw NotFound('User not found.');
    }
    return user;
  }

  Future<User> updateProfile(
    User current, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final payload = <String, Object?>{
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };

    if (payload.isEmpty) {
      throw BadRequest('No updatable fields provided.', code: 'empty_update');
    }

    payload['updatedAt'] = DateTime.now().toUtc().toIso8601String();

    final updated = await Query<User>(UserTable.metadata)
        .where(UserTable.id.eq(current.id!))
        .update(payload)
        .run(_database.context())
        .then((rows) => rows.first);

    return updated;
  }

  Future<void> deleteAccount(User current) async {
    await Query<User>(UserTable.metadata)
        .where(UserTable.id.eq(current.id!))
        .delete()
        .run(_database.context());
  }
}
