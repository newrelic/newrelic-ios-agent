//
//  CustomToggleStyle.swift
//  NRTestApp
//
//  Custom SwiftUI Toggle Style
//

import SwiftUI

struct CustomToggleStyle: ToggleStyle {
    var onColor: Color = .green
    var offColor: Color = .gray
    var thumbColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .fill(thumbColor)
                        .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0.75, y: 2)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

struct PillToggleStyle: ToggleStyle {
    var onColor: Color = Color(red: 144/255, green: 202/255, blue: 119/255)
    var offColor: Color = .gray
    var thumbColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? onColor : offColor)
                    .frame(width: 51, height: 31)

                // Pill-shaped thumb (wider than tall)
                Capsule()
                    .fill(thumbColor)
                    .frame(width: 27 * 1.5, height: 27) // 1.5x wider
                    .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0.75, y: 2)
                    .padding(2)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

struct SquareToggleStyle: ToggleStyle {
    var onColor: Color = .blue
    var offColor: Color = Color(.systemGray3)
    var thumbColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            RoundedRectangle(cornerRadius: 4)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: 51, height: 31)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(thumbColor)
                        .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0.75, y: 2)
                        .padding(2)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

struct ColorfulToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: configuration.isOn ? [.purple, .pink] : [Color(.systemGray4), Color(.systemGray5)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .fill(configuration.isOn ? .yellow : .white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 1, y: 2)
                        .padding(3)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}
