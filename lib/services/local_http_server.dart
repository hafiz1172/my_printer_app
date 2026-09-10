import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class LocalHttpPrintServer {
  HttpServer? _server;
  final Function(String text) onPrintRequested;

  LocalHttpPrintServer({required this.onPrintRequested});

  Future<void> start({int port = 40213}) async {
    final router = Router();

    // CORS handler for browser fetch requests
    Response corsResponse(Response res) => res.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type',
        });

    router.add('OPTIONS', '/<ignored|.*>', (Request req) {
      return corsResponse(Response.ok(''));
    });

    router.post('/print', (Request request) async {
      try {
        final payload = await request.readAsString();
        final body = jsonDecode(payload);
        final textToPrint = body['data'] ?? '';
        
        onPrintRequested(textToPrint);

        return corsResponse(Response.ok(jsonEncode({'status': 'queued'})));
      } catch (e) {
        return corsResponse(Response.internalServerError(body: e.toString()));
      }
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await io.serve(handler, InternetAddress.anyIPv4, port);
    stdout.writeln('RawBT Local Server active on port: ${_server?.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }
}
