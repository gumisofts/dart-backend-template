import 'dart:async';
import 'dart:io';

import 'package:gisila_doc/gisila_doc.dart' hide Query;
import 'package:gisila_orm/gisila.dart';
import 'package:my_app/config.dart';
import 'package:my_app/models/models.dart';
import 'package:my_app/utils/utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

part 'auth.g.dart';

@Controller('/auth', ['Auth'])
class AuthApi {
  // -------------------------------------------------------------------------
  // POST /auth/register
  // -------------------------------------------------------------------------

  @Post('/register', summary: 'Register a new account')
  Future<Response> register(Request request) => handleRequest(
        request,
        permission: () {},
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          final data = await form(request, fields: [
            emailValidator,
            passwordValidator,
            FieldValidator<String>(name: 'firstName', isRequired: false),
            FieldValidator<String>(name: 'lastName', isRequired: false),
          ]);

          final email = data['email'] as String;

          final existing = await Query<User>(UserTable.metadata)
              .where(UserTable.email.eq(email))
              .first(db.context());

          if (existing != null) {
            return jsonResponse(
              statusCode: HttpStatus.conflict,
              body: {'detail': 'An account with this email already exists.'},
            );
          }

          final user = await Query<User>(UserTable.metadata).insert({
            'email': email,
            'password': data['password'] as String,
            'firstName': data['firstName'] as String?,
            'lastName': data['lastName'] as String?,
            'isActive': true,
            'isStaff': false,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          }).one(db.context());

          final token = JWTAuth.sign(user);

          return jsonResponse(
            statusCode: HttpStatus.created,
            body: {'user': user.toJson(), 'access': token},
          );
        },
      );

  // -------------------------------------------------------------------------
  // POST /auth/login
  // -------------------------------------------------------------------------

  @Post('/login', summary: 'Login with email and password')
  Future<Response> login(Request request) => handleRequest(
        request,
        permission: () {},
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          final data = await form(request, fields: [
            emailValidator,
            FieldValidator<String>(name: 'password', isRequired: true),
          ]);

          final user = await Query<User>(UserTable.metadata)
              .where(UserTable.email.eq(data['email'] as String))
              .first(db.context());

          if (user == null || user.password != data['password']) {
            return jsonResponse(
              statusCode: HttpStatus.unauthorized,
              body: {'detail': 'Invalid email or password.'},
            );
          }

          if (user.isActive == false) {
            return jsonResponse(
              statusCode: HttpStatus.forbidden,
              body: {'detail': 'This account is inactive.'},
            );
          }

          final token = JWTAuth.sign(user);

          return jsonResponse(body: {'user': user.toJson(), 'access': token});
        },
      );

  // -------------------------------------------------------------------------
  // GET /auth/me
  // -------------------------------------------------------------------------

  @Get('/me', summary: 'Get the authenticated user profile')
  Future<Response> me(Request request) => handleRequest(
        request,
        permission: () {
          if (!request.isAuthenticated) throw unauthorizedException;
        },
        endpoint: () async => jsonResponse(body: request.contextUser!.toJson()),
      );

  // -------------------------------------------------------------------------
  // POST /auth/change-password
  // -------------------------------------------------------------------------

  @Post('/change-password', summary: 'Change password')
  Future<Response> changePassword(Request request) => handleRequest(
        request,
        permission: () {
          if (!request.isAuthenticated) throw unauthorizedException;
        },
        endpoint: () async {
          final db =
              request.contextDb ?? await Database.connect(databaseConfig);

          final data = await form(request, fields: [
            FieldValidator<String>(name: 'oldPassword', isRequired: true),
            FieldValidator<String>(
              name: 'newPassword',
              isRequired: true,
              validator: (v) => v.length >= 8
                  ? null
                  : 'Password must be at least 8 characters.',
            ),
          ]);

          final user = request.contextUser!;

          if (user.password != data['oldPassword']) {
            return jsonResponse(
              statusCode: HttpStatus.badRequest,
              body: {'detail': 'Old password is incorrect.'},
            );
          }

          await Query<User>(UserTable.metadata)
              .where(UserTable.id.eq(user.id!))
              .update({'password': data['newPassword'] as String}).run(
                  db.context());

          return jsonResponse(
              body: {'detail': 'Password changed successfully.'});
        },
      );
}
