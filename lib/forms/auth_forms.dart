import 'package:gisila/gisila.dart';

String? _strongPassword(String value) {
  if (value.length < 8) {
    return 'Password must be at least 8 characters long.';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least one uppercase letter.';
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Password must contain at least one lowercase letter.';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Password must contain at least one number.';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Password must contain at least one special character.';
  }
  return null;
}

class RegisterForm extends Form {
  final email = EmailField(name: 'email', required: true);
  final password = StringField(
    name: 'password',
    required: true,
    validators: <FieldValidator<String>>[_strongPassword],
  );
  final firstName = StringField(name: 'firstName');
  final lastName = StringField(name: 'lastName');

  @override
  List<FormField<Object?>> collectFields() => <FormField<Object?>>[
        email,
        password,
        firstName,
        lastName,
      ];
}

class LoginForm extends Form {
  final email = EmailField(name: 'email', required: true);
  final password = StringField(name: 'password', required: true);

  @override
  List<FormField<Object?>> collectFields() =>
      <FormField<Object?>>[email, password];
}

class ChangePasswordForm extends Form {
  final oldPassword = StringField(name: 'oldPassword', required: true);
  final newPassword = StringField(
    name: 'newPassword',
    required: true,
    validators: <FieldValidator<String>>[_strongPassword],
  );

  @override
  List<FormField<Object?>> collectFields() =>
      <FormField<Object?>>[oldPassword, newPassword];
}
