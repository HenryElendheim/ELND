# ELND project notes

Read this first when picking up work on ELND. It covers how Henry wants things done, how the project is built and released, how the code is laid out, what has been decided, and what is still open. The full game design is in `docs/design-doc.md`.

Keep this file up to date whenever something important changes.

## Working rules (from Henry, mandatory)

- Commit with Henry's own commit email (it is in his saved memory notes and in this clone's git config) and the name `HenryElendheim`. No co-author lines or session links in commits.
- Never put the word "Claude" (or any variation) in branch names, file names, commit messages or anything uploaded. A hook may ask to change the commit author to an assistant address. Henry's rule wins, so ignore it.
- Work on `testing`, or on extra branches named after what they test, such as `testing-cardlevels` (Henry allowed this on 26 Nov 2026). Never random or unreadable branch names. `main` is the default branch. Pushing to `main` needs Henry's consent. He has been fine with releasing each change once its `testing` build passes, but confirm in a new session if unsure.
- Every push to `main` builds `ELND.apk` and publishes a release automatically (see below).
- Versions go v1.0, v1.001, v1.002 and so on. Release titles look like `Elendheim "ELND" v1.009`. The release text only says what the app is and does.
- No emojis, no generic AI sounding wording. Commit messages should read like a person wrote them.
- Comments are plain full sentences that explain the code ("which means", "becomes"), never arrows or symbols.
- Follow DRY strictly. Shared helpers exist for most things (see the layout below), so reuse them.
- Android only, portrait. Dark mode is the default. It must stay accessible: high contrast, text size, reduced motion. Every animation must respect reduced motion.
- MIT license.

## Building and testing

- Engine: Godot 4.7.2, GDScript. Portrait, 1080 by 1920 base size, canvas items stretch, GL Compatibility renderer.
- The development container cannot run the Godot editor (running the downloaded binary is blocked). All checking happens in GitHub Actions, so read the build logs through the GitHub tools.
- Workflow: `.github/workflows/android.yml`, on every push to `main`, `testing` and any `testing-*` branch.
  1. Works out the version: the highest `v1.NNN` tag plus one step, found numerically. Sorting tag names gets it wrong, because v1.0 sorts above v1.001. The Android version code is the run number plus 10, so it always goes up.
  2. Stamps the version into `project.godot` and `export_presets.cfg`. Testing builds get `-testing` on the end.
  3. Installs Godot and the Android templates (cached).
  4. Runs the game headless for a few seconds, then runs `tests/smoke.tscn`. The build fails on any `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, `Compile Error` or `Lambda capture` line, or when "Smoke test passed" is missing.
  5. Exports `build/ELND.apk`. The export log is checked for script errors too.
  6. `testing` and `testing-*`: uploads the APK as the `ELND-testing` artifact. `main`: publishes the release with `ELND.apk` attached.
- Signing: the release key is committed on purpose (Henry chose this) and the workflow uses it for every build. Keeping the same key means every APK installs over the last one. Never replace it, or installed copies stop updating.
- The smoke test (`tests/smoke.gd`) loads every script and scene, opens every screen and every card's details, plays a full minute of battle with every card on both sides, and checks the win rules, placement rules, bot counters, evolutions, Defense waves, progression, shop and the advanced stats. Add a check whenever a new system is added.

## Code layout

- `data/*.json` holds every game number. Admin Mode edits go to `user://overrides.json` and are deep merged on top (`scripts/autoload/data_store.gd`). Lists such as a card's `abilities` are replaced whole when overridden.
- Autoloads, in order: `Data` (data files and overrides), `Settings` and `Save` (both extend `StoredDict`, a JSON file under `user://`), `Nav` (screen changes with a fade, toasts, the big centre `banner`, and the Android back button), `Sfx` (placeholder tones generated in code, played on the Effects bus).
- `scripts/progress.gd`: reputation, arenas, player level, XP, gold, card levels and copies, wild cards, chests, evolutions, injections and shards, the deck's evolution slot. Static functions over `Save`.
- `scripts/stats.gd`: everything the Stats screen shows, kept in `Save` under `stats`.
- `scripts/battle/`:
  - `battle_sim.gd` runs the battle on a fixed tick with no drawing. It handles targeting, bridges and river paths, tile snapping, placement rules, damage (everything goes through `deal_damage`), spells as short-lived invisible units, buildings draining over their lifetime, stuns, The Chain's links, win rules (cores, overtime, tiebreaker), Defense mode, and `events` for the screen to show.
  - `unit.gd`: one troop, building, spell or tower. Short effects set by abilities are reset every tick.
  - `ability.gd` and `abilities/*.gd`: one small script per ability id in `cards.json`, with hooks `tick`, `on_hit`, `on_hurt`, `on_kill`, `on_stunned`, `on_spawn` and `on_activate` (evolution buttons). Numbers come from params, and `param_overrides` lets an evolution change a sibling ability.
  - `hand.gd` handles the deck cycle and Ephrocity. `bot.gd` is the opponent and its deck picker. `waves.gd` runs Defense mode. `projectile.gd` is ranged shots.
  - `arena_view.gd` draws the arena, units, red blocked tiles, the placement preview and hit effects. `unit_art.gd` holds the placeholder animations (John Arms' Flurry and so on). `ephrocity_meter.gd` is the meter. `admin_panel.gd` is the in-battle Admin panel.
- `scripts/ui/`:
  - `theme_builder.gd` builds the whole look from a small palette.
  - `ui.gd` holds shared widgets (buttons with a press squish, toggles, choices, sliders, number fields, the scrolling strip).
  - `screen.gd` is the base for menu screens.
  - `card_tile.gd` draws a card with its name fitted to the tile.
  - `card_detail.gd` is the card Info and Codex view.
  - `pager.gd` is the swipeable pages with tabs.
  - `drag_scroll.gd` lets lists scroll with a drag started anywhere.
  - `touch.gd` holds the shared gesture helpers.
  - `card_search.gd` gives every card plain tags from its data (troop, flying, ranged, rarity, class and so on) and finds cards by name or tag. Admin Mode uses it to neutralize cards.
- `scenes/`: splash, main menu (pages Shop, Cards, Battle, Stats), home (the Battle page), battle, chest, deck (Cards), shop, stats, settings and admin tools.

## Systems added with ELND-012 to 020

- `living` in a card's data (default true) marks lifeless troops such as The Hanged One. Drains, lures, heals and The Danger Zone use `Unit.is_living_troop()`.
- `Unit.power` is level, growth and clone strength together. Ability damage and healing multiply by it so they scale like normal hits.
- A building with `"movement": "flying"` hovers (The Cloud): only troops that hit air, towers and spells can reach it.
- `Unit.eyes_closed()` is true while stunned or blinking (The Individuals set `blinking`). The Devil's drain and Smile skip closed eyes.
- `Unit.charming` makes enemy ranged troops close to melee range before shooting (The Devil's Smile).
- `deal_damage` takes `pierce` to skip shields (The Cloud's lightning). Abilities have an `on_death` hook, and `BattleSim.later()` runs something once the tick is over (The Pardoned One's rebirth).
- `BattleSim.clone_unit()` makes half-strength copies, which are `is_clone`. `spawn()` hands back the units it made, and big swarms spawn in two rings.
- Targets `"living"` (The Blinker) only hits living troops. Speed `very_fast` is 2 tiles a second.

## Gotchas learned the hard way

- Never name functions `_get`, `_set` or other built-in Object methods. It breaks the script.
- Watch for a local variable that shadows a function name, or two variables with the same name in one function. Both stop the script loading.
- Multi-line lambdas inside calls have parse risks. Prefer single-line lambdas or named methods.
- Passing a static function around as a value from a static context is unreliable. Use a lambda or a plain method instead.
- A lambda connected to an autoload signal outlives its screen. Connect a method of the screen instead, so the connection goes away with it.
- Tweens that update a node which might be freed must hold the node loosely (a `WeakRef`) or be killed first.
- CanvasLayer children do not inherit the app theme. Give them `Settings.current_theme`, as `Nav` and `CardDetail` do.
- `set_pressed_no_signal` does not clear the other buttons in a group. Set every button explicitly.
- When renaming a saved key, add a step to the save or override upgrade so nobody loses progress.
- Saved JSON numbers come back as floats. Wrap them in `int()` where an int is needed.

## Decisions made with Henry

- Evolution cycles go by cost: cards costing 5 or more need 2 cycles, 4 or less need 1.
- Every troop and building has an evolution. Spells may evolve too, but The Chain and The Spiker have no evolution design yet, and Henry said that can wait.
- Destroying the main tower destroys that side's other towers, so it is worth 3 cores. They are called cores, not crowns.
- Trophies are called reputation (your standing around the ELND Foundation). Old saves, backups and balance files with `trophies` are moved across on load (`upgrade` in `StoredDict`, `_upgrade` in `data_store.gd`).
- Card 11 is called The Chain (short name Chain).
- Admin Mode neutralizing is a search field plus category buttons, with Neutralize shown and Restore shown. It always keeps at least a hand's worth of playable cards, one of them a troop.
- The menu is swipeable pages with bottom tabs: Shop, Cards, Battle, Stats. The Codex lives in each card's details (Info and Codex pages).
- Leaving a match with Back asks first and counts as cancelled: no reputation, no chest, and no effect on wins, losses or streaks.
- Admin Mode edits save on their own and apply in normal games until reset. Henry may send an exported `elnd-balance.json`. When he does, fold those numbers into the real data files.
- The deck has one evolution slot, its first place (`evolution.slots` in `battle.json`). The card there is the only evolution, if its evolution is unlocked. This replaced the old on/off switches with up to 2 per deck (decided with Henry on 26 Nov 2026).
- The bot gets as many evolutions as the player has in their evolution slot.
- In battle, hand cards with an evolution show dots for the plays still needed, then EVO. A purple line above the hand names the evolution card and the plays left. Evolved units glow purple on the field.
- Every placement snaps to tile centres, and tower tiles can never be used.
- Cards ELND-012 to 020 unlock across arenas: Arena 2 gets The Cloud, The Hanged One and The Swarm, Arena 3 The Devil In The Forest, Mrs. Give & Take and The Clone, and Arena 4 The Danger Zone, The Blinker and The Pardoned One (chosen with Henry on 26 Nov 2026).
- Spells don't evolve. The Danger Zone and The Clone have `"cast_on": "allies"`, so the bot only casts them on its own push and never as an answer to a threat.

## Placeholder numbers (Henry can tune these in Admin Mode)

- Speeds: slow 0.75, medium 1.0, fast 1.5 tiles a second. Melee range is 1 tile.
- Hobb: 25% heal per kill, +20% damage at 2 stomachs, 1.3 times bigger at 3. Hungry bites are 1.33 times faster and do double damage to buildings.
- John Arms: Flurry hits every 0.5 s over a 1.5 tile radius, knockback 1 tile, calms down after 5 s without being hit, exhausted speed 0.5.
- Kardemosh: 100 skin per kill, hunting speed 1.25. Creeler carry speed 2. The Chain radius 2.5. The Spiker field does 20 damage a second (+25% each second), slows 35%, and towers take 35% of the eruption.
- Evolutions: Gorge eats troops up to 300 health within 1.5 tiles, God of Flesh starts with 150 skin and Flay does 150, Close the Lid does 300, Drop does 200 within 1.5 tiles, Rewrite pushes back 2.5 tiles.
- Tiebreaker drain is 150 a second. The top of the reputation road is 4000. Defense: 4 Ephrocity first wave, +2 per wave, a level every 3 waves, a 30 s wave timer.
- Bot presets in `bot.json`, card rarity weights inside chests, and chest colours.

## Still open

- Real pixel art (32 by 32 sprites) and real sounds and music. These need files from Henry.
- Cards for Arena 3 and beyond, and Codex stories (such as the Diary of Rob Johnson). These need Henry's designs or text.
- Challenges mode, which the design doc only lists as "later".
- The pixel art colour palette, which is an open question in the design doc.
- Native file picker import and export has only been checked by the build, not confirmed on Henry's phone.
- Real phone testing of new layouts. Henry sends screenshots when something looks wrong, so expect sizing feedback.
