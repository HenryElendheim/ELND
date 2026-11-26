# ELND — Design Doc

> Title: **ELND** (Henry says it "Elend"; players can say E-L-N-D too)
> Platform: Android (personal, not for sale)
> Engine: Godot 4 (latest stable), GDScript
> Last updated: 26 Nov 2026

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

### Evolution slot
- The **first place in the deck is the evolution slot**
- If you have the evolution for the card in that slot, it is the **only evolution in the deck**. Evolutions of cards in other places are not used.
- The number of slots is in `battle.json` (`evolution.slots`, default **1**)

### Showing evolutions in battle
- Hand cards with an evolution show a purple tag: **one dot per play still needed** (filled as they are done), then **EVO** when it is ready
- A line above the hand says how many plays are left (e.g. "Hobb evolves in 1 play"), even while the card waits in the queue
- Evolved troops and buildings on the field have a **purple glow and ring**, which pulses gently unless reduced motion is on

### Unlocking evolutions
- **Epic chests:** contain a **random evolution**
- **Legendary chests:** contain a random evolution **plus an Evolution Injection**
- **Evolution Injection:** use it on **any** card that can be evolved to unlock its evolution for free
- **Duplicate evolution:** turns into an **Injection Shard**. **3 shards = 1 Evolution Injection**

---

## 5b. Cards (from the Elendheim Codex)

> Stats are **draft** numbers, balanced around 15 tower damage at level 1.

**Starting set: 10 cards**
- **Common (5):** The Editor, The Spacefarer, The Individuals, The Dargalean, The Chain
- **Rare (2):** John Arms, The Gasket
- **Epic (2):** The Hobb, Kardemosh
- **Legendary (1):** The Creeler
- **Arena 2 unlocks:** The Spiker (Legendary spell), The Cloud, The Hanged One, The Swarm
- **Arena 3 unlocks:** The Devil In The Forest, Mrs. Give & Take, The Clone
- **Arena 4 unlocks:** The Danger Zone, The Blinker, The Pardoned One

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

### ELND-011 — The Chain
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

### ELND-012 — The Devil In The Forest
**Codex:** Class RINNER · Threat 3/5 · Tags: Cognitohazard. A demonic humanoid who is too charming: tall, curled horns, a wide warm smile. Nothing about it reads as a threat, and people feel a strong urge to walk over and say hi. Within 2 metres it drains their life essence; they fight back, but their hits barely affect it. Doesn't work if your eyes are closed or you're out of range. Contained by feeding it clones. Do not look at it directly ever. (Name originally from a 2018 game Henry made with old friends.)

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee |
| Targets | Ground |
| Rarity | Rare (Threat 3) |
| Ephrocity cost | 4 |
| Health | ~550 |
| Damage | Drain only (see below) |
| Speed | Medium |
| Unlock | Arena 3 |

**Passive: Smile (the urge to say hi)**
- Enemy ranged troops don't shoot it from a distance: they walk up to it, losing their range advantage

**Ability: Happy Face**
- Drains one enemy troop at a time within ~1.5 tiles: ~20 damage per second, and heals itself by the same amount
- The drained troop deals −50% damage to it ("hits barely affect it")
- When the victim dies, it picks the next closest one

**Limits (from the codex): no eyes, no effect**
- Towers, buildings and spells aren't affected by Smile or the −50%, so they hit it at full damage
- Any troop that's stunned or "blinking" (e.g. The Individuals mid-blink) is immune while its eyes are closed

**Evolution idea: Deeper Into the Woods**
- **Ability button:** instantly switches the drain to a new target and drains extra fast (3×) for 3 s

**Counter:** swarms (it can only drain one), spells, and letting your tower deal with it.

---

### ELND-013 — The Pardoned One
**Card name:** The Pardoned One · **Codex name:** Jessica Winters
**Codex:** Class REKNA · Threat 5/5. A winged woman, alive for over 1000 years, who hunts humans and feasts on their bones and marrow (claims she's no vampire: she doesn't drink blood). Pardoned for one reason: she cannot die. Killed, she's born anew in a new host, forever, unless she's kept alive and in one spot. Sharp Wings: shoots razor feathers that return to her wings carrying the victim's nutrients; use too many and she can't fly. Hard counter: birdfeed, even a whiff makes her lose interest in killing. Prefers to be called Jessica Winters.

| Stat | Draft |
|---|---|
| Type | Troop · Flying · Ranged |
| Targets | Air & ground |
| Rarity | Legendary (Threat 5) |
| Ephrocity cost | 6 |
| Health | ~850 |
| Damage | ~25 per feather · 0.6 s hit speed · range 5 tiles |
| Speed | Medium |
| Unlock | Arena 4 |

**Ability: Sharp Wings**
- Each shot sends out a feather that returns to her after ~1.5 s and heals her for the damage it dealt
- She has 12 feathers. If more than 8 are out at once, she's grounded: she can't fly, so melee ground troops can hit her, until enough feathers return. With all 12 out she can't shoot.
- She never lands in the river: over water she stays up until she reaches ground or a bridge

**Passive: Pardoned (reincarnation)**
- When she dies while flying, she's born anew once at your main tower with ~40% health
- If she dies while grounded ("kept in one spot"), she's gone for good

**Evolution idea: A Thousand Years**
- **Ability button:** Feather Storm: fires all her remaining feathers at everything in range at once, a huge burst with big healing, but she's grounded for 4 s afterwards

**Counter:** swarms to make her ground herself, then melee + spells. Future card idea: a Birdfeed spell that pacifies flyers for a few seconds.

---

### ELND-014 — The Cloud
**Codex:** Class CLAM · Threat 2/5. A cloud that perceives reality and strikes lightning straight down at anyone it finds threatening, or just annoying. Not even rubber stops its lightning. Can't strike faster than once every 5–8 s. Happy in captivity as long as it's entertained.

| Stat | Draft |
|---|---|
| Type | Building (hovering): stays where it's placed, counts as air (only air-targeting troops, towers and spells can hit it) |
| Rarity | Common (Threat 2) |
| Ephrocity cost | 3 |
| Health / lifetime | ~300 · drains over ~20 s |
| Damage | ~60 per strike + 1 s stun |
| Unlock | Arena 2 |

**Ability: Lightning Strike**
- Strikes an enemy troop below it (~2.5 tile radius), then waits 5–8 s (random each time). The first strike comes as soon as something is below it.
- Irritated: if something damages it, its next strike goes to that attacker (if in range)
- Lightning ignores shields: hits Kardemosh's Skin directly
- This is the game's first stun: it triggers Kardemosh's Halt reset and closes enemies' "eyes" vs The Devil In The Forest

**Evolution idea: Thunderhead**
- **Ability button:** Storm: drifts ~3 tiles toward the enemy side and strikes immediately

**Counter:** air-targeting troops and spells; rush past between strikes.

---

### ELND-015 — The Danger Zone
**Codex:** Class CLAM · Threat 4/5. A small parasite that affects a 15 m area, enraging everyone inside it. They grow stronger, fight to the death and don't feel their own bones breaking from their newfound strength. Can't stay active for more than 20 s. Mitigation: a full protective suit.

| Stat | Draft |
|---|---|
| Type | Spell (empower zone) |
| Rarity | Epic (Threat 4) |
| Ephrocity cost | 3 |
| Radius | ~3.5 tiles |
| Duration | 10 s (lore max 20 s) |
| Unlock | Arena 4 |

**Ability: Enrage**
- Every living troop inside, yours AND the enemy's, gets +35% attack speed and move speed and takes −25% damage ("doesn't feel the hurt")
- Backlash (breaking bones): when the zone ends, every troop that was enraged takes 10% of its max health as damage
- Play it where you have more troops than the enemy. Misplace it and you buff their push.

**Counter:** Full Protective Suit. Towers and buildings are unaffected, and so are non-living troops (see The Hanged One).

**Evolution:** spells don't evolve.

---

### ELND-016 — The Hanged One
**Codex:** Class CLAM · Threat 1/5. A humanoid whose neck has been perfectly broken by the rope around it. For unknown reasons it cannot strike a living creature. Borderline indestructible, but its hits are mediocre, so it can never break out of its cell. Almost like a lost dog seeking companionship. (Abilities and containment are not written in the codex yet, so the card mechanics below are draft.)

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee · Tank |
| Targets | Buildings & towers only (they aren't living) |
| Rarity | Common (Threat 1) |
| Ephrocity cost | 5 |
| Health | ~1400 (the game's biggest so far) |
| Damage | ~30 per hit · 1.5 s hit speed (mediocre) |
| Speed | Slow |
| Unlock | Arena 2 |

**Passive: Cannot Strike the Living**
- Ignores all troops and walks straight to buildings and towers: your first ground win condition

**Passive: Not Living**
- Can't be lured by The Gasket, drained by The Devil In The Forest or Mrs. Give & Take, healed by Mrs. Give & Take, or enraged by The Danger Zone (there's no life to affect)

**Passive: Lost Dog (teamwork)**
- While an allied troop is within ~2 tiles, it takes −20% damage. It's tougher with company.

**Evolution idea: The Rope**
- **Ability button:** Leash: pulls the nearest allied troop (within ~6 tiles) next to it so it's never alone

**Counter:** high-damage troops and swarms (it can't hit back), or kill its companions to remove Lost Dog.

---

### ELND-017 — The Clone
**Codex:** Class CLAM · Threat 1/5. A clone from the future that can duplicate itself at will. The Foundation used its DNA to build its own cloning machines and injections (the source of the clones used to feed ELND-012 and ELND-015). Its cells clone anything they touch, so the Foundation turned it into an almost-grenade: thrown on their strongest warriors, the clones fight alongside them. Clones are about 50% weaker, but fantastic decoys. Happy as long as it's treated kindly.

| Stat | Draft |
|---|---|
| Type | Spell (clone grenade) |
| Rarity | Common (Threat 1) |
| Ephrocity cost | 3 |
| Radius | ~3 tiles |
| Unlock | Arena 3 |

**Ability: Clone**
- Every allied troop in the area gets a clone next to it
- Clones have 50% health and 50% damage of the original (abilities included)
- Clones are the base form: evolutions aren't copied
- Doesn't clone buildings

**Lore interactions**
- A clone of The Pardoned One can't reincarnate (it was never really her)
- Clones count as living (unlike The Hanged One), so The Gasket and The Devil happily take them, which makes them perfect decoys

**Evolution:** spells don't evolve.

**Counter:** area spells; clones are half-strength and die fast.

---

### ELND-018 — Mrs. Give & Take
**Codex:** Class RINNER · Threat 3/5. A human woman who drains the life from one creature to give it to another. Take: drains one creature at a time, and it empowers her. Give: gives life force to the most hurt creature she can find; she can give more than she took, but only by draining her own life. Contained with lots of animal pets to look after; she drains every predatory animal sent in, to keep her pets safe and full of life.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Ranged (drain beam) · Support / healer |
| Targets | Ground & air (drain) |
| Rarity | Rare (Threat 3) |
| Ephrocity cost | 4 |
| Health | ~400 |
| Damage | Drain only (see below) · range ~4 tiles |
| Speed | Medium |
| Unlock | Arena 3 |

**Ability: Take**
- Drains one enemy at a time: ~15 damage per second, stored in her Life Pool (max ~300)
- Protective (her pets): she drains the enemy that's attacking the ally she's healing first ("drains the predators")
- Empowered: while her Life Pool is over half full, her drain is +50% faster

**Ability: Give**
- Constantly heals the most hurt allied troop in range (~20 health per second), paid from her Life Pool
- Empty pool: she keeps healing by spending her own health. She can die keeping an ally alive.

**Lore interactions**
- The Hanged One can't be drained or healed (not living)
- Clones are living: perfect "pets" or "prey"

**Evolution idea: Return**
- **Ability button:** dumps her entire Life Pool at once, split between all allies in range

**Counter:** kill her first (she's fragile), or out-damage her healing with swarms and spells.

---

### ELND-019 — The Blinker
**Codex:** Class HEIMER · Threat 5/5. A mass of flesh that can speed past you in less than a second and consumes your flesh quicker than you can blink. Zoom: it speeds itself forward, but every skip shortens its lifespan by the time it skipped, so it has to be careful. If it Zooms more than 4 times in a row without a recharge, it dies.

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee · Assassin |
| Targets | Living troops only (it eats flesh: ignores buildings, towers and The Hanged One) |
| Rarity | Legendary (Threat 5) |
| Ephrocity cost | 5 |
| Health | ~500 |
| Damage | ~90 per bite · 1.0 s hit speed |
| Speed | Very fast (2 tiles a second) |
| Unlock | Arena 4 |

**Ability: Zoom**
- When its target is more than ~2 tiles away, it Zooms: instantly dashes up to ~4 tiles and bites on arrival
- Each Zoom adds 1 Strain (its lifespan burning away). Strain recharges by 1 every 4 s without Zooming
- 5 Strain = death. On its own it stops at 4 ("it has to be careful")
- It only Zooms on its own side of the river (it can't skip over water)

**Evolution idea: Quicker Than You Can Blink**
- **Ability button:** Overzoom: forces one more Zoom past the limit, a huge bite (×3 damage), then it dies. A sacrifice play.

**Counter:** non-living tanks (The Hanged One), buildings, flyers (it can't reach them) and spells.

---

### ELND-020 — The Swarm
**Codex:** Class REKNA · Threat 1/5. A group of 15 short humanoids with sharp swords. (Only the summary is written in the codex so far, so the card mechanics below are draft.)

| Stat | Draft |
|---|---|
| Type | Troop · Ground · Melee · Swarm (×15) |
| Targets | Ground |
| Rarity | Common (Threat 1) |
| Ephrocity cost | 4 |
| Health | ~30 each |
| Damage | ~8 per hit each · 1.0 s hit speed |
| Speed | Fast |
| Unlock | Arena 2 |

No special ability: pure numbers. Fifteen sharp swords shred tanks and single-target cards (The Devil, Mrs. Give & Take, The Gasket can only handle one at a time).

**Evolution idea: Formation**
- **Ability button:** pulls all surviving members together into a tight group for a focused charge (+50% speed for 3 s)

**Counter:** area damage: The Spiker, John Arms' Flurry, area spells.

---

## 6. Progression

### 6.1 Reputation Road & Arenas
- **Reputation** is your standing around the ELND Foundation
- **+30 reputation** per win, **−15** per loss
- Reputation moves you along the **road**; a **new arena every 400 reputation**
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
- Only *different* levels change outcomes, which is exactly what the reputation road bot scaling and Pure Balance mode rely on

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
| **Battle** | Classic 1v1 vs a bot. Earns reputation + chests. |
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
- Bot card levels scale with **how far you've progressed on the reputation road**
- At the top of the road, the bot is **fully equal** to you
- Difficulty comes from *how smart the bot plays*

### 9.3 Pure Balance Mode (Setting)
- Removes levels from battles entirely: both sides equal from the start
- Gives **chests but no reputation**, so the reputation road stays meaningful

---

## 9b. In-game Codex (idea)

- A **Codex** menu where each card's full Elendheim Codex entry unlocks when you get the card
- Codex **Stories** (like *Diary of Rob Johnson*) unlock as extra lore, e.g. at card level milestones

---

## 10. Stats Tracking

Saved locally. Ideas:
- Wins / losses / win rate (overall + per mode + per difficulty)
- Highest reputation reached
- Most-played cards, win rate per card, favourite deck
- Chests opened (by rarity), legendaries pulled
- Longest win streak, three-core wins
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
- **Neutralize** a card (pulls it from bots and decks). Find cards with a search field by name or by category (troop, building, spell, ground, flying, melee, ranged, rarity, class) and neutralize or restore everything shown at once

**Battle testing**
- Spawn any troop on **either side**, anywhere
- Infinite Ephrocity toggle (for you or the bot)
- Time controls: pause, **0.25× / 0.5× / 2×** speed
- Set or force the bot's deck and difficulty
- Show hitboxes, attack ranges, targeting lines, FPS

**Progression & economy**
- Give cards, gold, XP, reputation, wild cards, injections
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
4. **Win rules:** cores, overtime, tiebreaker
5. **Smarter bot:** difficulty knobs + presets
6. **Spells & buildings**
7. **Progression:** reputation, road, arenas, chests, card levels, wild cards
8. **Evolutions:** cycle tracking, evolved forms, ability button, injections
9. **Save system + stats screen + gold & shop**
10. **Defense (PvE) mode**
11. **Polish:** art, sounds, animations, more cards
12. **Extras:** challenges, Pure Balance mode, in-game Codex, Admin Mode upgrades

> Rule: the game should be playable at the end of every milestone.

---

## 14. Open Questions

- [ ] Write the full Codex entries for The Creeler, The Spiker, The Dargalean and The Chain (drafts in section 5b)
- [ ] Can spells evolve? (suggested: no)
- [x] Cards for Arena 3 and 4 (ELND-012 to 020)
- [ ] Cards for Arena 5+
- [ ] Birdfeed spell (pacifies flyers for a few seconds, a hard counter to The Pardoned One)
- [ ] Full codex entries (abilities and containment) for The Hanged One and The Swarm
- [ ] Which cards can evolve, and each one's cycle requirement
- [ ] Pixel art colour palette
