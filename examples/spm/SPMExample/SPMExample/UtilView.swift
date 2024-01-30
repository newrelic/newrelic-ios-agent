//
//  UtilView.swift
//  testApp (iOS)
//
//  Created by Anna Huller on 6/14/22.
//

import SwiftUI
import NewRelic

struct UtilityView: View {

    @StateObject var viewModel: ViewModel

    var body: some View {
        VStack {
            HStack {
                var label = "Breadcrumbs:" + String(viewModel.numBreadcrumbs)
                Text(label)
                VStack {
                    Button("Add Valid Breadcrumb") {
                        viewModel.makeEvent()
                        viewModel.makeBreadcrumb(name: "test", attributes: ["button" : "Breadcrumb"])
                        label = "Breadcrumbs:" + String(viewModel.numBreadcrumbs)
                    }

                    Button("Add Invalid Breadcrumb") {
                        viewModel.makeEvent()
                        viewModel.makeBreadcrumb(name: "", attributes: ["button" : "Breadcrumb"])
                        label = "Breadcrumbs:" + String(viewModel.numBreadcrumbs)
                    }
                }
            }
            HStack {
                var label = "Attributes: " + viewModel.attributes
                Text(label)
                Button("Set Attributes!") {
                    viewModel.makeEvent()
                    viewModel.setAttributes()
                    label = viewModel.attributes
                }
            }
            
            Button("Crash Now!") {
                viewModel.makeEvent()
                viewModel.crash()
            }
            Button("Make Huge Crash Report!") {
                viewModel.makeEvent()
                viewModel.hugeCrashReport()
            }
            Button("Remove Attributes!") {
                viewModel.makeEvent()
                
                if viewModel.removeAttributes() == true {
                    viewModel.attributes = ""
                    
                }
            }
            Button("Record Error") {
                viewModel.makeError()
                viewModel.makeEvent()
            }

            Group {
                let label = "Button Presses: " + String(viewModel.events)
                Text(label)
                Button("Make 100 events") {
                    viewModel.make100Events()
                }
                Button("START Interaction Trace") {
                    viewModel.startInteractionTrace()
                }
                Button("END Interaction Trace") {
                    viewModel.stopInteractionTrace()

                }
                Button("Send Redirect Request") {
                    viewModel.sendRedirectRequest()
                }
                Button("Notice Network Request") {
                    viewModel.noticeNWRequest()
                }
                Button("Notice Network Failure") {
                    viewModel.noticeFailedNWRequest()
                }

                Button("URLSession dataTask") {
                    viewModel.doDataTask()
                }

                Button("URLSession dataTask w/ completion") {
                    viewModel.doDataTaskWithCompletionHandler()
                }
            }
        }
        .navigationBarTitle(viewModel.title)
        .NRTrackView(name: "UtilityView")
    }
}
