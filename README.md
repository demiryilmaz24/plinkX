# Last Marble

**A story-driven 2D Plinko and incremental/idle game developed with Godot 4.7 and GDScript.**

Last Marble follows Tekin, a man who visits a Plinko arcade every day in an attempt to pay off his debt. Players drop marbles, earn money, purchase upgrades, unlock automation, collect special items, and make financial decisions as the story progresses.

The project combines arcade gameplay with incremental progression, economy balancing, interactive story events, and bilingual localization.

## Technical Overview

| Category | Details |
|---|---|
| Game Engine | Godot 4.7 |
| Main Language | GDScript |
| Additional Tools | Python 3 |
| Genre | 2D Plinko, Incremental / Idle, Story-driven |
| Platform | PC |
| Supported Languages | English and Turkish |
| Art Style | Pixel art |
| Save System | Automatic saving every 15 seconds and on exit |

## Key Features

- **Plinko gameplay:** Drop marbles onto a board and earn rewards based on their landing positions.
- **Incremental progression:** Improve the board, purchase upgrades, and unlock automation.
- **Debt management:** Manage earnings and daily installment payments while progressing through Tekin's story.
- **Interactive environment:** Use the calendar, letters, debt ledger, marble collection, and in-game phone.
- **Character events:** Receive helpful bonuses or payment reminders through phone calls.
- **Collectibles and achievements:** Unlock marbles, special pegs, and achievements.
- **Daily progression:** Review statistics at the end of each day and progress through the Ticket Tree.
- **Bilingual localization:** Switch between English and Turkish without restarting the game or losing progress.
- **Pixel-perfect scaling:** Integer scaling keeps pixel art and text sharp, including on high-density displays.

## Getting Started

### Requirements

- Godot 4.7
- A PC capable of running the Godot project

### Running the Game

1. Clone or download this repository.
2. Open Godot 4.7.
3. Import the project by selecting `project.godot`.
4. Press **F5** to start the game.

Alternatively, launch the project from a terminal if Godot is available on your system:

```bash
godot --path .
```

Run this command from the project's root directory.

### Save Data

The game saves progress automatically every 15 seconds and when exiting.

On macOS, the save file is stored under the Godot application data directory:

```text
~/Library/Application Support/Godot/app_userdata/Son Bilye/son_bilye_save.json
```

This is the current save-data path used by the project. The folder name may differ from the game's English display name.

## Gameplay and Controls

### Main Menu

The game starts from the main menu, which provides the following options:

- Continue
- New Game
- Settings
- Quit

### Basic Controls

| Input | Action |
|---|---|
| Space | Drop the selected number of marbles |
| Drop button | Drop marbles using the selected batch size |
| Mouse | Interact with menus, upgrades, objects, and game systems |
| Esc | Open the pause menu or close certain dialogs |

### Game Interface

**Left Panel**

- Cash balance and installment payments
- Upgrade and automation cards
- Marble Polishing side activity

**Center / Desk**

- Calendar displaying the current day
- Story letters and events
- Debt Ledger showing installment payments
- Marble collection jar
- Interactive telephone

**Right Panel**

- Ticket indicator
- Achievements and menu
- Marble Wheel and Peg Wheel
- Available pegs and placement controls
- End Day button

### Phone Events

Characters can contact the player through the in-game phone.

- Friendly characters may grant **Fire Mode** for 15 seconds, doubling gameplay speed and removing the airborne marble limit.
- Sadık Bey may call to remind the player about outstanding installments.
- Depending on the payment status, the player may be able to pay immediately or face a penalty decision.

### End-of-Day Progression

At the end of each day, the player can:

1. Review daily statistics and earnings.
2. Finish the current day.
3. Access the Ticket Tree progression system.
4. Begin the next day.

## Project Structure

| Directory | Description |
|---|---|
| `assets/` | Artwork, sprites, fonts, and visual assets |
| `scenes/` | Godot scenes and interface layouts |
| `scripts/` | GDScript gameplay systems |
| `data/` | Game configuration and economy data |
| `docs/` | Design decisions, documentation, and economy reports |
| `tools/` | Python utilities for balancing, testing, and asset processing |

## Economy System and Balancing

The game uses a predefined economy model rather than dynamically recalculating its balancing values during gameplay.

Python utilities are used to calibrate daily financial requirements, generate game economy data, and produce reports.

### Calibrate the Economy

```bash
python3 tools/economy_model.py calibrate
```

Calibrates daily tariffs and installment values. This operation may update values in the economy model source file.

### Export Economy Data

```bash
python3 tools/economy_model.py export
```

Generates the `data/economy.json` file used by the game.

### Generate Economy Report

```bash
python3 tools/economy_model.py report
```

Generates the economy documentation in `docs/EKONOMI.md`.

### Analyze Marble Abilities

```bash
python3 tools/economy_model.py balls
```

Analyzes marble ability returns based on rarity.

## Asset Processing Tools

The project also includes Python scripts for preparing pixel-art assets and fonts.

### Font Processing

```bash
python3 tools/patch_font.py
```

Generates the modified `assets/fonts/PixelifySans-SB.ttf` font from its original source.

### Pixel-Art Conversion

```bash
python3 tools/pixelize_art.py assets/art/src/tekin_raw.png assets/art/portrait_tekin.png --key
```

Converts artwork to the intended pixel grid, including transparency processing for the magenta background.

### Sprite Sheet Processing

```bash
python3 tools/slice_sheet.py assets/art/src/balls_raw.png assets/art/balls demir,cam,kil,kaucuk,bakir,miknatis,volkan,altin,-,-,-,ikiz,kuyruklu,anka,kara_inci --min 15 --pitch-min 8 --hue-tol 0.035
```

Extracts individual sprites from a source sprite sheet. A hyphen (`-`) skips the corresponding item.

## Developer Tools and Testing

The project includes command-line arguments for debugging, automated gameplay, state manipulation, probability verification, and screenshot generation.

Developer arguments are passed after `--` when launching the Godot project.

**Important:** Use `--test-save` to avoid modifying your normal game progress during testing.

### Save and Startup

| Argument | Description |
|---|---|
| `--test-save` | Use a separate test save |
| `--fresh` | Delete the test save |
| `--skip-menu` | Skip the main menu |
| `--menu` | Force the main menu to appear |
| `--skip-story` | Skip the beginning-of-day story window |

### Game State and Progression

| Argument | Description |
|---|---|
| `--cash=N` | Set the available cash |
| `--day=N` | Set the current day |
| `--tickets=N` | Set the number of tickets |
| `--buy=ball_level:5,board_level:2` | Purchase specified upgrades using game rules |
| `--pay-all` | Pay outstanding installments |
| `--open-prestige` | Open the end-of-day progression screen |
| `--do-prestige` | Execute the progression action |
| `--tree-phase` | Move to the Ticket Tree phase |

### Gameplay and Simulation

| Argument | Description |
|---|---|
| `--demo` | Enable automatic marble dropping |
| `--autoplay` | Run the debugging player |
| `--timescale=N` | Adjust simulation speed |
| `--verify-probs` | Compare exact board probabilities against a 200,000-drop Monte Carlo simulation and observed landing results |
| `--spin=ball:3,peg:5` | Trigger specified wheel spins |
| `--give-pegs=huni:1` | Add a specified peg |
| `--place=3:1:huni` | Place a specified peg |
| `--select-ball=kara_inci` | Select a specific marble |
| `--give-balls=N` | Grant all marbles with the specified mastery level |

### Interface and Visual Testing

| Argument | Description |
|---|---|
| `--open=tree` | Open the Ticket Tree |
| `--pause` | Open the pause menu |
| `--edit` | Open the peg editor |
| `--jackpot-fx` | Trigger the jackpot effect |
| `--wheel=ball` | Open the Marble Wheel |
| `--ui-spin=ball+peg` | Open and spin both wheels |
| `--win=1440x810` | Set the game window size |
| `--crop=x,y,w,h` | Specify a screenshot crop |
| `--lang=tr` | Force Turkish localization |
| `--toggle-lang` | Switch languages shortly after startup |
| `--sprite-sheet=path.png` | Export marble and peg sprite inspection sheets |

### Debugging and Phone Events

| Argument | Description |
|---|---|
| `--measure` | Print the net result per marble drop |
| `--print` | Print the game state on exit |
| `--seconds=N --screenshot=path.png` | Capture a screenshot after N in-game seconds |
| `--phone=good` | Trigger a friendly phone call |
| `--phone=threat` | Trigger a threatening phone call |
| `--answer` | Automatically answer a phone call |
| `--call-act=pay\|hang\|boost` | Select an action in the active phone dialog |
| `--boost` | Activate Fire Mode |
| `--wheel-call=SN:_on_sell` | Invoke a wheel-window method after a specified delay |

## Documentation

Additional technical documentation is available in the repository:

- [Game Design and Architecture](docs/TASARIM.md) — Design decisions, assumptions, and code structure.
- [Economy and Balancing](docs/EKONOMI.md) — Economy tables and balancing simulations.

*These technical documents are currently written in Turkish.*

## Screenshots

Gameplay screenshots will be added here.

## Development Status

Personal game development project.

The repository contains the Godot project files, gameplay systems, economy tools, and supporting technical documentation.
