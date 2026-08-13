import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class ServiceListener {
  void onServiceEvent(CoreEvent event) {}

  void onServiceCrash(String message) {}
}

class Service {
  static Service? _instance;
  late MethodChannel methodChannel;
  ReceivePort? receiver;

  final ObserverList<ServiceListener> _listeners =
      ObserverList<ServiceListener>();

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Service._internal() {
    methodChannel = const MethodChannel('$packageName/service');
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'event':
          final data = call.arguments as String? ?? '';
          final result = ActionResult.fromJson(json.decode(data));
          for (final listener in _listeners) {
            listener.onServiceEvent(CoreEvent.fromJson(result.data));
          }
          break;
        case 'crash':
          final message = call.arguments as String? ?? '';
          for (final listener in _listeners) {
            listener.onServiceCrash(message);
          }
          break;
        default:
          throw MissingPluginException();
      }
    });
  }

  Future<T?> _invokeChannel<T>(Future<T?> Function() invoke) async {
    try {
      return await invoke();
    } on MissingPluginException catch (e) {
      commonPrint.log(
        'service channel not available: ${e.message}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  Future<ActionResult?> invokeAction(Action action) async {
    final data = await _invokeChannel<String>(
      () => methodChannel.invokeMethod<String>(
        'invokeAction',
        json.encode(action),
      ),
    );
    if (data == null) {
      return null;
    }
    final dataJson = await data.commonToJSON<dynamic>();
    return ActionResult.fromJson(dataJson);
  }

  Future<bool> start() async {
    return await _invokeChannel<bool>(
          () => methodChannel.invokeMethod<bool>('start'),
        ) ??
        false;
  }

  Future<bool> stop() async {
    return await _invokeChannel<bool>(
          () => methodChannel.invokeMethod<bool>('stop'),
        ) ??
        false;
  }

  Future<String> init() async {
    return await _invokeChannel<String>(
          () => methodChannel.invokeMethod<String>('init'),
        ) ??
        '';
  }

  Future<String> syncState(SharedState state) async {
    return await _invokeChannel<String>(
          () => methodChannel.invokeMethod<String>(
            'syncState',
            json.encode(state),
          ),
        ) ??
        '';
  }

  Future<bool> shutdown() async {
    return await _invokeChannel<bool>(
          () => methodChannel.invokeMethod<bool>('shutdown'),
        ) ??
        true;
  }

  Future<DateTime?> getRunTime() async {
    final ms = await _invokeChannel<int>(
          () => methodChannel.invokeMethod<int>('getRunTime'),
        ) ??
        0;
    if (ms == 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get hasListeners {
    return _listeners.isNotEmpty;
  }

  void addListener(ServiceListener listener) {
    _listeners.add(listener);
  }

  void removeListener(ServiceListener listener) {
    _listeners.remove(listener);
  }
}

Service? get service => system.isMobile ? Service() : null;
