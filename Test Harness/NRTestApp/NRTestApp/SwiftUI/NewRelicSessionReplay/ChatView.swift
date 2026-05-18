//
//  ChatView.swift
//  xc
//
//  Created by Jose Fernandes on 2026-02-11.
//
import SwiftUI

struct ChatView:  View {
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                HStack {
                    Button(action: {
                    }) {
                        HStack{
                            Image(systemName: "message.fill")
                                .foregroundColor(Color.white)
                            Text("Chat").foregroundColor(Color.white).font(Font.subheadline.weight(.bold))
                        }.padding([.bottom,.trailing],16)

                        
                    }
                    
                }
            }
            .frame(height: 25)
            .padding()
            .background(MUIToken.Design.colorDarkNavy
                .clipShape(RoundedRectangle(cornerRadius:16))
                .overlay(RoundedRectangle(cornerRadius:16)
                    .stroke(MUIToken.Design.colorLightGrey, lineWidth: 0.5))
                    .padding([.trailing, .bottom], 16.0)
            )
            
        }
    }
}

#Preview {
    VStack{
        ChatView()
    }
    
}
