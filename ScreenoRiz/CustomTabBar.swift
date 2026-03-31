//
//  CustomTabBar.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let onAddTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Main tab container (pill shape)
            HStack(spacing: 0) {
                // Overview tab
                TabButton(
                    icon: "house.fill",
                    title: "огляд",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                // Settings tab
                TabButton(
                    icon: "gearshape.fill",
                    title: "налаштування",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
            }
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
            
            // Add button (circular)
            Button {
                onAddTap()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(
            Color.black.opacity(0.01)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.ktfCaption)
            }
            .foregroundStyle(isSelected ? Color(hex: "F55426") : .white)
            .frame(width: 150, height: 64)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            
            CustomTabBar(
                selectedTab: .constant(0),
                onAddTap: {
                    print("Add tapped")
                }
            )
        }
    }
}
