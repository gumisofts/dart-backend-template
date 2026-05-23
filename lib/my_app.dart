import 'package:gisila/gisila.dart';
import 'package:gisila_doc/gisila_doc.dart';
import 'package:my_app/admin.dart';
import 'package:my_app/endpoints/auth.dart';
import 'package:my_app/endpoints/users.dart';
import 'package:my_app/middlewares/authentication.dart';

/// The top-level Shelf [Handler] for the application.
///
/// Wires together:
///  • **GisilaApp** — CORS, rate-limiting, request-id, structured logging,
///    body-size limit, error mapping, and timeout.
///  • **jwtMiddleware** — decodes Bearer tokens and injects the [User] into
///    `request.context['user']`.
///  • **allowedContentTypesMiddleware** — rejects unsupported Content-Types.
///  • **gisila_doc** controllers — API endpoints with OpenAPI spec generation.
///  • **GisilaStudio** — web-based admin panel at `/studio`.
///  • OpenAPI docs (Swagger UI / ReDoc) at `/docs`.
Handler get application {
  final spec = OpenApiSpec(
    info: const ApiInfo(
      title: 'My App API',
      version: '1.0.0',
      description: 'Generated with the Gisila dart-backend-template.',
    ),
  );

  final app = GisilaApp(
    config: AppConfig(
      cors: const CorsConfig(),
      rateLimit: const RateLimitConfig(requestsPerMinute: 300),
      requestTimeout: const Duration(seconds: 30),
      maxRequestBodyBytes: 10 * 1024 * 1024, // 10 MB
      serverHeader: 'my-app/1.0',
      poweredByHeader: false,
    ),
  );

  app.use(jwtMiddleware);
  app.use(allowedContentTypesMiddleware());

  app.registerController(
    attacher: (_, router, {prefix = ''}) {
      AuthApi().attachOpenApi(spec, router);
      UsersApi().attachOpenApi(spec, router);

      router.mount('/studio', adminHandler());

      // Swagger UI at /docs, ReDoc at /redoc, raw spec at /openapi.json
      router.mount('/', docsHandler(spec));
    },
  );

  return app.buildHandler();
}
