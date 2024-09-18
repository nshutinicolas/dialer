//
//  SpendingCategoryOverview.swift
//  Dialer
//
//  Created by Cédric Bahirwe on 18/09/2024.
//  Copyright © 2024 Cédric Bahirwe. All rights reserved.
//

import SwiftUI

struct SpendingCategoryOverview: View {
    let overview: InsightsView.Insight
    let isSelected: Bool
    let totalAmount: Int
    var body: some View {
        VStack(alignment: .leading) {

            VStack(alignment: .leading) {
                HStack {
                    Text(overview.totalAmount, format: .currency(code: "RWF"))
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .minimumScaleFactor(0.75)
                    //                            .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text(
                    Double(overview.totalAmount)/Double(totalAmount),
                        format: .percent.precision(.fractionLength(1))
                    )
                    .font(.caption)
                    .fontWeight(.semibold)
                }

                Text(overview.title)
                    .font(.callout)
                    .fontDesign(.rounded)
            }

            overview.icon
                .frame(width: 32, height: 32)
                .background(overview.color, in: .circle)
                .foregroundStyle(.white)

        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 28))
        .background(isSelected ? Color.blue : .clear, in: .circle)
    }
}

//#Preview {
//    SpendingCategoryOverview()
//}
