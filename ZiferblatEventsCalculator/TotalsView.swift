import SwiftUI

struct TotalsView: View {
    let totalOrgDebt: Double
    let totalCurDebt: Double

    var body: some View {
        Section(header: Text("Итого долги")) {
            DebtRow(label: "Организаторам", amount: totalOrgDebt)
            DebtRow(label: "Кураторам", amount: totalCurDebt)
            if totalOrgDebt == 0 && totalCurDebt == 0 {
                Text("Долгов нет 🎉")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct DebtRow: View {
    let label: String
    let amount: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(amount, specifier: "%.2f")")
                .monospacedDigit()
        }
    }
}

#Preview {
    List {
        TotalsView(totalOrgDebt: 12.5, totalCurDebt: 0)
    }
}
