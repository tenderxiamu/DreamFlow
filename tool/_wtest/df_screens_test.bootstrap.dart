// @dart=3.10
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_api/backend.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:stack_trace/stack_trace.dart';

import 'file:///C:/Users/29718/WorkBuddy/2026-10-11-20-44-45/dreamflow_flutter/test/df_screens_test.dart' as test;

// DO NOT RENAME: 工具链依赖此常量名获取 package config。
const packageConfigLocation = 'file:///C:/Users/29718/WorkBuddy/2026-10-11-20-44-45/dreamflow_flutter/.dart_tool/package_config.json';

/// Returns a serialized test suite.
StreamChannel<dynamic> serializeSuite(Function getMain()) {
  return RemoteListener.start(getMain);
}

Future<void> _testMain() async {
  await Future(test.main);
}

void catchIsolateErrors() {
  final ReceivePort errorPort = ReceivePort();
  Isolate.current.setErrorsFatal(false);
  Isolate.current.addErrorListener(errorPort.sendPort);
  errorPort.listen((dynamic message) {
    final IsolateSpawnException error = IsolateSpawnException(message[0] as String);
    final Trace stackTrace = message[1] == null
        ? Trace(const <Frame>[])
        : Trace.parse(message[1] as String);
    Zone.current.handleUncaughtError(error, stackTrace);
  });
}

void main() {
  final String serverPort = Platform.environment['SERVER_PORT'] ?? '';
  final String server = 'ws://127.0.0.1:$serverPort';
  StreamChannel<dynamic> testChannel = serializeSuite(() {
    catchIsolateErrors();
    goldenFileComparator = LocalFileComparator(Uri.parse('file:///C:/Users/29718/WorkBuddy/2026-10-11-20-44-45/dreamflow_flutter/test/df_screens_test.dart'));
    autoUpdateGoldenFiles = false;
    return _testMain;
  });

  WebSocket.connect(server).then((WebSocket socket) {
    socket.map((dynamic message) => json.decode(message as String)).pipe(testChannel.sink);
    socket.addStream(testChannel.stream.map(json.encode));
  });
}
