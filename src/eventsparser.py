import json
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def ConvertTimestamp(timestampStr: str) -> str:
    """
    Converts a UTC timestamp string to local time

    Parameters
    ----------
    timestampStr : str
        The ISO 8601 UTC timestamp string to convert.

    Returns
    -------
    str
        The formatted local time string.
    """

    dtUtc = datetime.fromisoformat(timestampStr)

    dtLocal = dtUtc.astimezone()

    formattedTarget = dtLocal.strftime("%a, %m-%d-%Y %I:%M:%S %p %Z")

    return formattedTarget

    # try:

    #     targetTzName = "Europe/London"
    #     targetTz = ZoneInfo(targetTzName)
    #     dtSpecificTz = dtUtc.astimezone(targetTz)

    #     print(
    #         f"\n--- Example: Converting to Specific Timezone ({targetTzName}) ---"
    #     )
    #     print(f"Converted to {targetTzName}:   {dtSpecificTz}")
    #     print(
    #         f"Formatted ({targetTzName}): {dtSpecificTz.strftime('%a, %m-%d-%Y %I:%M:%S %p %Z')}"
    #     )

    # except ZoneInfoNotFoundError:
    #     print(f"\nWarning: Could not find the specified timezone '{targetTzName}'.")
    # except Exception as eZi:
    #     print(f"\nError converting to specific timezone: {eZi}")


eventsPath = Path("../output/events.json")

if not eventsPath.exists():

    raise FileNotFoundError(f"File {eventsPath} not found")


with open(eventsPath, "r") as eventsFile:

    events = json.load(eventsFile)


if not isinstance(events, list):

    raise TypeError(f"Expected 'events' to be a list, got {type(events)}")

cleanedEvents = []

delKeys = [
    "alarms",
    "availability",
    "calendarItemExternalIdentifier",
    "calendarItemIdentifier",
    "timeZoneIdentifier",
    "isAllDay",
    "recurrenceRules",
    "creationDate",
    "lastModifiedDate",
]

for event in events:

    if not isinstance(event, dict):

        raise TypeError(
            f"Expected each item in 'events' to be a dictionary, got {type(event)}"
        )

    cleanedEvent = event.copy()

    # print(json.dumps(list(cleanedEvent.keys()), indent=4))

    # print(json.dumps(cleanedEvent, indent=4))

    for key in delKeys:

        if key in cleanedEvent:

            del cleanedEvent[key]

    # print(json.dumps(list(cleanedEvent.keys()), indent=4))

    cleanedEvents.append(cleanedEvent)


cleanedEventsPath = Path("../output/cleaned-events.json")

with open(cleanedEventsPath, "w") as cleanedEventsFile:

    json.dump(cleanedEvents, cleanedEventsFile, indent=4)

print(f"Cleaned {len(events)} events")
