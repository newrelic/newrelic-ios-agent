//
//  CameraView.swift
//  xc
//
//  Created by Jose Fernandes on 9/2/24.
//
import SwiftUI
import UniformTypeIdentifiers



struct TextPageView: View {
    var title:String
    var msg:String
    var body: some View {
        Text(msg).navigationTitle(title)
    }
}

//struct CameraView: UIViewControllerRepresentable {
//    
//    @Binding var selectedImage: UIImage?
//    @Environment(\.presentationMode) var isPresented
//    
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let imagePicker = UIImagePickerController()
//        imagePicker.sourceType = .camera
//        imagePicker.allowsEditing = true
//        imagePicker.delegate = context.coordinator
//        return imagePicker
//    }
//    
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
//        
//    }
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(picker: self)
//    }
//}

//// Coordinator will help to preview the selected image in the View.
//class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//    var picker: CameraView
//    
//    init(picker: CameraView) {
//        self.picker = picker
//    }
//    
//    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//        guard let selectedImage = info[.originalImage] as? UIImage else { return }
//        self.picker.selectedImage = selectedImage
//        self.picker.isPresented.wrappedValue.dismiss()
//    }
//}




struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var attachedFiles: [URL]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.attachedFiles.append(contentsOf: urls)
        }
    }
}

