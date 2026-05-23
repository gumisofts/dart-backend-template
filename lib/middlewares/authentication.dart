import 'dart:async';

import 'package:gisila_orm/gisila.dart';
import 'package:my_app/config.dart';
import 'package:my_app/models/models.dart';
import 'package:my_app/utils/jwt.dart';
import 'package:shelf/shelf.dart';

/// Shelf middleware that decodes a Bearer JWT and injects the resolved [User]
/// into `request.context['user']`.
///
/// If no valid token is present the context key is set to `false` so that
/// downstream handlers can distinguish "no auth" from "user not found".
FutureOr<Response> Function(Request) jwtMiddleware(
  FutureOr<Response> Function(Request) inner,
) {
  return (request) async {
    final auth = request.headers['authorization'] ?? '';
    final parts = auth.split(RegExp(r'\s+'));

    if (parts.length != 2 || parts.first != 'Bearer') {
      return inner(
        request.change(context: {...request.context, 'user': false}),
      );
    }

    final payload = JWTAuth.decodeAndVerify(parts.last);
    final userId = payload?['id'] as int?;

    User? user;
    if (userId != null) {
      final db = await Database.connect(databaseConfig);
      user = await Query<User>(UserTable.metadata)
          .where(UserTable.id.eq(userId))
          .first(db.context());
    }

    return inner(
      request.change(context: {...request.context, 'user': user ?? false}),
    );
  };
}
