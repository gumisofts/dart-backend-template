# dart-backend-template

A production-ready Dart backend template built on the **Gisila** stack:

| Package | Role |
|---------|------|
| `gisila` | Shelf-based HTTP framework: CORS, rate-limiting, middleware, codegen |
| `gisila_orm` | Schema-driven PostgreSQL ORM: YAML → Dart models + SQL |
| `gisila_doc` | OpenAPI 3.1 spec generation + Swagger UI / ReDoc |
| `gisila_studio` | Django-style admin panel from ORM table metadata |

Out of the box you get:
- **MVC layout** — thin controllers, typed `Form` inputs, request-scoped `Service` classes.
- JWT-backed `Authenticator` that hydrates the active `User` into `ctx.principal!.claims['user']`.
- Per-request PostgreSQL pool exposed through `ctx.db<Database>()`.
- Centralised error mapping: `Conflict`, `BadRequest`, `NotFound` propagate cleanly; `PostgresException`s become JSON.
- Per-route configuration (rate limit, timeout, content types, auth) via `RouteConfig`.
- Users CRUD + auth (register, login, `/auth/me`, change password).
- OpenAPI docs at `/docs` (Swagger UI) and `/redoc`.
- Admin panel at `/studio`.
- Docker Compose for local PostgreSQL.

---

## Prerequisites

- [Dart SDK](https://dart.dev/get-dart) `>=3.3.4`
- [Docker](https://docs.docker.com/get-docker/) (for local Postgres)
- The rest of the `gisila_tools` monorepo cloned next to this folder

---

## Quick start

### 1. Install dependencies

```bash
dart pub get
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env: set JWT_SECRET to a random string
```

### 3. Start PostgreSQL

```bash
docker compose up -d
```

This starts Postgres on **localhost:5454** (mapped from container port 5432).
The default credentials match `database.yaml`: `postgres / postgres / my_app`.

### 4. Generate ORM models and run migrations

```bash
# Generate Dart models + SQL migration files from schema.gisila.yaml
dart run build_runner build

# Apply the initial migration
dart run bin/migrate.dart up
```

> `bin/migrate.dart` is provided by `gisila_orm`. Run it from this directory.

### 5. Run the server

```bash
# Development (hot-reload)
dart run bin/server.dart --dev

# Production (multi-isolate)
dart run bin/server.dart
```

Open:
- API docs → <http://localhost:8000/docs>
- Admin panel → <http://localhost:8000/studio>  _(default: admin / admin)_

---

## Project structure

```
dart-backend-template/
├── bin/
│   └── server.dart                 # Entry point; hot-reload + multi-isolate
├── lib/
│   ├── my_app.dart                 # GisilaApp wiring (config, services, controllers)
│   ├── admin.dart                  # GisilaStudio model registrations
│   ├── config.dart                 # env, logger, databaseConfig, init()
│   ├── endpoints/                  # Thin controllers
│   │   ├── auth.dart
│   │   └── users.dart
│   ├── forms/                      # Typed request body schemas (Form subclasses)
│   │   ├── auth_forms.dart
│   │   └── user_forms.dart
│   ├── services/                   # Business logic (Service subclasses)
│   │   ├── auth_service.dart
│   │   └── users_service.dart
│   ├── infra/                      # Framework integrations
│   │   ├── database_provider.dart  # GisilaOrmDatabaseProvider
│   │   ├── jwt_authenticator.dart  # JWT-backed Authenticator
│   │   └── postgres_error_mapper.dart  # 23xxx → 400/409 JSON
│   ├── models/
│   │   ├── schema.gisila.yaml      # ORM schema definition (edit this!)
│   │   └── models.dart             # Re-exports generated .g.dart
│   └── utils/
│       ├── utils.dart              # Barrel export
│       └── jwt.dart                # JWTAuth.sign / verify / decodeAndVerify
├── database.yaml                   # PostgreSQL connection config
├── .env.example                    # Environment variable template
├── docker-compose.yaml             # Local Postgres on port 5454
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Renaming the project

1. Replace `my_app` with your project name everywhere:
   ```bash
   # macOS / Linux
   find . -type f \( -name "*.dart" -o -name "*.yaml" \) \
     -exec sed -i 's/my_app/your_project_name/g' {} +
   ```
2. Rename the folder: `mv dart-backend-template your_project_name`

---

## Adding a new model

1. Add the model to `lib/models/schema.gisila.yaml`:
   ```yaml
   Post:
     columns:
       title:
         type: varchar
         is_null: false
       body:
         type: text
         is_null: true
       author:
         type: User
         references: User
         reverse_name: posts
       created_at:
         type: timestamp
         is_null: false
   ```
2. Regenerate:
   ```bash
   dart run build_runner build
   ```
3. Migrate:
   ```bash
   dart run bin/migrate.dart up
   ```
4. Register in `lib/admin.dart`:
   ```dart
   studio.register<Post>(PostTable.metadata, displayName: 'Post');
   ```

---

## Adding a new endpoint

The template follows an explicit **MVC layout**:

```
controller (lib/endpoints/) ─── form (lib/forms/) ─── service (lib/services/)
                                                                │
                                                          ctx.db<Database>()
```

1. **Service** — owns persistence + business logic. Use `ctx.db<Database>()`
   for query execution and throw framework exceptions for errors:
   ```dart
   // lib/services/posts_service.dart
   import 'package:gisila/gisila.dart' hide Query;
   import 'package:gisila_orm/gisila.dart';
   import 'package:my_app/models/models.dart';

   class PostsService extends Service {
     Database get _db => db<Database>();

     Future<List<Post>> list() =>
         Query<Post>(PostTable.metadata).all(_db.context());

     Future<Post> create({required String title, String? body}) =>
         Query<Post>(PostTable.metadata).insert({
           'title': title,
           'body': body,
           'createdAt': DateTime.now().toUtc().toIso8601String(),
         }).one(_db.context());
   }
   ```
2. **Form** — declarative request body schema:
   ```dart
   // lib/forms/post_forms.dart
   import 'package:gisila/gisila.dart';

   class CreatePostForm extends Form {
     final title = StringField(name: 'title', required: true, maxLength: 200);
     final body  = StringField(name: 'body');

     @override
     List<FormField<Object?>> collectFields() => [title, body];
   }
   ```
3. **Controller** — thin orchestrator. Takes `Form` + `Service` params and
   returns the JSON body directly:
   ```dart
   // lib/endpoints/posts.dart
   import 'package:gisila_doc/gisila_doc.dart';
   import 'package:my_app/forms/post_forms.dart';
   import 'package:my_app/services/posts_service.dart';

   part 'posts.g.dart';

   @Controller('/posts', ['Posts'])
   @RequireAuth()
   class PostsApi {
     @Get('/', summary: 'List posts')
     Future<List<Map<String, Object?>>> list(PostsService posts) async {
       final all = await posts.list();
       return all.map((p) => p.toJson()).toList();
     }

     @Post('/', summary: 'Create a post')
     Future<Map<String, Object?>> create(
       CreatePostForm form,
       PostsService posts,
     ) async {
       final created = await posts.create(
         title: form.title.value!,
         body: form.body.value,
       );
       return created.toJson();
     }
   }
   ```
4. Run `dart run build_runner build` to generate `posts.g.dart`.
5. Register the service and controller in `lib/my_app.dart`:
   ```dart
   app.registerService<PostsService>(PostsService.new);

   app.registerController(attacher: (app, router, {prefix = ''}) {
     PostsApi().attachToApp(app, router, spec, prefix: prefix);
     // ... existing controllers
   });
   ```

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8000` | HTTP listen port |
| `JWT_SECRET` | `change-me-to-a-random-secret` | HMAC secret for signing JWTs |
| `JWT_EXPIRE_DAYS` | `30` | Token lifetime in days |
| `STUDIO_USERNAME` | `admin` | Admin panel username |
| `STUDIO_PASSWORD` | `admin` | Admin panel password |

---

## Deployment

Compile to a native executable:

```bash
dart compile exe bin/server.dart -o build/server
./build/server
```

Set `PORT`, `JWT_SECRET`, and point `database.yaml` at your production Postgres
instance before running in production.
