//
//  ContentView.swift
//  CoreBluetoothDemo
//
//  Created by Tuan on 6/4/24.
//

import SwiftUI




struct ContentView: View {
    @ObservedObject var bluetoothManager = BluetoothManager()

    var body: some View {
        NavigationView {
            VStack(spacing: 6) { // spacing between elements
                Button(action: {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                    }
                }) {
                    Text(bluetoothManager.isScanning ? "Stop Scanning" : "Start Scanning")
                        .font(.subheadline) // font for button text
                        .padding(10) // padding for button
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8) // corner radius
                }
                .padding(2) // padding around the button

                List(bluetoothManager.discoveredDevices) { device in
                    VStack(alignment: .leading, spacing: 1) { // Reduce vertical spacing
                        Text(device.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("UUID: \(device.uuid)")
                            .font(.caption)
                        Text("RSSI: \(device.rssi) dBm")
                            .font(.caption)
                        Text("Version: \(device.bluetoothVersion)")
                            .font(.caption)
                        HStack {
                            Button(action: {
                                if device.isConnected {
                                    bluetoothManager.disconnect()
                                } else {
                                    bluetoothManager.connectToDevice(device: device)
                                }
                            }) {
                                Text(device.isConnected ? "Disconnect" : "Connect")
                                    .font(.subheadline) // font
                                    .padding(8) // padding
                                    .background(device.isConnected ? Color.red : Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8) // corner radius
                            }
                            .padding(.trailing, 5) // trailing padding
                        }
                    }
                    .padding(.vertical, 1) // Reduced vertical padding
                }
                .navigationBarTitle("Bluetooth Devices")

                VStack(alignment: .leading) {
                    Text("Log Messages:")
                        .font(.headline)
                    List(bluetoothManager.logMessages, id: \.self) { logMessage in
                        Text(logMessage)
                            .font(.caption) // Smaller font for log messages
                    }
                }
                .padding()
            }
        }
        .alert(isPresented: $bluetoothManager.showError) {
            Alert(title: Text("Error"), message: Text(bluetoothManager.errorMessage), dismissButton: .default(Text("OK")))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}





/*
// old working try connect:
// try connect
struct ContentView: View {
    @ObservedObject var bluetoothManager = BluetoothManager()

    var body: some View {
        NavigationView {
            VStack {
                Button(action: {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        bluetoothManager.startScanning()
                    }
                }) {
                    Text(bluetoothManager.isScanning ? "Stop Scanning" : "Start Scanning")
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()

                List(bluetoothManager.discoveredDevices) { device in
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                        Text("UUID: \(device.uuid)")
                            .font(.subheadline)
                        Text("RSSI: \(device.rssi) dBm")
                            .font(.subheadline)
                        Text("Version: \(device.bluetoothVersion)")
                            .font(.subheadline)
                        HStack {
                            Button(action: {
                                if device.isConnected {
                                    bluetoothManager.disconnect()
                                } else {
                                    bluetoothManager.connectToDevice(device: device)
                                }
                            }) {
                                Text(device.isConnected ? "Disconnect" : "Connect")
                                    .font(.headline)
                                    .padding()
                                    .background(device.isConnected ? Color.red : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.trailing, 10)
                            Text(device.isConnected ? "Connected" : "Disconnected")
                                .font(.subheadline)
                                .foregroundColor(device.isConnected ? Color.green : Color.gray)
                        }
                    }
                }
                .navigationTitle("Bluetooth Devices")
                
                // Check if any device is connected to show TerminalView
                if bluetoothManager.connectedDevice != nil {
                    TerminalView(bluetoothManager: bluetoothManager)
                }
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
*/
