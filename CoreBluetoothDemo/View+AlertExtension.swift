//
//  View+AlertExtension.swift
//  CoreBluetoothDemo
//
//  Created by Tuan on 6/6/24.
//

//import Foundation
import SwiftUI

extension View {
    func showAlert(title: String, message: String) -> some View {
        return self.alert(isPresented: .constant(true)) {
            Alert(title: Text(title), message: Text(message), dismissButton: .default(Text("OK")))
        }
    }
}
