import Foundation
import EventKit

// MARK: - ANSI Escape Codes

struct ANSI {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
}

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
                    print("\(ANSI.red)Error requesting access: \(error)\(ANSI.reset)")
                } else {
                    print("\(ANSI.red)Access to calendar events was not granted.\(ANSI.reset)")
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
            print("\(ANSI.yellow)No events found.\(ANSI.reset)")
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
            print("\(ANSI.green)Events written to: \(fileURL.path)\(ANSI.reset)")
            print("\(ANSI.green)Total events exported: \(eventsJSON.count)\(ANSI.reset)")
        } catch {
            print("\(ANSI.red)Failed to write events to JSON: \(error)\(ANSI.reset)")
        }
    }
}

// MARK: - Utility Function for Date Range

/**
 Computes a date range relative to today with separate units for past and future offsets.

 This function calculates two dates:
 - A start date by subtracting the specified quantity of the given past unit from today.
 - An end date by adding the specified quantity of the given future unit to today.

 The function supports both singular and plural forms of the following units for both past and future:
 - "day" / "days": Uses calendar days.
 - "week" / "weeks": Returns a date that falls on the same weekday as today.
 - "month" / "months": Returns a date that falls on the same day-of-month as today.
 - "year" / "years": Returns a date that falls on the same month and day as today.

 Examples:
 - `getDateRange(past: 1, pastUnit: "day", future: 1, futureUnit: "day")` returns a range from yesterday to tomorrow.
 - `getDateRange(past: 1, pastUnit: "week", future: 1, futureUnit: "weeks")` returns a range from the same weekday last week to the same weekday next week.
 - `getDateRange(past: 1, pastUnit: "month", future: 1, futureUnit: "month")` returns a range from the same day last month to the same day next month.
 - `getDateRange(past: 1, pastUnit: "year", future: 1, futureUnit: "years")` returns a range from the same day last year to the same day next year.
 - Mixed units are also supported:
   - `getDateRange(past: 2, pastUnit: "days", future: 1, futureUnit: "week")` returns a range from 2 days ago to the same weekday one week from today.

 - Parameters:
    - past: The number of units to subtract from today's date for the start date.
    - pastUnit: A string representing the time unit for the past offset ("day", "days", "week", "weeks", "month", "months", "year", or "years").
    - future: The number of units to add to today's date for the end date.
    - futureUnit: A string representing the time unit for the future offset ("day", "days", "week", "weeks", "month", "months", "year", or "years").

 - Returns: An optional tuple containing the computed start and end dates, or `nil` if the dates could not be calculated.
 */
func getDateRange(past: Int, pastUnit: String, future: Int, futureUnit: String) -> (start: Date, end: Date)? {
    let calendar = Calendar.current
    let today = Date()

    func component(for unit: String) -> Calendar.Component? {
        let lower = unit.lowercased()
        if lower == "day" || lower == "days" { return .day }
        if lower == "week" || lower == "weeks" { return .weekOfYear }
        if lower == "month" || lower == "months" { return .month }
        if lower == "year" || lower == "years" { return .year }
        return nil
    }

    guard let pastComponent = component(for: pastUnit),
          let futureComponent = component(for: futureUnit) else {
        print("\(ANSI.red)Invalid unit type. Use 'day(s)', 'week(s)', 'month(s)', or 'year(s)'.\(ANSI.reset)")
        return nil
    }

    guard let startDate = calendar.date(byAdding: pastComponent, value: -past, to: today),
          let endDate = calendar.date(byAdding: futureComponent, value: future, to: today) else {
        return nil
    }

    return (startDate, endDate)
}

/// Formats a TimeInterval into a human-readable string.
func format(interval: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .full
    return formatter.string(from: interval) ?? ""
}

/// Displays detailed information about the computed date range using ANSI colors and formatting.
func displayDateRangeInfo(start: Date, end: Date) {
    let today = Date()
    let totalInterval = end.timeIntervalSince(start)
    let beforeToday = today.timeIntervalSince(start)
    let afterToday = end.timeIntervalSince(today)

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .full
    dateFormatter.timeStyle = .short

    print("\(ANSI.bold)\(ANSI.cyan)Date Range Information:\(ANSI.reset)")
    print("\(ANSI.bold)\(ANSI.cyan)-----------------------\(ANSI.reset)")
    print("\(ANSI.bold)Start Date:\(ANSI.reset) \(ANSI.magenta)\(dateFormatter.string(from: start))\(ANSI.reset)")
    print("\(ANSI.bold)End Date:  \(ANSI.reset) \(ANSI.magenta)\(dateFormatter.string(from: end))\(ANSI.reset)")
    print("\(ANSI.bold)Total Length:\(ANSI.reset) \(ANSI.green)\(format(interval: totalInterval))\(ANSI.reset)")
    print("\(ANSI.bold)Started:\(ANSI.reset) \(ANSI.yellow)\(format(interval: beforeToday))\(ANSI.reset) before today")
    print("\(ANSI.bold)Ends:   \(ANSI.reset) \(ANSI.yellow)\(format(interval: afterToday))\(ANSI.reset) after today")
}

// MARK: - Main Execution

// Define date range using the utility function with different units for past and future.
// Example: Get events from 1 week ago to 1 month ahead.
guard let dateRange = getDateRange(past: 2, pastUnit: "days", future: 1, futureUnit: "week") else {
    fatalError("Failed to compute date range")
}

displayDateRangeInfo(start: dateRange.start, end: dateRange.end)

let extractor = EventExtractor()
extractor.requestAccessAndFetchAllEvents(startDate: dateRange.start, endDate: dateRange.end)

// Wait until asynchronous operations are complete, then write JSON and exit.
extractor.dispatchGroup.wait()
extractor.writeEventsToJSONFile()
exit(0)
