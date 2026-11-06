import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

Future<void> main() async {
  final file = File('assets/order.json');
  if (!await file.exists()) {
    stderr.writeln('Missing assets/order.json. Run from the my_order folder.');
    exitCode = 1;
    return;
  }
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  developer.log('Server running on port 8080');
  await for (final request in server) {
    request.response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, PUT, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'Content-Type')
      ..contentType = ContentType.json;
    try {
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 204;
      } else if (request.uri.path != '/orders') {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'error': 'Not found'}));
      } else if (request.method == 'GET') {
        request.response.write(await file.readAsString());
      } else if (request.method == 'PUT') {
        final raw = await utf8.decoder.bind(request).join();
        final parsed = jsonDecode(raw);
        if (parsed is! List || parsed.any((e) => e is! Map ||
            !e.containsKey('Item') || !e.containsKey('ItemName') ||
            !e.containsKey('Price') || !e.containsKey('Quantity') ||
            !e.containsKey('Currency'))) {
          request.response.statusCode = 400;
          request.response.write(jsonEncode({'error': 'Invalid order list'}));
        } else {
          final temp = File('${file.path}.tmp');
          await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(parsed), flush: true);
          // Replace existing JSON only after the new content is written.
          if (await file.exists()) await file.delete();
          await temp.rename(file.path);
          request.response.write(jsonEncode({'message': 'Saved to assets/order.json'}));
        }
      } else {
        request.response.statusCode = 405;
        request.response.write(jsonEncode({'error': 'Method not allowed'}));
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
    } finally {
      await request.response.close();
    }
  }
}
