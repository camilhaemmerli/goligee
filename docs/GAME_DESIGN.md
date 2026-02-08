# Goligee -- Game Design Document

## Vision
An 8-bit isometric tower defense game where you command riot police defending a government
building against waves of increasingly organized protestors. The tone is darkly satirical --
ironic authoritarian propaganda-speak throughout. Post-apocalyptic urban setting, perpetually
at night with harsh streetlights and emergency floodlights.

---

## Core Mechanics

### Damage Types (8 types)

| Type            | Color     | Strengths                    | Weaknesses                |
|-----------------|-----------|------------------------------|---------------------------|
| Kinetic         | Silver    | Reliable baseline            | Weak vs armor             |
| Chemical        | Coral     | Burn DoT, AoE               | Useless vs Chemical-immune|
| Hydraulic       | Cool Blue | Slows/Freezes                | Low damage                |
| Electric        | Gold      | Chain hits, stuns            | Weak vs shielded          |
| Sonic           | Green     | DoT stacking, ignores armor  | Useless vs mechanized    |
| Directed Energy | Purple    | Ignores physical armor       | Weak vs energy-resist     |
| Cyber           | White/Gold| Strong vs analog/unshielded  | Weak vs cyber-hardened    |
| Psychological   | Void      | Debuffs, morale drain        | Weak vs true believers    |

### Armor Types (6 types)

| Armor Type | Kinetic | Chemical | Hydraulic | Electric | Sonic | Directed Energy | Cyber | Psychological |
|------------|---------|----------|-----------|----------|-------|-----------------|-------|---------------|
| Unarmored  | 1.0     | 1.25     | 1.0       | 1.5      | 1.5   | 1.0             | 1.0   | 1.25          |
| Light      | 1.0     | 1.5      | 1.25      | 1.0      | 1.25  | 1.25            | 1.0   | 1.0           |
| Medium     | 1.0     | 1.0      | 1.0       | 0.75     | 1.0   | 0.75            | 1.0   | 1.0           |
| Heavy      | 0.7     | 0.75     | 1.0       | 1.25     | 1.0   | 1.5             | 1.0   | 0.5           |
| Fortified  | 0.5     | 0.5      | 0.75      | 0.35     | 1.0   | 0.35            | 1.0   | 0.5           |
| Boss       | 0.8     | 0.9      | 0.85      | 0.9      | 0.7   | 0.85            | 1.0   | 0.75          |

### Damage Formula

```
final_damage = base_damage
  * armor_type_multiplier[damage_type][armor_type]
  * elemental_resistance
  * (1 - armor / (armor + 100))   # diminishing returns
  * vulnerability_modifier          # from debuffs
  * crit_multiplier                 # 1.0 or crit_mult
```

---

## Towers

### Tower List

| Tower                | Damage Type     | Projectile | AoE   | Cost | Role              |
|----------------------|-----------------|------------|-------|------|-------------------|
| Rubber Bullet Turret | Kinetic         | Bullet     | No    | 100  | Starter DPS       |
| Tear Gas Launcher    | Chemical        | Lobbed     | 1.5t  | 200  | AoE specialist    |
| Taser Grid           | Electric        | Chain      | Chain | 175  | Crowd control     |
| Water Cannon         | Hydraulic       | Nova       | 2.0t  | 125  | Slow/Freeze       |
| Surveillance Hub     | Psychological   | Hitscan    | No    | 250  | Recon/Support     |
| Pepper Spray Emitter | Chemical        | Beam       | No    | 175  | Sustained DoT     |
| LRAD Cannon          | Sonic           | Lobbed     | 1.0t  | 150  | Stacking DoT      |
| Microwave Emitter    | Directed Energy | Hitscan    | No    | 225  | Anti-armor        |

### Upgrade System (BTD6-style 3-path)

Each tower has **3 upgrade paths with 5 tiers each**.
- Only **2 paths** can be selected per tower
- Only **1 path** can go beyond tier 2
- Crosspathing creates meaningful sub-builds

#### Rubber Bullet Turret Upgrade Paths

**Path A -- "Marksman Protocol" (Single Target DPS)**
1. Extended Barrel (+20% range)
2. Penetrator Rounds (pierce 2 enemies)
3. Advanced Optics (+50% damage, +30% range)
4. Kneecapper (15% chance to stun 0.5s)
5. **DEADSHOT** -- Hitscan projectiles, 25% crit, 3x crit multiplier

**Path B -- "Suppression Fire" (AoE/Speed)**
1. Rapid Cycling (+30% fire rate)
2. Double Tap (2 rounds per attack)
3. Burst Pattern (1.5 tile AoE, lobbed)
4. Full Auto (4 rounds per attack)
5. **BULLET HELL** -- 8 rounds/sec continuous rain in radius

**Path C -- "Special Munitions" (Utility)**
1. Irritant Tips (3 DPS chemical for 3s)
2. Guided Rounds (homing)
3. Weakening Impact (+15% damage taken by target for 2s)
4. Directed Energy Rounds (damage type -> Directed Energy)
5. **EXPERIMENTAL ORDNANCE** -- every 5th shot hits all enemies in range

#### Tear Gas Launcher Upgrade Paths

**Path A -- "Chemical Warfare"** -> Tier 5: **NERVE AGENT DEPLOYER** (massive AoE, screen shake)
**Path B -- "Saturation Coverage"** -> Tier 5: **CARPET GASSER** (line of gas clouds)
**Path C -- "Crowd Psychology"** -> Tier 5: **PANIC INDUCER** (periodic AoE stun)

#### Taser Grid Upgrade Paths

**Path A -- "High Voltage"** -> Tier 5: **ARC REACTOR** (10 chain targets, all stunned)
**Path B -- "Neural Disruptor"** -> Tier 5: **EMP GRID** (beam splits to 3 targets)
**Path C -- "Compliance Network"** -> Tier 5: **BLACKOUT FIELD** (disables enemy abilities in range)

#### Water Cannon Upgrade Paths

**Path A -- "Pressure Control"** -> Tier 5: **TSUNAMI CANNON** (drench all in range every 10s)
**Path B -- "Hydro Cutter"** -> Tier 5: **INDUSTRIAL WASHER** (massive hydraulic DPS in huge area)
**Path C -- "Crowd Soaker"** -> Tier 5: **HYPOTHERMIA FIELD** (-50% armor, +30% damage taken)

#### Surveillance Hub Upgrade Paths

**Path A -- "Drone Fleet"** -> Tier 5: **PANOPTICON** (permanent drone army)
**Path B -- "Data Mining"** -> Tier 5: **SOCIAL CREDIT ENGINE** (+100% gold from kills in range)
**Path C -- "Propaganda Network"** -> Tier 5: **MINISTRY OF TRUTH** (demoralized enemies explode on death)

#### Pepper Spray Emitter Upgrade Paths

**Path A -- "Concentrated Formula"** -> Tier 5: **WEAPONIZED CAPSAICIN** (maximum potency continuous burn)
**Path B -- "Wide Dispersal"** -> Tier 5: **CLOUD CHAMBER** (massive area chemical cloud)
**Path C -- "Irritant Research"** -> Tier 5: **SYNTHETIC ALLERGEN** (targets develop permanent vulnerability)

#### LRAD Cannon Upgrade Paths

**Path A -- "Volume Control"** -> Tier 5: **BROWN NOTE** (devastating single-target sonic blast)
**Path B -- "Frequency Modulation"** -> Tier 5: **RESONANCE CASCADE** (harmonic chain to multiple targets)
**Path C -- "Psychological Ops"** -> Tier 5: **SUBLIMINAL ARRAY** (enemies in range turn on each other)

#### Microwave Emitter Upgrade Paths

**Path A -- "Power Amplification"** -> Tier 5: **DEATH RAY*** (extreme focused beam damage)
**Path B -- "Beam Focus"** -> Tier 5: **PRECISION DENIAL** (pinpoint accuracy, ignores all defenses)
**Path C -- "Area Coverage"** -> Tier 5: **COOKING FIELD** (wide-area persistent heat zone)

### Tower Synergies

| Tower A              | Tower B              | Proximity Bonus                                        |
|----------------------|----------------------|--------------------------------------------------------|
| Water Cannon         | Pepper Spray Emitter | "Chemical Wash": soaked then sprayed = 2x dmg          |
| Taser Grid x2        | (Adjacent)           | "Power Grid": +25% damage to both                      |
| Surveillance Hub     | Any DPS tower        | "Targeting Data": DPS +15% dmg, Hub -10% range         |
| Rubber Bullet Turret | Surveillance Hub     | "Guided Rounds": Rubber Bullet +50% fire rate          |
| Tear Gas Launcher    | Taser Grid           | "Electrochemical": gas clouds stun on hit              |

---

## Enemies

### Standard Enemies

| Enemy              | HP  | Speed | Armor | Type         | Special              | Gold |
|--------------------|-----|-------|-------|--------------|----------------------|------|
| Rioter             | 30  | 2.0   | 0     | Light/Ground | Stealth              | 5    |
| Masked Protestor   | 60  | 1.2   | 5     | Medium/Ground| Cyber 2x, Psych immune| 8   |
| Shield Wall        | 150 | 0.8   | 15    | Heavy/Ground | --                   | 15   |
| Molotov Thrower    | 40  | 1.8   | 0     | Light/Ground | Chemical immune, Hydraulic 2x | 10 |
| Drone Operator     | 45  | 1.5   | 0     | Light/Flying | Flight               | 12   |
| Flash Mob          | 80  | 0.6   | 0     | Unarmored    | Splits on death      | 6    |
| Street Medic       | 50  | 1.0   | 0     | Light/Ground | Self-shield every 8s | 14   |
| Armored Van        | 300 | 0.5   | 30    | Fortified    | Regen 1%/s           | 25   |
| Infiltrator        | 70  | 1.6   | 0     | Unarmored    | Stealth + phase      | 18   |
| Social Media Swarm | 15  | 2.2   | 0     | Unarmored    | Pack of 8-12         | 2ea  |
| Tunnel Rat         | 120 | 1.0   | 10    | Medium/Ground| Burrow at 50% HP     | 16   |
| Union Boss         | 200 | 0.7   | 20    | Heavy/Ground | Slows nearby towers  | 22   |

### Boss Enemies

| Boss             | HP     | Signature Mechanic                                       |
|------------------|--------|----------------------------------------------------------|
| The Demagogue    | 5,000  | Elevated platform, megaphone AoE, descends at 50% HP     |
| The Hacktivist   | 3,500  | Summons bot accounts, heals from kills, shield regen      |
| The Barricade    | 10,000 | Immune to <tier3 abilities, sheds debris as HP drops       |
| The Influencer   | 2,000  | Spawns followers, splits into 4 sub-influencers at 25% HP |
| Ghost Protocol   | 4,000  | Cycles immunity every 5s, teleports forward                |

### Enemy Abilities

| Ability        | Trigger    | Effect                                     |
|----------------|------------|--------------------------------------------|
| Healing Aura   | Periodic   | Heals nearby allies 5% max HP every 3s     |
| Shield Gen     | Periodic   | 20% max HP shield to self+allies every 8s  |
| Split          | On Death   | Spawns 2-4 smaller versions at 30% HP      |
| Burrow         | At 50% HP  | Underground, immune 2s, reappears ahead    |
| Flight         | Passive    | Ignores ground-only towers, direct path    |
| Stealth        | Passive    | Invisible without detection towers         |
| Regeneration   | Passive    | Heals 2% max HP per second                 |
| Speed Burst    | At 25% HP  | +100% movement speed                       |
| Summon Minions | Periodic   | Spawns 3 small escorts every 10s           |
| Immunity Shift | Periodic   | Cycles Kinetic/Directed Energy immunity every 5s |
| Death Explosion| On Death   | AoE damage to nearby towers                |
| Purge          | Periodic   | Removes all debuffs every 6s               |

---

## Wave System

### Difficulty Scaling

```
HP multiplier    = 1.0 + (wave * 0.12) + (wave^1.3 * 0.02)
Count multiplier = 1.0 + (wave * 0.08)
Speed multiplier = 1.0 + min(wave * 0.02, 0.6)  # capped at +60%
Gold per enemy   = base_gold * (1.0 + wave * 0.05)
```

### Wave Progression Example

| Wave | Composition                                     | Purpose              |
|------|-------------------------------------------------|----------------------|
| 1    | 10 Rioters                                      | Teach basics         |
| 3    | 8 Rioters + 5 Masked Protestors                 | Introduce armor      |
| 5    | 12 Masked Protestors + 3 Drone Operators         | Introduce flying     |
| 7    | 20 Social Media Swarm                            | Teach AoE value      |
| 10   | **BOSS: Shield Wall Commander** + 10 Shield Walls| First boss test      |
| 15   | 15 Flash Mobs (split on death)                   | Test sustained DPS   |
| 18   | 10 Infiltrators                                  | Force detection      |
| 20   | **BOSS: The Demagogue** + mixed                  | Mid-game skill check |
| 30   | **BOSS: The Hacktivist** + bot horde             | Strategic boss       |
| 35   | MASS DEMO: 100 Swarm from 3 entrances            | Swarm test           |
| 40   | **FINAL BOSS: The Barricade** + full mob         | Final challenge      |

### Special Wave Types

- **Mass Demonstration**: 3-5x enemy count, weak enemies. Tests AoE coverage.
- **Organized Cell**: Fewer enemies with random modifiers (Militant, Armored, Medic-Supported, Fast-Movers, Shielded)
- **Special Operation**: Special rules -- "Blackout" (all stealth), "General Strike" (30% resurrect), "Payday" (3x budget, 50% faster)
- **Coalition March**: Multiple bosses simultaneously

---

## Map Design

### Isometric Grid
- Tile size: 32x16 pixels (2:1 ratio)
- Coordinate system: cube coordinates internally (q, r, s), converted to screen space for rendering
- Depth sorting: `sort_key = tile_y + tile_x`, back-to-front rendering

### Elevation Mechanics

| Mechanic         | Effect                                        |
|------------------|-----------------------------------------------|
| Height Advantage | +25% range for towers on higher elevation     |
| Height Damage    | +10% damage per tier above target              |
| Cliff Paths      | Enemies climb 50% slower on ascent            |
| Elevation Block  | Cliffs block beam/hitscan LOS (lobbed unaffected) |

### Map Features
- **Bottlenecks**: Narrow 1-2 tile paths for AoE towers
- **Crossroads**: Merged paths for multi-lane coverage
- **Environmental hazards**: Burning barricades (damage enemies), flooded streets (slow), toxic spill (poison)
- **Multi-entrance maps**: Later maps have 2-3 entrances requiring split defenses
- Spawn points represent where protestors enter the district; the goal represents the Capitol building

---

## Atmosphere & Effects

### Smoke & Smog System
- Multi-layer parallax smoke particles near ground
- Depth-based desaturation (far objects fade toward smog color)
- Full-screen haze shader with animated noise texture
- Depth smoke gradient: Full color -> `#4A3050` @50% -> `#6B4A60` @70% -> `#9A6B80` @100%

### Explosion System
- Lifecycle: Flash -> Bloom -> Fire -> Warm Smoke -> Cool Smoke -> Fade
- Color gradient: amber flash `#F0D0D8` -> `#E0B0B8` -> tear gas yellow-green `#C87878` -> `#8A5060` -> muzzle flash white `#6B4A60` -> transparent
- Screen shake on heavy impacts
- Lingering particle trails on projectiles (tear gas clouds, rubber bullet tracers, water cannon spray)
- Tier 5 attacks are visual spectacle events

### 8-Bit Constraints
- Sprite sizes: 16x16 base, 32x32 large, 48x48 boss
- Animation: 4-8 frames (true 8-bit feel)
- Nearest-neighbor scaling only (no anti-aliasing on sprites)
- Post-processing (smoke, bloom) can be smooth/modern -- they are "the atmosphere"

---

## Engagement & Progression Systems

Seven psychological systems designed to drive retention and player satisfaction.
See `docs/ENGAGEMENT_BRIEF.md` for detailed research, sources, and implementation specs.

### 1. Game Juice & Feedback

Multi-layered feedback that makes every action feel impactful.

| Layer         | Examples                                                              |
|---------------|-----------------------------------------------------------------------|
| Per-Shot      | Tower recoil (1-2px), muzzle flash, projectile trails                 |
| Per-Hit       | Type-specific impacts (chemical cloud burst, water splash, spark arc)  |
| Per-Kill      | Budget coins fly to HUD, ragdoll stumble, floating damage numbers     |
| Per-Wave      | Screen-wide amber pulse, budget tally, streak banner                  |
| Per-Milestone | Tier 5 unlock fanfare, boss defeat slow-mo (0.5s), particle cascade  |

- Damage numbers color-coded by type (coral for Chemical, cool blue for Hydraulic, etc.)
- Screen shake scales with damage dealt (light for rubber bullets, heavy for tear gas)
- Boss kills trigger brief slow-motion with radial particle burst

### 2. Near-Miss & Loss Aversion

Leverage loss aversion (Kahneman & Tversky) to keep players engaged through close calls.

- **"Almost!" popups** when enemies escape with <10% HP remaining
- **Perfect Wave streak** -- consecutive no-leak waves grant +5% cumulative gold bonus
- **Last Stand mode** -- at 1 life remaining: smoke thickens, music shifts to minor key, heartbeat audio layer
- **Post-defeat "What If" panel** -- shows which upgrade would have stopped the leaking enemy
- **Commendations earned on defeat** -- meta-currency from all runs softens the sting of losing

### 3. Variable Rewards & Discovery

Variable-ratio reinforcement (Skinner) keeps players curious and hunting for surprises.

| Mechanic             | Trigger                    | Reward                                   |
|----------------------|----------------------------|------------------------------------------|
| Radicalized Enemies  | 3-5% spawn chance          | Red-black glow, +50% HP, drops Riot Tokens|
| Supply Convoys       | Every 8-12 waves (random)  | Fast, fragile convoy -- destroy for bonus budget/items |
| Synergy Discovery    | Place towers in proximity  | Hidden synergies revealed, logged in Field Manual      |
| Tower Evolutions     | Adjacent tier 4+ towers    | Merge into ultra-tower (e.g., Hypothermia Field + Cloud Chamber = Chemical Winter) |

- Field Manual: collectible screen tracking all discovered combos
- "???" silhouettes for undiscovered synergies hint at hidden depth

### 4. Compounding Power Fantasy

Players should feel increasingly powerful -- numbers going up is intrinsically satisfying.

- **Real-time DPS meter** with milestones at 1K / 5K / 10K DPS (visual flourish on each)
- **Per-tower kill counters** -- 100+ kills adds a subtle glow to the tower sprite
- **Budget interest** -- 5% interest on banked gold between waves (rewards saving)
- **Wave calling** -- send next wave early for +10-25% gold bonus (risk/reward)
- **Post-game stats screen** -- budget-per-wave graph, total damage, MVP tower

### 5. Meta-Progression

Cross-run progression that gives every session lasting value.

```
Commendations (meta-currency)
  +-- Earned from: completing waves, defeating bosses, map stars, achievements
  +-- Spent on: Protocol Manual

Protocol Manual (4 branches):
  |-- Tactical    -- tower damage, fire rate, range
  |-- R&D         -- new synergies, tower evolutions
  |-- Logistics   -- starting budget, interest rate, sell refund
  +-- Resilience  -- extra lives, slow aura, Last Stand bonuses
```

| System             | Description                                                      |
|--------------------|------------------------------------------------------------------|
| Map Stars          | 3-star rating per map (complete / 15+ lives / par time)          |
| Tower Mastery      | Global XP bar per tower type -- cosmetic skins at milestones     |
| Threat Database    | Enemy encyclopedia with "???" silhouettes for undiscovered types |
| Commendation Board | Visual board that fills in with achievements                     |

- New players start with 50 Commendations (endowed progress effect -- motivates continued play)

### 6. Flow State Maintenance

Keep players in Csikszentmihalyi's flow channel -- never bored, never overwhelmed.

- **Active abilities** (cooldown-based, not passive):
  - Airstrike (30s) -- targeted AoE burst
  - Flash Freeze (45s) -- slow all enemies for 3s
  - Emergency Funding (60s) -- 2x budget for 10s
- **Wave preview** -- shows composition of next 2-3 waves for strategic planning
- **Speed control** -- 1x / 2x / 3x with auto-suggestion after idle periods
- **Hidden dynamic difficulty** -- +/-10% enemy HP based on performance (never disclosed to player)

### 7. Roguelike Endgame (Internal Affairs)

Post-campaign endless mode with roguelike draft mechanics for infinite replayability.

- **Draft system** -- after each wave, choose 1 of 3 random towers/upgrades to add
- **Random map modifiers** -- smoke zones, reversed paths, toxic spill tiles, narrow bottlenecks
- **Martial Law Gambit** -- opt-in challenge (+50% enemy HP, 3x budget drops)
- **Challenge modifiers** with score multipliers (e.g., "No Water Cannons", "Double speed")
- **Leaderboard** -- scored by waves survived x modifier multiplier

### Implementation Priority

| Priority | System                   | Impact    | Effort | Rationale                          |
|----------|--------------------------|-----------|--------|------------------------------------|
| 1        | Game Juice & Feedback    | Very High | Medium | Foundation -- makes everything feel good |
| 2        | Near-Miss & Loss Aversion| High      | Low    | Small changes, outsized impact     |
| 3        | Compounding Power Fantasy| High      | Low    | Simple counters/meters, big payoff |
| 4        | Variable Rewards         | Very High | Medium | Core differentiator for Goligee    |
| 5        | Flow Maintenance         | High      | Medium | Keeps sessions going longer        |
| 6        | Meta-Progression         | Very High | High   | Critical for long-term retention   |
| 7        | Roguelike Endgame        | High      | High   | Endgame content, ship post-launch  |
