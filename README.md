# MONORAIL - by ZenZeros7128 and Nice Nature, and the help of 3sori

> **24 tiles. Two players. One loop.**
> If you think the track cannot be completed, say it.
> Then watch the other player prove you wrong.

**MONORAIL** is a two-player turn-based strategy game inspired by the **Monorail game from *The Genius***.
This is not a game about placing railway tiles nicely.
It is a game about committing to a path, reading what your opponent is building, and knowing exactly when to say:
**"Impossible."**

---
## Idea
Two players share the same set of railway tiles.
Each turn, a player places **1–3 tiles**, building toward a complete railway loop through the two starting stations.
A tile can be:
- **Straight**
- **Corner**
Tracks may remain open while the board develops, but a rail cannot run directly into the closed side of another tile.
The player who completes the valid loop wins.
Simple enough.
Until somebody decides the board cannot be solved.
---

## Impossible
At the beginning of a turn, a player may declare the current board:
> **IMPOSSIBLE**
The opponent then becomes the **Challenger**.
The normal three-tile limit disappears.
The Challenger receives the remaining tiles and must prove that the railway can still be completed.

- Complete the loop → **Challenger wins**
- Run out of tiles → **Declarer wins**
- Give up → **Declarer wins**

There is no algorithm deciding whether the board is impossible.
You made the claim.
Your opponent gets the chance to humiliate you for it.
---

## Controls - for now

| Action | Control |
|---|---|
| Select a tile | `Straight` / `Corner` |
| Place tile | Click a highlighted cell |
| Select pending tile | Click the tile |
| Rotate tile | `Rotate` |
| Cancel pending move | `Cancel` |
| Commit move | `Confirm` |
| Declare the board impossible | `Impossible` |
| Concede during Impossible review | `Give Up` |
| Pan board | Hold Left Mouse + Drag |
| Zoom | Mouse Wheel |
| Quit | `Esc` |
---

## Current Build
### Hotseat Beta v0.1

The current version supports:
- 2-player local hotseat
- Infinite board navigation
- Tile placement and rotation
- 1–3 tile normal turns
- Move validation
- Track-edge validation
- Turn management
- Win detection
- Impossible declaration
- Unlimited Challenger placement
- Challenger Give Up
- Game log
- Play Again / Back to Menu
- Windows build

It is playable.
It is also a beta.
---

## Under the Hood

Built with:
- **Godot 4**
- **GDScript**
- **Git / GitHub**

The project separates gameplay state and rules from presentation wherever possible.
Core systems include:
- `GameState`
- `Move`
- `PendingMove`
- `MoveValidator`
- `PlacementHelper`
- `RulesEngine`
- `WinChecker`
- `ImpossibleFlow`

The current build is local hotseat, but the state/move architecture is being designed with future multiplayer support in mind.
---

## What's Next
The obvious answer would be "multiplayer."
The responsible answer is:
**playtest first.**

Current priorities:
- collect gameplay feedback
- fix rule and interaction problems
- rethink the visual direction
- improve onboarding
- then begin multiplayer architecture

Future experiments may include:
- online multiplayer
- room-based matches
- persistent / asynchronous matches
- AI opponents

No promises.
Good games survive playtests before they survive roadmaps.
---

## Inspiration
MONORAIL is inspired by the **Monorail game featured in the Korean television show *The Genius***.
This project is an independent fan-made interpretation created for learning and experimentation and is not affiliated with or endorsed by the original show or its rights holders.
And u guys can watch The Genius, especially season 4, it's peak entertainment with mind-blowing scenes. SS1 is good too imo
---

## Status

**Playable Hotseat Beta — v0.1**
https://drive.google.com/drive/folders/14oILM4MmHQI9RbFGiJ-QaBLY35Dh_tT6?usp=drive_link

The rules work.
The UI works.
The art direction is awaiting judgment.
The players are not.
