import Foundation

final class EventInstanceManager: ObservableObject {
    @Published var instances: [EventInstance] = [] {
        didSet { save() }
    }

    private let fileName = "event_instances.json"

    init() {
        load()
    }

    // MARK: - CRUD
    func add(_ instance: EventInstance) {
        instances.append(instance)
    }

    func updateInstance(at index: Int, with instance: EventInstance) {
        guard instances.indices.contains(index) else { return }
        instances[index] = instance
    }

    func deleteInstance(at offsets: IndexSet) {
        instances.remove(atOffsets: offsets)
    }

    // MARK: - CSV
    func exportToCSV() -> URL? {
        let header = "Дата,Название,Куратор,Гостей,Сумма,Орг всего,Кур всего,Орг выплачено,Кур выплачено,Орг выплачен,Кур выплачен"
        let rows = instances.map { instance in
            [
                instance.date.formatted(date: .numeric, time: .omitted),
                instance.eventInstanceName,
                instance.instanceCurName,
                "\(instance.numberOfPeople)",
                String(format: "%.2f", instance.instanceMoney),
                String(format: "%.2f", instance.instanceOrgFee),
                String(format: "%.2f", instance.instanceCurFee),
                String(format: "%.2f", instance.orgPaidAmount),
                String(format: "%.2f", instance.curPaidAmount),
                instance.isOrgFullyPaid ? "Да" : "Нет",
                instance.isCurFullyPaid ? "Да" : "Нет"
            ].joined(separator: ",")
        }

        let csv = ([header] + rows).joined(separator: "\n")
        guard let data = csv.data(using: .utf8) else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("events.csv")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("CSV write error: \(error)")
            return nil
        }
    }

    // MARK: - Persistence (local)
    func save() {
        do {
            let data = try JSONEncoder().encode(instances)
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Save error: \(error)")
        }
    }

    func load() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: url)
            instances = try JSONDecoder().decode([EventInstance].self, from: data)
        } catch {
            instances = []
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
