import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:my_app/config.dart';
import 'package:my_app/my_app.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_hotreload/shelf_hotreload.dart';

Future<void> main(List<String> args) async {
  await init();
  final port = int.parse(env.getOrElse('PORT', () => '8000'));
  final isDev = args.contains('--dev') || args.contains('dev');

  if (isDev) {
    _createDevServer(port);
  } else {
    await _createServer(port);
  }

  logger.i('Server started on port $port${isDev ? ' (hot-reload)' : ''}');
  logger.i('Docs:  http://localhost:$port/docs');
  logger.i('Admin: http://localhost:$port/studio');
}

Future<void> _createServer(int port) async {
  for (var i = 0; i < Platform.numberOfProcessors; i++) {
    await Isolate.spawn(
      debugName: 'Isolate $i',
      (int p) async {
        await init();
        final handler = await application();
        final server = await serve(handler, '0.0.0.0', p, shared: true);
        server.autoCompress = true;
      },
      port,
    );
  }

  final handler = await application();
  final server = await serve(handler, '0.0.0.0', port, shared: true);
  server.autoCompress = true;
}

void _createDevServer(int port) => withHotreload(
      () async {
        final handler = await application();
        return serve(handler, '0.0.0.0', port, shared: true);
      },
    );
