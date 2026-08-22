import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Local development proxy for Flutter Web.
///
/// Flutter Web runs in a browser, so requests to the app API are restricted by
/// CORS. Mobile/desktop builds do not have this restriction. This proxy keeps
/// the app code using normal HTTP APIs while adding the CORS headers required by
/// the browser during local web debugging.
///
/// Defaults:
///   listen: http://127.0.0.1:9982
///   target: http://47.239.60.107:8081
///
/// Override:
///   dart tool/web_api_proxy.dart --target http://host:port --port 9982
Future<void> main(List<String> args) async {
  final target = _argValue(args, '--target') ??
      Platform.environment['TARGET_API_BASE'] ??
      'http://47.239.60.107:8081';
  final host = _argValue(args, '--host') ??
      Platform.environment['WEB_PROXY_HOST'] ??
      '127.0.0.1';
  final portText = _argValue(args, '--port') ??
      Platform.environment['WEB_PROXY_PORT'] ??
      '9982';
  final port = int.tryParse(portText) ?? 9982;
  final targetBase = Uri.tryParse(_trimTrailingSlash(target));
  if (targetBase == null ||
      !targetBase.hasScheme ||
      targetBase.host.trim().isEmpty) {
    stderr.writeln('Invalid --target: $target');
    exitCode = 2;
    return;
  }

  final server = await HttpServer.bind(host, port);
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 15);

  stdout.writeln('99chat web API proxy started');
  stdout.writeln('  listen: http://$host:$port');
  stdout.writeln('  target: ${targetBase.toString()}');
  stdout.writeln('  press Ctrl+C to stop');

  await for (final request in server) {
    unawaited(_handle(request, client, targetBase));
  }
}

Future<void> _handle(
  HttpRequest incoming,
  HttpClient client,
  Uri targetBase,
) async {
  final origin = incoming.headers.value('origin');
  _writeCors(incoming.response, origin);

  if (incoming.method.toUpperCase() == 'OPTIONS') {
    incoming.response.statusCode = HttpStatus.noContent;
    await _safeClose(incoming.response);
    return;
  }

  final started = DateTime.now();
  final targetUri = _targetUri(targetBase, incoming.uri);

  try {
    final outbound = await client.openUrl(incoming.method, targetUri);
    _copyRequestHeaders(incoming, outbound);

    await outbound.addStream(incoming.map<List<int>>((chunk) => chunk));
    final upstream = await outbound.close();

    incoming.response.statusCode = upstream.statusCode;
    incoming.response.reasonPhrase = upstream.reasonPhrase;
    _copyResponseHeaders(upstream, incoming.response);
    _writeCors(incoming.response, origin);

    await upstream.pipe(incoming.response);

    final cost = DateTime.now().difference(started).inMilliseconds;
    stdout.writeln(
      '[${DateTime.now().toIso8601String()}] '
      '${incoming.method} ${incoming.uri} -> ${upstream.statusCode} ${cost}ms',
    );
  } catch (e, st) {
    final cost = DateTime.now().difference(started).inMilliseconds;
    stderr.writeln(
      '[${DateTime.now().toIso8601String()}] '
      '${incoming.method} ${incoming.uri} proxy error after ${cost}ms: $e',
    );
    stderr.writeln(st);

    try {
      incoming.response.statusCode = HttpStatus.badGateway;
      incoming.response.headers.contentType = ContentType.json;
      _writeCors(incoming.response, origin);
      incoming.response.write(jsonEncode({
        'code': 'WEB_API_PROXY_UPSTREAM_ERROR',
        'message': 'Web API proxy cannot reach upstream server',
        'upstream': targetUri.toString(),
        'detail': e.toString(),
      }));
      await _safeClose(incoming.response);
    } catch (_) {
      await _safeClose(incoming.response);
    }
  }
}

Uri _targetUri(Uri targetBase, Uri incomingUri) {
  final basePath = _trimTrailingSlash(targetBase.path);
  final incomingPath = incomingUri.path.startsWith('/')
      ? incomingUri.path
      : '/${incomingUri.path}';
  final mergedPath = '$basePath$incomingPath';
  return targetBase.replace(
    path: mergedPath.isEmpty ? '/' : mergedPath,
    query: incomingUri.query.isEmpty ? null : incomingUri.query,
  );
}

void _copyRequestHeaders(HttpRequest incoming, HttpClientRequest outbound) {
  incoming.headers.forEach((name, values) {
    final lower = name.toLowerCase();
    if (_hopByHopHeaders.contains(lower) ||
        lower == 'host' ||
        lower == 'origin') {
      return;
    }
    for (final value in values) {
      outbound.headers.add(name, value);
    }
  });
  outbound.headers.set(HttpHeaders.hostHeader, outbound.uri.authority);
}

void _copyResponseHeaders(HttpClientResponse upstream, HttpResponse outgoing) {
  upstream.headers.forEach((name, values) {
    final lower = name.toLowerCase();
    if (_hopByHopHeaders.contains(lower) ||
        lower.startsWith('access-control-')) {
      return;
    }
    for (final value in values) {
      outgoing.headers.add(name, value);
    }
  });
}

void _writeCors(HttpResponse response, String? origin) {
  final trimmedOrigin = origin?.trim();
  final allowOrigin = (trimmedOrigin == null || trimmedOrigin.isEmpty)
      ? '*'
      : trimmedOrigin;

  response.headers.set('Access-Control-Allow-Origin', allowOrigin);
  response.headers.set('Access-Control-Allow-Credentials', 'true');
  response.headers.set(
    'Access-Control-Allow-Methods',
    'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  );
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Origin,Accept,Content-Type,Authorization,X-Client-Version,X-Client-Platform,X-Requested-With',
  );
  response.headers.set('Access-Control-Max-Age', '86400');
  response.headers.add('Vary', 'Origin');
}

Future<void> _safeClose(HttpResponse response) async {
  try {
    await response.close();
  } catch (_) {}
}

String? _argValue(List<String> args, String name) {
  for (var i = 0; i < args.length; i++) {
    final item = args[i];
    if (item == name && i + 1 < args.length) {
      return args[i + 1];
    }
    if (item.startsWith('$name=')) {
      return item.substring(name.length + 1);
    }
  }
  return null;
}

String _trimTrailingSlash(String value) {
  var text = value.trim();
  while (text.length > 1 && text.endsWith('/')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

const _hopByHopHeaders = <String>{
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
};
