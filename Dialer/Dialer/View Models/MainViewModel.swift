//
//  MainViewModel.swift
//  Dialer
//
//  Created by Cédric Bahirwe on 14/02/2021.
//

import Foundation
import SwiftUI

protocol UtilitiesDelegate {
    func didSelectOption(with code: DialerQuickCode)
}

@MainActor class MainViewModel: ObservableObject {
    
    @Published var pinCode: CodePin? = DialerStorage.shared.getCodePin()
    @Published var hasReachSync = DialerStorage.shared.isSyncDateReached() {
        didSet(newValue) {
            if newValue == false {
                DialerStorage.shared.clearSyncDate()
            }
        }
    }

    var utilityDelegate: UtilitiesDelegate?
    
    // Present a sheet contains all dialed code
    @Published var showHistorySheet: Bool = false
    
    // Present a sheet contains settings of the app
    @Published
    private(set) var showSettingsSheet: Bool = false
    
    var estimatedTotalPrice: Int {
        recentCodes.map(\.totalPrice).reduce(0, +)
    }
    
    @Published var purchaseDetail = PurchaseDetailModel()
    
    @Published private(set) var recentCodes: [RecentDialCode] = []
    
    @Published private(set) var elecMeters: [ElectricityMeter] = []

    @Published private(set) var ussdCodes: [USSDCode] = []
    
    /// Store a given  `RecentCode`  locally.
    /// - Parameter code: the code to be added.
    private func storeCode(code: RecentDialCode) {
        if let index = recentCodes.firstIndex(where: { $0.detail.amount == code.detail.amount }) {
            recentCodes[index].increaseCount()
        } else {
            recentCodes.append(code)
        }
        saveRecentCodesLocally()
    }
    
    
    func containsMeter(with number: String) -> Bool {
        guard let meter = try? ElectricityMeter(number) else { return false }
        return elecMeters.contains(meter)
    }
    
    /// Save RecentCode(s) locally.
    func saveRecentCodesLocally() {
        do {
            try DialerStorage.shared.saveRecentCodes(recentCodes)
        } catch {
            Tracker.shared.logError(error: error)
            Log.debug("Could not save recent codes locally: ", error.localizedDescription)
        }
    }
    
    ///  Delete locally the Pin Code.
    func removePin() {
        DialerStorage.shared.removePinCode()
        pinCode = nil
    }

    /// Has user saved Code Pin
    func hasStoredCodePin() -> Bool {
        DialerStorage.shared.hasSavedCodePin()
    }
    
    /// Retrieve all locally stored recent codes.
    func retrieveCodes() {
        recentCodes = DialerStorage.shared.getRecentCodes()
    }
    
    /// Confirm and Purchase an entered Code.
    func confirmPurchase() {
        let purchase = purchaseDetail
        Task {
            do {
                try await dialCode(from: purchase)
                self.storeCode(code: RecentDialCode(detail: purchase))
                self.purchaseDetail = PurchaseDetailModel()
            } catch let error as DialingError {
                Log.debug(error.message)
            }
        }
    }
    
    /// Delete locally the used Code(s).
    /// - Parameter offSets: the offsets to be deleted
    func deletePastCode(at offSets: IndexSet) {
        recentCodes.remove(atOffsets: offSets)
        saveRecentCodesLocally()
    }
    
    /// Save locally the Code Pin
    /// - Parameter value: the pin value to be saved.
    func saveCodePin(_ value: CodePin) {
        pinCode = value
        do {
            try DialerStorage.shared.saveCodePin(value)
        } catch {
            Log.debug("Storage: \(error.localizedDescription)")
        }
    }
    
    /// Used on the `PuchaseDetailView` to dial, save code, save pin.
    /// - Parameters:
    ///   - purchase: the purchase to take the fullCode from.
    private func dialCode(from purchase: PurchaseDetailModel) async throws {
        
        let newUrl = getFullUSSDCode(from: purchase)
        
        if let telUrl = URL(string: "tel://\(newUrl)"),
           UIApplication.shared.canOpenURL(telUrl) {
            let isCompleted = await UIApplication.shared.open(telUrl)
            if !isCompleted {
                throw DialingError.canNotDial
            }
        } else {
            throw DialingError.canNotDial
        }
    }

    func getFullUSSDCode(from purchase: PurchaseDetailModel) -> String {
        let code: String
        if let _ = pinCode, String(pinCode!).count >= 5 {
            code = String(pinCode!)
        } else {
            code = ""
        }
        return purchase.getDialCode(pin: code)

    }

    func getPurchaseDetailUSSDCode() -> String {
        getFullUSSDCode(from: purchaseDetail)
    }
    
    /// Returns a `RecentDialCode` that matches the identifier.
    func getRecentDialCode(with identifier: String) -> RecentDialCode? {
        recentCodes.first(where: { $0.id.uuidString == identifier })
    }
    
    /// Perform an independent dial, without storing or tracking.
    /// - Parameter code: a `DialerQuickCode`  code to be dialed.
    static func performQuickDial(for code: DialerQuickCode) async {
        if let telUrl = URL(string: "tel://\(code.ussd)"),
           UIApplication.shared.canOpenURL(telUrl) {
            
            let isCompleted = await UIApplication.shared.open(telUrl)
            if isCompleted {
                Log.debug("Successfully Dialed")
            } else {
                Log.debug("Failed Dialed")
            }
            
        } else {
            Log.debug("Can not dial this code")
        }
    }
    
    /// Perfom a quick dialing from the `History View Row.`
    /// - Parameter recentCode: the row code to be performed.
    func performRecentDialing(for recentCode: RecentDialCode) {
        let recent = recentCode
        Task {
            do {
                try await dialCode(from: recent.detail)
                self.storeCode(code: recent)
            } catch let error as DialingError {
                Log.debug(error.message)
            }
        }
    }
    
    func showSettingsView() {
        showSettingsSheet = true
        Tracker.shared.logEvent(.settingsOpened)
    }
    
    func dismissSettingsView() {
        showSettingsSheet = false
    }
    
    func settingsAndHistorySheetBinding() -> Binding<Bool> {
        let setter = { [weak self] (value: Bool) in
            guard let strongSelf = self else { return }
            if strongSelf.showSettingsSheet {
                strongSelf.showSettingsSheet = value
            } else {
                DispatchQueue.main.async {
                    strongSelf.showHistorySheet = value
                }
            }
        }
        let getter = showSettingsSheet ? showSettingsSheet : showHistorySheet
        
        return Binding(
            get: { getter },
            set: { setter($0) })
    }
}

// MARK: - Extension used for Quick USSD actions.
extension MainViewModel {
    private func performQuickDial(for quickCode: DialerQuickCode) {
        if UIApplication.hasSupportForUSSD {
            Task {
                await Self.performQuickDial(for: quickCode)
            }
        } else {
            utilityDelegate?.didSelectOption(with: quickCode)
        }
    }

    func checkMobileWalletBalance() {
        performQuickDial(for: .mobileWalletBalance(code: pinCode))
    }

    func getElectricity(for meterNumber: String, amount: Int) {
        let number = meterNumber.replacingOccurrences(of: " ", with: "")
        performQuickDial(for: .electricity(meter: number, amount: amount, code: pinCode))
    }
    
}

// MARK: - Extension used for Error, Models, etc
extension MainViewModel {
    enum DialingError: Error {
        case canNotDial, emptyPin, unknownFormat(String)
        var message: String {
            switch self {
            case .canNotDial:
                return "Can not dial this code"
            case .unknownFormat(let format):
                return "Can not decode this format: \(format)"
            case .emptyPin:
                return "Pin Code not found, configure pin and try again"
            }
        }
    }

}

// MARK: Electricity Storage
extension MainViewModel {

    /// Store a given  `MeterNumber`  locally.
    /// - Parameter code: the code to be added.
    func storeMeter(_ number: ElectricityMeter) {
        guard elecMeters.contains(where: { $0.id == number.id }) == false else { return }
        elecMeters.append(number)
        saveMeterNumbersLocally(elecMeters)
    }

    /// Save MeterNumber(s) locally.
    private func saveMeterNumbersLocally(_ meters: [ElectricityMeter]) {
        do {
            try DialerStorage.shared.saveElectricityMeters(meters)
        } catch {
            Tracker.shared.logError(error: error)
            Log.debug("Could not save meter numbers locally: ", error.localizedDescription)
        }
    }

    /// Retrieve all locally stored Meter Numbers codes
    func retrieveMeterNumbers() {
        elecMeters = DialerStorage.shared.getMeterNumbers()
    }

    func deleteMeter(at offSets: IndexSet) {
        elecMeters.remove(atOffsets: offSets)
        saveMeterNumbersLocally(elecMeters)
    }
}

// MARK: Custom USSD Storage
extension MainViewModel {
    /// Store a given  `USSDCode`  locally.
    /// - Parameter code: the code to be added.
    func storeUSSD(_ code: USSDCode) {
        guard ussdCodes.contains(where: { $0 == code }) == false else { return }
        ussdCodes.append(code)
        saveUSSDCodesLocally(ussdCodes)
    }

    /// Update an existing `USSDCode` locally.
    /// - Parameter code: the code to be updated
    func updateUSSD(_ code: USSDCode) {
        if let index = ussdCodes.firstIndex(of: code) {
            ussdCodes[index] = code
        }
        saveUSSDCodesLocally(ussdCodes)
    }

    /// Save USSDCode(s) locally.
    private func saveUSSDCodesLocally(_ codes: [USSDCode]) {
        do {
            try DialerStorage.shared.saveUSSDCodes(codes)
        } catch {
            Tracker.shared.logError(error: error)
            Log.debug("Could not save ussd codes locally: ", error.localizedDescription)
        }
    }

    /// Retrieve all locally stored Meter Numbers codes
    func retrieveUSSDCodes() {
        ussdCodes = DialerStorage.shared.getUSSDCodes()
    }

    func deleteUSSD(at offSets: IndexSet) {
        ussdCodes.remove(atOffsets: offSets)
        saveUSSDCodesLocally(ussdCodes)
    }

    func removeAllUSSDs() {
        DialerStorage.shared.removeAllUSSDCodes()
        ussdCodes = []
    }
}

// MARK: - Extension used for Home Quick Actions
extension RecentDialCode {
    
    /// - Tag: QuickActionUserInfo
    var quickActionUserInfo: [String: NSSecureCoding] {
        /** Encode the id of the recent code into the userInfo dictionary so it can be passed
         back when a quick action is triggered.
         */
        return [ SceneDelegate.codeIdentifierInfoKey: self.id.uuidString as NSSecureCoding ]
    }
}
