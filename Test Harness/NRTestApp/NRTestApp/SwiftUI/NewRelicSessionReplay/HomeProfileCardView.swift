//
//  HomeProfileCardView.swift
//  xc
//
//  Created by Jose Fernandes on 2026-02-11.
//

import SwiftUI

struct HomeProfileCardView: View {

    private var name: String
    private var subTitle: String

    init(name: String,subTitle: String ) {
        self.name = name
        self.subTitle = subTitle 
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                MUIToken.Design.pageContainerInverse
                    .frame(height: (geometry.size.height / 2) + MUIToken.Design.sizingXs)
            }            
            cardView
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    var cardView: some  View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(name)
                            .font(.title3)
                            .foregroundColor(MUIToken.Design.pageTextDefault)
                            .bold()
                            .padding(.bottom, 4)
                        Spacer() // Pushes the text to the left
                    }
                    HStack {
                        Text(subTitle)
                            .font(.subheadline)
                            .foregroundColor(MUIToken.Design.pageTextSubtle)
                    }
                }
            }
            .padding([.leading, .trailing, .top], MUIToken.Design.sizingLg)
            .padding(.bottom, MUIToken.Design.spacingBase)
        }
        .background(
            RoundedRectangle(cornerRadius: MUIToken.CornerRadius.sm)
                .fill(MUIToken.Design.pageContainerSurface)
                
        )
        .overlay(
            RoundedRectangle(cornerRadius: MUIToken.CornerRadius.sm)
                .stroke(MUIToken.Design.pageBorderDefault, lineWidth: 1)
        )
        .padding([.top,.leading,.trailing],MUIToken.Design.spacingLg)

    }
}
#Preview {
    HomeProfileCardView(name: "John Doe", subTitle: "")
}
