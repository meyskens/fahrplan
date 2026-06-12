import Foundation

/// Stub left in place so any existing references to BluetoothManager.shared
/// continue to compile. BLE on iOS is now fully owned by flutter_blue_plus,
/// which already has CoreBluetooth state restoration enabled from main.dart.
@objc public class BluetoothManager: NSObject {
    @objc public static let shared = BluetoothManager()
}
