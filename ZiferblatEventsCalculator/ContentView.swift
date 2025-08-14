import SwiftUI

struct ContentView: View {
    @StateObject var eventManager = EventManager()
    @StateObject var instanceManager = EventInstanceManager()

    // Создание
    @State private var selectedEventID: UUID?
    @State private var moneyText = ""
    @State private var numOfPeopleText = ""
    @State private var selectedDate = Date()

    // Редактирование
    @State private var editingInstance: EventInstance? = nil
    @State private var editMoney = ""
    @State private var editPeople = ""
    @State private var editDate = Date()
    @State private var editOrgPaid = false
    @State private var editCurPaid = false
    @State private var editOrgPaidAmount = ""
    @State private var editCurPaidAmount = ""

    // MARK: - Totals
    private var totalOrgDebt: Double {
        instanceManager.instances.reduce(0) { sum, inst in
            let remain = max(0, inst.instanceOrgFee - inst.orgPaidAmount)
            return sum + remain
        }
    }
    private var totalCurDebt: Double {
        instanceManager.instances.reduce(0) { sum, inst in
            let remain = max(0, inst.instanceCurFee - inst.curPaidAmount)
            return sum + remain
        }
    }

    var body: some View {
        NavigationView {
            Form {
                eventPickerSection
                parametersSection
                createButtonSection

                // ⬇️ Новая секция с итогами долгов
                totalsSection

                exportSection
                navigationSection
            }
            .navigationTitle("Новое мероприятие")
        }
        .sheet(item: $editingInstance, content: editSheet)
    }

    // MARK: - Sections

    private var eventPickerSection: some View {
        Section(header: Text("Тип мероприятия")) {
            if eventManager.events.isEmpty {
                Text("Нет доступных типов. Добавь в «Управление типами».")
                    .foregroundColor(.secondary)
            } else {
                Picker("Выбери мероприятие", selection: $selectedEventID) {
                    ForEach(eventManager.events.map { ($0.id, $0.eventName) }, id: \.0) { (id, name) in
                        Text(name).tag(Optional(id))
                    }
                }
            }
        }
    }

    private var parametersSection: some View {
        Section(header: Text("Параметры")) {
            DatePicker("Дата мероприятия", selection: $selectedDate, displayedComponents: .date)

            LabeledContent("Сумма") {
                TextField("например 150.00", text: $moneyText)
                    .keyboardType(.decimalPad)
            }

            LabeledContent("Кол-во людей") {
                TextField("например 12", text: $numOfPeopleText)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var createButtonSection: some View {
        Section {
            Button("Создать EventInstance") { createInstance() }
                .disabled(selectedEventID == nil || moneyText.isEmpty || numOfPeopleText.isEmpty)
        }
    }

    // NEW: totals
    private var totalsSection: some View {
        Section(header: Text("Итого долги")) {
            HStack {
                Text("Организаторам")
                Spacer()
                Text("\(totalOrgDebt, specifier: "%.2f")")
                    .monospacedDigit()
            }
            HStack {
                Text("Кураторам")
                Spacer()
                Text("\(totalCurDebt, specifier: "%.2f")")
                    .monospacedDigit()
            }
            if totalOrgDebt == 0 && totalCurDebt == 0 {
                Text("Долгов нет 🎉")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var exportSection: some View {
        Section {
            Button("Экспорт в CSV") {
                if let url = instanceManager.exportToCSV() {
                    shareCSV(url: url)
                }
            }
        }
    }

    private var navigationSection: some View {
        Section(header: Text("Навигация")) {
            NavigationLink("Управление типами", destination: EventListView(eventManager: eventManager))

            NavigationLink("Список мероприятий") {
                EventInstanceListView(
                    instanceManager: instanceManager,
                    editingInstance: $editingInstance,
                    editMoney: $editMoney,
                    editPeople: $editPeople,
                    editDate: $editDate,
                    editOrgPaid: $editOrgPaid,
                    editCurPaid: $editCurPaid
                )
            }

            NavigationLink("Импорт времени") {
                TimeImportView(eventManager: eventManager, instanceManager: instanceManager)
            }

            NavigationLink("Перенос данных (импорт/экспорт)") {
                TransferView(eventManager: eventManager, instanceManager: instanceManager)
            }
        }
    }

    // MARK: - Edit Sheet

    private func editSheet(instance: EventInstance) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Редактировать")) {
                    Text("Событие: \(instance.eventInstanceName)")
                    Text("Куратор: \(instance.instanceCurName)")
                    DatePicker("Дата", selection: $editDate, displayedComponents: .date)

                    TextField("Сумма", text: $editMoney, prompt: Text("например 150.00"))
                        .keyboardType(.decimalPad)
                    TextField("Людей", text: $editPeople, prompt: Text("например 12"))
                        .keyboardType(.numberPad)
                }

                Section(header: Text("Выплаты")) {
                    Toggle("Орг. комиссия выплачена (полностью)", isOn: $editOrgPaid)
                    TextField("Выплачено организатору", text: $editOrgPaidAmount, prompt: Text("0 если не выплачено"))
                        .keyboardType(.decimalPad)

                    Toggle("Кур. комиссия выплачена (полностью)", isOn: $editCurPaid)
                    TextField("Выплачено куратору", text: $editCurPaidAmount, prompt: Text("0 если не выплачено"))
                        .keyboardType(.decimalPad)

                    Text("Осталось организатору: \(previewRemaining(for: instance).0, specifier: "%.2f")")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Осталось куратору: \(previewRemaining(for: instance).1, specifier: "%.2f")")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Сохранить") {
                        if let money = Double(editMoney),
                           let people = Int(editPeople),
                           let index = instanceManager.instances.firstIndex(where: { $0.id == instance.id }) {

                            let coefOrg = instance.instanceOrgFee / max(instance.instanceMoney, 0.0001)
                            let coefCur = instance.instanceCurFee / max(instance.instanceMoney, 0.0001)
                            let newOrgFee = money * coefOrg
                            let newCurFee = money * coefCur

                            let paidOrgInput = Double(editOrgPaidAmount) ?? 0
                            let paidCurInput = Double(editCurPaidAmount) ?? 0

                            let finalOrgPaidAmount = editOrgPaid ? newOrgFee : paidOrgInput
                            let finalCurPaidAmount = editCurPaid ? newCurFee : paidCurInput

                            let finalOrgPaidFlag = finalOrgPaidAmount >= newOrgFee - 0.005
                            let finalCurPaidFlag = finalCurPaidAmount >= newCurFee - 0.005

                            let updated = EventInstance(
                                date: editDate,
                                eventInstanceName: instance.eventInstanceName,
                                instanceCurName: instance.instanceCurName,
                                numberOfPeople: people,
                                instanceMoney: money,
                                instanceOrgFee: newOrgFee,
                                instanceCurFee: newCurFee,
                                orgPaid: finalOrgPaidFlag,
                                curPaid: finalCurPaidFlag,
                                orgPaidAmount: max(0, finalOrgPaidAmount),
                                curPaidAmount: max(0, finalCurPaidAmount)
                            )

                            instanceManager.updateInstance(at: index, with: updated)
                            editingInstance = nil
                        }
                    }

                    Button("Отменить", role: .cancel) { editingInstance = nil }
                }
            }
            .navigationTitle("Редактировать")
            .onAppear {
                editMoney = String(instance.instanceMoney)
                editPeople = String(instance.numberOfPeople)
                editDate = instance.date
                editOrgPaid = instance.orgPaid
                editCurPaid = instance.curPaid
                editOrgPaidAmount = String(format: "%.2f", instance.orgPaidAmount)
                editCurPaidAmount = String(format: "%.2f", instance.curPaidAmount)
            }
        }
    }

    // MARK: - Helpers

    private func previewRemaining(for instance: EventInstance) -> (Double, Double) {
        let moneyValue = Double(editMoney) ?? instance.instanceMoney
        let coefOrg = instance.instanceOrgFee / max(instance.instanceMoney, 0.0001)
        let coefCur = instance.instanceCurFee / max(instance.instanceMoney, 0.0001)
        let newOrgFee = moneyValue * coefOrg
        let newCurFee = moneyValue * coefCur
        let paidOrgInput = Double(editOrgPaidAmount) ?? 0
        let paidCurInput = Double(editCurPaidAmount) ?? 0
        let consideredOrgPaid = editOrgPaid ? newOrgFee : paidOrgInput
        let consideredCurPaid = editCurPaid ? newCurFee : paidCurInput
        let remainingOrg = max(0, newOrgFee - consideredOrgPaid)
        let remainingCur = max(0, newCurFee - consideredCurPaid)
        return (remainingOrg, remainingCur)
    }

    private func createInstance() {
        guard let id = selectedEventID,
              let event = eventManager.events.first(where: { $0.id == id }),
              let money = Double(moneyText),
              let numOfPeople = Int(numOfPeopleText) else { return }

        let newInstance = tryAgain(
            event: event,
            money: money,
            numOfPeople: numOfPeople,
            limit: event.limit ?? 0,
            date: selectedDate
        )
        instanceManager.add(newInstance)

        moneyText = ""
        numOfPeopleText = ""
        selectedDate = Date()
    }

    private func shareCSV(url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}
