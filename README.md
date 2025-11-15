# Fahrplan

Fahrplan is a "life assistant" that is made for the Even Realities G1 smartglasses. It is an opinionated half reverse engineered addition go the G1. It focusses less on (or not on generative) AI and more on a day to day life assistant for neurodiverse people like myself.

The name "Fahrplan" comes from the german word for "bus/train/conference schedule". It takes the concept of a "next stops" screen you see on public transport to plan for daily tasks and schedule. Thus the idea for this name.

While it is meant to offer an "OS" for the Even Realities G1 and will copy some of the original functionality like notifications it is not designed to be a full smartglasses OS.

## Features

### Core Functionality
* **Notification Mirroring**: Mirror notifications from whitelisted apps to your G1 glasses
* **Time & Weather**: Automatic updates of time and weather information on the dashboard
* **Calendar Integration**: Display calendar events on your glasses

### Dashboard Widgets
* **Daily Fahrplan**: A daily schedule presented in the G1 dashboard with timed tasks
* **Stops**: One-off timers that present immediate text messages for time-critical actions (e.g., "leave for work")
* **Checklists**: Persistent to-do lists displayed on your dashboard
* **WebViews**: Custom web content widgets that can be displayed on demand
* **[Träwelling](https://traewelling.de/) Integration**: Real-time train info including next stops and delays

### Voice Control
Voice commands can be triggered by holding the left button (Even AI) or using **wake word detection**:

* **Wake Word Detection**: Say "Okay Glass" to activate voice control (supports Porcupine and Snowboy engines)
* **Music Control**: Play, pause, next, previous, and query what's playing
* **Checklist Management**: Open/close checklists by voice (e.g., "open checklist shopping")
* **WebView Management**: Show/hide custom web content (e.g., "show webview transit")
* **HomeAssistant**: Send commands to HomeAssistant by voice

### Advanced Features
* **Train Conductor Mode**: Enhanced Träwelling features for conductors
* **Debug Screen**: Testing interface with fun extras like Bad Apple video (unzip `assets/badapple.zip` first)

## Get it!

- Latest build of the main branch: [Android APK](https://nightly.link/meyskens/fahrplan/workflows/build_apk.yml/main/app-release.apk.zip)

## Why the G1 specifically?

Simple: they are the only glasses with display that fit my face and are able to ship my prescription. And are not bulky or spy on you. That's it.

## Supported OSes?

- Android (primary development)
- iOS (probably works in simple tasks, notifications and permissions will need work!)
- Linux will not work: experiments have been done with Bluez but BLE notifications are buggy, sorry 

## Thanks
Thanks to @emingenc and @NyasakiAT for their work in building the G1 BLE libraries, also thanks a lot to benny04409 for helping with reverse engineering the firmware.
- https://github.com/emingenc/even_glasses (The most complete library!)
- https://github.com/emingenc/g1_flutter_blue_plus/tree/main (The foundations for the Dart implementation)
- https://github.com/NyasakiAT/G1-Navigate (Further development of the Dart implementation and BMP composing code)

## Copy me!

Sadly time constraints permit me from making some of my code into proper maintained Dart libraries. Please copy as much code as you want into your applications! Expanding the G1 open source ecosystem is better for everyone!
