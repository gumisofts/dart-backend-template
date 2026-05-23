import 'dart:async';
import 'dart:io';

import 'package:gisila_doc/gisila_doc.dart' hide Query;
import 'package:gisila_orm/gisila.dart';
import 'package:my_app/config.dart';
import 'package:my_app/models/models.dart';
import 'package:my_app/utils/utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'users.g.dart';

@Controller('/users', ['Users'])
class UsersApi {
  // -------------------------------------------------------------------------
  // GET /users  (staff only)
  // -------------------------------------------------------------------------

  @Get('/', summary: 'List all users (staff only)')
  Future<Response> listUsers(Request request) => handleRequest(
        request,
        permission: () {
          if (!request.isAuthenticated) throw unauthorizedException;
          if (request.contextUser!.isStaff != true) throw forbiddenException;
        },
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          final users = await Query<User>(UserTable.metadata).all(db.context());

          return jsonResponse(
            body: {'results': users.map((u) => u.toJson()).toList()},
          );
        },
      );

  // -------------------------------------------------------------------------
  // GET /users/:id
  // -------------------------------------------------------------------------

  @Get('/{id}', summary: 'Retrieve a user by ID')
  Future<Response> getUser(Request request, String id) => handleRequest(
        request,
        permission: () {
          if (!request.isAuthenticated) throw unauthorizedException;
        },
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          final parsedId = int.tryParse(id);
          if (parsedId == null) {
            return jsonResponse(
              statusCode: HttpStatus.badRequest,
              body: {'detail': 'Invalid user id.'},
            );
          }

          final user = await Query<User>(UserTable.metadata)
              .where(UserTable.id.eq(parsedId))
              .first(db.context());

          if (user == null) {
            return jsonResponse(
              statusCode: HttpStatus.notFound,
              body: {'detail': 'User not found.'},
            );
          }

          return jsonResponse(body: user.toJson());
        },
      );

  // -------------------------------------------------------------------------
  // PATCH /users/me
  // -------------------------------------------------------------------------

  @Patch('/me', summary: 'Update own profile')
  Future<Response> updateMe(Request request) => handleRequest(
        request,
        permission: () {
          if (!request.isAuthenticated) throw unauthorizedException;
        },
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          final data = await form(request, fields: [
            FieldValidator<String>(name: 'firstName'),
            FieldValidator<String>(name: 'lastName'),
            FieldValidator<String>(name: 'phoneNumber'),
          ]);

          if (data.isEmpty) {
            return jsonResponse(
              statusCode: HttpStatus.badRequest,
              body: {'detail': 'No updatable fields provided.'},
            );
          }

          final updated = await Query<User>(UserTable.metadata)
              .where(UserTable.id.eq(request.contextUser!.id!))
              .update({
                if (data['firstName'] != null) 'firstName': data['firstName'],
                if (data['lastName'] != null) 'lastName': data['lastName'],
                if (data['phoneNumber'] != null)
                  'phoneNumber': data['phoneNumber'],
                'updatedAt': DateTime.now().toUtc().toIso8601String(),
              })
              .run(db.context())
              .then((rows) => rows.first);

          return jsonResponse(body: updated.toJson());
        },
      );

  // -------------------------------------------------------------------------
  // DELETE /users/me
  // -------------------------------------------------------------------------

  @Delete('/me', summary: 'Delete own account')
  Future<Response> deleteMe(Request request) => handleRequest(
        request,
        permission: () {
          if (!request.isAuthenticated) throw unauthorizedException;
        },
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          await Query<User>(UserTable.metadata)
              .where(UserTable.id.eq(request.contextUser!.id!))
              .delete()
              .run(db.context());

          return jsonResponse(body: {'detail': 'Account deleted.'});
        },
      );
}
