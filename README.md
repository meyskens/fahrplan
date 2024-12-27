# Fahrplan

Fahrplan is a "life assistant" that is made for the Even Realities G1 smartglasses. It is an opinionated half reverse engineered addition go the G1. It focusses less on (or not on generative) AI and more on a day to day life assistant for neurodiverse people like myself.

The name "Fahrplan" comes from the german word for "bus/train/conference schedule". It takes the concept of a "next stops" screen you see on public transport to plan for daily tasks and schedule. Thus the idea for this name.

While it is meant to offer an "OS" for the Even Realities G1 and will copy some of the original functionality like notifications it is not designed to be a full smartglasses OS.

## Why the G1 specifically?

Simple: they are the only glasses with display that fit my face and are able to ship my prescription. That's it.

## Supported OSes?

- Android (primary development)
- iOS (probably works as no native code is used)
- Linux will not work: experiments have been done with Bluez but BLE notifications are buggy, sorry 

## Thanks
Thanks to @emingenc and @NyasakiAT for their work in building the G1 BLE libraries 
- https://github.com/emingenc/even_glasses (The most complete library!)
- https://github.com/emingenc/g1_flutter_blue_plus/tree/main (The foundations for the Dart implementation)
- https://github.com/NyasakiAT/G1-Navigate (Further development of the Dart implementation and BMP composing code)

## Copy me!

Sadly time constraints permit me from making some of my code into proper maintained Dart libraries. Please copy as much code as you want into your applications! Expanding the G1 open source ecosystem is better for everyone!