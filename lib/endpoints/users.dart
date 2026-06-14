import 'dart:async';

import 'package:gisila_doc/gisila_doc.dart';
import 'package:my_app/forms/user_forms.dart';
import 'package:my_app/models/models.dart';
import 'package:my_app/services/users_service.dart';

part 'users.g.dart';

@Controller('/users', ['Users'])
@RequireAuth()
class UsersApi {
  @Get('/', summary: 'List all users (staff only)')
  @Roles({'staff'})
  Future<Map<String, Object?>> listUsers(UsersService users) async {
    final all = await users.listAll();
    return <String, Object?>{
      'results': all.map((u) => u.toJson()).toList(),
    };
  }

  @Get('/{id}', summary: 'Retrieve a user by ID')
  Future<Map<String, Object?>> getUser(String id, UsersService users) async {
    final user = await users.findById(id);
    return user.toJson(exclude: ['password']);
  }

  @Patch('/me', summary: 'Update own profile')
  Future<Map<String, Object?>> updateMe(
    UpdateProfileForm form,
    UsersService users,
    RequestContext ctx,
  ) async {
    final current = ctx.principal!.claims['user'] as User;
    final updated = await users.updateProfile(
      current,
      firstName: form.firstName.value,
      lastName: form.lastName.value,
      phoneNumber: form.phoneNumber.value,
    );
    return updated.toJson(exclude: ['password']);
  }

  @Delete('/me', summary: 'Delete own account')
  Future<Map<String, Object?>> deleteMe(
    UsersService users,
    RequestContext ctx,
  ) async {
    final current = ctx.principal!.claims['user'] as User;
    await users.deleteAccount(current);
    return <String, Object?>{'detail': 'Account deleted.'};
  }
}
