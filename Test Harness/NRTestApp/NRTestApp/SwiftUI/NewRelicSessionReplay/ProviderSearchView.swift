//
//  ProviderSearchView.swift
//  xc
//
//  Created by Jose Fernandes on 2024-09-04.
//

import SwiftUI
struct HealthProvider: Identifiable {
   let id = UUID()
   let name: String
   let companyName: String
   let phoneNumber: String
   let address: String
}

struct ViewModel {
     func  search(matching searchString: String) -> [HealthProvider] {
        // Dummy data - replace with your actual service call and response handling
        if searchString == "1234" {
            return [
                HealthProvider(name: "Provider A", companyName: "Company A", phoneNumber: "1234567890", address: "123 Street, City, Country"),
                HealthProvider(name: "Provider B", companyName: "Company B", phoneNumber: "0987654321", address: "456 Avenue, City, Country")
            ]
        } else {
            return []
        }
    }
}

struct ProviderSearchView: View {
        @State private var viewModel = ViewModel()
        @Binding var selectedProvider: String
        @State private var phoneNumber: String = ""
        @State private var postalCode: String = ""
        @State private var providerSearchString: String = ""
        @State private var providers: [HealthProvider] = []
        @State private var previousProviders: [HealthProvider] = [
             HealthProvider(name: "Provider A", companyName: "Company A", phoneNumber: "1234567890", address: "123 Street, City, Country"),
             HealthProvider(name: "Provider B", companyName: "Company B", phoneNumber: "0987654321", address: "456 Avenue, City, Country")
        ]
       @State private var searchCompleted: Bool = false
    
       var body: some View {
           NavigationView{
               VStack {
                   List{
                       if providers.isEmpty {
                           Section{
                               VStack {
                                   Text("No provider found.")
                                       .font(.headline)
                                       .padding(.top)
                                   Button(action: submitClaimAsProviderNotListed) {
                                       HStack {
                                           Text("Submit Claim as ").foregroundColor(.gray)
                                           Text("Provider Not Listed").foregroundColor(.blue)
                                       }.frame(maxWidth: .infinity)
                                   }
                               }
                           }.listRowBackground(EmptyView())
                       } else {
                           Section{
                               ForEach(providers) { provider in
                                   VStack(alignment: .leading) {
                                       Text(provider.name).font(.headline)
                                       Text(provider.companyName).font(.subheadline)
                                       Text(provider.phoneNumber.formatPhoneNumber()).font(.subheadline)
                                       Text(provider.address).font(.caption)
                                           .foregroundStyle(.gray)
                                   }
                               }
                           } header: {
                               Text("Search results")
                           }
                       }
                       Section{
                           ForEach(previousProviders) { provider in
                               VStack(alignment: .leading) {
                                   Text(provider.name).font(.headline)
                                   Text(provider.companyName).font(.subheadline)
                                   Text(provider.phoneNumber.formatPhoneNumber()).font(.subheadline)
                                   Text(provider.address).font(.caption)
                                       .foregroundStyle(.gray)
                               }
                           }
                       } header: {
                           Text("Previous providers")
                       }
                   }
                   .searchable(text: $providerSearchString)
                   .onSubmit(of: .search) {
                       providers = viewModel.search(matching: providerSearchString)
                   }
                   
               }

               .navigationTitle("Search Providers")
           }
           .navigationViewStyle(.stack)
       }

       func submitClaimAsProviderNotListed() {
           // Implement the submission logic here
           print("Submit claim as 'Provider Not Listed'")
       }

    }
    
    
    
#Preview {
    struct Preview: View {
        @State private var search: String = "Select Provider"
         var body: some View {
             ProviderSearchView(selectedProvider: $search)
         }
     }

     return Preview()
    
}


extension String {
    func formatPhoneNumber() -> String {
        let cleanNumber = components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        let mask = "(XXX) XXX-XXXX"
        
        var result = ""
        var startIndex = cleanNumber.startIndex
        var endIndex = cleanNumber.endIndex
        
        for char in mask where startIndex < endIndex {
            if char == "X" {
                result.append(cleanNumber[startIndex])
                startIndex = cleanNumber.index(after: startIndex)
            } else {
                result.append(char)
            }
        }
        
        return result
    }
}
