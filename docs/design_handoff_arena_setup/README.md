# Handoff: Arena Match Setup Flow (Godot)

## Overview
Pre-match setup flow for a Godot arena PvP tactical RPG (Divinity: Original Sin-style). Players configure a free-for-all match: number of players (1-4), champions per player (1-4), then each player drafts unique classes for their champions, readies up, and sees a final roster confirmation before battle starts.

## About the Design Files
The bundled file **Arena Match Setup.dc.html** is a **design reference built in HTML/React** — it shows exact layout, color, typography, and interaction behavior. It is NOT code to port line-for-line. Recreate this UI natively in Godot using **Control nodes + a Theme resource + GDScript**, following the existing patterns/scenes already in the Godot project. If the project has no UI scene structure yet, set one up (e.g. a `MatchSetup.tscn` with child scenes/states for each screen).

## Fidelity
**High-fidelity.** Colors, type sizes, spacing, and states below are exact — recreate pixel-close in Godot's Control/Theme system, adapted to whatever resolution/UI scale the game targets (design was authored at a 16:9 desktop reference).

## Screens / Views

### 1. Setup Screen
**Purpose:** Choose match size before drafting.
- Centered vertical column, generous gaps (~48px between groups).
- Header block: small eyebrow label "FREE-FOR-ALL ARENA" (letter-spacing 6px, 20px, accent-red), then large title "SET UP THE MATCH" (46px bold, letter-spacing 3px).
- Two identical selector groups, stacked: "NUMBER OF PLAYERS" and "CHAMPIONS PER PLAYER" (14px label, letter-spacing 3px, muted).
  - Each group: row of 4 cards (values 1-4), 150px wide, ~22px/16px padding, 1px border, dark panel background. Unselected border is neutral dark gray; selected border + number color switch to bright/gold. Big number (38px bold) + small caption below ("PLAYER" / "PLAYERS", "CHAMPION" / "CHAMPIONS" — singular/plural).
- Bottom: solid gold "CONTINUE" button (18px bold, letter-spacing 3px, dark text on gold fill), brightens on hover.

### 2. Draft Screen
**Purpose:** Each player independently picks a unique class per champion slot.
- Top bar (96px): back arrow left ("← BACK", returns to Setup), centered title "DRAFT YOUR WARBAND" (28px bold), right-aligned summary "{N} PLAYERS · {M} EACH".
- Main area: one vertical panel per player, side by side, divided by thin 1px vertical rule (dark gray) between panels — panel count = player count (1-4), each flexes equally.
  - Panel header: player label ("PLAYER ONE"/"TWO"/"THREE"/"FOUR", colored in that player's accent hue) + a READY toggle button on the opposite side (right-aligned for P1, left-aligned for P2 — mirror layout outward from center).
  - Slot row: one 60×60px square per champion slot. Empty = dashed border, "+" glyph. Filled = solid tile with 2-letter class code, accent-colored border.
  - Class list: single-column list of all 8 classes below the slots, scrollable if it overflows. Each row: 36×36 icon tile (2-letter code, accent-tinted) + class name (11.5px bold serif) + role tag (9px muted). Clicking a class assigns it to the player's next empty slot; clicking again (or clicking a filled slot) removes it. A class already used by that player is highlighted (accent-tinted background + border); a class unavailable because all slots are full is dimmed to 40% opacity. Classes are NOT shared/blocked across players — two players may draft the same class.
- READY button: disabled/dim until all of that player's slots are filled. Click toggles ready (locks that player's picks — clicking classes/slots does nothing while ready); label reads "PICK ALL" → "READY" → "WAITING…".
- Bottom center: "BEGIN BATTLE" button (440×64px), dim/disabled until **every** player is ready; becomes solid gold and clickable once all are ready → advances to Confirm screen.

### 3. Confirm Screen
**Purpose:** Final roster review before entering the arena.
- Centered eyebrow "THE GATES OPEN" (16px, letter-spacing 6px) + title "CHAMPIONS ASSEMBLED" (40px bold).
- Row of roster panels, one per player, divided by thin vertical rules — same player order/colors as draft. Each panel: player label, then a vertical list of that player's picked champions (icon tile + name + role), player 2+ mirrored/right-aligned text for visual symmetry when only 2 players.
- Bottom: solid gold "ENTER ARENA" button (360×64px, final CTA — hands off to actual battle scene) + a muted "Back to draft" text link beneath it.

## Interactions & Behavior
- **Card selection** (party size / champ count): click sets the value immediately, no confirmation needed.
- **Class pick**: click unpicked class → fills player's first empty slot. Click a picked class, or click a filled slot square, → clears that slot. No-op if all slots already full and class isn't already picked.
- **Ready lock**: while a player is "ready", their class list and slots are inert (clicks ignored) until they un-ready by clicking the READY button again.
- **Begin Battle**: only enabled when every player's ready flag is true.
- **Navigation**: Setup → Draft → Confirm, each with a back action (Draft's back returns to Setup and **resets all picks**; Confirm's back returns to Draft **keeping** current picks/ready state).
- Hover states: card borders brighten to gold-accent on hover; buttons brighten on hover; text links lighten on hover.
- No animations/transitions in the reference — instant state swaps between screens.

## State Management
- `step`: enum `setup | draft | confirm`
- `playerCount`: int 1-4
- `champCount`: int 1-4 (champions per player)
- `teams`: array of `playerCount` arrays, each of length `champCount`, holding a class id or null per slot
- `readies`: array of `playerCount` booleans
- Transition Setup→Draft (re)initializes `teams` to all-null arrays of the chosen sizes and resets `readies` to false.
- Transition Draft→Confirm only fires when `readies.every(true)`.

## Design Tokens

### Colors (hex, converted from the source oklch values — see file for exact oklch if your pipeline supports it)
| Token | Hex | Use |
|---|---|---|
| bg-base | #090504 | page background (dark end of radial gradient) |
| bg-radial-outer | #1e130f | page background (light end of radial gradient, top-center) |
| panel-bg | #180f0d | option cards, roster rows |
| panel-bg-alt | #140e0b | unpicked class row background |
| icon-tile-bg | #281c18 | class/roster icon tile background |
| icon-tile-border | #49352f | class icon tile border |
| border-default | #3b2922 | panel/card borders |
| border-unselected | #402e27 | unselected setup-card border |
| border-divider | #322621 | vertical dividers between panels, header rule |
| border-ready-inactive | #56423c | ready button border when slots incomplete |
| begin-disabled-bg | #231814 | Begin Battle button, disabled state |
| text-primary | #eae3de | primary body text |
| text-bright | #e3ddd8 | filled slot code text |
| text-muted | #9a8c85 | secondary labels |
| text-disabled | #6d6059 | disabled text |
| text-on-gold | #0c0806 | text on gold-filled buttons |
| accent-gold | #b47900 | primary CTA color, Player 2 identity, selected-state highlight |
| accent-gold-hover | #ce9200 | CTA hover |
| accent-red (Player 1) | #ca5551 | Player 1 identity color |
| accent-teal (Player 3) | #0099a3 | Player 3 identity color |
| accent-violet (Player 4) | #9565c7 | Player 4 identity color |
| picked-bg-p1..p4 | #331513 / #2b1c00 / #002629 / #251932 | tinted background of a class row once picked, per player |

All 4 player accents share the same OKLCH lightness (0.6) and chroma (0.15), varying only hue (25° red / 80° gold / 200° teal / 305° violet) — keep that relationship if you retint.

### Typography
- Display/UI labels: **Cinzel** (serif, all-caps headers, class names, buttons, badges) — weights 500/600/700.
- Body/copy: **Work Sans** — weights 400/500/600.
- Scale used: 9px (fine print) · 10.5-11.5px (class name/role) · 13-16px (labels) · 18-20px (buttons/eyebrows) · 28-46px (titles).
- Letter-spacing: headers/labels typically 1.5-6px tracked out; body text untracked.

### Spacing / Sizing
- Setup cards: 150px wide, 22px/16px padding.
- Slot squares: 60×60px (draft), gap 10-12px.
- Class icon tiles: 36×36px (draft), 40-52px (confirm roster).
- Top bar height: 96px. Begin Battle button: 440×64px. Enter Arena button: 360×64px.
- Borders: 1px throughout (solid for filled/active states, dashed for empty slots).
- No rounded corners anywhere in this design — all edges are square (deliberate, tactical/military feel).

## Assets
No external image/icon assets — all "icons" are 2-letter monogram codes on flat-colored square tiles (WB, SH, PY, CR, DS, WR, ST, PL for the 8 placeholder classes: Warbringer, Shadowblade, Pyromancer, Cryomancer, Deathspeaker, Windrunner, Stoneward, Plaguebringer). Replace with real class portraits/icons when available — keep the square tile framing.
Fonts: Google Fonts "Cinzel" and "Work Sans" (both free/open license, safe to bundle as .ttf in the Godot project).

## Files
- `Arena Match Setup.dc.html` — full interactive reference (open in a browser to click through all 3 screens and see hover/state behavior live).
