# dart-backend-template

A production-ready Dart backend template built on the **Gisila** stack:

| Package | Role |
|---------|------|
| `gisila` | Shelf-based HTTP framework: CORS, rate-limiting, middleware, codegen |
| `gisila_orm` | Schema-driven PostgreSQL ORM: YAML → Dart models + SQL |
| `gisila_doc` | OpenAPI 3.1 spec generation + Swagger UI / ReDoc |
| `gisila_studio` | Django-style admin panel from ORM table metadata |

Out of the box you get:
- JWT authentication (register, login, `/auth/me`)
- Users CRUD endpoints
- OpenAPI docs at `/docs` (Swagger UI) and `/redoc`
- Admin panel at `/studio`
- Form validation helpers and typed error handling
- Docker Compose for local PostgreSQL

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
│   ├── my_app.dart                 # GisilaApp wiring (middleware, routes, docs)
│   ├── admin.dart                  # GisilaStudio model registrations
│   ├── config.dart                 # env, logger, databaseConfig, init()
│   ├── endpoints/
│   │   ├── auth.dart               # POST /auth/register|login, GET /auth/me
│   │   └── users.dart              # GET/PATCH/DELETE /users/...
│   ├── middlewares/
│   │   └── authentication.dart     # JWT → request.contextUser
│   ├── models/
│   │   ├── schema.gisila.yaml      # ORM schema definition (edit this!)
│   │   └── models.dart             # Re-exports generated .g.dart
│   └── utils/
│       ├── utils.dart              # Barrel export
│       ├── jwt.dart                # JWTAuth.sign / verify / decodeAndVerify
│       ├── extensions.dart         # request.contextUser, .isAuthenticated
│       ├── exceptions.dart         # EndpointException, unauthorizedException
│       ├── request_handler.dart    # handleRequest() error-handling wrapper
│       └── forms/
│           ├── field_exceptions.dart
│           ├── form_validators.dart  # form(), FieldValidator, common validators
│           └── parsers/
│               └── form_data.dart   # multipart + urlencoded parser
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

1. Create `lib/endpoints/posts.dart`:
   ```dart
   import 'package:gisila_doc/gisila_doc.dart' hide Query;
   import 'package:gisila_orm/gisila.dart';
   import 'package:my_app/config.dart';
   import 'package:my_app/models/models.dart';
   import 'package:my_app/utils/utils.dart';
   import 'package:shelf/shelf.dart';
   import 'package:shelf_router/shelf_router.dart';

   part 'posts.g.dart';

   @Controller('/posts', ['Posts'])
   class PostsApi {
     @Get('/', summary: 'List posts')
     Future<Response> list(Request request) => handleRequest(
           request,
           permission: () {},
           endpoint: () async {
             final db = request.contextDb ?? await Database.connect(databaseConfig);
             final posts = await Query<Post>(PostTable.metadata).all(db.context());
             return jsonResponse(body: {'results': posts.map((p) => p.toJson()).toList()});
           },
         );
   }
   ```
2. Run `dart run build_runner build` to generate `posts.g.dart`.
3. Register in `lib/my_app.dart`:
   ```dart
   PostsApi().attachOpenApi(spec, router);
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
