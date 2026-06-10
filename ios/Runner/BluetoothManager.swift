import CoreBluetooth
import Flutter

@objc public class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @objc public static let shared = BluetoothManager(channel: FlutterMethodChannel())
    
    var centralManager: CBCentralManager!
    var pairedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    var connectedDevices: [String: (CBPeripheral?, CBPeripheral?)] = [:]
    var currentConnectingDeviceName: String? // Save the name of the currently connecting device
    
    var channel: FlutterMethodChannel!
    
    var blueInfoSink:FlutterEventSink!
    var blueSpeechSink:FlutterEventSink!
    
    var leftPeripheral:CBPeripheral?
    var leftUUIDStr:String?
    var rightPeripheral:CBPeripheral?
    var rightUUIDStr:String?
    
    var UARTServiceUUID:CBUUID
    var UARTRXCharacteristicUUID:CBUUID
    var UARTTXCharacteristicUUID:CBUUID
    
    var leftWChar:CBCharacteristic?
    var rightWChar:CBCharacteristic?
    var leftRChar:CBCharacteristic?
    var rightRChar:CBCharacteristic?
    
    var hasStartedSpeech = false

    init(channel: FlutterMethodChannel) {
        UARTServiceUUID          = CBUUID(string: ServiceIdentifiers.uartServiceUUIDString)
        UARTTXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartTXCharacteristicUUIDString)
        UARTRXCharacteristicUUID = CBUUID(string: ServiceIdentifiers.uartRXCharacteristicUUIDString)
        
        super.init()
        self.channel = channel
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan(result: @escaping FlutterResult) {
        guard centralManager.state == .poweredOn else {
            result(FlutterError(code: "BluetoothOff", message: "Bluetooth is not powered on.", details: nil))
            return
        }

        centralManager.scanForPeripherals(withServices: nil, options: nil)
        result("Scanning for devices...")
    }

    func stopScan(result: @escaping FlutterResult) {
        centralManager.stopScan()
        result("Scan stopped")
    }

    func connectToDevice(deviceName: String, result: @escaping FlutterResult) {
        centralManager.stopScan()

        // First try to get from pairedDevices (if scan was done)
        if let peripheralPair = pairedDevices[deviceName] {
            guard let leftPeripheral = peripheralPair.0, let rightPeripheral = peripheralPair.1 else {
                result(FlutterError(code: "PeripheralNotFound", message: "One or both peripherals are not found", details: nil))
                return
            }
            currentConnectingDeviceName = deviceName
            centralManager.connect(leftPeripheral, options: nil)
            centralManager.connect(rightPeripheral, options: nil)
            result("Connecting to \(deviceName)...")
            return
        }

        // If not in pairedDevices, deviceName might be a direct peripheral identifier
        // Try to retrieve by UUID if it's a valid UUID string
        if let uuid = UUID(uuidString: deviceName) {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let peripheral = peripherals.first {
                currentConnectingDeviceName = peripheral.name ?? deviceName
                centralManager.connect(peripheral, options: nil)
                result("Connecting to \(deviceName)...")
                return
            }
        }

        result(FlutterError(code: "DeviceNotFound", message: "Device not found: \(deviceName)", details: nil))
    }

    func connectToPeripherals(leftUUID: String?, rightUUID: String?, result: @escaping FlutterResult) {
        centralManager.stopScan()

        var leftPeripheral: CBPeripheral?
        var rightPeripheral: CBPeripheral?

        if let leftUUIDStr = leftUUID, let leftUUID = UUID(uuidString: leftUUIDStr) {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [leftUUID])
            leftPeripheral = peripherals.first
            if leftPeripheral != nil {
                self.leftPeripheral = leftPeripheral
                self.leftUUIDStr = leftUUIDStr
            }
        }

        if let rightUUIDStr = rightUUID, let rightUUID = UUID(uuidString: rightUUIDStr) {
            let peripherals = centralManager.retrievePeripherals(withIdentifiers: [rightUUID])
            rightPeripheral = peripherals.first
            if rightPeripheral != nil {
                self.rightPeripheral = rightPeripheral
                self.rightUUIDStr = rightUUIDStr
            }
        }

        guard leftPeripheral != nil || rightPeripheral != nil else {
            result(FlutterError(code: "PeripheralNotFound", message: "Could not retrieve peripherals with provided UUIDs", details: nil))
            return
        }

        currentConnectingDeviceName = "FlutterConnected"

        if let left = leftPeripheral {
            centralManager.connect(left, options: nil)
        }
        if let right = rightPeripheral {
            centralManager.connect(right, options: nil)
        }

        result("Connecting to peripherals...")
    }

    func disconnectFromGlasses(result: @escaping FlutterResult) {
        for (_, devices) in connectedDevices {
            if let leftPeripheral = devices.0 {
                centralManager.cancelPeripheralConnection(leftPeripheral)
            }
            if let rightPeripheral = devices.1 {
                centralManager.cancelPeripheralConnection(rightPeripheral)
            }
        }
        connectedDevices.removeAll()
        result("Disconnected all devices.")
    }

    // MARK: - CBCentralManagerDelegate Methods
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name else { return }
        let components = name.components(separatedBy: "_")
        guard components.count > 1, let channelNumber = components[safe: 1] else { return }

        if name.contains("_L_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].0 = peripheral // Left device
        } else if name.contains("_R_") {
            pairedDevices["Pair_\(channelNumber)", default: (nil, nil)].1 = peripheral // Right device
        }

        if let leftPeripheral = pairedDevices["Pair_\(channelNumber)"]?.0, let rightPeripheral = pairedDevices["Pair_\(channelNumber)"]?.1 {
            let deviceInfo: [String: String] = [
                "leftDeviceName": leftPeripheral.name ?? "",
                "rightDeviceName": rightPeripheral.name ?? "",
                "channelNumber": channelNumber
            ]
            channel.invokeMethod("foundPairedGlasses", arguments: deviceInfo)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let deviceName = currentConnectingDeviceName else { return }
        guard let peripheralPair = pairedDevices[deviceName] else { return }

        if connectedDevices[deviceName] == nil {
            connectedDevices[deviceName] = (nil, nil)
        }

        if peripheralPair.0 === peripheral {
            connectedDevices[deviceName]?.0 = peripheral // Left device connected
            
            self.leftPeripheral = peripheral
            self.leftPeripheral?.delegate = self
            self.leftPeripheral?.discoverServices([UARTServiceUUID])
            
            self.leftUUIDStr = peripheral.identifier.uuidString;
            
            print("didConnect----self.leftPeripheral---------\(self.leftPeripheral)--self.leftUUIDStr----\(self.leftUUIDStr)----")
        } else if peripheralPair.1 === peripheral {
            connectedDevices[deviceName]?.1 = peripheral // Right device connected
            
            self.rightPeripheral = peripheral
            self.rightPeripheral?.delegate = self
            self.rightPeripheral?.discoverServices([UARTServiceUUID])
            
            self.rightUUIDStr = peripheral.identifier.uuidString
            
            print("didConnect----self.rightPeripheral---------\(self.rightPeripheral)---self.rightUUIDStr----\(self.rightUUIDStr)-----")
        }

        if let leftPeripheral = connectedDevices[deviceName]?.0, let rightPeripheral = connectedDevices[deviceName]?.1 {
            let connectedInfo: [String: String] = [
                "leftDeviceName": leftPeripheral.name ?? "",
                "rightDeviceName": rightPeripheral.name ?? "",
                "status": "connected"
            ]
            channel.invokeMethod("glassesConnected", arguments: connectedInfo)

            currentConnectingDeviceName = nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?){
        print("didDisconnectPeripheral-----peripheral-----\(peripheral)--")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("peripheral------\(peripheral)-----didDiscoverServices--------")
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid .isEqual(UARTServiceUUID){
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("peripheral------\(peripheral)-----didDiscoverCharacteristicsFor----service----\(service)----")
        guard let characteristics = service.characteristics else { return }

        if service.uuid.isEqual(UARTServiceUUID){
            for characteristic in characteristics {
                if characteristic.uuid.isEqual(UARTRXCharacteristicUUID){
                    if(peripheral.identifier.uuidString == self.leftUUIDStr){
                        self.leftRChar = characteristic
                    }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                        self.rightRChar = characteristic
                    }
                } else if characteristic.uuid.isEqual(UARTTXCharacteristicUUID){
                    if(peripheral.identifier.uuidString == self.leftUUIDStr){
                        self.leftWChar = characteristic
                    }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                        self.rightWChar = characteristic
                    }
                }
            }
            
            if(peripheral.identifier.uuidString == self.leftUUIDStr){
                if(self.leftRChar != nil && self.leftWChar != nil){
                    self.leftPeripheral?.setNotifyValue(true, for: self.leftRChar!)
                  
                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "L")
                }
            }else if(peripheral.identifier.uuidString == self.rightUUIDStr){
                if(self.rightRChar != nil && self.rightWChar != nil){
                    self.rightPeripheral?.setNotifyValue(true, for: self.rightRChar!)
                    self.writeData(writeData: Data([0x4d, 0x01]), lr: "R")
                }
            }
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("subscribe fail: \(error)")
            return
        }
        if characteristic.isNotifying {
            print("subscribe success")
        } else {
            print("subscribe cancel")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
        case .poweredOff:
            print("Bluetooth is powered off.")
        default:
            print("Bluetooth state is unknown or unsupported.")
        }
    }
    
    
    // Completion handlers for write operations (to match Android's withoutResponse: false behavior)
    private var writeCompletionHandlers: [CBUUID: () -> Void] = [:]
    
    func sendData(params:[String:Any], result: @escaping FlutterResult) {
        let flutterData = params["data"] as! FlutterStandardTypedData
        let lr = params["lr"] as? String
        
        // Count how many writes we need to do
        var pendingWrites = 0
        var completedWrites = 0
        var writeError: Error?
        
        let checkCompletion = {
            completedWrites += 1
            if completedWrites >= pendingWrites {
                if let error = writeError {
                    result(FlutterError(code: "WriteError", message: error.localizedDescription, details: nil))
                } else {
                    result(nil)
                }
            }
        }
        
        // If characteristics aren't discovered yet, trigger service discovery
        if self.leftWChar == nil && self.leftPeripheral != nil {
            print("writeData: leftWChar is nil, triggering service discovery")
            self.leftPeripheral?.discoverServices([UARTServiceUUID])
        }
        if self.rightWChar == nil && self.rightPeripheral != nil {
            print("writeData: rightWChar is nil, triggering service discovery")
            self.rightPeripheral?.discoverServices([UARTServiceUUID])
        }

        if lr == "L" {
            if self.leftWChar != nil {
                pendingWrites = 1
                writeCompletionHandlers[self.leftWChar!.uuid] = checkCompletion
                self.leftPeripheral?.writeValue(writeData, for: self.leftWChar!, type: .withResponse)
            } else {
                print("writeData: leftWChar still nil after discovery attempt")
                result(FlutterError(code: "NotConnected", message: "Left glass not connected", details: nil))
            }
            return
        }
        if lr == "R" {
            if self.rightWChar != nil {
                pendingWrites = 1
                writeCompletionHandlers[self.rightWChar!.uuid] = checkCompletion
                self.rightPeripheral?.writeValue(writeData, for: self.rightWChar!, type: .withResponse)
            } else {
                print("writeData: rightWChar still nil after discovery attempt")
                result(FlutterError(code: "NotConnected", message: "Right glass not connected", details: nil))
            }
            return
        }
        
        // Write to both glasses
        if self.leftWChar != nil {
            pendingWrites += 1
        }
        if self.rightWChar != nil {
            pendingWrites += 1
        }
        
        if pendingWrites == 0 {
            result(FlutterError(code: "NotConnected", message: "No glasses connected", details: nil))
            return
        }
        
        if let leftWChar = self.leftWChar {
            writeCompletionHandlers[leftWChar.uuid] = checkCompletion
            self.leftPeripheral?.writeValue(writeData, for: leftWChar, type: .withResponse)
        } else {
            print("writeData: leftWChar is nil, cannot write data to left peripheral.")
        }

        if let rightWChar = self.rightWChar {
            writeCompletionHandlers[rightWChar.uuid] = checkCompletion
            self.rightPeripheral?.writeValue(writeData, for: rightWChar, type: .withResponse)
        } else {
            print("writeData: rightWChar is nil, cannot write data to right peripheral.")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Call completion handler if one exists for this characteristic
        if let completion = writeCompletionHandlers[characteristic.uuid] {
            completion()
            writeCompletionHandlers.removeValue(forKey: characteristic.uuid)
        }
        
        guard error == nil else {
            print("didWriteValueFor----characteristic---\(characteristic)---- \(error!)")
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("didWriteValueFor----------- \(error!)")
            return
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //print("didUpdateValueFor--------peripheral-----\(peripheral.identifier.uuidString)--characteristic.value----\(characteristic.value)--")
        let data = characteristic.value
        self.getCommandValue(data: data!,cbPeripheral: peripheral)
    }
    
    func getCommandValue(data:Data,cbPeripheral:CBPeripheral? = nil){
        let rspCommand = AG_BLE_REQ(rawValue: (data[0]))
        switch rspCommand{
            case .BLE_REQ_TRANSFER_MIC_DATA:
                 let hexString = data.map { String(format: "%02hhx", $0) }.joined()
                 let effectiveData = data.subdata(in: 2..<data.count)
                 let pcmConverter = PcmConverter()
                 var pcmData = pcmConverter.decode(effectiveData)
               
                 let inputData = pcmData as Data
                 SpeechStreamRecognizer.shared.appendPCMData(inputData)
            
                 break
            default:
                let isLeft = cbPeripheral?.identifier.uuidString == self.leftUUIDStr
                let legStr = isLeft ? "L" : "R"
                var dictionary = [String: Any]()
                dictionary["type"] = "type" // todo
                dictionary["lr"] = legStr
                dictionary["data"] = data

                // Safely call the event sink if it's set
                if let sink = self.blueInfoSink {
                    sink(dictionary)
                } else {
                    print("blueInfoSink is nil, cannot forward data to Flutter")
                }
                break
        }
    }
}

// Extension for safe array indexing
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
