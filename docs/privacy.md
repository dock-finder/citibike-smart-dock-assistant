<!-- Published as a public Google Doc; see docs/app-store-connect.md for the link. Keep the two in sync. -->

# Dock Finder Privacy Policy

_Last updated: October 20, 2026_

Dock Finder is an iPhone app, currently in testing, that helps Citi Bike riders in New York City find an open dock and get to it hands-free. This policy explains what the app collects, where it goes, and the choices you have. Questions go to **dbh2054@stern.nyu.edu**.

## The short version

- Dock Finder works without an account. We never ask for your email, phone number or Apple ID.
- **Usage sharing is off unless you turn it on.** If you agree to share, the app sends the Dock Finder team a record of how you use it, including your location at the time. If you don't, none of that leaves your iPhone.
- We don't sell your data, use it for ads, or track you across other apps or websites.

## What stays on your iPhone

These are stored only on your device, whether or not you share usage data:

- **Saved places** (like "Home" or "School") and their locations. They're also backed up in your iPhone's keychain so they survive reinstalling the app. Deleting a place in the app removes it from the backup too.
- **Your savings history**, the time and money Dock Finder estimates it saved you.
- **Rides and directions in progress.**
- **Motion activity.** Dock Finder asks iOS whether you're biking, so it only alerts you when you ride (not walk or take the subway) up to a saved place. That answer is used on the device and never sent anywhere.

## What's sent when you share usage data

When you choose **Share Usage Data**, during setup or later under **Privacy** on the home screen, the app sends events to the Dock Finder team's Google Sheet. An event is sent when you open the app, start or end a ride, get a dock alert or Siri answer, answer one of Siri's follow-up questions, start or stop directions, change your sharing settings, or when a request to Dock Finder fails. Each event can include:

- **A random ID** made on your iPhone when you installed the app. It isn't linked to your name, email, Apple ID or device serial number.
- **A name, only if you entered one.** It's optional and can be anything, so testers can be told apart.
- **Your precise location** at the time of the event.
- **The ride's destination**, including its name and location. If the destination is a saved place like "Home", that place's name and location are included.
- **The docks involved**, such as the dock suggested and any full dock it steered you away from.
- **The answer the app gave you**, and the time and money it estimates it saved you.
- **What you asked Siri for**, as Siri heard it: the destination, place or station you named, or your whole request when you use "Ask Dock Finder a question". Also whether you said yes to a follow-up like "Want me to direct you there?". Never a recording.
- **Whether a request failed and why**, such as no location access, no internet, or a place that couldn't be found, plus how long the answer took and how old your location was.
- **The app version** and when the event happened.

We use this to measure how riders use Dock Finder, what it saves them, and what doesn't work. Only the Dock Finder team can see the sheet. It's stored in Google Sheets, which Google operates under its own privacy policy.

**Turning sharing off** stops all new events and deletes any events your iPhone hasn't sent yet. To have events that were already sent deleted, email **dbh2054@stern.nyu.edu** with the name you entered (if any) and roughly when you used the app, and we'll remove them.

## Other services the app uses

Some features need outside services. These run whether or not you share usage data.

| Service | What it receives | Why |
|---|---|---|
| **Citi Bike's public station feed** (Lyft) | A standard web request. No personal information. | Live dock and bike availability. |
| **Apple Maps** | Places you search for, and your location and the dock's for directions. | Finding places and turn-by-turn directions. Covered by Apple's privacy policy. |
| **Siri and Apple Intelligence** | What you say to Siri. Dock Finder's on-device model runs on your iPhone. | Voice requests. Handled by Apple under its privacy policy. |
| **Dock Finder's assistant server** (n8n), with **OpenAI** and **OpenStreetMap** | Only questions the app can't understand on your iPhone: the text of the question, your location, and the random ID. The server sends the question's text to OpenAI to interpret it, and place names to OpenStreetMap to find them. | Answering free-form questions. Most requests never reach it. |

## Children

Dock Finder isn't directed at children under 13, and we don't knowingly collect information from them.

## Changes

If this policy changes, we'll update this page and the date above, and mention it in the TestFlight notes for the build that changes it.

## Contact

**dbh2054@stern.nyu.edu**
