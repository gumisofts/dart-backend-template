import 'package:dotenv/dotenv.dart';
import 'package:gisila_orm/gisila.dart';
import 'package:logger/logger.dart';

/// Global environment variables (platform env + .env file).
final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();

/// Application-wide structured logger.
final logger = Logger(
  printer: PrettyPrinter(
    dateTimeFormat: (dt) => dt.toIso8601String(),
  ),
);

/// Resolved database config (populated by [init]).
late DatabaseConfig databaseConfig;

/// The validated `JWT_SECRET` (populated by [init]).
late String jwtSecret;

/// Shortest `JWT_SECRET` the server accepts.
const minJwtSecretLength = 32;

/// Initialise app globals before the server starts.
///
/// Call this once in `main()` (and again inside each spawned [Isolate]).
/// Throws a [StateError] when `JWT_SECRET` is missing or weak, so the server
/// never starts with forgeable tokens.
Future<void> init() async {
  jwtSecret = _loadJwtSecret();
  databaseConfig = await DatabaseConfig.fromFile('database.yaml');
}

String _loadJwtSecret() {
  final secret = env['JWT_SECRET'] ?? '';
  final placeholder = secret
      .toLowerCase()
      .replaceAll(RegExp('[^a-z]'), '')
      .contains('changeme');
  final problem = secret.isEmpty
      ? 'is not set'
      : secret.length < minJwtSecretLength
          ? 'is shorter than $minJwtSecretLength characters'
          : placeholder
              ? 'is still the placeholder from .env.example'
              : null;
  if (problem == null) return secret;
  if (secret.isNotEmpty && env['GISILA_ALLOW_INSECURE'] == '1') {
    logger.w('JWT_SECRET $problem; starting anyway because '
        'GISILA_ALLOW_INSECURE=1. Tokens can be forged.');
    return secret;
  }
  throw StateError('JWT_SECRET $problem. Generate one with '
      '`openssl rand -hex 32` and put it in .env.');
}
