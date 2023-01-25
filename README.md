# mpv-touch-gestures

### Touch gestures for mpv

Configuration and extension of [pointer-event](https://github.com/christoph-heinrich/mpv-pointer-event) to improve the usability of mpv on touch devices.

Also works with mouse input, but the primary focus is touch.

## Features

* Single click/tap pauses/unpauses the video.
* Long click/tap opens the menu.
* Double click/tap on the left or right third to seek 10 seconds.
* Double click/tap on the middle third cycles fullscreen.
* Drag/swipe vertical on the left half to change speed.
* Drag/swipe vertical on the right half to change volume.
* Drag/swipe horizontal to seek.
* [uosc](https://github.com/tomasklaen/uosc) integration

## Installation

1. Install [pointer-event](https://github.com/christoph-heinrich/mpv-pointer-event)
2. Save the `touch-gestures.lua` into your [scripts directory](https://mpv.io/manual/stable/#script-location)
3. Save the `pointer-event.conf` into your `script-opts` directory (next to the [scripts directory](https://mpv.io/manual/stable/#script-location), create if it doesn't exist)
The preconfigured `margin_*` values in `pointer-event.conf` work well with the default configuration of [uosc](https://github.com/tomasklaen/uosc).