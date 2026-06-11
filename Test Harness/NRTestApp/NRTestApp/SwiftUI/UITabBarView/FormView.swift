import SwiftUI
import NewRelic

struct FormView: View {
    @Binding var badgeCount: Int?
    @StateObject private var viewModel = FormViewModel()
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Full Name", text: $viewModel.fullName)
                        .onChange(of: viewModel.fullName) { newValue in
                            NewRelic.recordBreadcrumb("FullName field changed", attributes: ["length": newValue.count])
                        }

                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField("Phone", text: $viewModel.phone)
                        .keyboardType(.phonePad)
                }

                Section(header: Text("Date Selection")) {
                    DatePicker("Birth Date",
                             selection: $viewModel.birthDate,
                             displayedComponents: .date)
                        .datePickerStyle(.compact)

                    DatePicker("Appointment Date & Time",
                             selection: $viewModel.appointmentDate,
                             in: Date()...,
                             displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: viewModel.appointmentDate) { newValue in
                            NewRelic.recordCustomEvent("AppointmentDateSelected",
                                                      attributes: [
                                                        "date": newValue.timeIntervalSince1970,
                                                        "daysFromNow": Calendar.current.dateComponents([.day], from: Date(), to: newValue).day ?? 0
                                                      ])
                        }
                }

                Section(header: Text("Preferences")) {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(Category.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }

                    Picker("Priority", selection: $viewModel.priority) {
                        Text("Low").tag(1)
                        Text("Medium").tag(2)
                        Text("High").tag(3)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Enable Notifications", isOn: $viewModel.notificationsEnabled)

                    Toggle("Agree to Terms", isOn: $viewModel.agreedToTerms)
                }

                Section(header: Text("Additional Information")) {
                    TextEditor(text: $viewModel.notes)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )

                    Stepper("Quantity: \(viewModel.quantity)", value: $viewModel.quantity, in: 1...100)
                }

                Section {
                    Button {
                        submitForm()
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Submit Form")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isSubmitting || !viewModel.isFormValid)
                    .foregroundColor(.white)
                    .listRowBackground(viewModel.isFormValid ? Color.blue : Color.gray)
                }
            }
            .navigationTitle("Form Entry")
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    viewModel.resetForm()
                }
            } message: {
                Text("Form submitted successfully!")
            }
            .onAppear {
                NewRelic.recordBreadcrumb("FormView appeared")
            }
        }
    }

    private func submitForm() {
        let interactionId = NewRelic.startInteraction(withName: "FormSubmission")

        viewModel.isSubmitting = true

        NewRelic.recordCustomEvent("FormSubmitAttempt",
                                  attributes: [
                                    "category": viewModel.selectedCategory.rawValue,
                                    "priority": viewModel.priority,
                                    "notificationsEnabled": viewModel.notificationsEnabled,
                                    "hasNotes": !viewModel.notes.isEmpty
                                  ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            viewModel.isSubmitting = false

            if Bool.random() {
                showSuccessAlert = true
                // Clear the badge when form is successfully submitted
                badgeCount = nil
                NewRelic.recordCustomEvent("FormSubmitSuccess",
                                          attributes: ["formCompletionTime": "2.0"])
            } else {
                NewRelic.recordCustomEvent("FormSubmitError",
                                          attributes: [
                                            "errorType": "ValidationError",
                                            "errorMessage": "Simulated error"
                                          ])
                NewRelic.recordError(NSError(domain: "FormSubmission",
                                           code: 400,
                                           userInfo: [NSLocalizedDescriptionKey: "Form validation failed"]))
            }

            NewRelic.stopCurrentInteraction(interactionId)
        }
    }
}

enum Category: String, CaseIterable, Identifiable {
    case business = "Business"
    case personal = "Personal"
    case education = "Education"
    case healthcare = "Healthcare"
    case finance = "Finance"

    var id: String { rawValue }
}

class FormViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var phone = ""
    @Published var birthDate = Date()
    @Published var appointmentDate = Date()
    @Published var selectedCategory: Category = .personal
    @Published var priority = 2
    @Published var notificationsEnabled = true
    @Published var agreedToTerms = false
    @Published var notes = ""
    @Published var quantity = 1
    @Published var isSubmitting = false

    var isFormValid: Bool {
        !fullName.isEmpty && !email.isEmpty && agreedToTerms
    }

    func resetForm() {
        fullName = ""
        email = ""
        phone = ""
        birthDate = Date()
        appointmentDate = Date()
        selectedCategory = .personal
        priority = 2
        notificationsEnabled = true
        agreedToTerms = false
        notes = ""
        quantity = 1

        NewRelic.recordCustomEvent("FormReset")
    }
}

#Preview {
    FormView(badgeCount: .constant(3))
}
