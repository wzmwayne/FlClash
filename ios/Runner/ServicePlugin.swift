import Darwin
import Flutter
import Foundation

class ServicePlugin: NSObject, FlutterPlugin {
  private static var channel: FlutterMethodChannel?
  private static var bridgeInstalled = false

  private static var callbacks: [UInt: (String) -> Void] = [:]
  private static var nextKey: UInt = 1
  private static let eventKey: UInt = UInt.max
  private static var callbackLock = NSLock()

  private static var storedSetupParams = "{\"selected-map\":{},\"test-url\":\"\"}"
  private static var startedAt: Int64 = 0

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.follow.clash/service",
      binaryMessenger: registrar.messenger()
    )
    ServicePlugin.channel = channel
    let instance = ServicePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init": ServicePlugin.handleInit(result)
    case "shutdown": ServicePlugin.handleShutdown(result)
    case "invokeAction": ServicePlugin.handleInvokeAction(call, result)
    case "getRunTime": ServicePlugin.handleGetRunTime(result)
    case "syncState": ServicePlugin.handleSyncState(call, result)
    case "start": ServicePlugin.handleStart(result)
    case "stop": ServicePlugin.handleStop(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Handlers

  private static func handleInit(_ result: @escaping FlutterResult) {
    installBridge()
    callbackLock.lock()
    callbacks[eventKey] = { jsonString in
      DispatchQueue.main.async {
        channel?.invokeMethod("event", arguments: jsonString)
      }
    }
    callbackLock.unlock()
    setEventListener(UnsafeMutableRawPointer(bitPattern: eventKey))
    result("")
  }

  private static func handleShutdown(_ result: @escaping FlutterResult) {
    stopTun()
    suspend(1)
    result(true)
  }

  private static func handleInvokeAction(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let json = call.arguments as? String else {
      result("")
      return
    }
    guard let callback = registerCallback({ string in
      DispatchQueue.main.async {
        result(string)
      }
    }) else {
      result("")
      return
    }
    invokeAction(callback, strdup(json))
  }

  private static func handleGetRunTime(_ result: @escaping FlutterResult) {
    result(Int(startedAt))
  }

  private static func handleSyncState(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let json = call.arguments as? String
    if let json = json, !json.isEmpty {
      if let data = json.data(using: .utf8),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let setup = object["setupParams"] as? [String: Any] {
        if let map = setup["selectedMap"] as? [String: String] {
          storedSetupParams = makeSetupParamsJson(map)
        }
      }
    }
    result("")
  }

  private static func handleStart(_ result: @escaping FlutterResult) {
    guard let homeDir = homeDirPath() else {
      result(false)
      return
    }
    let version = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    let initParams = "{\"home-dir\":\(jsonEscape(homeDir)),\"version\":\(version)}"
    guard let callback = registerCallback({ string in
      let ok = string.isEmpty
      if ok {
        startedAt = Int64(Date().timeIntervalSince1970 * 1000)
        startTUN(nil, 0, strdup(""), strdup(""), strdup(""))
      }
      DispatchQueue.main.async {
        result(ok)
      }
    }) else {
      result(false)
      return
    }
    quickSetup(callback, strdup(initParams), strdup(storedSetupParams))
  }

  private static func handleStop(_ result: @escaping FlutterResult) {
    stopTun()
    result(true)
  }

  // MARK: - Bridge

  private static func installBridge() {
    guard !bridgeInstalled else { return }
    bridgeInstalled = true

    result_func = { callback, data in
      var string = ""
      if let data = data {
        string = String(cString: data)
      }
      deliverCallback(callback, string)
    }
    release_object_func = { callback in
      removeCallback(callback)
    }
    free_string_func = { pointer in
      if let pointer = pointer {
        free(pointer)
      }
    }
    protect_func = { _, _ in }
    resolve_process_func = { _, _, _, _, _ in nil }
  }

  private static func registerCallback(_ callback: @escaping (String) -> Void) -> UnsafeMutableRawPointer? {
    callbackLock.lock()
    defer { callbackLock.unlock() }
    let key = nextKey
    nextKey += 1
    callbacks[key] = callback
    return UnsafeMutableRawPointer(bitPattern: key)
  }

  private static func deliverCallback(_ callback: UnsafeMutableRawPointer?, _ string: String) {
    guard let callback = callback else { return }
    let key = UInt(bitPattern: callback)
    callbackLock.lock()
    let callbackClosure = callbacks[key]
    callbackLock.unlock()
    callbackClosure?(string)
  }

  private static func removeCallback(_ callback: UnsafeMutableRawPointer?) {
    guard let callback = callback else { return }
    let key = UInt(bitPattern: callback)
    callbackLock.lock()
    callbacks.removeValue(forKey: key)
    callbackLock.unlock()
  }

  // MARK: - Helpers

  private static func homeDirPath() -> String? {
    guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.path
  }

  private static func makeSetupParamsJson(_ selectedMap: [String: String]) -> String {
    var entries: [String] = []
    for (key, value) in selectedMap {
      entries.append("\(jsonEscape(key)):\(jsonEscape(value))")
    }
    return "{\"selected-map\":{\(entries.joined(separator: ","))},\"test-url\":\"\"}"
  }

  private static func jsonEscape(_ string: String) -> String {
    var out = "\""
    for scalar in string.unicodeScalars {
      switch scalar {
      case "\\": out += "\\\\"
      case "\"": out += "\\\""
      default:
        if scalar.value < 0x20 {
          out += String(format: "\\u%04x", scalar.value)
        } else {
          out.unicodeScalars.append(scalar)
        }
      }
    }
    out += "\""
    return out
  }
}
