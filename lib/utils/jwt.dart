import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:my_app/config.dart';
import 'package:my_app/models/models.dart';

/// Stateless JWT helper.
///
/// The secret is read from the `JWT_SECRET` environment variable.
/// The token lifetime defaults to `JWT_EXPIRE_DAYS` (default: 30).
class JWTAuth {
  static String _secret() => env.getOrElse('JWT_SECRET', () => 'change-me');
  static Duration _expiry() => Duration(
        days: int.parse(env.getOrElse('JWT_EXPIRE_DAYS', () => '30')),
      );

  /// Signs a JWT for [user] and returns the token string.
  static String sign(User user) {
    return JWT(
      {
        'id': user.id,
        'email': user.email ?? '',
        'isStaff': user.isStaff,
      },
      jwtId: '',
    ).sign(
      SecretKey(_secret()),
      expiresIn: _expiry(),
    );
  }

  /// Returns `true` when [token] has a valid signature and is not expired.
  static bool verify(String token) {
    try {
      JWT.verify(token, SecretKey(_secret()));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Decodes [token] payload without verifying the signature.
  static Map<String, dynamic> decode(String token) {
    return JWT.decode(token).payload as Map<String, dynamic>;
  }

  /// Returns the decoded payload when [token] is valid, otherwise `null`.
  static Map<String, dynamic>? decodeAndVerify(String token) =>
      verify(token) ? decode(token) : null;
}
