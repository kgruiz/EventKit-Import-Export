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

// MARK: - Utility Function for Date Range

/**
 Computes a date range relative to today based on a specified time unit and quantity.

 This function calculates two dates:
 - A start date by subtracting the specified quantity of the given unit from today.
 - An end date by adding the specified quantity of the given unit to today.

 The function supports the following units:
 - "day": Uses calendar days.
 - "week": Returns dates that fall on the same weekday as today.
 - "month": Returns dates that fall on the same day-of-month as today.
 - "year": Returns dates that fall on the same month and day as today.

 Examples:
 - `getDateRange(past: 1, future: 1, unit: "day")` returns a range from yesterday to tomorrow.
 - `getDateRange(past: 1, future: 1, unit: "week")` returns a range from the same weekday last week to the same weekday next week.
 - `getDateRange(past: 1, future: 1, unit: "month")` returns a range from the same day last month to the same day next month.
 - `getDateRange(past: 1, future: 1, unit: "year")` returns a range from the same day last year to the same day next year.

 - Parameters:
    - past: The number of units to subtract from today's date to compute the start date.
    - future: The number of units to add to today's date to compute the end date.
    - unit: A string representing the time unit. Must be one of "day", "week", "month", or "year".

 - Returns: An optional tuple containing the computed start and end dates, or `nil` if the dates could not be calculated.
 */
func getDateRange(past: Int, future: Int, unit: String) -> (start: Date, end: Date)? {
    let calendar = Calendar.current
    let today = Date()

    var startDate: Date?
    var endDate: Date?

    switch unit.lowercased() {
    case "day":
        startDate = calendar.date(byAdding: .day, value: -past, to: today)
        endDate = calendar.date(byAdding: .day, value: future, to: today)

    case "week":
        if let start = calendar.date(byAdding: .weekOfYear, value: -past, to: today),
           let end = calendar.date(byAdding: .weekOfYear, value: future, to: today) {
            let weekday = calendar.component(.weekday, from: today)
            startDate = calendar.nextDate(after: start, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTimePreservingSmallerComponents)
            endDate = calendar.nextDate(after: end, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTimePreservingSmallerComponents)
        }

    case "month":
        if let start = calendar.date(byAdding: .month, value: -past, to: today),
           let end = calendar.date(byAdding: .month, value: future, to: today) {
            let day = calendar.component(.day, from: today)
            startDate = calendar.nextDate(after: start, matching: DateComponents(day: day), matchingPolicy: .nextTimePreservingSmallerComponents)
            endDate = calendar.nextDate(after: end, matching: DateComponents(day: day), matchingPolicy: .nextTimePreservingSmallerComponents)
        }

    case "year":
        if let start = calendar.date(byAdding: .year, value: -past, to: today),
           let end = calendar.date(byAdding: .year, value: future, to: today) {
            let month = calendar.component(.month, from: today)
            let day = calendar.component(.day, from: today)
            startDate = calendar.nextDate(after: start, matching: DateComponents(month: month, day: day), matchingPolicy: .nextTimePreservingSmallerComponents)
            endDate = calendar.nextDate(after: end, matching: DateComponents(month: month, day: day), matchingPolicy: .nextTimePreservingSmallerComponents)
        }

    default:
        print("Invalid unit type. Use 'day', 'week', 'month', or 'year'.")
        return nil
    }

    guard let finalStartDate = startDate, let finalEndDate = endDate else {
        return nil
    }

    return (finalStartDate, finalEndDate)
}

// MARK: - Main Execution

// Define date range using the utility function.
// Example: Get events from 1 unit in the past to 1 unit in the future.
// The unit can be "day", "week", "month", or "year".
// Here we use "week" to get the same weekday last week and next week.
guard let dateRange = getDateRange(past: 1, future: 1, unit: "week") else {
    fatalError("Failed to compute date range")
}

let extractor = EventExtractor()
extractor.requestAccessAndFetchAllEvents(startDate: dateRange.start, endDate: dateRange.end)

// Wait until asynchronous operations are complete, then write JSON and exit.
extractor.dispatchGroup.wait()
extractor.writeEventsToJSONFile()
exit(0)
