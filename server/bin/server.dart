import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:libiko_server/src/api.dart';
import 'package:libiko_server/src/auth.dart';
import 'package:libiko_server/src/database.dart';

Future<void> main() async {
  final secret = Platform.environment['LIBIKO_JWT_SECRET'];
  if (secret == null || secret.isEmpty) {
    stderr.writeln('LIBIKO_JWT_SECRET is required');
    exit(1);
  }
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbPath = Platform.environment['LIBIKO_DB_PATH'] ?? 'data/libiko.db';

  final dir = Directory(File(dbPath).parent.path);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final db = Database.open(dbPath);
  final handler = Api(db, Auth(secret)).handler;

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('libiko-server listening on http://${server.address.host}:${server.port}');
}
