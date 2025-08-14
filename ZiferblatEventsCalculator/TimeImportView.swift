import SwiftUI

struct TimeImportView: View {
    @ObservedObject var eventManager: EventManager
    @ObservedObject var instanceManager: EventInstanceManager

    // Выбор типа мероприятия
    @State private var selectedEventID: UUID?

    // Параметры импорта
    @State private var date: Date = .now
    @State private var rateText: String = "3.5"     // ставка за минуту
    @State private var capPerLine: Int = 232        // лимит минут на одну строку (как в .py)

    // Текст с временами
    @State private var rawText: String = ""

    // Результаты парсинга
    @State private var peopleCount: Int = 0
    @State private var totalMinutes: Int = 0
    @State private var previewMoney: Double = 0

    // Превью рассчитанного инстанса по тем же правилам, что и в приложении
    @State private var previewInstance: EventInstance?

    // Ошибка парсинга
    @State private var parseError: String?

    var body: some View {
        Form {
            eventPickerSection
            settingsSection
            inputSection
            resultSection
            actionsSection
        }
        .navigationTitle("Импорт времени")
    }

    // MARK: - Sections

    private var eventPickerSection: some View {
        Section(header: Text("Тип мероприятия")) {
            if eventManager.events.isEmpty {
                Text("Сначала добавьте тип мероприятия в “Управление типами”.")
                    .foregroundColor(.secondary)
            } else {
                Picker("Выбери мероприятие", selection: $selectedEventID) {
                    ForEach(eventManager.events.map { ($0.id, $0.eventName) }, id: \.0) { (id, name) in
                        Text(name).tag(Optional(id))
                    }
                }
                if let ev = selectedEvent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Куратор по умолчанию: \(ev.curName)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        if let limit = ev.limit, ev.orgFee == 0.3 {
                            Text("Порог для куратора: \(limit, specifier: "%.2f")")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        if !ev.paysOrg {
                            if let override = ev.curFeeOverride {
                                Text("Организатор без комиссии · Куратор: \(override * 100, specifier: "%.0f")%")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Организатор без комиссии")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingsSection: some View {
        Section(header: Text("Параметры расчёта")) {
            DatePicker("Дата", selection: $date, displayedComponents: .date)

            TextField("Ставка за минуту", text: $rateText, prompt: Text("например 3.5"))
                .keyboardType(.decimalPad)

            Stepper(value: $capPerLine, in: 1...600) {
                Text("Лимит минут на строку: \(capPerLine)")
            }
        }
    }

    private var inputSection: some View {
        Section(header: Text("Вставь времена (каждая строка: \"HH:MM - HH:MM\" или \"HH.MM HH.MM\")")) {
            TextEditor(text: $rawText)
                .frame(minHeight: 150)
                .font(.system(.body, design: .monospaced))

            if let err = parseError {
                Text(err)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button("Рассчитать") { recalc() }
                .disabled(selectedEvent == nil || rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var resultSection: some View {
        Section(header: Text("Результат")) {
            HStack { Text("Участников"); Spacer(); Text("\(peopleCount)") }
            HStack { Text("Сумма минут"); Spacer(); Text("\(totalMinutes)") }
            HStack { Text("Выручка"); Spacer(); Text("\(previewMoney, specifier: "%.2f")") }
            if let inst = previewInstance {
                HStack { Text("Организатор"); Spacer(); Text("\(inst.instanceOrgFee, specifier: "%.2f")") }
                HStack { Text("Куратор"); Spacer(); Text("\(inst.instanceCurFee, specifier: "%.2f")") }
                Text("Куратор: \(inst.instanceCurName)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button("Создать EventInstance") {
                createInstanceFromPreview()
            }
            .disabled(previewInstance == nil)

            Button("Экспорт строки в CSV (events_import.csv)") {
                exportOneCSVRow()
            }
            .disabled(previewInstance == nil)
        }
    }

    // MARK: - Derived

    private var selectedEvent: Event? {
        guard let id = selectedEventID else { return nil }
        return eventManager.events.first(where: { $0.id == id })
    }

    // MARK: - Actions

    private func recalc() {
        parseError = nil
        previewInstance = nil
        peopleCount = 0
        totalMinutes = 0
        previewMoney = 0

        guard let ev = selectedEvent else { return }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var minutesArray: [Int] = []

        for (idx, line) in lines.enumerated() {
            do {
                let m = try minutesForLine(line)
                minutesArray.append(min(m, capPerLine))
            } catch {
                parseError = "Ошибка в строке \(idx + 1): \(error.localizedDescription)"
                minutesArray = []
                break
            }
        }

        peopleCount = minutesArray.count
        totalMinutes = minutesArray.reduce(0, +)

        let rate = Double(rateText.replacingOccurrences(of: ",", with: ".")) ?? 3.5
        let money = Double(totalMinutes) * rate
        previewMoney = money

        // считаем комиссии тем же методом, что и в приложении
        let inst = tryAgain(
            event: ev,
            money: money,
            numOfPeople: peopleCount,
            limit: ev.limit ?? 0,
            date: date
        )
        previewInstance = inst
    }

    private func createInstanceFromPreview() {
        guard let inst = previewInstance else { return }
        instanceManager.add(inst)
        // Очистим ввод, но оставим выбранный тип
        rawText = ""
        peopleCount = 0
        totalMinutes = 0
        previewMoney = 0
        previewInstance = nil
    }

    private func exportOneCSVRow() {
        guard let inst = previewInstance else { return }

        let header = "Дата,Название,Куратор,Людей,Сумма,Орг,Кур"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let row = [
            df.string(from: inst.date),
            inst.eventInstanceName,
            inst.instanceCurName,
            "\(inst.numberOfPeople)",
            String(format: "%.2f", inst.instanceMoney),
            String(format: "%.2f", inst.instanceOrgFee),
            String(format: "%.2f", inst.instanceCurFee),
        ].joined(separator: ",")

        let csv = ([header, row]).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("events_import.csv")
        do {
            try csv.data(using: .utf8)?.write(to: url)
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } catch {
            print("CSV write error: \(error)")
        }
    }

    // MARK: - Parsing helpers

    private func minutesForLine(_ line: String) throws -> Int {
        // Поддержка: "HH:MM - HH:MM", "HH.MM HH.MM", "HH:MM HH:MM"
        let cleaned = line.trimmingCharacters(in: .whitespaces)
        let tokens = cleaned
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard tokens.count >= 2 else {
            throw NSError(domain: "Parse", code: 1, userInfo: [NSLocalizedDescriptionKey: "недостаточно значений времени"])
        }
        let t1 = try parseTime(tokens[0])
        let t2 = try parseTime(tokens[1])
        let minutes = (t2.hour - t1.hour) * 60 + (t2.minute - t1.minute)
        return max(0, minutes)
    }

    private func parseTime(_ s: String) throws -> (hour: Int, minute: Int) {
        let norm = s.replacingOccurrences(of: ".", with: ":")
        let parts = norm.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0..<24).contains(h),
              (0..<60).contains(m) else {
            throw NSError(domain: "Parse", code: 2, userInfo: [NSLocalizedDescriptionKey: "неверный формат времени \(s)"])
        }
        return (h, m)
    }
}
