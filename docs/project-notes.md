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

- `data/*.json` holds every game number. Card descriptions (`how_it_works`) never type numbers out. They use placeholders such as `{happy_face.drain_per_second|lvl}` that `CardText.fill` reads from the data, so text always matches the real values, Admin edits included. `|pct`, `|more`, `|less` and `|lvl` change how a number shows, and `|lvl` is only for numbers battles scale with level. The smoke test fails on a placeholder that points at nothing. Admin Mode edits go to `user://overrides.json` and are deep merged on top (`scripts/autoload/data_store.gd`). Lists such as a card's `abilities` are replaced whole when overridden.
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
  - `screen.gd` is the base for menu screens. Screens opened on top of the main menu (Settings, Admin, Foundation road, Foundation items) get a Back button fixed in the top left that never scrolls away (`wants_back`, `refresh_back`). A main menu page can ask for it while it shows a deeper view, as the advanced stats do. Card details have the same Back in the top left.
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

## Battle readability

- Every troop, building and tower shows its level ("Lv 3") just above where its health bar sits. A swarm shows it once.
- A spell landing flashes over its area with a ring sweeping out, in its class colour (`cast` event).
- Units show what is happening to them: a red aura while enraged (`Unit.enraged`), dark spikes while slowed by The Spiker (`Unit.slowed`), a dark haze while filled with dread, a grey ring while chained, and yellow sparks while stunned. The Danger Zone's backlash bursts red on each troop (`backlash` event), and clones streak in cyan from their original (`cloned` event).
- The Foundation road lists the last Site at the top and Lab 1 at the bottom, and opens on where you are.
- The Cards screen has a Locked section with every card from later arenas, showing the arena that unlocks it. Tapping one shows its details with no buttons.

## Cards screen

- Up to 3 decks (`deck.slots` in `battle.json`), kept in `Save` under `decks`. The one picked last is the battle deck and is also kept under `deck`, so battles, stats and the bot read it as before (`Progress.decks`, `save_deck`, `select_deck`). `BattleSim.valid_deck` turns a saved deck into a playable one.
- The collection and the locked cards can be sorted (cost, rarity, type, name, ELND number) and filtered with the Filter button, which opens `FilterPicker`: search the filters, pick several and Apply. Picks in one group mean any of them, picks across groups mean all (`CardSearch.GROUPS`, `CardSearch.fits`), and an X next to the button clears them. Rebuilding the Cards screen keeps both the page and the sort row scrolled where they were. A new sort starts highest first (names start at A), and tapping the sort in use again flips it. The button in use says which way it goes, such as "Cost: high first", with no extra explaining text. The choice and direction are remembered in Settings (`collection_sort`, `collection_descending`).
- The sort and filter rows (`Ui.strip`) scroll sideways with a drag from anywhere on them (`DragScroll.attach(scroll, true)`). They join `Touch.SIDEWAYS_GROUP`, and a page swipe that starts on one is ignored, so dragging the filters never flips the menu page.
- `TapGuard` (`scripts/ui/tap_guard.gd`) makes buttons react only to a clean tap. Nav gives every button one as it appears (`node_added`). A normal button keeps its own pressing, and the guard cancels the press (with `Touch.cancel_press`) once the finger slides off or moves too far. Faking presses for normal buttons broke battle buttons and others in v1.015, so never set `button_mask` to 0 on a normal button. Sideways rows (`Ui.strip`) and card tiles give the guard their own tap and hold actions; only those stop pressing themselves and let touches pass through.
- Card tiles on this screen use their own tap and hold (`CardTile.enable_gestures`, built on `TapGuard`) and let touches pass through, so a swipe that starts on a card scrolls the list. Holding a deck card picks it up (`Touch.holding` stops lists and pages moving), and dropping it on another deck card swaps them. Collection cards cannot be dragged; they go in with Add or Swap into deck.

## Reputation and celebrations

- `ReputationBar` shows how far you are from your Lab or Site to the next one. It sits on the Battle page, on your place on the Foundation road, and in the battle result, where it plays the change: the gain pops up and the bar fills with a ticking count. Crossing into a new place flashes the bar and sends `place_reached`.
- `PlaceReached` celebrates a new Lab or Site, with a flash, rays, the name slammed down and the newly unlocked cards popping in.
- `Celebration` is the shared base for full screen celebrations (`LevelUp` and `PlaceReached`): dark cover, title, rays behind a centre piece, lines, a white flash, and a tap that skips to the end and then closes.
- `Progress.arena_at` and `share_to_next` turn a reputation into a place and how far it is to the next.
- The Devil's Smile charms at most two enemy ranged troops at a time, the closest with their eyes open (`max_charmed`), using `Unit.charmed_by`.
- Every member of a swarm shows its level.
- Cards can be dragged from the hand onto the arena (`_input` in `battle.gd`): leaving the card picks it, the preview follows the finger over the arena, and letting go there plays it. A tap still picks it the normal way.
- The named effect tags and dashed lines added in v1.014 were taken out again because they caused visual bugs.

## Admin card editor

- `CardEditor` (`scripts/ui/card_editor.gd`) is shared by the Admin screen ("Edit cards") and the in-battle Admin panel. Search or Show all, tap a card or tower (side, main, Defense core), and edit its numbers (cost, health, damage, seconds per hit, range, group size, unit size, lifetime, area, unlock place), its type, movement, attack, targets and speed, and every ability and evolution number.
- Edits go through `Data.set_override`, so they save straight away and reach running battles. A changed value shows its default and has its own reset, and there are resets for abilities, the evolution and the whole card.
- Only the evolved Pardoned One is born anew (once, when killed while flying, coming back still evolved). Her base form dies for good (decided with Henry on 27 Nov 2026).
- Every ability number the game uses lives in the data, including The Pardoned One's lifesteal (`sharp_wings.heal_share`), The Devil's self heal (`happy_face.heal_share`) and The Clone's separate `health_share` and `damage_share`. `Ability.number` takes a fallback, so older saved edits without a new number keep working.
- The editor also edits names, short names, descriptions, Codex entries, class and threat (rarity), and tokens. Edited cards and towers have a star after their name in the picker.
- Any card can be copied into a brand new card (`custom_1`, `custom_2` and so on) with the next card number. It lives only in the Admin overrides, works like any other card (decks, chests, the road), and can be deleted again.
- A troop whose type is edited to spell becomes a still green circle that never leaves (a spell with an ability stays on the field). So a type change in the editor needs a second tap, number boxes only save a value that actually changed, and edited cards and towers have a star after their name.
- The in-battle spawn tool lists every collectable card in a sideways row, locked ones included.

## Items, injections and gold

- The Foundation items screen (`scenes/items.gd`, from the Battle page) shows gold, wild cards, injections, shards, evolutions unlocked, chests waiting and the games left until the next Injection chest.
- Every 10 finished games (`injection_chest.every_games` in `chests.json`) an Injection chest is queued. It holds one Evolution Injection. Epic and Legendary chests no longer give evolutions or injections (decided with Henry on 27 Nov 2026).
- Card level ups give no gold (`per_card_upgrade_times_level` is 0). Battle wins and player level ups still do.

## Defense mode

- The enemy has a single core (`core` in `towers.json`) where its main tower would be: 2600 health, 45 damage every 0.5 s. Waves keep coming and grow stronger until the core falls or your main tower does.
- Destroying the core wins, with a chest that is better the faster it fell (`win_chest_by_seconds` in `defense.json`). Losing gives the wave chest as before.

## Levelling up with wild cards

- `LevelUp` (`scripts/ui/level_up.gd`) celebrates a card levelling up with wild cards: pop in, a charging shake with a rising tone, then a white flash, spinning rays (the shared `Burst`), sparks, LEVEL UP slammed down, the level ticking up, health and damage counting up, and the gold earned. A tap skips to the end, another closes it. Reduced motion shows the end straight away.
- Card details say "Add" and "Remove" for the deck.
- The Admin neutralize list is empty until you search, pick a category, or press Show all.

## Chest opening

- Cards come out as real tiles over a burst of light in their rarity colour: common pops, rare flips in, epic bursts purple, and legendary gets a white flash, spinning rays, a "LEGENDARY" title, a slam and a long buzz. New cards get the codex stamp slammed on.
- Skip works on every chest. Skipping, or reaching the last card, shows a summary of everything the chest gave, rarest first, with counts, NEW or level, and extras.
- Placeholder sounds `card`, `card_rare` and `legendary` are in `sfx.gd`.

## Troop movement

- Close to its goal (within `steering.approach_tiles` of attack range), a troop heads for a free spot on a ring around the goal at attacking distance, trying further round each way until one is open. Attackers spread around towers and big troops instead of queuing.
- On the way, `_steer` checks for a unit just ahead. Allies walking on in the same direction do not count, so groups still move together. Anything standing in the way (a busy ally, a tower, a building, a troop it cannot hit) is passed on the more open side, and the side is kept for `keep_side_seconds` so it does not wobble.
- Forced moves (being lured into The Gasket, carried off) still go straight to their spot.
- The numbers live in `battle.json` under `steering`.

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
- Arenas are called Labs and Sites in the game (`arena_names` in `progression.json`, read with `Progress.arena_name`). The code still says arena for the number.
- The Weight, The Moth Choir, The Toll, The Brood and The Splitter are Claude's drafts, made when Henry asked for more cards and an answer to all flyers. Henry may rewrite their lore and names.
- The Zap and The Gazers were asked for by Henry: Zap costs 2, deals 40 and stuns for 1 s, and the Gazers are four flying heads shooting every 0.25 s that one Zap kills. Both unlock at Lab 5, and their codex entries are drafts.
- Cards that are not anomalies are Foundation Items (`"item": true`) with their own numbers, shown as FI-001 (`CardSearch.code`). So far The Weight is FI-001 and The Zap FI-002 (decided with Henry on 28 Nov 2026). ELND numbers are for anomalies only, with no gaps: The Moth Choir 021, The Toll 022, The Brood 023, The Splitter 024, The Gazers 025. Number order puts anomalies first, then items (`CardSearch.order`), and "Foundation Item" is a filter.
- Tokens (`"token": true`, such as Broodlings and the Splitter's halves and quarters) only appear on the field. `BattleSim.is_collectable` keeps them out of chests, decks, the collection and search.
- `Unit.base_flying` is what the card says, and `flying` is what it is right now. `grounded_left` (The Weight) keeps a flyer on the ground, except over the river.
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
