# App Store Connect text

Copy-paste text for Dock Finder's TestFlight and App Store pages.

- **Privacy Policy URL:** https://github.com/dock-finder/citibike-smart-dock-assistant/blob/main/docs/privacy.md
- **Support URL:** https://github.com/dock-finder/citibike-smart-dock-assistant/blob/main/docs/support.md

## TestFlight → Test Information

**Beta App Description** (up to 4,000 characters)

> Dock Finder helps Citi Bike riders in New York City find an open dock before they arrive, without taking out their phone. Start a ride with Siri ("Ask Dock Finder to start a ride to School") and Dock Finder checks live dock availability as you get close. If your usual dock is full, it tells you the nearest one with room and can guide you there with spoken turn-by-turn directions. You can also ask about any station, find a dock near you or a saved place, and see the time and money Dock Finder has saved you.

**Feedback Email:** dbh2054@stern.nyu.edu

**Marketing URL:** leave blank.

**Privacy Policy URL:** see the top of this page.

**Beta App Review Information**
- **Sign-in required:** No. Dock Finder has no accounts.
- **Contact:** your name, phone and dbh2054@stern.nyu.edu.
- **Review Notes:**

> Dock Finder is for Citi Bike, New York City's bike share. Its dock suggestions use Citi Bike's live public station feed, so they're most meaningful with a location in New York City. Outside NYC the app still runs but finds no nearby docks.
>
> To test without being in NYC:
> 1. On the home screen, save a place with an NYC address, for example "School" at 44 West 4th Street, New York, NY, and choose a usual dock.
> 2. Ask Siri "Ask Dock Finder to check my School dock" or "Ask Dock Finder how many bikes are out". Both answer from the live feed, wherever you are.
> 3. Ask Siri "Ask Dock Finder to start a ride to School". The ride starts and a Live Activity appears. The arrival alert itself only fires near the place.
>
> Permissions: Always location lets Dock Finder speak a dock suggestion with the phone locked during a ride, and guide the rider turn by turn. Background audio is used only to speak those alerts and directions. Motion & Fitness is used on device to tell biking from walking, so alerts don't fire on foot.
>
> Usage data: at first launch the app asks whether to share usage data, including location, with the development team. It's off unless the user taps Share Usage Data, and it can be turned off under Privacy on the home screen.

## TestFlight → each build → What to Test

> First external build. Please try:
> - Saving a place (Home, Work, School) and picking a usual dock
> - "Ask Dock Finder to start a ride to …" on a real ride, phone in your pocket
> - "Ask Dock Finder to direct me there" after a dock suggestion
> - "Ask Dock Finder to find a dock near me"
>
> Tell us when Siri runs the wrong action, an alert comes too early or too late, or a suggested dock was actually full. Take a screenshot in the app to send feedback.

## App Store (only when submitting to the App Store)

**Subtitle** (30 characters): `Hands-free bike share docking`

**Promotional Text:** `Ride with your phone in your pocket. Dock Finder tells you where there's room before you get there.`

**Description**

> Never circle a full Citi Bike station again.
>
> Dock Finder checks live dock availability as you ride and tells you where to dock before you arrive, out loud, with your phone locked in your pocket.
>
> START A RIDE WITH SIRI
> "Ask Dock Finder to start a ride to work." When you get close, Dock Finder checks your usual dock. If it's full, it tells you the nearest one with room.
>
> TURN-BY-TURN TO THE DOCK
> "Ask Dock Finder to direct me there" for spoken directions to the dock, with progress on your Lock Screen.
>
> ALERTS AT YOUR SAVED PLACES
> Bike up to Home, Work or School and Dock Finder tells you where to dock, even if you didn't start a ride. It only alerts you when you're biking.
>
> CHECK ANY STATION
> Ask whether a station has room, find a dock near you or near a saved place, or see how many bikes are out citywide.
>
> SEE WHAT YOU SAVE
> A dashboard shows the time and money Dock Finder estimates it has saved you.
>
> Dock Finder uses Citi Bike's public station data. It isn't affiliated with or endorsed by Citi Bike or Lyft.

**Keywords** (100 characters): `bike share,bikeshare,dock,nyc,bike,cycling,station,siri,commute,directions,new york,ebike`

Keywords leave out "Citi Bike" on purpose: App Review can reject trademarked names in keywords. Naming it factually in the description, with the disclaimer, is the usual practice.

**Category:** Navigation (primary), Travel (secondary)

**Age Rating:** answer "None" or "No" to every question → 4+

**Content Rights:** "Yes, it contains, shows or accesses third-party content", and confirm you have the rights. The content is Citi Bike's public GBFS station feed.

**Copyright:** `2026 Dock Finder team`

## App Privacy (nutrition label)

Answer **Yes, we collect data from this app**, then:

| Data type | Purpose | Linked to user? | Tracking? |
|---|---|---|---|
| Location → Precise Location | Analytics, App Functionality | No | No |
| Usage Data → Product Interaction | Analytics | No | No |
| Browsing History → Search History (the destination, place, station or request said to Siri) | Analytics | No | No |
| Diagnostics → Performance Data (how long answers take) | Analytics | No | No |
| Diagnostics → Other Diagnostic Data (why a request failed) | Analytics | No | No |
| Contact Info → Name | Analytics | No | No |
| User Content → Other User Content (free-form questions sent to the assistant server) | App Functionality | No | No |

"Linked to user: No" relies on the per-install ID not being tied to an account or real identity. The name is optional and free-form. If you'd rather be conservative, mark Name as **linked**.
