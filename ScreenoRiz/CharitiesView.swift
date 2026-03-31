//
//  CharitiesView.swift
//  ScreenoRiz
//
//  Created by Yevhen on 28.02.2026.
//

import SwiftUI

struct CharitiesView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text("фонди")
                        .font(.ktfTitleLarge)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    // Invisible button for balance
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 30)
                
                // Charities list
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Charity.all) { charity in
                            CharityCard(charity: charity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct CharityCard: View {
    let charity: Charity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(charity.name)
                .font(.ktfTitle)
                .foregroundStyle(.white)
            
            Text(charity.description)
                .font(.ktfBody)
                .foregroundStyle(.white.opacity(0.7))
            
            if let url = URL(string: charity.url) {
                Link(destination: url) {
                    HStack {
                        Text("відвідати сайт")
                            .font(.ktfBody)
                            .foregroundStyle(Color(hex: "F55426"))
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "F55426"))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.1))
        )
    }
}

#Preview {
    CharitiesView()
}
