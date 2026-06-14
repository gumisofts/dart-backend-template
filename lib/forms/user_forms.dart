import 'package:gisila/gisila.dart';

/// `PATCH /users/me` body — every field is optional, but at least one
/// must be provided. The controller enforces the "at least one" rule;
/// forms only handle per-field validation.
class UpdateProfileForm extends Form {
  final firstName = StringField(name: 'firstName');
  final lastName = StringField(name: 'lastName');
  final phoneNumber = StringField(name: 'phoneNumber');

  @override
  List<FormField<Object?>> collectFields() => <FormField<Object?>>[
        firstName,
        lastName,
        phoneNumber,
      ];
}
