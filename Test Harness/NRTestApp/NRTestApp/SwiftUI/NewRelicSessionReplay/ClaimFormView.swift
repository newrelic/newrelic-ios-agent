

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@available(iOS 16.0, *)
struct ClaimFormView: View {
    @State private var selectedPerson: String = "Select Person"
    @State private var isCompanySwitchOn: Bool = false
    @State private var isGotInsuranceSwitchOn: Bool = false
    @State private var selectedCompany: String = ""
    @State private var selectedHealthProvider: String = "Select Provider"
    @State private var attachedFiles: [URL] = []
   // @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedImage: UIImage?
    @State private var selectedPaymentMethod: PaymentMethod = .healthPlan
    @State private var showConfirmation: Bool = false
    @State private var agreeToTerms: Bool = false
    @State private var showAttachmentSheet: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPhoto: Bool = false
    @State private var showProviders: Bool = false
    @State private var showWhyWeAskingMsg: Bool = false
    @State private var selectedPhotoNames: [String] = []
    @State private var expenses: [Expense] = []
    @State private var showExpenseEntry: Bool = false
    @State private var expenseToEdit: Expense? = nil
    @State private var otherPlan: String = ""
    @State private var otherCert: String = ""

   
    var body: some View {
        NavigationView {
            ZStack (alignment: .topTrailing){
                
                MUIToken.Design.pageContainerInverse.ignoresSafeArea(edges: .top)
                
                ZStack (alignment: .bottomTrailing){
                    VStack{
                        HomeProfileCardView(name: "Mr Guy", subTitle: "something about another thing")
                        Form {
                            Section(header: Text("Who is this for?")) {
                                Picker("Name", selection: $selectedPerson) {
                                    // List of companies
                                    Text("Person A").tag("Person A")
                                    Text("Person B").tag("Person B")
                                }
                            }
                            
                            Section(header: Text("Other Insurance")) {
                                Toggle(isOn: $isGotInsuranceSwitchOn) {
                                    Text("Does this person have other coverage?")
                                    Text("[Why are we asking this?](https://google.com)").font(.caption)
                                    
                                }
                                
                                if isGotInsuranceSwitchOn {
                                    Toggle(isOn:$isCompanySwitchOn) {
                                        Text("Is this claim for an amount the other insurance didn't pay for?")
                                        Button(action: {
                                            showWhyWeAskingMsg = true
                                            
                                        }) {
                                            Text("Why are we asking?")
                                                .font(.caption)
                                        }
                                    }.sheet(isPresented: $showWhyWeAskingMsg) {
                                        Text("Do you have claims with leftover amounts? If you've already submitted a claim to another plan, and you didn't get the full amount back, you can submit the rest of the claim to us.").padding()
                                    }
                                    
                                    if !isCompanySwitchOn && isGotInsuranceSwitchOn {
                                        Picker("Company", selection: $selectedCompany) {
                                            // List of companies
                                            Text("Company A").tag("Company A")
                                            Text("Company B").tag("Company B")
                                        }
                                    }
                                }
                            }
                            if !isCompanySwitchOn && isGotInsuranceSwitchOn && selectedCompany == "Company A" {
                                Section {
                                    TextField("Plan contract number", text: $otherPlan)
                                    TextField("Certificate Number", text: $otherCert)
                                }
                                header: {
                                    Text("Company details")
                                }
                                footer: {
                                    Text("Please do not submit a separate claim for this expense as any unpaid portion will be processed under the secondary policy wih company.  It may take 5-7 business days to process")
                                }
                            }
                            Section(header: Text("Provider")) {
                                
                                Picker("Company", selection: $selectedHealthProvider) {
                                    // List of previous providers
                                    Text("Company A").tag("Company A")
                                    Text("Company B").tag("Company B")
                                    Text("add new").tag("add")
                                }
                                //                    .onChange(of: selectedHealthProvider) { oldValue, newValue in
                                //                        if newValue == "add" {
                                //                            showProviders = true
                                //                        }
                                //                    }
                                
                            }
                            
                            
                            Section(header: Text("Expenses")) {
                                Button("Add Expense") {
                                    expenseToEdit = nil
                                    showExpenseEntry = true
                                }
                                
                                if !expenses.isEmpty {
                                    ForEach(expenses) { expense in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("\(expense.type.rawValue) - $\(expense.amount, specifier: "%.2f")")
                                                Text(expense.date, style: .date)
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                expenseToEdit = expense
                                                showExpenseEntry = true
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            Button(action: {
                                                deleteExpense(expense)
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            
                            // Add Photos and Files Section
                            Section {
                                Button("Add attachment") {
                                    showAttachmentSheet = true
                                }
                                .actionSheet(isPresented: $showAttachmentSheet) {
                                    ActionSheet(
                                        title: Text("Select Attachment"),
                                        buttons: [
                                            .default(Text("Camera")) {
                                                showCamera = true
                                            },
                                            .default(Text("Photo Library")) {
                                                showPhoto = true
                                            },
                                            .default(Text("Files")) {
                                                showFilePicker = true
                                            },
                                            .cancel()
                                        ]
                                    )
                                }
                                
                                //                    // Display attached files or photos
                                //                    if !selectedPhotos.isEmpty {
                                //                        ForEach(selectedPhotoNames, id: \.self) { name in
                                //                            Text(name)
                                //                        }
                                //                    }
                                
                                if !attachedFiles.isEmpty {
                                    ForEach(attachedFiles, id: \.self) { file in
                                        Text(file.lastPathComponent)
                                    }
                                }
                            } header: {
                                Text("Attachments")
                            } footer: {
                                Label("For audit purposes, please keep your documents for 12 months after submitting the claim, regardless if you attach documents or not.", systemImage: "info.circle")
                            }
                            
                            Section(header: Text("Payment Method")) {
                                Picker("Payment Method", selection: $selectedPaymentMethod) {
                                    Text("Health Plan").tag(PaymentMethod.healthPlan)
                                    Text("Spending Account").tag(PaymentMethod.spendingAccount)
                                    Text("Health + Spending Account").tag(PaymentMethod.healthThenSpending)
                                }
                            }
                            
                            Section {
                                Button("Submit") {
                                    showConfirmation = true
                                }
                            }
                        }
                        
                    }
                    ChatView()
                }
                
                .navigationTitle("Accupuncturist").toolbarColorScheme(.dark)
                
                .sheet(isPresented: $showConfirmation) {
                    ConfirmationView()
                }
                .sheet(isPresented: $showFilePicker) {
                    DocumentPickerView(attachedFiles: $attachedFiles)
                }
                .sheet(isPresented: $showCamera) {
                    //    CameraView(selectedImage: $selectedImage)
                }
                .sheet(isPresented: $showProviders){
                    ProviderSearchView(selectedProvider: $selectedHealthProvider)
                }
                //            .photosPicker(isPresented: $showPhoto, selection:$selectedPhotos,matching: .images,photoLibrary: .shared())
                .sheet(isPresented: $showExpenseEntry) {
                    ExpenseEntryView(
                        expenses: $expenses,
                        expenseToEdit: expenseToEdit,
                        onSave: { newExpense in
                            if let expenseToEdit = expenseToEdit {
                                if let index = expenses.firstIndex(where: { $0.id == expenseToEdit.id }) {
                                    expenses[index] = newExpense
                                }
                            } else {
                                expenses.append(newExpense)
                            }
                        }
                    )
                }
            }
                //            .onChange(of: selectedPhotos) { newItems in
                //                loadPhotoNames(from: newItems)
                //            }
          
        }
    }
    
    private func deleteExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses.remove(at: index)
        }
    }
    
//    private func loadPhotoNames(from items: [PhotosPickerItem]) {
//        selectedPhotoNames = []
//        
//        for item in items {
//            item.loadTransferable(type: Data.self) { result in
//                switch result {
//                case .success(let data):
//                    if let data = data, let image = UIImage(data: data) {
//                        selectedPhotoNames.append("Image:\(item.itemIdentifier)")
//                    } else {
//                        selectedPhotoNames.append("Unknown Image")
//                    }
//                case .failure(let error):
//                    print("Error loading photo: \(error)")
//                }
//            }
//        }
//    }
}





#Preview{
    if #available(iOS 16.0, *) {
        ClaimFormView()
    } else {
        // Fallback on earlier versions
    }
}
