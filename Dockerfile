# Build a self-contained native server, then run it on a small base image.
#   docker build -t my_app .
#   docker run -p 8080:8080 -e DATABASE_URL=postgres://... -e JWT_SECRET=... my_app
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get
COPY . .
# Generated code (models, routes) is not committed; build it here.
RUN dart run build_runner build --delete-conflicting-outputs \
 && dart compile exe bin/server.dart -o /app/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --no-create-home app
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
USER app
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
