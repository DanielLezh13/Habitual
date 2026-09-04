# Habitual (iOS)

Habitual is a SwiftUI habit-tracking app that combines quick, precise habit logging, sleep tracking, and Apple Health-style interactive insights charts in a mobile-first experience.

## Live Demo

- [Appetize Demo (iPhone 17 Pro Max)](https://appetize.io/app/b_jcw3saojl7d2a4onr7ed4gursy?device=iphone17promax&osVersion=26.0&toolbar=true)
- [LinkedIn Media Redirect](https://daniellezh13.github.io/Habitual/linkedin-demo/)

## Demo Videos

### Tracker Pages

https://github.com/user-attachments/assets/8f73cfb7-49ba-4392-8a03-bbca37186854

### Inight page

https://github.com/user-attachments/assets/b7215407-4eb7-4ee8-8ae3-2a808747aace

## What You Can Track

- Sleep
- ZYN
- Coffee
- Tea
- Cigarette
- Vape
- Drink
- Water
- Meal
- Cannabis

## Core Features

- One-tap logging for active tracker pages.
- Add/remove tracker pages (up to 5 active addable pages at once) and hide/show the built-in Sleep page.
- Sleep tracking with ongoing and manual-style sleep log history.
- Insights charts with day/week/month/year range views.
- Full mixed history view (sleep + all trackers) with swipe-to-delete and confirmed clear-all.

## Tech Stack

- `SwiftUI`
- `Combine` (`ObservableObject` store architecture)
- Local JSON persistence
- Custom chart rendering and gesture handling

## Run Locally

1. Open `ZynSleep.xcodeproj` in Xcode.
2. Select an iOS Simulator or physical iPhone.
3. Build and run.

## Install on a Personal iPhone

1. In Xcode, sign in under **Xcode > Settings > Apple Accounts**.
2. Connect and unlock the iPhone, trust the Mac if prompted, and enable Developer Mode on the iPhone if Xcode requests it.
3. Select the `ZynSleep` target, open **Signing & Capabilities**, leave **Automatically manage signing** enabled, and select your team.
4. Keep the existing `com.daniel.zynsleep` bundle identifier when reinstalling over an older copy so the app can retain its local data.
5. Select the iPhone as the run destination and choose **Product > Run**.

With a free Personal Team, Apple expires the development provisioning profile after seven days. Rebuild and run from Xcode again to renew it. Do not delete the expired app first if you want to preserve its local logs. TestFlight is the longer-lived beta option for an Apple Developer Program membership; each TestFlight build can be tested for up to 90 days.
