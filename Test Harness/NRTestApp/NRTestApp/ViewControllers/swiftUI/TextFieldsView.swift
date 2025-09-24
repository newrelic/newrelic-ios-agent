//
//  TextFieldsView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/12/25.
//

import SwiftUI
import NewRelic

@available(iOS 14.0, *)
struct TextFieldsView: View {
    @State private var singleLineText: String = ""
    @State private var multiLineText: String = ""
    @State private var secureText: String = ""
    @State private var isValid: Bool = true

    var body: some View {
        Form {
            Section(header: Text("Single Line Text Field")) {
                TextField("Enter single line text", text: $singleLineText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Section(header: Text("Multi-Line Text Field")) {
                TextEditor(text: $multiLineText)
                    .frame(height: 100)
                    .border(Color.gray, width: 1)
                    .padding()
            }

            Section(header: Text("Secure Text Field")) {
                SecureField("Enter secure text", text: $secureText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Section {
                Button("Validate Input") {
                    isValid = !singleLineText.isEmpty && !secureText.isEmpty
                }
                .alert(isPresented: Binding<Bool>(
                    get: { !isValid },
                    set: { _ in isValid = true }
                )) {
                    Alert(title: Text("Validation Error"), message: Text("Please fill in all fields."), dismissButton: .default(Text("OK")))
                }
            }
        }
        .navigationBarTitle("Text Fields")
        .NRTrackView(name: "TextFieldsView")
    }
}

@available(iOS 14.0, *)
struct TextFieldsView_Previews: PreviewProvider {
    static var previews: some View {
        TextFieldsView()
    }
}
