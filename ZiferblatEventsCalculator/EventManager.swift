import Foundation

final class EventManager: ObservableObject {
    @Published var events: [Event] = [] {
        didSet { save() }
    }

    private let fileName = "events.json"

    init() {
        load()
    }

    // MARK: - CRUD
    func add(_ event: Event) {
        events.append(event)
        save()
    }

    func update(_ event: Event) {
        if let idx = events.firstIndex(where: { $0.id == event.id }) {
            events[idx] = event
            save()
        }
    }

    func remove(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        events.removeAll { $0.id == id }
        save()
    }

    func replaceAll(_ newEvents: [Event]) {
        events = newEvents
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        events.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func removeAll() {
        events.removeAll()
        save()
    }

    // MARK: - Persistence (local)
    func save() {
        do {
            let data = try JSONEncoder().encode(events)
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Save events error: \(error)")
        }
    }

    func load() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: url)
            events = try JSONDecoder().decode([Event].self, from: data)
        } catch {
            events = []
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
