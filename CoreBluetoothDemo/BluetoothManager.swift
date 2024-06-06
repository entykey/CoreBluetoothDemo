//
//  BluetoothManager.swift
//  CoreBluetoothDemo
//
//  Created by Tuan on 6/4/24.
//

import Foundation
import CoreBluetooth
import Combine



class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var isScanning = false
    @Published var logMessages: [String] = [] // Store log messages
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    
    var connectedDevice: BluetoothDevice? // Track connected device (serving the TerminalView)
    var connectedPeripheral: CBPeripheral?
    

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
    
    func startScanning() {
        discoveredDevices.removeAll()
        clearLog()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
        print("Started scanning for peripherals...")
    }

    func stopScanning() {
        centralManager.stopScan()
        discoveredDevices.removeAll()
        isScanning = false
        print("Stopped scanning for peripherals.")
    }

    func connectToDevice(device: BluetoothDevice) {
        guard let peripheral = device.peripheral else {
//            handleError("Peripheral is nil for device \(device.name)")
            print("Peripheral is nil for device \(device.name)")
            addLog("Peripheral is nil for device \(device.name)")
            return
        }
        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        print("Connecting to \(device.name)...")
        addLog("Peripheral is nil for device \(device.name)")
    }


    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off.")
        case .resetting:
            print("Bluetooth is resetting.")
        case .unauthorized:
            print("Bluetooth is not authorized.")
        case .unsupported:
            print("Bluetooth is not supported on this device.")
        case .unknown:
            print("Bluetooth state is unknown.")
        @unknown default:
            print("A new state was added that is not handled.")
        }
    }

    
    // bug: does not update UI of the device connection (paired) status
//    func disconnect() {
//        guard let peripheral = connectedDevice?.peripheral else {
//            print("No connected device to disconnect.")
//            return
//        }
//
//        centralManager.cancelPeripheralConnection(peripheral)
//        print("Disconnected from \(connectedDevice?.name ?? "Unknown device").")
//        connectedDevice = nil
//    }
    
    func disconnect() {
        guard let peripheral = connectedDevice?.peripheral else {
            print("No connected device to disconnect.")
            addLog("No connected device to disconnect.")
            return
        }

        centralManager.cancelPeripheralConnection(peripheral)
    
        // update UI connection status
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral == peripheral }) {
            discoveredDevices[index].isConnected = false
        }
        print("Disconnected from \(connectedDevice?.name ?? "Unknown device").")
        connectedDevice = nil
    }

    // MARK: - CBCentralManagerDelegate

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown"
        var bluetoothVersion = "Unknown"

        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if manufacturerData.count >= 2 {
                let manufacturerIdentifier = manufacturerData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) }
                if manufacturerIdentifier == 0x004C { // Apple's manufacturer identifier
                    bluetoothVersion = "BLE"
                }
            }
        }

        let device = BluetoothDevice(name: deviceName, uuid: peripheral.identifier.uuidString, rssi: RSSI.intValue, bluetoothVersion: bluetoothVersion, peripheral: peripheral)
        
        if !discoveredDevices.contains(where: { $0.uuid == device.uuid }) {
            // push device to the discoveredDevices array
            discoveredDevices.append(device)
            print("Discovered: \(device.name), UUID: \(device.uuid), RSSI: \(device.rssi), Version: \(device.bluetoothVersion)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let index = discoveredDevices.firstIndex(where: { $0.peripheral == peripheral }) {
            
            // connectedDevice prop serving TerminalView
            connectedDevice = discoveredDevices[index]
            discoveredDevices[index].isConnected = true
        }
        let message = "Connected to \(peripheral.name ?? "Unknown peripheral")"
        let timestamp = getCurrentTimestamp()
        let logMessage = "[\(timestamp)] \(message)"
        print(logMessage)
        addLog(logMessage)
        
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown error"
        
        let message = "Failed to connect to \(peripheral.name ?? "Unknown peripheral"): \(errorMessage)"
        let timestamp = getCurrentTimestamp()
        let logMessage = "[\(timestamp)] \(message)"
        print(logMessage)
        addLog(logMessage)
        showErrorAlert(message: errorMessage)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Disconnected successfully"
        
        let message = "Disconnected from \(peripheral.name ?? "Unknown peripheral"): \(errorMessage)"
        let timestamp = getCurrentTimestamp()
        let logMessage = "[\(timestamp)] \(message)"
        print(logMessage)
        addLog(logMessage)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services for \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("No services found for \(peripheral.name ?? "Unknown peripheral")")
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("No characteristics found for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral")")
            return
        }

        for characteristic in characteristics {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        if let value = characteristic.value {
            let message = String(data: value, encoding: .utf8) ?? "Received data is not UTF-8 encoded"
            let timestamp = getCurrentTimestamp()
            let logMessage = "[\(timestamp)] \(message)"
            print("Received message from \(peripheral.name ?? "Unknown peripheral"): \(logMessage)")
            addLog(logMessage)
        }
    }
    
    // Helper function to get current timestamp with nanoseconds and milliseconds
    private func getCurrentTimestamp() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSSSS"
        return formatter.string(from: now)
    }
    
    // Method to add log messages
//    func addLog(_ message: String) {
//        logMessages.append(message)
//    }
    
    // Add log message to logMessages array
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages.append(message)
        }
    }
    
    private func clearLog() {
        DispatchQueue.main.async {
            self.logMessages.removeAll()
        }
    }
}

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let uuid: String
    let rssi: Int
    let bluetoothVersion: String
    var peripheral: CBPeripheral? // Store the CBPeripheral instance for each device
    var isConnected = false // Track connection status

    init(name: String, uuid: String, rssi: Int, bluetoothVersion: String, peripheral: CBPeripheral?) {
        self.name = name
        self.uuid = uuid
        self.rssi = rssi
        self.bluetoothVersion = bluetoothVersion
        self.peripheral = peripheral
    }
}





// connected, no connection status, no disconnect button
/* logs:
 Started scanning for peripherals...
 Discovered: Tứng hay ho 🦭, UUID: 8DAC7973-F026-A2C7-A4FA-2D1E6FEACBBE, RSSI: -49, Version: Unknown
 Discovered: Unknown, UUID: E281CA54-B32B-2936-B5AF-3935FCC64995, RSSI: -96, Version: Unknown
 Discovered: Unknown, UUID: EC288815-4B46-C0DE-52D1-8D7823E3BD9F, RSSI: -82, Version: Unknown
 Discovered: Unknown, UUID: 329B4CBA-2D81-AFEC-2991-26AE587036D4, RSSI: -66, Version: Unknown
 Discovered: Unknown, UUID: 4159A49E-3C43-6456-0C6B-E391E62B1C91, RSSI: -88, Version: Unknown
 Discovered: Unknown, UUID: 471C12AB-5071-CA56-98B7-2278E47FB801, RSSI: -92, Version: Unknown
 Discovered: Unknown, UUID: E1A71073-20DA-D23B-CC96-6CA5A6FA6533, RSSI: -91, Version: Unknown
 Connecting to Tứng hay ho 🦭...
 Connected to Tứng hay ho 🦭
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Discovered: Unknown, UUID: 3C7474DE-5353-0E90-5253-CDF1F7390A50, RSSI: -100, Version: Unknown
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Discovered: Unknown, UUID: 8EB3868C-0500-FBC0-3AF8-A381DEDC748F, RSSI: -66, Version: Unknown
 Discovered: Unknown, UUID: 2A5D2EBD-7241-A3C7-2669-7A06910AC01B, RSSI: -64, Version: Unknown
 Received message from Tứng hay ho 🦭: Received data is not UTF-8 encoded
 Connecting to Tứng hay ho 🦭...
 Connected to Tứng hay ho 🦭
 */
/*
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var isScanning = false
    var connectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
        print("Started scanning for peripherals...")
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        print("Stopped scanning for peripherals.")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off.")
        case .resetting:
            print("Bluetooth is resetting.")
        case .unauthorized:
            print("Bluetooth is not authorized.")
        case .unsupported:
            print("Bluetooth is not supported on this device.")
        case .unknown:
            print("Bluetooth state is unknown.")
        @unknown default:
            print("A new state was added that is not handled.")
        }
    }

    func connectToDevice(device: BluetoothDevice) {
        guard let peripheral = device.peripheral else {
            print("Peripheral is nil for device \(device.name)")
            return
        }

        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        print("Connecting to \(device.name)...")
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            print("Disconnected from peripheral.")
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var deviceName = peripheral.name ?? "Unknown"
        var bluetoothVersion = "Unknown"

        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if manufacturerData.count >= 2 {
                let manufacturerIdentifier = manufacturerData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) }
                if manufacturerIdentifier == 0x004C { // Apple's manufacturer identifier
                    bluetoothVersion = "BLE"
                }
            }
        }

        let device = BluetoothDevice(name: deviceName, uuid: peripheral.identifier.uuidString, rssi: RSSI.intValue, bluetoothVersion: bluetoothVersion, peripheral: peripheral)

        if !discoveredDevices.contains(where: { $0.uuid == device.uuid }) {
            discoveredDevices.append(device)
            print("Discovered: \(device.name), UUID: \(device.uuid), RSSI: \(device.rssi), Version: \(device.bluetoothVersion)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown peripheral")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown peripheral"): \(error?.localizedDescription ?? "Unknown error")")
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services for \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("No services found for \(peripheral.name ?? "Unknown peripheral")")
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("No characteristics found for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral")")
            return
        }

        for characteristic in characteristics {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        if let value = characteristic.value {
            let message = String(data: value, encoding: .utf8) ?? "Received data is not UTF-8 encoded"
            print("Received message from \(peripheral.name ?? "Unknown peripheral"): \(message)")
        }
    }
}

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let uuid: String
    let rssi: Int
    let bluetoothVersion: String
    var peripheral: CBPeripheral? // Store the CBPeripheral instance for each device

    init(name: String, uuid: String, rssi: Int, bluetoothVersion: String, peripheral: CBPeripheral?) {
        self.name = name
        self.uuid = uuid
        self.rssi = rssi
        self.bluetoothVersion = bluetoothVersion
        self.peripheral = peripheral
    }
}
 */






/*
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var isScanning = false
    var connectedPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        discoveredDevices.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
        print("Started scanning for peripherals...")
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        print("Stopped scanning for peripherals.")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off.")
        case .resetting:
            print("Bluetooth is resetting.")
        case .unauthorized:
            print("Bluetooth is not authorized.")
        case .unsupported:
            print("Bluetooth is not supported on this device.")
        case .unknown:
            print("Bluetooth state is unknown.")
        @unknown default:
            print("A new state was added that is not handled.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var deviceName = peripheral.name ?? "Unknown"
        var bluetoothVersion = "Unknown"

        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if manufacturerData.count >= 2 {
                let manufacturerIdentifier = manufacturerData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) }
                if manufacturerIdentifier == 0x004C { // Apple's manufacturer identifier
                    bluetoothVersion = "BLE"
                }
            }
        }

        let device = BluetoothDevice(name: deviceName, uuid: peripheral.identifier.uuidString, rssi: RSSI.intValue, bluetoothVersion: bluetoothVersion)

        if !discoveredDevices.contains(where: { $0.uuid == device.uuid }) {
            discoveredDevices.append(device)
            print("Discovered: \(device.name), UUID: \(device.uuid), RSSI: \(device.rssi), Version: \(device.bluetoothVersion)")
        }
    }

    // err:
    /*
     Users/user/Documents/IosDev/swift_playground/CoreBluetoothDemo/CoreBluetoothDemo/BluetoothManager.swift:87:43 Value of optional type 'CBPeripheral?' must be unwrapped to a value of type 'CBPeripheral'
     */
//    func connectToDevice(device: BluetoothDevice) {
//        guard let peripheral = discoveredDevices.first(where: { $0.uuid == device.uuid }) else {
//            print("Device not found.")
//            return
//        }
//
//        connectedPeripheral = peripheral.peripheral
//        centralManager.connect(peripheral.peripheral, options: nil)
//        print("Connecting to \(peripheral.name)...")
//    }
    
    func connectToDevice(device: BluetoothDevice) {
        guard let peripheral = device.peripheral else {
            print("Peripheral is nil for device \(device.name)")
            return
        }

        connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
        print("Connecting to \(device.name)...")
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            print("Disconnected from peripheral.")
        }
    }

    // MARK: - CBPeripheralDelegate

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown peripheral")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown peripheral"): \(error?.localizedDescription ?? "Unknown error")")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services for \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("No services found for \(peripheral.name ?? "Unknown peripheral")")
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            print("No characteristics found for service \(service.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral")")
            return
        }

        for characteristic in characteristics {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic \(characteristic.uuid.uuidString) on \(peripheral.name ?? "Unknown peripheral"): \(error.localizedDescription)")
            return
        }

        if let value = characteristic.value {
            let message = String(data: value, encoding: .utf8) ?? "Received data is not UTF-8 encoded"
            print("Received message from \(peripheral.name ?? "Unknown peripheral"): \(message)")
        }
    }
}

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let uuid: String
    let rssi: Int
    let bluetoothVersion: String
    var peripheral: CBPeripheral? // Store the CBPeripheral instance for each device
}
 */





// Devices scanning
/*
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    var centralManager: CBCentralManager!
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var isScanning = false

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
        print("Started scanning for peripherals...")
    }

    func stopScanning() {
        centralManager.stopScan()
        discoveredDevices.removeAll() // Clear the list when stopping the scan
        isScanning = false
        print("Stopped scanning for peripherals.")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            print("Bluetooth is powered off.")
        case .resetting:
            print("Bluetooth is resetting.")
        case .unauthorized:
            print("Bluetooth is not authorized.")
        case .unsupported:
            print("Bluetooth is not supported on this device.")
        case .unknown:
            print("Bluetooth state is unknown.")
        @unknown default:
            print("A new state was added that is not handled.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var deviceName = peripheral.name ?? "Unknown"
        var bluetoothVersion = "Unknown"

        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            // Process manufacturer data if available to guess Bluetooth version
            if manufacturerData.count >= 2 {
                let manufacturerIdentifier = manufacturerData.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) }
                if manufacturerIdentifier == 0x004C { // Apple's manufacturer identifier
                    bluetoothVersion = "BLE"
                }
            }
        }

        let device = BluetoothDevice(name: deviceName, uuid: peripheral.identifier.uuidString, rssi: RSSI.intValue, bluetoothVersion: bluetoothVersion)

        if !discoveredDevices.contains(where: { $0.uuid == device.uuid }) {
            discoveredDevices.append(device)
            print("Discovered: \(device.name), UUID: \(device.uuid), RSSI: \(device.rssi), Version: \(device.bluetoothVersion)")
        }
    }
}

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let uuid: String
    let rssi: Int
    let bluetoothVersion: String
}
 */







// JDY-24M
/*
class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    let deviceName = "JDY-24M"
    let serviceUUID = CBUUID(string: "FFE0")
    let characteristicUUID = CBUUID(string: "FFE1")

    @Published var receivedData: String = "No data received yet"
    @Published var dataList: [(value: String, timestamp: String)] = []
    var t0: Date = Date()

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
            print("Scanning for peripherals with service UUID: \(serviceUUID)")
        } else {
            print("Bluetooth is not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == deviceName {
            centralManager.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
            print("Connecting to \(deviceName)")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(deviceName)")
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics([characteristicUUID], for: service)
                    print("Service found: \(service.uuid)")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == characteristicUUID {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Characteristic found: \(characteristic.uuid)")
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            let decodedValue = String(data: data, encoding: .utf8) ?? "N/A"
            let timestamp = Date()
            let elapsedMilliseconds = timestamp.timeIntervalSince(t0) * 1000
            let timestampString = String(format: "t%.0f: %@.%03d", elapsedMilliseconds, timestamp.description, Int(timestamp.timeIntervalSince1970 * 1000) % 1000)
            let dataEntry = (value: decodedValue, timestamp: timestampString)

            DispatchQueue.main.async {
                self.receivedData = decodedValue
                self.dataList.append(dataEntry)
            }

            print("Received data: \(decodedValue) at \(timestampString)")
        }
    }
}
*/
