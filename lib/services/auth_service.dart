import 'package:gisila/gisila.dart' hide Query;
import 'package:gisila_orm/gisila.dart';
import 'package:my_app/models/models.dart';
import 'package:my_app/utils/jwt.dart';

/// Business logic for the `/auth` endpoints. Controllers stay thin and
/// forward to this service; persistence and JWT minting live here.
class AuthService extends Service {
  Database get _database => db<Database>();

  Future<({User user, String accessToken})> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final existing = await Query<User>(UserTable.metadata)
        .where(UserTable.email.eq(email))
        .first(_database.context());

    if (existing != null) {
      throw Conflict(
        'An account with this email already exists.',
        code: 'email_taken',
      );
    }

    final user = await Query<User>(UserTable.metadata).insert({
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'isActive': true,
      'isStaff': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    }).one(_database.context());

    return (user: user, accessToken: JWTAuth.sign(user));
  }

  Future<({User user, String accessToken})> login({
    required String email,
    required String password,
  }) async {
    final user = await Query<User>(UserTable.metadata)
        .where(UserTable.email.eq(email))
        .first(_database.context());

    if (user == null || user.password != password) {
      throw Unauthorized('Invalid email or password.');
    }
    if (user.isActive == false) {
      throw Forbidden('This account is inactive.');
    }

    return (user: user, accessToken: JWTAuth.sign(user));
  }

  Future<void> changePassword(
    User current, {
    required String oldPassword,
    required String newPassword,
  }) async {
    if (current.password != oldPassword) {
      throw BadRequest(
        'Old password is incorrect.',
        code: 'invalid_old_password',
      );
    }

    await Query<User>(UserTable.metadata)
        .where(UserTable.id.eq(current.id!))
        .update({'password': newPassword}).run(_database.context());
  }
}
