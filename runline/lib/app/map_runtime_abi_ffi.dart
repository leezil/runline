import 'dart:ffi';

/// The running Dart VM's ABI, not the device's list of translatable ABIs.
/// This query does not load or call the Kakao native SDK.
String currentMapAbi() => Abi.current().toString();
