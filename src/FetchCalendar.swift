import Foundation
import EventKit

// MARK: - JSON Structures

struct EventJSON: Codable {
    let calendarItemIdentifier: String
    let calendarItemExternalIdentifier: String?
    let calendarTitle: String?
    let title: String?
    let location: String?
    let creationDate: Date?
    let lastModifiedDate: Date?
    let timeZoneIdentifier: String?
    let url: String?
    let notes: String?
    let attendees: [String]?
    let alarms: [AlarmJSON]?
    let recurrenceRules: [RecurrenceRuleJSON]?
    let startDate: Date?
    let endDate: Date?
    let isAllDay: Bool
    let availability: Int
}

struct AlarmJSON: Codable {
    let absoluteDate: Date?
    let relativeOffset: TimeInterval
    let proximity: Int
    let structuredLocationTitle: String?
    let structuredLocationRadius: Double?
}

struct RecurrenceRuleJSON: Codable {
    let frequency: Int
    let interval: Int
    let recurrenceEndDate: Date?
    let occurrenceCount: Int?
}

// MARK: - EventExtractor Class

class EventExtractor {

    let eventStore = EKEventStore()
    let dispatchGroup = DispatchGroup()
    var eventsJSON: [EventJSON] = []

    /// Requests full access to calendar events and, if granted, fetches events within the specified date range.
    func requestAccessAndFetchAllEvents(startDate: Date, endDate: Date) {
        dispatchGroup.enter()
        eventStore.requestFullAccessToEvents { granted, error in
            if granted {
                self.fetchAllEvents(startDate: startDate, endDate: endDate)
            } else {
                if let error = error {
                    print("Error requesting access: \(error)")
                } else {
                    print("Access to calendar events was not granted.")
                }
                self.dispatchGroup.leave()
            }
        }
    }

    /// Fetches events within the specified date range and converts them to JSON-serializable objects.
    func fetchAllEvents(startDate: Date, endDate: Date) {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        if events.isEmpty {
            print("No events found.")
        }
        for event in events {
            if let jsonEvent = createEventJSON(from: event) {
                eventsJSON.append(jsonEvent)
            }
        }
        dispatchGroup.leave()
    }

    /// Converts an EKEvent to an EventJSON object.
    func createEventJSON(from event: EKEvent) -> EventJSON? {
        let calendarTitle = event.calendar.title
        let attendeesNames = event.attendees?.compactMap { $0.name }
        let alarmsJSON: [AlarmJSON]? = event.alarms?.map { alarm in
            let structuredTitle = alarm.structuredLocation?.title
            let structuredRadius = alarm.structuredLocation?.radius
            return AlarmJSON(
                absoluteDate: alarm.absoluteDate,
                relativeOffset: alarm.relativeOffset,
                proximity: alarm.proximity.rawValue,
                structuredLocationTitle: structuredTitle,
                structuredLocationRadius: structuredRadius
            )
        }
        let recurrenceRulesJSON: [RecurrenceRuleJSON]? = event.recurrenceRules?.map { rule in
            let recurrenceEndDate = rule.recurrenceEnd?.endDate
            let occurrenceCount = rule.recurrenceEnd?.occurrenceCount
            return RecurrenceRuleJSON(
                frequency: rule.frequency.rawValue,
                interval: rule.interval,
                recurrenceEndDate: recurrenceEndDate,
                occurrenceCount: occurrenceCount
            )
        }

        return EventJSON(
            calendarItemIdentifier: event.calendarItemIdentifier,
            calendarItemExternalIdentifier: event.calendarItemExternalIdentifier,
            calendarTitle: calendarTitle,
            title: event.title,
            location: event.location,
            creationDate: event.creationDate,
            lastModifiedDate: event.lastModifiedDate,
            timeZoneIdentifier: event.timeZone?.identifier,
            url: event.url?.absoluteString,
            notes: event.notes,
            attendees: attendeesNames,
            alarms: alarmsJSON,
            recurrenceRules: recurrenceRulesJSON,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            availability: event.availability.rawValue
        )
    }

    /// Writes the eventsJSON array to a JSON file in the current directory.
    func writeEventsToJSONFile() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(eventsJSON)
            let fileURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("events.json")
            try data.write(to: fileURL)
            print("Events written to: \(fileURL.path)")
            print("Total events exported: \(eventsJSON.count)")
        } catch {
            print("Failed to write events to JSON: \(error)")
        }
    }
}

// MARK: - Main Execution

// Example date range: from one day ago to one year from now.
let calendar = Calendar.current
guard let startDate = calendar.date(byAdding: .day, value: -1, to: Date()),
      let endDate = calendar.date(byAdding: .year, value: 1, to: Date()) else {
    fatalError("Failed to compute date range")
}

let extractor = EventExtractor()
extractor.requestAccessAndFetchAllEvents(startDate: startDate, endDate: endDate)

// Wait until asynchronous operations are complete, then write JSON and exit.
extractor.dispatchGroup.wait()
extractor.writeEventsToJSONFile()
exit(0)