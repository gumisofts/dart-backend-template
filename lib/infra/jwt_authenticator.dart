import 'package:gisila/gisila.dart' hide Query;
import 'package:gisila_orm/gisila.dart';
import 'package:my_app/models/models.dart';
import 'package:my_app/utils/jwt.dart';

/// JWT-backed [Authenticator] for the my_app template.
///
/// Parses a `Bearer …` token from the `Authorization` header, verifies
/// the signature, hydrates the matching [User] from the database, and
/// returns a [Principal] whose claims carry the user.
///
/// Downstream controllers can read the authenticated user from
/// `ctx.principal!.claims['user'] as User`. The `staff` role is filled
/// in when [User.isStaff] is true so `@Roles({'staff'})` works out of
/// the box.
class JwtAuthenticator extends Authenticator {
  const JwtAuthenticator({required this.database});

  final Database database;

  @override
  Future<Principal?> authenticate(Request request) async {
    final auth = request.headers['authorization'] ?? '';
    final parts = auth.split(RegExp(r'\s+'));
    if (parts.length != 2 || parts.first != 'Bearer') return null;

    final payload = JWTAuth.decodeAndVerify(parts.last);
    if (payload == null) return null;

    final userId = payload['id'] as int?;
    if (userId == null) return null;

    final user = await Query<User>(UserTable.metadata)
        .where(UserTable.id.eq(userId))
        .first(database.context());

    if (user == null || user.isActive == false) return null;

    return Principal(
      id: user.id!.toString(),
      roles: <String>{
        if (user.isStaff) 'staff',
      },
      claims: <String, Object?>{
        'user': user,
      },
    );
  }
}
