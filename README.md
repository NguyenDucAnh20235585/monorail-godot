# MONORAIL — by ZenZeros7128 & Nice Nature, with help from 3sori

> **24 tiles. Two players. One loop.**
>
> If you think the track cannot be completed, say it.
> Then watch the other player prove you wrong.

**MONORAIL** is a two-player turn-based strategy game inspired by the **Monorail game from *The Genius***.

This is not a game about placing railway tiles nicely.

It is a game about committing to a path, reading what your opponent is building, and knowing exactly when to say:

> **"Impossible."**

---

## Idea

Two players share the same set of **24 railway tiles**.

Each normal turn, a player places **1–3 tiles**, gradually building a complete railway loop through the two starting stations.

A tile can be:

- **Straight**
- **Corner**

Tracks may remain open while the board develops, but an open rail cannot point directly into the closed side of an adjacent tile.

If multiple tiles are placed in the same turn, they must form one orthogonally connected group.

A closed railway loop is only valid when:

- it passes through both starting stations;
- every railway tile currently on the board belongs to that loop;
- there are no extra railway tiles or separate closed loops.

The player who completes the valid final loop wins.

Simple enough.

Until somebody decides the board cannot be solved.

---

## Impossible

At the **beginning of a turn**, before placing any pending tiles, a player may declare:

> **IMPOSSIBLE**

The opponent then becomes the **Challenger**.

The normal three-tile placement limit disappears, and the Challenger receives the remaining tiles to prove that the railway can still be completed.

- Complete a valid loop → **Challenger wins**
- Run out of tiles without completing it → **Declarer wins**
- Give up → **Declarer wins**

During an Impossible challenge, the Challenger keeps control of the turn and may continue placing tiles until the challenge is resolved.

There is no automatic exact solver deciding whether a human player's declaration is correct.

You made the claim.

Your opponent gets the chance to prove you wrong.

And possibly humiliate you for it.

---

## Game Modes

### Local PVP

Two players take turns on the same machine.

Classic couch warfare.

### PVE

Play against the current AI opponent.

The AI can:

- generate legal moves;
- search for promising placements;
- complete winning loops;
- challenge Impossible declarations;
- declare Impossible using heuristic evaluation.

For PVE, the player can choose:

- **Go First**
- **Go Second**
- **Random**

The AI is still being tuned, so questionable life decisions are expected.

---

## Controls — for now

| Action | Control |
|---|---|
| Select tile type | `Straight` / `Corner` |
| Place tile | Click a highlighted cell |
| Select pending tile | Click the tile |
| Rotate selected tile | `Rotate` |
| Cancel pending move | `Cancel` |
| Commit move | `Confirm` |
| Declare the board impossible | `Impossible` |
| Concede during Impossible challenge | `Give Up` |
| Pan board | Hold Left Mouse + Drag |
| Zoom | Mouse Wheel |
| Pause / Back | `Esc` |

`Esc` opens the Pause Menu during gameplay and is also used to return from Settings.

---

## Current Build

### v0.1.0-alpha

The current version supports:

- Local PVP
- PVE against AI
- First / Second / Random starting choice
- Infinite board navigation
- Tile placement and rotation
- 1–3 tile normal turns
- Multi-tile connected placement
- Move validation
- Track-edge validation
- Invalid closed-loop prevention
- Final-loop win validation
- Turn management
- Impossible declaration
- Challenger mode
- Unlimited Challenger placement
- Challenger Give Up
- AI Impossible challenge
- AI Impossible declaration
- AI recovery against invalid/no-action states
- Automatic zero-tile Impossible resolution
- Game log
- Pause Menu
- Settings navigation
- Play Again
- Back to Menu
- Windows build
- Automated core tile-logic tests

It is playable.

It is also an alpha.

Please behave accordingly.

---

## Under the Hood

Built with:

- **Godot 4**
- **GDScript**
- **Git / GitHub**

The project separates gameplay state, validation, and presentation wherever practical.

Core systems include:

- `GameState`
- `Move`
- `PendingMove`
- `MonoTile`
- `MoveValidator`
- `PlacementHelper`
- `RulesEngine`
- `WinChecker`
- `ImpossibleFlow`
- `MoveGenerator`
- `AIPlayer`
- `GameSession`

The game uses a grid-based board and deterministic move/state structures.

The architecture is being kept modular so that future systems such as multiplayer, serialization, and improved AI can be added without rewriting the entire gameplay layer.

At least that's the plan.

---

## Alpha Testing

The current goal is not to pile on features.

The goal is to find out whether the game actually survives other human beings.

If you encounter a bug, soft-lock, confusing interaction, or questionable rule situation, please note:

- what you were doing before it happened;
- what you expected to happen;
- what actually happened;
- whether you were playing **PVP or PVE**;
- if PVE, who went first;
- screenshot or video if possible.

Feedback is especially useful for:

- rule clarity;
- possible exploits;
- Impossible flow;
- AI behavior;
- AI difficulty;
- controls;
- camera movement;
- confusing UI;
- situations where the game gets stuck.

---

## What's Next

The obvious answer would be:

> **"Multiplayer."**

The responsible answer is:

> **"Playtest first."**

Current priorities:

1. Collect tester feedback
2. Fix gameplay blockers and soft-locks
3. Fix rule exploits
4. Improve controls and onboarding
5. Tune the AI
6. Polish UI / UX
7. Revisit the visual direction

After the core game is proven stable, future experiments may include:

- online multiplayer;
- room-based matches;
- persistent / asynchronous matches;
- stronger AI;
- additional settings and control options;
- general visual and audio polish.

No promises.

Good games survive playtests before they survive roadmaps.

---

## Inspiration

MONORAIL is inspired by the **Monorail game featured in the Korean television show *The Genius***.

This project is an independent fan-made interpretation created for learning and experimentation and is **not affiliated with or endorsed by the original show or its rights holders**.

Also, go watch *The Genius*.

Season 4 is peak entertainment.

Season 1 is pretty damn good too, imo.

---

## Status

### **Playable Alpha — v0.1.0**

### Download

https://drive.google.com/drive/folders/14oILM4MmHQI9RbFGiJ-QaBLY35Dh_tT6?usp=drive_link

Current target:

> **Play it. Break it. Tell us how you broke it.**

The rules work.

The game flow works.

The AI works... most of the time.

The art direction is awaiting judgment.

The players are not.
