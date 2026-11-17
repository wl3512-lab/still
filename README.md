# still

An on-device iPhone camera coach (Xcode name: FrameGuide). It's rule-based and works offline, and it gives one plain-language move at a time so casual shooters ("the noticer") get the shot without having to learn photography.

This repo holds the **design source** so far: the audience board, the six interface rules, and the interactive prototype. The native Swift app isn't built yet.

## What's here

- `project/Main.dc.html` is the interactive prototype (390×844). The other phone boards import it with a `start` prop to freeze one state:
  Permission → Spotting → Guiding → Aligned → Captured, plus Hints, Quiet, Unsure and OffTarget.
- `project/Audience.dc.html` covers who it's for: the noticer, three moments, push/pull/worry/habit, and who it's not for.
- `project/Principles.dc.html` has the six rules, where still sits among other apps, and the research pass marks.
- `project/canvas.json` is the board layout and the canvas notes.

The `.dc.html` files come from a Claude Design canvas and rely on its runtime (`support.js`), so they won't fully render if you open them straight from disk. To see them live, use the canvas: https://claude.ai/artifact/G6yAW4dFjGXRi2sYeh3Wio

## Core rules

1. Seconds, not settings
2. One thing at a time
3. Show, then say
4. Coach, never judge
5. Honest when unsure
6. Fade as you learn
