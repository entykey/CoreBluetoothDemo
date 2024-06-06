//
//  TerminalView.swift
//  CoreBluetoothDemo
//
//  Created by Tuan on 6/4/24.
//

import SwiftUI

struct TerminalView: View {
    @ObservedObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 10) {
            Text("Terminal")
                .font(.headline)
                .padding(.top, 10)

            ScrollView {
                VStack() {
                    ForEach(bluetoothManager.logMessages, id: \.self) { message in
                        VStack{
                            Text(message)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true) // Allow text to wrap
                                .frame(maxWidth: .infinity, alignment: .leading) // Align text to the leading edge
                                .padding(.horizontal, 10) // Add horizontal padding for better readability
                                .background(Color.white) // Optional: Add a background color to each message
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
//                                        .stroke(Color.gray, lineWidth: 1) // Add a border around each message
                                )
                                .padding(.vertical, 2) // Adjust vertical padding between messages
                        }
                    }
                }
                .padding(5)
            }
            .frame(maxHeight: 150)
            
            Spacer()
        }
        .padding(10)
    }
}

struct TerminalView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalView(bluetoothManager: BluetoothManager())
    }
}
