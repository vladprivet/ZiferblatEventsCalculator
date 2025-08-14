// TransferView.swift
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct TransferView: View {
    @ObservedObject var eventManager: EventManager
    @ObservedObject var instanceManager: EventInstanceManager

    @State private var showImporter = false
    @State private var errorText: String?
    @State private var infoText: String?

    enum ImportMode: String, CaseIterable, Identifiable {
        case merge = "Слить по ID"
        case addAsNew = "Добавить как новые"
        case replaceAll = "Заменить всё"
        var id: String { rawValue }
    }
    @State private var importMode: ImportMode = .merge

    var body: some View {
        Form {
            Section(header: Text("Экспорт")) {
                Button("Экспортировать всё (.json)") { exportAll() }
            }

            Section(header: Text("Импорт")) {
                Picker("Режим", selection: $importMode) {
                    ForEach(ImportMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)

                Button("Импортировать из файла (.json)") { showImporter = true }

                if let info = infoText { Text(info).foregroundColor(.secondary).font(.footnote) }
                if let err = errorText { Text(err).foregroundColor(.red).font(.footnote) }
            }

            Section(footer:
                Text("""
                • «Слить по ID»: обновит записи с теми же ID, новые ID добавит.
                • «Добавить как новые»: всем записям назначит новые ID.
                • «Заменить всё»: удалит текущие данные и загрузит из файла.
                """).font(.footnote)
            ) { EmptyView() }
        }
        .navigationTitle("Перенос данных")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importAll(from: url)
            case .failure(let error):
                errorText = "Ошибка импорта: \(error.localizedDescription)"
                infoText = nil
            }
        }
    }

    // MARK: - Export

    private func exportAll() {
        let backup = AppBackup(events: eventManager.events, instances: instanceManager.instances)
        do {
            let data = try JSONEncoder().encode(backup)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ziferblat_backup.json")
            try data.write(to: url, options: [.atomic])

            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } catch {
            errorText = "Ошибка экспорта: \(error.localizedDescription)"
            infoText = nil
        }
    }

    // MARK: - Import

    private func importAll(from url: URL) {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        // iCloud: убедимся, что файл загружен
        do {
            let values = try url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if values.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.importAll(from: url) }
                return
            }
        } catch { /* не iCloud — ок */ }

        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { readableURL in
            do {
                let data = try Data(contentsOf: readableURL)
                let backup = try JSONDecoder().decode(AppBackup.self, from: data)

                let incomingE = backup.events.count
                let incomingI = backup.instances.count
                var addedE = 0, addedI = 0, updatedE = 0, updatedI = 0

                switch importMode {
                case .replaceAll:
                    let newEvents = backup.events.sorted {
                        $0.eventName.localizedCaseInsensitiveCompare($1.eventName) == .orderedAscending
                    }
                    let newInstances = backup.instances.sorted { $0.date < $1.date }
                    DispatchQueue.main.async {
                        self.eventManager.events = newEvents
                        self.instanceManager.instances = newInstances
                        self.errorText = nil
                        self.infoText = "Заменено всё: клубов \(incomingE), мероприятий \(incomingI)"
                    }

                case .addAsNew:
                    let newEvents = backup.events.map { e in
                        Event(id: UUID(), eventName: e.eventName, curName: e.curName,
                              orgFee: e.orgFee, limit: e.limit, paysOrg: e.paysOrg,
                              curFeeOverride: e.curFeeOverride)
                    }
                    let newInstances = backup.instances.map { i in
                        EventInstance(id: UUID(), date: i.date, eventInstanceName: i.eventInstanceName,
                                      instanceCurName: i.instanceCurName, numberOfPeople: i.numberOfPeople,
                                      instanceMoney: i.instanceMoney, instanceOrgFee: i.instanceOrgFee,
                                      instanceCurFee: i.instanceCurFee, orgPaid: i.orgPaid, curPaid: i.curPaid,
                                      orgPaidAmount: i.orgPaidAmount, curPaidAmount: i.curPaidAmount)
                    }
                    addedE = newEvents.count
                    addedI = newInstances.count
                    DispatchQueue.main.async {
                        self.eventManager.events.append(contentsOf: newEvents)
                        self.instanceManager.instances.append(contentsOf: newInstances)
                        self.errorText = nil
                        self.infoText = "Добавлено как новые: клубов +\(addedE), мероприятий +\(addedI)"
                    }

                case .merge:
                    var eventsByID = Dictionary(uniqueKeysWithValues: eventManager.events.map { ($0.id, $0) })
                    var instancesByID = Dictionary(uniqueKeysWithValues: instanceManager.instances.map { ($0.id, $0) })

                    for e in backup.events {
                        if eventsByID[e.id] == nil { addedE += 1 } else { updatedE += 1 }
                        eventsByID[e.id] = e
                    }
                    for i in backup.instances {
                        if instancesByID[i.id] == nil { addedI += 1 } else { updatedI += 1 }
                        instancesByID[i.id] = i
                    }

                    let mergedEvents = Array(eventsByID.values).sorted {
                        $0.eventName.localizedCaseInsensitiveCompare($1.eventName) == .orderedAscending
                    }
                    let mergedInstances = Array(instancesByID.values).sorted { $0.date < $1.date }

                    DispatchQueue.main.async {
                        self.eventManager.events = mergedEvents
                        self.instanceManager.instances = mergedInstances
                        self.errorText = nil
                        self.infoText = "Слито по ID: добавлено клубов +\(addedE), обновлено \(updatedE); мероприятий +\(addedI), обновлено \(updatedI)"
                    }
                }

            } catch {
                DispatchQueue.main.async {
                    self.errorText = "Не удалось импортировать: \(error.localizedDescription)"
                    self.infoText = nil
                }
            }
        }

        if let coordError {
            self.errorText = "Ошибка доступа к файлу: \(coordError.localizedDescription)"
            self.infoText = nil
        }
    }
}
