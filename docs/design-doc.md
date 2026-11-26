# ELND — Design Doc

> Title: **ELND** (Henry says it "Elend"; players can say E-L-N-D too)
> Platform: Android (personal, not for sale)
> Engine: Godot 4 (latest stable), GDScript
> Last updated: 25 Nov 2026

---

## 0. Build Notes (read first)

This doc is the full design for **ELND**. Build it milestone by milestone (section 13).

**Ground rules**
- Follow the **milestones in order**. The game must be **playable at the end of every milestone**. Don't build ahead.
- Values marked *draft*, *suggested* or *default* are starting points: use them, but they'll be tuned in Admin Mode.
- If something isn't decided in this doc, **ask Henry** instead of inventing a design.

**Tech**
- **Godot 4** (latest stable), **GDScript**
- Target: **Android phone, portrait** (reference resolution 1080×1920)
- Set up the **Android export on day one** so every milestone can be tested on the phone
- Pixel art: **32×32** sprites, nearest-neighbour filtering, integer scaling (no blurry pixels)
- Until real art exists: **coloured placeholder shapes** with the card name

**Data-driven architecture (required for Admin Mode)**
- **Every game number lives in data files, never hardcoded**: card stats, abilities, towers, Ephrocity timings, chests, odds, economy, XP, bot settings
- Defaults ship in `res://data/` (e.g. `cards.json`, `towers.json`, `battle.json`, `chests.json`, `economy.json`, `progression.json`, `bot.json`)
- `res://` is read-only on Android, so **Admin Mode edits are saved as overrides in `user://`** and merged on top of the defaults (with "reset to default" per value/card)
- Cards are built from **reusable components** (movement, targeting, attack, area damage, building decay, etc.) configured by data; unique abilities (Snatch, Three Stomachs, Quiet Revision…) are small separate scripts referenced by ID
- Battle logic runs on a **fixed timestep**, separate from visuals, so Admin Mode time controls (pause / 0.25× / 2×) work cleanly
- Player progress saves to `user://save.json`

**Admin Mode early:** build a basic version in milestones 1–2 (spawn troops on either side, edit stats live, show ranges/hitboxes, time controls). It's the main testing tool and grows with every milestone.

---

## 1. Vision

My own Clash Royale-style game: **all the joy of Clash, none of the pay-to-win or grind.**

- Real-time card battles against bots
- My own original cards
- Chests, card levels and unlocks are kept, but they're **fast and generous**
- PvE modes (tower defense style) alongside classic battles
- Made just for me to enjoy on the go: no real money, no ads, no timers

---

## 2. World & Lore

- **Setting:** an SCP-style sci-fi future
- **The cards are anomalies** (creatures) contained by **The ELND Foundation**
- The Foundation makes anomalies **fight each other** to study them:
  - Which ones are most useful in a fight
  - What their methods are
  - How much they truly care about **teamwork**
- **Ephrocity** is what runs in every anomaly's veins. It's what makes them anomalous, and it's the energy you spend in battle.
- Older codex entries may mention the "Elendheim Foundation" or "ELD-" numbers: that's the **old name**. In the game it's always the **ELND Foundation** / **ELND-###**.

### Containment Classes
Every anomaly has a class (from the Elendheim Codex), shown as a coloured tag on its card:

| Class | Colour |
|---|---|
| **CLAM** | Green |
| **REKNA** | Yellow |
| **RINNER** | Red |
| **HEIMER** | Purple |
| **NEUTRALIZED** | Grey |

- Suggested use: the class tag + colour shows on the card frame (lore flavour, not stats; rarity comes from Threat)
- Admin Mode tie-in: "Neutralize" a card to disable it from bots and decks while you rebalance it

### The ELND Foundation
- **ELND = Ephrocity Logging & Neutralization Division**
- The name is a hint towards *Elendheim*

---

## 2b. Art Style

- **Pixel art**
- **Sprite size: 32×32** for all troops (keep it consistent; larger bosses can use multiples like 64×64)

### Attack Animations
Awesome but **readable**: no visual clutter.
- Short, punchy animations (3–6 frames) with a clear **impact frame**
- **1-frame white hit flash** on whatever gets hit
- **Screen shake only for big hits** (tower destroyed, legendary abilities)
- Small, short particles (under ~0.5 s); save the big effects for **abilities and evolutions**
- **Team outline colours** (e.g. blue = you, red = enemy) so you can always tell sides apart
- Damage numbers **off by default** (toggle in Settings)

---

## 3. Core Battle Rules

- 1v1, real-time, two lanes
- **Deck:** 8 cards, **hand:** 4 cards, cycling like Clash
- **Ephrocity** regenerates over time and is spent to play cards

### 3.1 Ephrocity (energy meter)

- Colour: **wine red** (suggested base `#722F37`, filled bars glowing `#A33B4C`)
- **Max: 10 bars** · **Start of match: 5 bars**
- **Timing is the same as Clash Royale's elixir:**

| Phase | Time | Rate | 1 bar every |
|---|---|---|---|
| Regular | Minutes 1–2 | x1 | 2.8 s |
| Regular | Minute 3 (last 1:00) | x2 | 1.4 s |
| Overtime | Minute 4 | x2 | 1.4 s |
| Overtime | Minute 5 | x3 | ~0.93 s |

- Suggested: a visual/sound cue when double and triple Ephrocity kick in

### 3.2 Arena & Towers

| Tower | Health (lvl 1) | Damage (lvl 1) | Range | Active |
|---|---|---|---|---|
| **Side towers** (x2) | 1500 | 15 | 7.5 tiles (same as Clash) | Always |
| **Main tower** (middle) | 3000 | 15 | 7 tiles (same as Clash) | Wakes up when damaged **or** when a side tower is destroyed |

- Tower damage/health **scale with levels** (same scaling as troops)
- Towers hit **air & ground**
- Suggested hit speed (Clash): side towers 0.8 s, main tower 1.0 s
- Note: all troop stats get balanced *around* 15 tower damage, so a basic troop's health should be roughly ~100–300 at level 1

### 3.2a Arena Size
- Same as Clash: **18 tiles wide × 32 tiles long**, a river in the middle, **2 bridges**
- **Deploy time: 1 s** (same as Clash) before a placed troop becomes active

### 3.2b Troop Placement
- Troops can be placed on **your own half** only
- Destroying an enemy side tower lets you also place on **the enemy's side of that lane** (like Clash)
- **Spells** can be cast anywhere

### 3.3 Winning (same as Clash)

1. Destroy the **main tower** → instant win
2. When time runs out, whoever **destroyed more towers** wins
3. If tied → **overtime (2 min):** the first tower destroyed wins
4. If still tied → **tiebreaker:** all remaining towers rapidly lose health; the **first tower to fall loses**

---

## 4. Card Types

### 4.1 Troops
Every troop has these attributes:

| Attribute | Options |
|---|---|
| **Targets** | Buildings only · Ground only · Air & ground |
| **Movement** | Ground · Flying |
| **Attack range** | Melee · Ranged (with a range value) |

- **Building-only troops** ignore enemy troops and walk straight to towers/buildings
- **Flying troops** can **only** be hit by: ranged troops, other flying troops, spells, and towers. Melee ground troops can't touch them.
- Reference (Clash): melee is 0.8–1.6 tiles, ranged is 2+ tiles

### 4.2 Spells
Almost-instant abilities. Three kinds so far:
- **Damage:** hit an area
- **Empower:** buff your troops
- **Ephrocity Surge:** costs **1**. x2 Ephrocity production for **10 s**, then an **Ephrocity deficit** for **10 s** (each bar takes **+2 s** longer to regenerate)

> Math (during x1 time): boost ≈ +3.6 bars, deficit ≈ −1.5 bars, cost −1 → **net ≈ +1 bar**. A tempo card that's actually worth playing. Wasted if you're already near 10.

### 4.3 Buildings
- Stand still and defend
- Their **health slowly drains over time**, which is their lifetime timer
- Damaging a building **lowers its health, which shortens its timer**

---

## 5. Evolutions

An **Evolution** is an empowered version of a card.

### How it triggers
- An evolved card must be **cycled** before it plays as its evolved form
- Each evolution has a **cycle requirement** (suggested: 1 or 2 cycles, set per card)
- After the requirement is met, the next time you play it, it comes out evolved

### Evolution ability
- Activated via a **button in the bottom right**
- The button must **never cover** the cards, the Ephrocity meter, or the towers
- Suggested: the button shows the evolved troop's icon + a cooldown ring
- **If more than one evolved troop is alive:** suggested a small stack of buttons (one per evo) or tap-to-switch

### Ability cost & cooldown
- Costs **Ephrocity**, and the cost **scales with the troop's max health** (tankier evos pay more)
- **Formula:** cost = 1 + (max health ÷ 500), rounded, clamped to **1–4**
- **20-second cooldown** after use
- If the evolved troop survives, the ability can be used again after the cooldown

### Evolution slots
- Max **2 evolutions** per deck

### Unlocking evolutions
- **Epic chests:** contain a **random evolution**
- **Legendary chests:** contain a random evolution **plus an Evolution Injection**
- **Evolution Injection:** use it on **any** card that can be evolved to unlock its evolution for free
- **Duplicate evolution:** turns into an **Injection Shard**. **3 shards = 1 Evolution Injection**

---

## 5b. Cards (from the Elendheim Codex)

> Stats are **draft** numbers, balanced around 15 tower damage at level 1.

**Starting set: 10 cards**
- **Common (5):** The Editor, The Spacefarer, The Individuals, The Dargalean, Chain
- **Rare (2):** John Arms, The Gasket
- **Epic (2):** The Hobb, Kardemosh
- **Legendary (1):** The Creeler
- **Arena 2 unlock:** The Spiker (Legendary spell)

**Rarity rule:** rarity follows the Codex threat level.
Threat 1–2 → Common · Threat 3 → Rare · Threat 4 → Epic · Threat 5 → Legendary

### ELND-001 — The Hobb
**Codex:** Class RINNER · Threat 4/5. Small humanoid with endless stomachs. **3 stomachs**, each able to turn *anything* into nutrients. **48 cm** tall. If starved for over an hour it eats anything around it, and its teeth get strong enough to bite through metal. First anomaly ever captured.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee |
| Targets | Ground |
| Rarity | Epic (Threat 4) |
| Ephrocity cost | 3 |
| Health | ~250 |
| Damage | ~25 per bite · 1.2 s hit speed |
| Speed | Fast |

**Passive: Three Stomachs**
- Every enemy troop it kills is **devoured**: heals a chunk and fills **1 stomach**
- 1 stomach: +heal · 2 stomachs: +damage · 3 stomachs (full): grows bigger, more health and damage for the rest of its life

**Passive: Munchies**
- If The Hobb goes **8 seconds without devouring**, it gets hungry: faster bites and **bonus damage vs buildings and towers** (teeth through metal)
- Ignore it and it eats your tower. Feed it your troops and it gets bigger. No safe answer except killing it fast.

**Evolution idea: Insatiable**
- Can devour **buildings** outright (eats *anything*)
- **Ability button:** *Gorge*: instantly devours a small enemy troop in front of it, filling a stomach

**Counter:** area spells and swarms early, before it eats.

---

### ELND-002 — The Editor
**Codex:** Class REKNA · Threat 2/5. A quiet presence that edits geography while unobserved: a door moves a metre, a stair gains a step. Can't change anything under direct observation. Countered by *Constant Watch*.

| Stat | Draft |
|---|---|
| Type | **Building** (a presence anchored to a spot) |
| Rarity | Common (Threat 2) |
| Ephrocity cost | 3 |
| Health / lifetime | ~400 · drains over ~30 s |
| Damage | None |

**Ability: Quiet Revision**
- Every **5 s**, The Editor "edits" the arena: the enemy troop **furthest along its path** gets shifted **back ~1.5 tiles** (a door moves a metre)
- **Only works while unobserved:** if any enemy troop is within **3 tiles** of The Editor, it can't revise

**Counter: Constant Watch.** Park a troop next to it, or knock it out with a spell. Straight from the codex.

**Evolution idea: Rewrite**
- **Ability button:** a bigger revision: pushes back **every** enemy troop in one lane at once

---

### ELND-003 — John Arms
**Codex:** Class REKNA · Threat 3/5 · Clearance 3. Once human, now arms for every body part: eyes held by hands, a tongue that is an arm, fingers for teeth. Completely harmless unless attacked first. *Flurry:* spins at up to 80 km/h and smashes anything it hits into the wall behind it, but tires out quickly. Treat it with respect and it respects you back.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee (area) |
| Targets | **Only what attacks it** |
| Rarity | Rare (Threat 3) |
| Ephrocity cost | 5 |
| Health | ~900 |
| Damage | ~30 per spin hit, area, with **knockback** |
| Speed | Medium |

**Passive: Respect**
- John Arms **doesn't attack** and **isn't attacked by building-only troops** (they ignore it)
- It walks the lane peacefully until something **damages it**, then it locks onto that attacker (troop or tower)

**Ability: Flurry**
- When provoked: spins for **4 s**, hitting everything around it and **knocking enemies back** (smashed into the wall)
- Then **Exhausted** for **3 s**: slow and can't attack. That's the window to kill it.

**Why it's interesting:** a tank the enemy *wants* to leave alone, but it walks toward their towers. Hitting it wakes it up. The tower shooting it counts as attacking it.

**Evolution idea: No Hard Feelings**
- **Ability button:** an on-demand Flurry, even if nobody has attacked it yet
- Exhaustion is shorter (2 s)

**Counter:** bait the Flurry, then hit hard during Exhausted. Or just don't touch it and defend elsewhere.

---

### ELND-004 — Kardemosh
**Codex:** Class RINNER · Threat 4/5. An autonomous mechanical humanoid that became self-aware and craves to be human. It rips the skin off humans and stitches it onto its own body, a patchwork of many people. The skin decays, forcing it to hunt again. Calm while wearing enough skin. Saying **"Halt!"** stops it dead and it takes about a minute to reset, but overusing the exploit lets it adapt. Prefers the name Kardemosh, "God of Flesh".

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee |
| Targets | Depends on mode (see below) |
| Rarity | Epic (Threat 4) |
| Ephrocity cost | 5 |
| Health | ~700 (mechanical body) |
| Damage | ~45 per hit · 1.5 s hit speed |
| Speed | Medium |

**Passive: Skin Stealer**
- Every enemy troop it kills gives it **Skin**: a shield layer on top of its health (max ~300)
- Skin **decays over time** (~10 per second)
- **Hunting mode (low Skin):** targets **troops**, moves faster. It wants skin.
- **Calm mode (Skin above ~200):** feels human, ignores troops and walks to **buildings/towers** instead
- So it defends by hunting your troops, then turns into a tanky tower pusher once it's "dressed"

**Weakness: Halt**
- Any **stun** on Kardemosh triggers a **reset**: it's stunned much longer than normal (e.g. 3 s instead of 0.5 s)
- **Adapts:** the second Halt in the same life only lasts half as long, the third does nothing ("it will find a way to counter it")

**Evolution idea: God of Flesh**
- Starts with some Skin already on
- **Ability button:** *Flay*: rips the Skin off the nearest enemy troop for big damage and instantly gains that much Skin

**Counter:** stun it early, then hit hard during the reset. Don't feed it cheap troops.

---

### ELND-005 — The Gasket
**Codex:** Class CLAM · Threat 3/5. An inescapable coffin. It never attacks, but whoever lies down in it feels comfort so deep they never want to leave. Works on only one person at a time. Hard counter: leave it be. Notes: *Do. Not. Enter. The. Gasket.*

| Stat | Draft |
|---|---|
| Type | **Building** (trap) |
| Rarity | Rare (Threat 3) |
| Ephrocity cost | 4 |
| Health / lifetime | ~600 · drains over ~35 s |
| Damage | None directly |

**Ability: Comfortable End**
- When empty, it **lures** the nearest enemy **ground troop** within ~4 tiles: the troop stops what it's doing and walks into the coffin
- The trapped troop **can't act** and **slowly loses health** (~8% of max health per second) until it dies
- Only **one troop at a time**; after it dies, The Gasket waits ~2 s, then lures again
- Great against big tanks: it costs 4 and can take out a 7-cost troop

**Counters**
- **Leaving it be:** flying troops and building-only troops are never lured
- **Amnestics:** destroy The Gasket and the trapped troop is freed (dazed for 1 s)

**Evolution idea: Do Not Enter**
- **Ability button:** *Close the Lid*: big burst of damage to the trapped troop, then the lid opens again right away

---

### ELND-006 — The Creeler
**Codex (draft):** Class HEIMER · Threat 5/5. A tall, spindly thing that hangs from ceilings. Its ribcage opens like a **creel**, a fisherman's basket trap. It lowers itself silently, closes around a person and lifts them away. No one taken has been found.

| Stat | Draft |
|---|---|
| Type | Troop · **Flying** · Melee |
| Targets | **Buildings & towers** (win condition) |
| Rarity | Legendary (Threat 5) |
| Ephrocity cost | 6 |
| Health | ~800 |
| Damage | ~40 per hit · 1.5 s hit speed |
| Speed | Slow |

**Ability: Snatch**
- When an enemy **ground troop** comes within range, The Creeler grabs it and flies it to the **very start of the enemy's side of the board** (their back line), drops it there, then heads back to attack the tower
- The defender is removed from the fight, and The Creeler gets free time on the tower
- **Cooldown: ~10 s.** It can only snatch one troop at a time, so a second defender is the answer
- While carrying a troop it **can't attack** and takes **+25% damage**

**Evolution idea: Empty Basket**
- **Ability button:** *Drop*: releases the carried troop early, from height, for big impact damage to it and everything around it

**Counter:** flying troops and spells (they can't be snatched), towers, or two ground defenders at once (it can only take one).

---

### ELND-007 — The Spiker
**Codex (draft):** Class RINNER · Threat 5/5. A seed-like anomaly. Wherever it lands, black spikes erupt from the ground within seconds and keep growing as long as something living stands nearby.

| Stat | Draft |
|---|---|
| Type | **Spell** (damage) |
| Rarity | Legendary (Threat 5) |
| Ephrocity cost | 4 |
| Radius | ~3 tiles |
| Damage | ~120 on eruption (reduced vs towers) |

**Ability: Spike Field**
- Spikes erupt in the target area, then leave a **spike field for 4 s**: damages and **slows** anything standing in it
- Damage grows a little each second something stays inside

**Unlock:** first Legendary unlockable in **Arena 2** (not in the starting set)

**Evolution:** spells can't evolve (suggested); keep it as is

---

### ELND-008 — The Dargalean
**Codex (draft):** Class CLAM · Threat 1/5. A small, gentle creature with big eyes. Everyone who sees it feels an urge to go pet it. Harmless, but staff keep "losing" hours in its room.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · No attack |
| Rarity | Common (Threat 1) |
| Ephrocity cost | **1** |
| Health | ~120 |
| Damage | None |
| Speed | Medium |

**Ability: Irresistible**
- All enemy troops within ~3 tiles **target The Dargalean** for as long as it lives
- Role: **cheap cycle card + decoy**: pull a tank off a lane, or buy time

**Evolution idea: Lost Hours**
- **Ability button:** *Cuddle*: enemies near it stop attacking anything for 2 s

**Counter:** ranged attackers and spells pop it instantly.

---

### ELND-009 — The Spacefarer ("Sleepfield")
**Codex:** Class CLAM · Threat 1/5. A humanoid alien who claims to be a human from the future. Intersex, like everyone of their species. Barely needs food or water and only 3 hours of sleep. Safe if kept fed and talked to.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · **Ranged** (future blaster) |
| Targets | **Air & ground** |
| Rarity | Common (Threat 1) |
| Ephrocity cost | 2 |
| Health | ~150 |
| Damage | ~18 per shot · 1.0 s hit speed · range 5 tiles |
| Speed | Medium |

**Passive: Three Hours**
- Never tires: **attack speed increases by 10% every 3 s** it keeps attacking (max +50%)
- Resets if it stops attacking for a moment

**Role:** cheap ranged support and **anti-air**. Sits behind a tank and ramps up.

**Evolution idea: From the Future**
- **Ability button:** *Time Skip*: blinks ~3 tiles away (backwards to escape, or forward to chase) and keeps its ramped-up attack speed

**Counter:** anything that reaches it. It's fragile.

---

### ELND-010 — The Individuals
**Codex:** Class CLAM · Threat 1/5. Top halves of human heads sticking out of the ground, sliding around like slugs and staring. Their gaze fills you with dread until they blink. Through a screen they look 2D. Throw something behind them and they all turn. Harmless, just creepy.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee · **Swarm (x4)** |
| Targets | Ground |
| Rarity | Common (Threat 1) |
| Ephrocity cost | 2 |
| Health | ~60 each |
| Damage | ~10 per hit each · 1.0 s hit speed |
| Speed | **Slow** (sliding) |

**Passive: Gaze**
- Enemy troops they're looking at feel **dread: −30% attack speed** (doesn't stack between Individuals)
- **Blink:** every 4 s they blink for 1 s and the dread pauses

**Weakness: Distract**
- When any Individual is hit, **all of them turn** toward that attacker. Bait them with something cheap from the side and push past while they're looking away.

**Evolution idea: Seen Through a Screen**
- **Ability button:** *Flatten*: they turn 2D for 2 s and **can't be targeted** (invisible from the side)

**Counter:** any area damage.

---

### ELND-011 — Chain
**Codex (draft):** Class CLAM · Threat 1/5. An ordinary-looking steel chain. Anything it touches becomes linked: what happens to one happens to the other.

| Stat | Draft |
|---|---|
| Type | **Spell** (link) |
| Rarity | Common (Threat 1) |
| Ephrocity cost | 2 |
| Damage | ~30 on cast |

**Ability: Link**
- Chains up to **3 enemy troops** in the target area together for **6 s**
- **Damage dealt to one is shared with all linked troops** (each takes the full amount)
- Combo card: great with The Spiker, The Hobb, Kardemosh, or any big hitter

**Counter:** spread your troops out so it can't catch three.

---

## 6. Progression

### 6.1 Trophy Road & Arenas
- **+30 trophies** per win, **−15** per loss
- Trophies move you along the **road**; a **new arena every 400 trophies**
- New arenas unlock new cards for chests

### 6.2 Player Level
- **No max player level** (effectively infinite)
- Gained through XP from playing and upgrading cards
- **Every 3 player levels:** your towers level up
- **Every other level:** a **rank up chest** (= a Rare chest + 100 gold)
- Every player level gives **100 gold**

### 6.2b Tower Levels
- Tower level is tied to player level and **caps at level 20**
- Towers only level up **every 3 player levels**, so max towers come at around **player level 58**
- After that, player levels keep giving rank up chests + gold

### 6.3 Card Levels
- Cards level up using **duplicate copies only, no currency needed**
- **Max card level: 20**
- Upgrading should feel quick and rewarding, never grindy

### 6.3b Level Scaling (rule)
- **Same level = same interaction.** Two cards at level 1 fight exactly the same as at level 10 or 20
- How: every level multiplies **health and damage** by the **same factor for every card and every tower** (default **+10% per level**, compounding: level 20 ≈ 6.1× level 1)
- **Never scales:** speed, hit speed, range, Ephrocity cost, ability timings
- Only *different* levels change outcomes, which is exactly what the trophy-road bot scaling and Pure Balance mode rely on

### 6.3c Copies Needed
- Level 2: **3** copies · Level 3: **6** · Level 4: **9** · … each level needs **3 more** than the last
- Formula: copies for level *n* = **3 × (n − 1)**
- Total from level 1 to 20: **570 copies** per card

> Grind check: chests average ~9 cards per game (from the odds table). Maxing all 10 starting cards ≈ 5,700 copies ≈ **~600 games** plus shop chests. Fine as a long-term goal, but every new card adds 570 more. Chests scaling with arena (section 7.1) makes later levels much faster, since the most expensive upgrades happen when chests are biggest. Tune the 0.25 multiplier in Admin Mode if it's too fast or too slow.

### 6.3d XP
- **+100 XP** per win
- **+50 XP** per card level up
- XP to reach the next player level (default): **200 + 50 × current level** (level 1→2 = 250 XP, level 10→11 = 700 XP)

### 6.4 Wild Cards
- When a card is at **max level (20)**, extra copies of it become **wild cards**
- Wild cards can level up **any** card in the game
- No duplicate is ever wasted

---

## 7. Chests & Gold

### 7.1 Free chests
- **You get a chest after every game.** No slots, no timers.

| Rarity | Odds |
|---|---|
| Common | 60% |
| Rare | 25% |
| Epic | 12% |
| Legendary | 3% |

- **Pity timer:** guaranteed Legendary chest if none in the last 30 games
- Higher rarity chests = more cards + higher chance of rare cards

| Chest | Cards | Guaranteed extras |
|---|---|---|
| Common | 5 | 1 Rare |
| Rare | 10 | 1 Epic |
| Epic | 20 | 1 random evolution |
| Legendary | 40 | 1 random evolution + 1 Evolution Injection + 1 extra Legendary |

**Chests scale with your arena:** the card counts above are for **Arena 1**. Each new arena gives more cards from the same chest.
- Default formula: cards × **(1 + 0.25 × (arena − 1))**, rounded
- e.g. a Common chest: 5 cards in Arena 1 → 10 in Arena 5 → 15 in Arena 9
- Guaranteed extras (evolutions, injections, extra Legendary) stay the same

### 7.1b Chest Opening Animations
Goal: **really satisfying and addicting**, escalating hard with rarity.

- **Anticipation:** tap to open; the chest shakes, Ephrocity (wine red) leaks from the seams. The longer the build-up, the rarer the chest.
- **Rarity reveal by colour:** the glow shifts to the rarity colour at the last moment, so you're never sure until it pops
- **Epic:** purple surge, the chest floats up, energy crackles, heavy bass hit + strong vibration
- **Legendary:** full **containment breach**: screen goes dark, red alarm lights sweep, warning text ("CONTAINMENT BREACH"), the chest cracks open with light beams, a big music sting and long vibration
- **Upgrade surprise (idea):** sometimes a chest **upgrades mid-animation** (Common → Rare → Epic…), which keeps every opening exciting
- **Card reveal:** cards come out one at a time with a tap; Rare+ cards flip with a short pause first
- **New card:** an "**NEW ANOMALY ACQUIRED**" codex stamp slams onto the card, and it unlocks in the in-game Codex
- **Haptics** (phone vibration) on every big moment
- **Skip button** for Common/Rare chests so they never get annoying

### 7.2 Gold & Shop
- **Gold is earned from:**
  - **50** per win
  - **20 × new level** per card upgrade
  - **100** per player level
- **Gold is only used to buy chests** in the **Shop** (never for upgrades)
- Shop chests use the same contents table as above:

| Shop chest | Price |
|---|---|
| Common | 200 |
| Rare | 500 |
| Epic | 1,200 |
| Legendary | 3,000 |

- No real money, ever

---

## 8. Game Modes

| Mode | Description |
|---|---|
| **Battle** | Classic 1v1 vs a bot. Earns trophies + chests. |
| **Defense (PvE)** | Tower defense: waves of anomalies attack your towers, you defend with your deck. A chest after every run; the further you get, the better the chest tier. Best wave saved as a record. |
| **Challenges** *(later)* | Special rule sets, e.g. "spells only", boss fights, survival. |

All modes use the **same cards and unit system**.

---

## 9. Bot AI

### 9.1 Difficulty (in Settings)
Presets: **Easy / Medium (default) / Hard**, plus optional custom sliders.

Knobs:
- **Reaction time:** how fast it responds to your pushes
- **Ephrocity smarts:** saves up for big pushes vs. dumps cards instantly
- **Counter-play:** how often it picks the *right* counter
- **Deck quality:** random decks vs. synergy decks

### 9.2 Bot Card Levels
- Bot card levels scale with **how far you've progressed on the trophy road**
- At the top of the road, the bot is **fully equal** to you
- Difficulty comes from *how smart the bot plays*

### 9.3 Pure Balance Mode (Setting)
- Removes levels from battles entirely: both sides equal from the start
- Gives **chests but no trophies**, so the trophy road stays meaningful

---

## 9b. In-game Codex (idea)

- A **Codex** menu where each card's full Elendheim Codex entry unlocks when you get the card
- Codex **Stories** (like *Diary of Rob Johnson*) unlock as extra lore, e.g. at card level milestones

---

## 10. Stats Tracking

Saved locally. Ideas:
- Wins / losses / win rate (overall + per mode + per difficulty)
- Highest trophies reached
- Most-played cards, win rate per card, favourite deck
- Chests opened (by rarity), legendaries pulled
- Longest win streak, three-crown wins
- Total games / total playtime
- PvE: highest wave reached

---

## 11. Balancing & Dev Tools

- There will always be some imbalance, and that's fine. It's my game.
- **All card stats live in data files** (not hardcoded)
- **Admin Mode** (the dev menu): edit and test **everything** on the fly, no code needed
- **Unlock:** tap the version number in Settings 7 times

**Card & balance editor**
- Edit any stat of any card, tower or evolution (health, damage, speed, range, cost, ability values, cooldowns)
- Changes apply **live**, even mid-match
- Save to the data files, reset a card to defaults, or **export/import** a whole balance setup
- **Neutralize** a card (pulls it from bots and decks)

**Battle testing**
- Spawn any troop on **either side**, anywhere
- Infinite Ephrocity toggle (for you or the bot)
- Time controls: pause, **0.25× / 0.5× / 2×** speed
- Set or force the bot's deck and difficulty
- Show hitboxes, attack ranges, targeting lines, FPS

**Progression & economy**
- Give cards, gold, XP, trophies, wild cards, injections
- Set player level, arena, card levels; unlock everything
- Edit chest odds, chest contents, arena scaling, copies curve, XP curve
- Open **any chest type** and **force its rarity** (to test animations)
- Reset progress

---

## 12. Settings (so far)

- Bot difficulty (Easy / Medium / Hard / Custom)
- Pure Balance mode on/off
- Sound / music volume
- Admin Mode (tap version number 7 times)

---

## 13. Build Milestones

0. **Setup:** Godot project, data files structure, Android export working on Henry's phone
1. **Arena prototype:** 18×32 arena, river, bridges, towers, units walk and fight + basic Admin Mode
2. **Cards & Ephrocity:** the starting cards (troops first), deck of 8, hand of 4, meter, placing units (1 s deploy), targeting rules
3. **Dumb bot** → **first full match playable**
4. **Win rules:** crowns, overtime, tiebreaker
5. **Smarter bot:** difficulty knobs + presets
6. **Spells & buildings**
7. **Progression:** trophies, road, arenas, chests, card levels, wild cards
8. **Evolutions:** cycle tracking, evolved forms, ability button, injections
9. **Save system + stats screen + gold & shop**
10. **Defense (PvE) mode**
11. **Polish:** art, sounds, animations, more cards
12. **Extras:** challenges, Pure Balance mode, in-game Codex, Admin Mode upgrades

> Rule: the game should be playable at the end of every milestone.

---

## 14. Open Questions

- [ ] Write the full Codex entries for The Creeler, The Spiker, The Dargalean and Chain (drafts in section 5b)
- [ ] Can spells evolve? (suggested: no)
- [ ] Cards for Arena 3+
- [ ] Which cards can evolve, and each one's cycle requirement
- [ ] Pixel art colour palette
