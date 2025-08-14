import SwiftUI

struct EventInstanceListView: View {
    @ObservedObject var instanceManager: EventInstanceManager
    @Binding var editingInstance: EventInstance?
    @Binding var editMoney: String
    @Binding var editPeople: String
    @Binding var editDate: Date
    @Binding var editOrgPaid: Bool
    @Binding var editCurPaid: Bool

    private enum DebtFilter: String, CaseIterable, Identifiable {
        case all = "Все"
        case withDebt = "С долгами"
        case noDebt = "Без долга"
        var id: String { rawValue }
    }

    @State private var debtFilter: DebtFilter = .all

    var body: some View {
        List {
            // фильтр + заголовок
            Section {
                Picker("Фильтр долгов", selection: $debtFilter) {
                    ForEach(DebtFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // список инстансов
            Section {
                ForEach(filteredAndSortedInstances(), id: \.id) { instance in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(instance.eventInstanceName) — \(instance.date.formatted(date: .numeric, time: .omitted))")
                            .font(.headline)
                        Text("Гостей: \(instance.numberOfPeople), Сумма: \(instance.instanceMoney, specifier: "%.2f")")
                            .font(.subheadline)
                        Text("Орг: \(instance.orgPaidAmount, specifier: "%.2f") / \(instance.instanceOrgFee, specifier: "%.2f") \(instance.isOrgFullyPaid ? "✓" : "✗")")
                            .font(.caption)
                        Text("Кур: \(instance.curPaidAmount, specifier: "%.2f") / \(instance.instanceCurFee, specifier: "%.2f") \(instance.isCurFullyPaid ? "✓" : "✗")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // открыть редактирование
                        editingInstance = instance
                        editMoney = String(instance.instanceMoney)
                        editPeople = String(instance.numberOfPeople)
                        editDate = instance.date
                        editOrgPaid = instance.orgPaid
                        editCurPaid = instance.curPaid
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteByID(instance.id)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }

                        Button {
                            editingInstance = instance
                            editMoney = String(instance.instanceMoney)
                            editPeople = String(instance.numberOfPeople)
                            editDate = instance.date
                            editOrgPaid = instance.orgPaid
                            editCurPaid = instance.curPaid
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                    }
                }
                // ВАЖНО: onDelete по ID, а не по индексам исходного массива
                .onDelete { offsets in
                    let base = filteredAndSortedInstances()
                    let idsToDelete = offsets.compactMap { base[$0].id }
                    instanceManager.instances.removeAll { idsToDelete.contains($0.id) }
                }
            }
        }
        .navigationTitle("Список мероприятий")
        .toolbar {
            EditButton()
        }
    }

    // MARK: - Helpers

    private func hasDebt(_ i: EventInstance) -> Bool {
        let orgDebt = i.orgPaidAmount < i.instanceOrgFee - 0.005
        let curDebt = i.curPaidAmount < i.instanceCurFee - 0.005
        return orgDebt || curDebt
    }

    private func filteredAndSortedInstances() -> [EventInstance] {
        let base: [EventInstance]
        switch debtFilter {
        case .all:
            base = instanceManager.instances
        case .withDebt:
            base = instanceManager.instances.filter { hasDebt($0) }
        case .noDebt:
            base = instanceManager.instances.filter { !hasDebt($0) }
        }
        // новые сверху
        return base.sorted { $0.date > $1.date }
    }

    private func deleteByID(_ id: UUID) {
        instanceManager.instances.removeAll { $0.id == id }
    }
}
