//
//  SendingView.swift
//  Dialer
//
//  Created by Cédric Bahirwe on 10/06/2021.
//

import SwiftUI

struct TransferView: View {
    @EnvironmentObject private var merchantStore: UserMerchantStore
    @Environment(\.colorScheme) private var colorScheme

    @FocusState private var focusedState: FocusField?
    @State private var showReportSheet = false
    @State private var showCreateMerchantView = false
    @State private var didCopyToClipBoard = false
    @State private var showContactPicker = false
    @State private var allContacts: [Contact] = []
    @State private var selectedContact: Contact = Contact(names: "", phoneNumbers: [])
    @State private var transaction: Transaction = Transaction(amount: "", number: "", type: .merchant)
    
    private var rowBackground: Color {
        Color(.systemBackground).opacity(colorScheme == .dark ? 0.6 : 1)
    }

    private var feeHintView: Text {
        let fee = transaction.estimatedFee
        if fee == -1 {
            return Text("We can not estimate the fee for this amount.")
        } else {
            return Text(String(format: NSLocalizedString("Estimated fee: amount RWF", comment: ""), fee))
        }
    }
    
    private var navigationTitle: String {
        transaction.type == .merchant ? "Pay Merchant" : "Transfer momo"
    }
    
    var body: some View {
        VStack(spacing: 0) {

            VStack(spacing: 15) {

                VStack(spacing: 10) {
                    if transaction.type == .client && !transaction.amount.isEmpty {
                        feeHintView
                            .font(.caption).foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.default, value: transaction.estimatedFee)
                    }

                    NumberField("Enter Amount", text: $transaction.amount.animation())
                        .focused($focusedState, equals: .amount)
                }

                VStack(spacing: 10) {
                    if transaction.type == .client {
                        Text(selectedContact.names).font(.caption).foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.default, value: transaction.type)
                    }
                    NumberField(transaction.type == .client ?
                                "Enter Receiver's number" :
                                    "Enter Merchant Code", text: $transaction.number.onChange(handleNumberField).animation())
                    .focused($focusedState, equals: .number)

                    if transaction.type == .merchant {
                        Text("The code should be a 5-6 digits number")
                            .font(.caption).foregroundColor(.blue)
                    }
                }

                VStack(spacing: 18) {
                    if transaction.type == .client {
                        Button(action: {
                            hideKeyboard()
                            showContactPicker = true
                            Tracker.shared.logEvent(.conctactsOpened)
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("Pick a contact")
                            }
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: .lightShadow, radius: 6, x: -6, y: -6)
                            .shadow(color: .darkShadow, radius: 6, x: 6, y: 6)
                        }                 }

                    HStack {
                        if UIApplication.hasSupportForUSSD {
                            Button(action: transferMoney) {
                                Text("Dial USSD")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.blue.opacity(transaction.isValid ? 1 : 0.3))
                                    .cornerRadius(8)
                                    .foregroundColor(Color.white)
                            }
                            .disabled(transaction.isValid == false)

                            Button(action: copyToClipBoard) {
                                Image(systemName: "doc.on.doc.fill")
                                    .frame(width: 48, height: 48)
                                    .background(Color.blue.opacity(transaction.isValid ? 1 : 0.3))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            .disabled(transaction.isValid == false || didCopyToClipBoard)
                        } else {
                            Button(action: copyToClipBoard) {
                                Label("Copy USSD code", systemImage: "doc.on.doc.fill")
                                    .foregroundColor(.white)
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(Color.blue.opacity(transaction.isValid ? 1 : 0.3))
                                    .cornerRadius(8)
                                    .foregroundColor(Color.white)
                            }
                            .disabled(transaction.isValid == false || didCopyToClipBoard)
                        }
                    }
                }
                .padding(.top)

                if didCopyToClipBoard {
                    CopiedUSSDLabel()
                }
            }
            .padding()

            if transaction.type == .merchant {
                List {
                    Section {
                        if merchantStore.merchants.isEmpty {
                            Text("No Merchants Saved Yet.")
                                .opacity(0.5)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 50)
                            
                         } else {
                            ForEach(merchantStore.merchants) { merchant in
                                HStack {
                                    HStack(spacing: 4) {
                                        if merchant.code == transaction.number {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                                .font(.body.weight(.semibold))
                                        }
                                        
                                        Text(merchant.name)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("#\(merchant.code)")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        transaction.number = merchant.code
                                    }
                                    Tracker.shared.logMerchantSelection(merchant)
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                            }
                            .onDelete(perform: deleteMerchant)
                        }
                    } header: {
                        HStack {
                            Text("Saved Merchants")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            Spacer(minLength: 1)
                            
                            Button {
                                showCreateMerchantView.toggle()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .imageScale(.large)
                            }

                        }
                    } footer: {
                        if !merchantStore.merchants.isEmpty {
                            Text("Please make sure the merchant code is correct before dialing.\nNeed Help? Go to ***Settings > Contact Us***")
                        }
                    }
                    .listRowBackground(rowBackground)
                }
                .hideListBackground()
            } else {
                Spacer()
            }
        }
        .sheet(isPresented: showCreateMerchantView ? $showCreateMerchantView : $showContactPicker) {
            if showCreateMerchantView {
                CreateMerchantView(merchantStore: merchantStore)
            } else {
                ContactsListView(contacts: allContacts, selection: $selectedContact.onChange(cleanPhoneNumber))
            }
        }
        .actionSheet(isPresented: $showReportSheet) {
            ActionSheet(title: Text("Report a problem."),
                        buttons: alertButtons)
        }
        .background(Color.primaryBackground.ignoresSafeArea().onTapGesture(perform: hideKeyboard))
        .trackAppearance(.transfer)
        .onAppear(perform: initialization)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button(action: {
                    focusedState = focusedState?.next()
                }) {
                    Text("Next")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(5)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: switchPaymentType) {
                    Text(transaction.type == .client ? "Pay Merchant" : "Send Money")
                        .font(.system(size: 18, design: .rounded))
                        .foregroundColor(.blue)
                        .padding(5)
                }
            }
        }
    }

    private var alertButtons: [ActionSheet.Button] {
        [.default(Text("This merchant code is incorrect")), .cancel()]
    }
    
    private func deleteMerchant(at offSets: IndexSet) {
        merchantStore.deleteMerchants(at: offSets)
    }
}

private extension TransferView {

    func initialization() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            focusedState = .amount
        }
        
        requestContacts()
    }

    func switchPaymentType() {
        withAnimation {
            transaction.type.toggle()
        }
    }

    func requestContacts() {
        Task {
            do {
                allContacts = try await PhoneContacts.getMtnContacts()
            } catch {
                Tracker.shared.logError(error: error)
                Log.debug(error.localizedDescription)
            }
        }
    }
    
    private func cleanPhoneNumber(_ value: Contact?) {
        guard let contact = value else { return }
        let firstNumber  = contact.phoneNumbers.first!
        transaction.number = firstNumber
    }
    
    private func transferMoney() {
        hideKeyboard()
        Task {
            await MainViewModel.performQuickDial(for: .other(transaction.fullCode))
            Tracker.shared.logTransaction(transaction: transaction)
        }
    }
    
    /// Create a validation for the  `Number` field value
    /// - Parameter value: the validated data
    private func handleNumberField(_ value: String) {
        if transaction.type == .merchant {
            transaction.number = String(value.prefix(6))
        } else {
            let matchedContacts = allContacts.filter({ $0.phoneNumbers.contains(value.lowercased())})
            if matchedContacts.isEmpty == false {
                selectedContact = matchedContacts.first!
            } else {
                selectedContact = .init(names: "", phoneNumbers: [])
            }
        }
    }

    private func copyToClipBoard() {
        UIPasteboard.general.string = transaction.fullCode
        withAnimation { didCopyToClipBoard = true }

        DispatchQueue.main.asyncAfter(deadline: .now()+2) {
            withAnimation {
                didCopyToClipBoard = false
            }
        }
    }
    
    enum FocusField {
        case amount, number
        func next() -> Self? {
            self == .amount ? .number : nil
        }
    }
}

#if DEBUG
struct SendingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TransferView()
                .environmentObject(UserMerchantStore())
        }
    }
}
#endif
