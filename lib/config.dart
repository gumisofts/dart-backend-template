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

/// Initialise app globals before the server starts.
///
/// Call this once in `main()` (and again inside each spawned [Isolate]).
Future<void> init() async {
  databaseConfig = await DatabaseConfig.fromFile('database.yaml');
}
