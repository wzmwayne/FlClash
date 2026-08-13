import 'package:flutter_riverpod/riverpod.dart';

enum VpnCapability { available, degraded, unavailable }

class VpnError {
  final String message;
  final bool isFatal;

  const VpnError(this.message, {this.isFatal = false});
}

final vpnCapabilityProvider =
    StateProvider<VpnCapability>((ref) => VpnCapability.unavailable);

final vpnErrorProvider = StateProvider<VpnError?>((ref) => null);
