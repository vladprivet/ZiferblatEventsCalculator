import SwiftUI

struct EventListView: View {
    @ObservedObject var eventManager: EventManager

    @State private var editingEvent: Event? = nil
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteID: UUID?

    var body: some View {
        List {
            Section {
                if eventManager.events.isEmpty {
                    ContentUnavailableView(
                        "Нет клубов",
                        systemImage: "calendar.badge.plus",
                        description: Text("Нажми «Добавить» вверху, чтобы создать клуб.")
                    )
                } else {
                    ForEach(eventManager.events, id: \.id) { event in
                        Button {
                            editingEvent = event
                        } label: {
                            EventRowSummary(event: event)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                pendingDeleteID = event.id
                                showDeleteConfirm = true
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            Button {
                                editingEvent = event
                            } label: {
                                Label("Редактировать", systemImage: "pencil")
                            }
                        }
                    }
                    .onMove(perform: onMove)
                    .onDelete(perform: onDelete)
                }
            }
        }
        .navigationTitle("Клубы")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    AddEventView(eventManager: eventManager)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editingEvent) { ev in
            EditEventSheet(event: ev) { updated in
                eventManager.update(updated)
            } onDelete: { id in
                pendingDeleteID = id
                showDeleteConfirm = true
            }
        }
        .confirmationDialog("Удалить клуб?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                if let id = pendingDeleteID {
                    eventManager.remove(id: id)
                    pendingDeleteID = nil
                }
            }
            Button("Отмена", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    // MARK: - Actions

    private func onMove(from source: IndexSet, to destination: Int) {
        eventManager.move(from: source, to: destination)
    }

    private func onDelete(at offsets: IndexSet) {
        // Удаляем сразу без отдельного диалога (есть свайп-подтверждение)
        eventManager.remove(at: offsets)
    }
}

// MARK: - Короткая сводка строки

private struct EventRowSummary: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.eventName)
                .font(.headline)
            HStack(spacing: 12) {
                Text("Куратор: \(event.curName)")
                if event.paysOrg {
                    Text("Орг: \(Int(event.orgFee * 100))%")
                    if event.orgFee == 0.30, let lim = event.limit {
                        Text("Порог: \(Int(lim))")
                    }
                } else {
                    Text("Орг: 0%")
                    if let ov = event.curFeeOverride {
                        Text("Кур: \(Int(ov * 100))%")
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Экран добавления

private struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var eventManager: EventManager

    @State private var name: String = ""
    @State private var curator: String = "лула"
    @State private var paysOrg: Bool = true
    @State private var orgFeeChoice: OrgFeeChoice = .fee30
    @State private var limitText: String = ""
    @State private var curOverrideText: String = ""

    var body: some View {
        Form {
            Section("Название и куратор") {
                TextField("Название", text: $name)
                TextField("Куратор", text: $curator)
            }
            Section("Комиссии") {
                Toggle("Организатор получает комиссию", isOn: $paysOrg)
                if paysOrg {
                    Picker("Комиссия организатора", selection: $orgFeeChoice) {
                        Text("25%").tag(OrgFeeChoice.fee25)
                        Text("30%").tag(OrgFeeChoice.fee30)
                    }
                    .pickerStyle(.segmented)
                    if orgFeeChoice == .fee30 {
                        TextField("Порог для куратора", text: $limitText)
                            .keyboardType(.decimalPad)
                    }
                } else {
                    TextField("Процент куратора (%)", text: $curOverrideText)
                        .keyboardType(.decimalPad)
                }
            }
            Section {
                Button("Сохранить") { save() }
                    .disabled(!canSave)
            }
        }
        .navigationTitle("Новый клуб")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") { dismiss() }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !curator.trimmingCharacters(in: .whitespaces).isEmpty &&
        (paysOrg || (Double(curOverrideText.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0)
    }

    private func save() {
        let limit: Double? = (paysOrg && orgFeeChoice == .fee30)
            ? (Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0)
            : nil
        let curOverride: Double? = (!paysOrg)
            ? max(0, (Double(curOverrideText.replacingOccurrences(of: ",", with: ".")) ?? 0)) / 100.0
            : nil

        let event = Event(
            id: UUID(),
            eventName: name.trimmingCharacters(in: .whitespaces),
            curName: curator.trimmingCharacters(in: .whitespaces),
            orgFee: paysOrg ? (orgFeeChoice == .fee25 ? 0.25 : 0.30) : 0.0,
            limit: limit,
            paysOrg: paysOrg,
            curFeeOverride: curOverride
        )
        eventManager.add(event)
        dismiss()
    }
}

// MARK: - Шит редактирования

private struct EditEventSheet: View {
    @Environment(\.dismiss) private var dismiss

    let event: Event
    var onSave: (Event) -> Void
    var onDelete: (UUID) -> Void

    @State private var name: String = ""
    @State private var curator: String = ""
    @State private var paysOrg: Bool = true
    @State private var orgFeeChoice: OrgFeeChoice = .fee30
    @State private var limitText: String = ""
    @State private var curOverrideText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Название и куратор") {
                    TextField("Название", text: $name)
                    TextField("Куратор", text: $curator)
                }
                Section("Комиссии") {
                    Toggle("Организатор получает комиссию", isOn: $paysOrg)
                    if paysOrg {
                        Picker("Комиссия организатора", selection: $orgFeeChoice) {
                            Text("25%").tag(OrgFeeChoice.fee25)
                            Text("30%").tag(OrgFeeChoice.fee30)
                        }
                        .pickerStyle(.segmented)
                        if orgFeeChoice == .fee30 {
                            TextField("Порог для куратора", text: $limitText)
                                .keyboardType(.decimalPad)
                        }
                    } else {
                        TextField("Процент куратора (%)", text: $curOverrideText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section {
                    Button("Сохранить изменения") { save() }

                    Button("Удалить клуб", role: .destructive) {
                        onDelete(event.id)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Редактировать")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        name = event.eventName
        curator = event.curName
        paysOrg = event.paysOrg
        if paysOrg {
            orgFeeChoice = abs(event.orgFee - 0.25) < 0.0001 ? .fee25 : .fee30
            if let lim = event.limit, abs(event.orgFee - 0.30) < 0.0001 {
                limitText = String(format: "%.0f", lim)
            } else { limitText = "" }
            curOverrideText = ""
        } else {
            orgFeeChoice = .fee30
            limitText = ""
            if let ov = event.curFeeOverride {
                curOverrideText = String(format: "%.0f", ov * 100)
            } else {
                curOverrideText = ""
            }
        }
    }

    private func save() {
        let limit: Double? = (paysOrg && orgFeeChoice == .fee30)
            ? (Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0)
            : nil
        let curOverride: Double? = (!paysOrg)
            ? max(0, (Double(curOverrideText.replacingOccurrences(of: ",", with: ".")) ?? 0)) / 100.0
            : nil

        let updated = Event(
            id: event.id,
            eventName: name.trimmingCharacters(in: .whitespaces),
            curName: curator.trimmingCharacters(in: .whitespaces),
            orgFee: paysOrg ? (orgFeeChoice == .fee25 ? 0.25 : 0.30) : 0.0,
            limit: limit,
            paysOrg: paysOrg,
            curFeeOverride: curOverride
        )
        onSave(updated)
        dismiss()
    }
}

// MARK: - Support

private enum OrgFeeChoice: Hashable { case fee25, fee30 }
