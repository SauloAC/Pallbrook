# Pallbrook

A 2.5D investigation game about a doctor called to a small town where people are
falling ill from an anemia no one can explain. By day you examine patients, question
the townsfolk and piece together the previous doctor's torn diary. By night, one of
them hunts. Find the vampire, convince the town at a hearing, and survive long enough
to be believed.

![Pallbrook — the town at dusk](art_source/preview.png)

**Status:** in development · playtest builds for Windows and macOS ·
English, Português (Brasil), Español, 日本語 · built in Godot 4.7 with GDScript.

<!-- TODO: add a short gameplay GIF here and a download link (itch.io or GitHub Releases) -->

## How to play

- **Day:** talk to townsfolk, ask about alibis and what they saw last night, and examine
  patients. Every exam is recorded on a hospital-style patient chart in your casebook.
- **Night:** the vampire leaves home to feed. Watch a door and it may give up for the
  night — but being seen out late changes how the town treats you.
- **Clues:** a bite mark marks a victim, not the vampire. Contradictions only count once
  *you* compare two statements and find them.
- **Daytime is time you spend:** read the Town Hall register and the church burial book,
  sit at the tavern at noon and overhear the town, learn the iron tonic at the library,
  buy its ingredients from the merchant beyond the bridge and brew it at the clinic,
  treat patients who come by appointment, or take an afternoon nap to last longer tonight.
- **The old doctor's diary:** your predecessor's torn pages are hidden around town, a few
  each day. The clinic wall holds an outbreak map where every case gets pinned.
- **Exhaustion:** sleep in your clinic bed at night. Collapse in the street instead and
  you tire earlier the next night. You can hide in bushes and tall grass when chased.
- **The hearing:** accuse someone in front of the town and let them vote. The town wants
  a full case (three pieces of evidence and two witnesses who speak up) unless they
  trust you deeply. You get two hearings per run. Convict an innocent and you pay for
  it; fail against the real vampire and it comes for you. Convict the vampire and its
  servants go free.
- **The first day is guided:** a short tutorial walks you through the clinic, the casebook,
  an exam and your first night.

## What's interesting under the hood

### A vampire with a body, not a script
`VampireDirector` picks a secret vampire each run and simulates its night. It has its
own blood level that drops every dawn: well fed, it bites carefully and can walk out on
foggy days as an ordinary person; starving, it bites twice as hard and turns reckless.
Every number that shapes a run — hunt hours, bite size, hunger, how often a clue points
to the real culprit — is an exported variable, so balance changes happen in the
inspector, not in code.

### A past written to fit the culprit
`TownHistory` writes the town's last forty years at the start of each run, after the
vampire is chosen: the pale deaths begin the year it settled in Pallbrook, and two
innocents arrived around the same time. The Town Hall register narrows the list without
naming anyone; the church book, which the priest only shows once he trusts you, pins
down when it began. If the priest is the vampire, he shows it all the same, with
harmless notes where the pale deaths should be.

### Systems that don't know about each other
Global signals live in one `EventBus` autoload (`phase_changed`, `npc_died`,
`clue_found`, `hour_changed`…). The day/night cycle, NPCs, HUD, audio and casebook
react to events instead of calling each other, which kept a growing project from
turning into a web of references.

### Characters are data
Each of the 7 townsfolk is a `.tres` resource in `data/npcs/` — name, role, home,
an hour-by-hour schedule, dialogue, a clue trait and a portrait. Adding a character means adding a file, not editing
`NPC.gd`.

### Four languages from one table
Every line on screen is a key in `localization/strings.csv` (~700 keys × EN, JA, PT-BR,
ES), served through Godot's translation server and a small `Lang` autoload. The game
starts in the system language and can switch from the title screen. Portuguese and
Spanish need grammatical gender (*cansado / cansada*), so lines about a woman have their
own feminine row, picked by `Lang.g()`. The Japanese build
exists because Japanese-speaking friends asked to playtest it.

### Playtesting built into the game
A `Playtest` autoload quietly logs what happens in each run — the day reached, deaths,
collapses, who was accused, time spent reading — and writes a readable `.txt` plus a
`.json` for comparing testers. At the end of a run it asks four short questions
(who did you suspect, what confused you, what did you enjoy, anything else).
Design changes come from those reports, not guesses.

## Decided by playtesting

<!-- Fill each one with what testers did, what you changed, and the result. -->

- **The health bar gave the vampire away on day one.** The vampire was the only
  person *not* losing blood. It now starts the game freshly fed, so day one looks normal.
- **Daytime felt empty.** Testers waited for night. Added actions that cost in-game
  hours (library research, the merchant, town records), so time itself became the
  resource.
- **A bite mark looks like a confession.** It actually marks a victim. Kept the
  misdirection, but added a hint that a bite trace on clothes can be misleading.
- **The town was convinced too easily.** One clue could win a hearing. Now the town
  wants three pieces of evidence and two witnesses who actually speak, unless trust in
  the doctor is very high.
- **Exams cost nothing.** A player could examine everyone in a minute. Each exam now
  takes an hour of the day.
- **Collapsing in the street had no real cost.** Being seen was the only penalty. Now the
  doctor tires an hour earlier the next night, and an afternoon nap or a night in bed
  makes up for it.

## Project structure

```
autoload/      Global singletons: EventBus, GameState, Lang, Audio, Settings, Playtest
scenes/        Godot scenes (town, buildings, UI)
scripts/
  cycle/       DayNightCycle, VampireDirector
  npc/         NPC behaviour, schedules and visuals
  data/        Diary text, TownHistory (the town's past, generated per run)
  ui/          Casebook (Notebook), Hearing, Mural, Dialogue, HUD, Tutorial, Hints
  world/       Clinic mural, diary pages, merchant, library book, town records,
               tavern lunch, afternoon nap, safe zones
data/npcs/     One resource per character
localization/  strings.csv — every on-screen line, four languages
assets/        Models, portraits, audio, fonts, UI theme
```

## Running it

1. Install [Godot 4.7](https://godotengine.org/download).
2. Clone this repository and open `project.godot`.
3. Press **F5**.

## Design process

The design lives outside the code: a FigJam dev diary (in Portuguese, with an English
copy) and a design document covering the endings, the casebook, the vampire's rules
and planned expansions. Casebook layouts are prototyped in Figma before they are
built.

## Credits

3D characters and town kits by [Quaternius](https://quaternius.com) (CC0). Music, sound
effects, fonts and AI-generated art are listed with their licences in
[CREDITS.md](CREDITS.md).

## Author

Saulo de Andrade Costa · [LinkedIn](https://www.linkedin.com/in/saulo-a-costa) ·
[Portfolio](https://portfolio-saulo.vercel.app/)
