import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VpnCapability { available, degraded, unavailable }

class VpnError {
  final String message;
  final bool isFatal;

  const VpnError(this.message, {this.isFatal = false});
}

class VpnCapabilityNotifier extends Notifier<VpnCapability> {
  @override
  VpnCapability build() => VpnCapability.unavailable;

  void setCapability(VpnCapability value) => state = value;
}

class VpnErrorNotifier extends Notifier<VpnError?> {
  @override
  VpnError? build() => null;

  void setError(VpnError? error) => state = error;

  void clearError() => state = null;
}

final vpnCapabilityProvider =
    NotifierProvider<VpnCapabilityNotifier, VpnCapability>(
  VpnCapabilityNotifier.new,
);

final vpnErrorProvider = NotifierProvider<VpnErrorNotifier, VpnError?>(
  VpnErrorNotifier.new,
);
