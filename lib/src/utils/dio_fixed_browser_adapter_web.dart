// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

import 'package:dio/src/adapter.dart';
import 'package:dio/src/dio_error.dart';
import 'package:dio/src/headers.dart';
import 'package:dio/src/options.dart';

/// Patched copy of dio 4.0.6 [BrowserHttpClientAdapter].
///
/// Upstream completes the same [Completer] twice when [connectTimeout] is set
/// and a GET succeeds — `haveSent` stays false without upload progress, so the
/// delayed timeout handler still fires after [onLoad]. Web-only.
HttpClientAdapter createFixedWebHttpClientAdapter() =>
    FixedBrowserHttpClientAdapter();

class FixedBrowserHttpClientAdapter implements HttpClientAdapter {
  final _xhrs = <HttpRequest>{};

  bool withCredentials = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final xhr = HttpRequest();
    _xhrs.add(xhr);
    xhr
      ..open(options.method, '${options.uri}')
      ..responseType = 'arraybuffer';

    final withCreds = options.extra['withCredentials'];
    if (withCreds != null) {
      xhr.withCredentials = withCreds == true;
    } else {
      xhr.withCredentials = withCredentials;
    }

    options.headers.remove(Headers.contentLengthHeader);
    options.headers.forEach((key, v) => xhr.setRequestHeader(key, '$v'));

    if (options.connectTimeout > 0 && options.receiveTimeout > 0) {
      xhr.timeout = options.connectTimeout + options.receiveTimeout;
    }

    final completer = Completer<ResponseBody>();

    void safeComplete(ResponseBody body) {
      if (!completer.isCompleted) {
        completer.complete(body);
      }
    }

    void safeCompleteError(Object error, [StackTrace? stackTrace]) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace ?? StackTrace.current);
      }
    }

    xhr.onLoad.first.then((_) {
      if (completer.isCompleted) {
        return;
      }
      final body = (xhr.response as ByteBuffer).asUint8List();
      safeComplete(
        ResponseBody.fromBytes(
          body,
          xhr.status,
          headers: xhr.responseHeaders
              .map((k, v) => MapEntry(k, v.split(','))),
          statusMessage: xhr.statusText,
          isRedirect: xhr.status == 302 || xhr.status == 301,
        ),
      );
    });

    var haveSent = false;

    if (options.connectTimeout > 0) {
      Future<void>.delayed(Duration(milliseconds: options.connectTimeout))
          .then((_) {
        if (!haveSent && !completer.isCompleted) {
          safeCompleteError(
            DioError(
              requestOptions: options,
              error: 'Connecting timed out [${options.connectTimeout}ms]',
              type: DioErrorType.connectTimeout,
            ),
          );
          xhr.abort();
        }
      });
    }

    var sendStart = 0;
    xhr.upload.onProgress.listen((event) {
      haveSent = true;
      if (options.sendTimeout > 0) {
        sendStart = sendStart == 0
            ? DateTime.now().millisecondsSinceEpoch
            : sendStart;
        final elapsed = DateTime.now().millisecondsSinceEpoch - sendStart;
        if (elapsed > options.sendTimeout && !completer.isCompleted) {
          safeCompleteError(
            DioError(
              requestOptions: options,
              error: 'Sending timed out [${options.sendTimeout}ms]',
              type: DioErrorType.sendTimeout,
            ),
          );
          xhr.abort();
        }
      }
      if (options.onSendProgress != null &&
          event.loaded != null &&
          event.total != null) {
        options.onSendProgress!(event.loaded!, event.total!);
      }
    });

    var receiveStart = 0;
    xhr.onProgress.listen((event) {
      if (options.receiveTimeout > 0) {
        receiveStart = receiveStart == 0
            ? DateTime.now().millisecondsSinceEpoch
            : receiveStart;
        if (DateTime.now().millisecondsSinceEpoch - receiveStart >
                options.receiveTimeout &&
            !completer.isCompleted) {
          safeCompleteError(
            DioError(
              requestOptions: options,
              error: 'Receiving timed out [${options.receiveTimeout}ms]',
              type: DioErrorType.receiveTimeout,
            ),
          );
          xhr.abort();
        }
      }
      if (options.onReceiveProgress != null &&
          event.loaded != null &&
          event.total != null) {
        options.onReceiveProgress!(event.loaded!, event.total!);
      }
    });

    xhr.onError.first.then((_) {
      safeCompleteError(
        DioError(
          type: DioErrorType.response,
          error: 'XMLHttpRequest error.',
          requestOptions: options,
        ),
      );
    });

    cancelFuture?.then((err) {
      if (xhr.readyState < 4 && xhr.readyState > 0) {
        try {
          xhr.abort();
        } catch (_) {}
        if (!completer.isCompleted) {
          safeCompleteError(err);
        }
      }
    });

    if (requestStream != null) {
      final bytesCompleter = Completer<Uint8List>();
      final sink = ByteConversionSink.withCallback(
        (bytes) => bytesCompleter.complete(Uint8List.fromList(bytes)),
      );
      requestStream.listen(
        sink.add,
        onError: bytesCompleter.completeError,
        onDone: sink.close,
        cancelOnError: true,
      );
      final bytes = await bytesCompleter.future;
      xhr.send(bytes);
    } else {
      xhr.send();
    }

    return completer.future.whenComplete(() {
      _xhrs.remove(xhr);
    });
  }

  @override
  void close({bool force = false}) {
    if (force) {
      for (final xhr in _xhrs) {
        xhr.abort();
      }
    }
    _xhrs.clear();
  }
}
