//
//  DashBoardView.swift
//  Dialer
//
//  Created by Cédric Bahirwe on 04/04/2021.
//

import SwiftUI

struct DashBoardView: View {
    @EnvironmentObject private var data: MainViewModel
    
    @AppStorage(UserDefaults.Keys.showWelcomeView)
    private var showWelcomeView: Bool = true
    
    @AppStorage(UserDefaults.Keys.allowBiometrics)
    private var allowBiometrics = false
    
    @State private var presentQuickDial = false
    @State private var presentTransferView = false
    @State private var showPurchaseSheet = false
        
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                VStack(spacing: 29) {
                    HStack(spacing: 20) {
                        DashItemView(
                            title: "Buy airtime",
                            icon: "wallet.pass")
                        .onTapGesture {
                            withAnimation {
                                showPurchaseSheet = true
                                Tracker.shared.logEvent(.airtimeOpened)
                            }
                        }
                        
                        DashItemView(
                            title: "Transfer/Pay",
                            icon: "paperplane.circle")
                        .onTapForBiometrics {
                            presentTransferView = $0
                            Tracker.shared.logEvent(.transferOpened)
                        }
                    }
                    
                    HStack(spacing: 15) {
                        DashItemView(
                            title: "History",
                            icon: "clock.arrow.circlepath")
                        .onTapGesture {
                            data.showHistorySheet.toggle()
                            Tracker.shared.logEvent(.historyOpened)
                        }
                        
                        NavigationLink {
                            MySpaceView()
                        } label: {
                            DashItemView(
                                title: "My Space",
                                icon: "person.crop.circle.badge")
                            .onAppear() {
                                Tracker.shared.logEvent(.mySpaceOpened)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                    }
                }
                .padding()
                
                NavigationLink(isActive: $presentTransferView) {
                    TransferView()
                } label: { EmptyView() }
                
                Spacer()
                
                bottomBarView
            }
            .blur(radius: showPurchaseSheet ? 3 : 0)
            .allowsHitTesting(!showPurchaseSheet)
            
            if showPurchaseSheet {
                Color.black.opacity(0.001)
                    .onTapGesture {
                        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.8)) {
                            showPurchaseSheet = false
                        }
                    }
            }
            PurchaseDetailView(isPresented: $showPurchaseSheet, data: data)
            
        }
        .sheet(isPresented: showWelcomeView ? $showWelcomeView : data.settingsAndHistorySheetBinding()) {
            if showWelcomeView {
                WhatsNewView(isPresented: $showWelcomeView)
            } else {
                if data.showSettingsSheet {
                    SettingsView()
                        .environmentObject(data)
                } else {
                    DialingsHistoryView(data: data)
                }
            }
        }
        .fullScreenCover(isPresented: $presentQuickDial) {
            QuickDialingView()
        }
        .background(Color.primaryBackground)
        .navigationTitle("Dialer")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if allowBiometrics {
                    gearGradient
                        .onTapForBiometrics {
                            if $0 {
                                data.showSettingsView()
                            }
                        }
                } else {
                    Button(action: data.showSettingsView) { gearGradient }
                }
            }
        }
        .trackAppearance(.dashboard)
    }
    
    private var gearGradient: some View {
        LinearGradient(gradient: Gradient(colors: [.red, .blue]), startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: 30, height: 30)
            .mask(
                Image(systemName: "gear")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            )
    }
    
}

extension DashBoardView {
    var bottomBarView: some View {
        HStack {
            if UIApplication.hasSupportForUSSD {
                Button {
                    presentQuickDial.toggle()
                } label: {
                    Label("Quick Dial", systemImage: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.mainRed)
            }
            
            Spacer(minLength: 5)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#if DEBUG
struct DashBoardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DashBoardView()
                .environmentObject(MainViewModel())
        }
    }
}
#endif
