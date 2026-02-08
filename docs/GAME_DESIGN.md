# Goligee -- Game Design Document

## Vision
An 8-bit isometric tower defense game with atmospheric fog effects, beautiful explosions,
and deeply satisfying upgrade paths. The world is perpetually at twilight -- violet,
melancholic, and mystical.

---

## Core Mechanics

### Damage Types (8 types)

| Type       | Color     | Strengths                | Weaknesses              |
|------------|-----------|--------------------------|-------------------------|
| Physical   | Silver    | Reliable baseline        | Weak vs armor           |
| Fire       | Coral     | Burn DoT, AoE           | Useless vs Fire enemies |
| Ice        | Cool Blue | Slows/Freezes            | Low damage              |
| Lightning  | Gold      | Chain hits, stuns        | Weak vs shielded        |
| Poison     | Green     | DoT stacking, ignores armor | Useless vs undead    |
| Magic      | Purple    | Ignores physical armor   | Weak vs magic-resist    |
| Holy       | White/Gold| Strong vs undead/dark    | Weak vs holy-aligned    |
| Dark       | Void      | Debuffs, life steal      | Weak vs holy enemies    |

### Armor Types (6 types)

| Armor Type | Physical | Fire | Ice  | Lightning | Poison | Magic | Holy | Dark |
|------------|----------|------|------|-----------|--------|-------|------|------|
| Unarmored  | 1.0      | 1.25 | 1.0  | 1.5       | 1.5    | 1.0   | 1.0  | 1.25 |
| Light      | 1.0      | 1.5  | 1.25 | 1.0       | 1.25   | 1.25  | 1.0  | 1.0  |
| Medium     | 1.0      | 1.0  | 1.0  | 0.75      | 1.0    | 0.75  | 1.0  | 1.0  |
| Heavy      | 0.7      | 0.75 | 1.0  | 1.25      | 1.0    | 1.5   | 1.0  | 0.5  |
| Fortified  | 0.5      | 0.5  | 0.75 | 0.35      | 1.0    | 0.35  | 1.0  | 0.5  |
| Boss       | 0.8      | 0.9  | 0.85 | 0.9       | 0.7    | 0.85  | 1.0  | 0.75 |

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

| Tower        | Damage Type | Projectile | AoE   | Cost | Role              |
|--------------|-------------|------------|-------|------|-------------------|
| Arrow Tower  | Physical    | Arrow      | No    | 100  | Starter DPS       |
| Cannon Tower | Physical    | Lobbed     | 1.5t  | 200  | AoE specialist    |
| Lightning    | Lightning   | Chain      | Chain | 175  | Crowd control     |
| Ice Tower    | Ice         | Nova       | 2.0t  | 125  | Slow/Freeze       |
| Necromancer  | Dark        | Hitscan    | No    | 250  | Summon/Support    |
| Flame Tower  | Fire        | Beam       | No    | 175  | Sustained DoT     |
| Poison Spire | Poison      | Lobbed     | 1.0t  | 150  | Stacking DoT      |
| Arcane Tower | Magic       | Hitscan    | No    | 225  | Anti-armor        |

### Upgrade System (BTD6-style 3-path)

Each tower has **3 upgrade paths with 5 tiers each**.
- Only **2 paths** can be selected per tower
- Only **1 path** can go beyond tier 2
- Crosspathing creates meaningful sub-builds

#### Arrow Tower Upgrade Paths

**Path A -- "Sharpshooter" (Single Target DPS)**
1. Long Shots (+20% range)
2. Piercing Arrows (pierce 2 enemies)
3. Sniper Training (+50% damage, +30% range)
4. Crippling Shot (15% chance to stun 0.5s)
5. **DEADSHOT** -- Hitscan projectiles, 25% crit, 3x crit multiplier

**Path B -- "Storm of Arrows" (AoE/Speed)**
1. Rapid Fire (+30% fire rate)
2. Double Shot (2 arrows per attack)
3. Arrow Rain (1.5 tile AoE, lobbed)
4. Hail of Arrows (4 arrows per attack)
5. **ARROWMAGEDDON** -- 8 arrows/sec continuous rain in radius

**Path C -- "Enchanted Quiver" (Utility)**
1. Poison Tips (3 DPS poison for 3s)
2. Tracking Arrows (homing)
3. Weakening Shots (+15% damage taken by target for 2s)
4. Elemental Arrows (damage type -> Magic)
5. **ARCANE ARCHER** -- every 5th shot hits all enemies in range

#### Cannon Tower Upgrade Paths

**Path A -- "Siege Engine"** -> Tier 5: **DOOMSDAY CANNON** (massive AoE, screen shake)
**Path B -- "Bombardier"** -> Tier 5: **CARPET BOMBER** (line of explosions)
**Path C -- "Demolitions Expert"** -> Tier 5: **EARTHQUAKE GENERATOR** (periodic AoE stun)

#### Lightning Tower Upgrade Paths

**Path A -- "Storm Lord"** -> Tier 5: **THUNDERGOD** (10 chain targets, all stunned)
**Path B -- "Tesla Coil"** -> Tier 5: **ARC REACTOR** (beam splits to 3 targets)
**Path C -- "EMP Specialist"** -> Tier 5: **BLACKOUT FIELD** (disables enemy abilities in range)

#### Ice Tower Upgrade Paths

**Path A -- "Permafrost"** -> Tier 5: **ABSOLUTE ZERO** (freeze all in range every 10s)
**Path B -- "Ice Shards"** -> Tier 5: **BLIZZARD** (massive ice DPS in huge area)
**Path C -- "Cryogenic Support"** -> Tier 5: **BRITTLE AURA** (-50% armor, +30% damage taken)

#### Necromancer Tower Upgrade Paths

**Path A -- "Death Lord"** -> Tier 5: **LICH KING** (permanent skeleton army)
**Path B -- "Soul Harvest"** -> Tier 5: **SOUL ENGINE** (+100% gold from kills in range)
**Path C -- "Hex Master"** -> Tier 5: **DOOM CURSE** (cursed enemies explode on death)

### Tower Synergies

| Tower A       | Tower B       | Proximity Bonus                              |
|---------------|---------------|----------------------------------------------|
| Ice Tower     | Fire Tower    | "Thermal Shock": frozen then burned = 2x dmg |
| Lightning x2  | (Adjacent)    | "Power Grid": +25% damage to both            |
| Necromancer   | Any DPS tower | "Dark Pact": DPS +15% dmg, Necro -10% range  |
| Arrow Tower   | Command Tower | "Volley Fire": Arrow +50% fire rate           |
| Cannon Tower  | Lightning     | "Overcharge": shells stun on hit              |

---

## Enemies

### Standard Enemies

| Enemy           | HP  | Speed | Armor | Type         | Special              | Gold |
|-----------------|-----|-------|-------|--------------|----------------------|------|
| Goblin Scout    | 30  | 2.0   | 0     | Light/Ground | Stealth              | 5    |
| Skeleton Warrior| 60  | 1.2   | 5     | Medium/Ground| Holy 2x, Dark immune | 8    |
| Orc Brute       | 150 | 0.8   | 15    | Heavy/Ground | --                   | 15   |
| Fire Imp        | 40  | 1.8   | 0     | Light/Ground | Fire immune, Ice 2x  | 10   |
| Harpy           | 45  | 1.5   | 0     | Light/Flying | Flight               | 12   |
| Slime           | 80  | 0.6   | 0     | Unarmored    | Splits on death      | 6    |
| Mage Cultist    | 50  | 1.0   | 0     | Light/Ground | Self-shield every 8s | 14   |
| Iron Golem      | 300 | 0.5   | 30    | Fortified    | Regen 1%/s           | 25   |
| Shadow Wraith   | 70  | 1.6   | 0     | Unarmored    | Stealth + phase      | 18   |
| Swarm Beetles   | 15  | 2.2   | 0     | Unarmored    | Pack of 8-12         | 2ea  |
| Burrower Worm   | 120 | 1.0   | 10    | Medium/Ground| Burrow at 50% HP     | 16   |
| Frost Giant     | 200 | 0.7   | 20    | Heavy/Ground | Slows nearby towers  | 22   |

### Boss Enemies

| Boss          | HP    | Signature Mechanic                                   |
|---------------|-------|------------------------------------------------------|
| Dragon Lord   | 5,000 | Flies, fire breath AoE, lands at 50% HP              |
| Lich Queen    | 3,500 | Summons undead, heals from minion deaths, shield regen|
| Golem Titan   | 10,000| Immune to <tier3 abilities, sheds armor as HP drops   |
| Swarm Mother  | 2,000 | Spawns beetles, splits into 4 daughters at 25% HP    |
| Void Walker   | 4,000 | Cycles immunity every 5s, teleports forward           |

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
| Immunity Shift | Periodic   | Cycles Physical/Magic immunity every 5s    |
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

| Wave | Composition                          | Purpose              |
|------|--------------------------------------|----------------------|
| 1    | 10 Goblin Scouts                     | Teach basics         |
| 3    | 8 Goblins + 5 Skeleton Warriors      | Introduce armor      |
| 5    | 12 Skeletons + 3 Harpies            | Introduce flying     |
| 7    | 20 Swarm Beetles                     | Teach AoE value      |
| 10   | **BOSS: Orc Warchief** + 10 Brutes  | First boss test      |
| 15   | 15 Slimes (split on death)           | Test sustained DPS   |
| 18   | 10 Shadow Wraiths                    | Force detection      |
| 20   | **BOSS: Dragon Lord** + mixed        | Mid-game skill check |
| 30   | **BOSS: Lich Queen** + undead horde  | Strategic boss       |
| 35   | HORDE: 100 Beetles from 3 entrances | Swarm test           |
| 40   | **FINAL BOSS: Golem Titan** + army  | Final challenge      |

### Special Wave Types

- **Horde**: 3-5x enemy count, weak enemies. Tests AoE coverage.
- **Elite**: Fewer enemies with random modifiers (Berserker, Ironclad, Vampiric, Hasty, Shielded)
- **Event**: Special rules -- "Eclipse" (all stealth), "Blood Moon" (30% resurrect), "Gold Rush" (3x gold, 50% faster)
- **Boss Rush**: Multiple bosses simultaneously

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
- **Chokepoints**: Narrow 1-2 tile paths for AoE towers
- **Crossroads**: Merged paths for multi-lane coverage
- **Environmental hazards**: Lava (damages enemies), frozen rivers (slows), swamps (poison)
- **Multi-entrance maps**: Later maps have 2-3 entrances requiring split defenses

---

## Atmosphere & Effects

### Fog System
- Multi-layer parallax fog particles near ground
- Depth-based desaturation (far objects fade toward sky color)
- Full-screen fog shader with animated noise texture
- Depth fog gradient: Full color -> `#4A3050` @50% -> `#6B4A60` @70% -> `#9A6B80` @100%

### Explosion System
- Lifecycle: Flash -> Bloom -> Fire -> Warm Smoke -> Cool Smoke -> Fade
- Color gradient: `#F0D0D8` -> `#E0B0B8` -> `#C87878` -> `#8A5060` -> `#6B4A60` -> transparent
- Screen shake on heavy impacts
- Lingering particle trails on projectiles
- Tier 5 attacks are visual spectacle events

### 8-Bit Constraints
- Sprite sizes: 16x16 base, 32x32 large, 48x48 boss
- Animation: 4-8 frames (true 8-bit feel)
- Nearest-neighbor scaling only (no anti-aliasing on sprites)
- Post-processing (fog, bloom) can be smooth/modern -- they are "the atmosphere"

---

## Engagement & Progression Systems

Seven psychological systems designed to drive retention and player satisfaction.
See `docs/ENGAGEMENT_BRIEF.md` for detailed research, sources, and implementation specs.

### 1. Game Juice & Feedback

Multi-layered feedback that makes every action feel impactful.

| Layer         | Examples                                                        |
|---------------|-----------------------------------------------------------------|
| Per-Shot      | Tower recoil (1-2px), muzzle flash, projectile trails           |
| Per-Hit       | Type-specific impacts (ember burst, crystal shatter, void rift) |
| Per-Kill      | Gold coins fly to HUD, corpse dissolve, floating damage numbers |
| Per-Wave      | Screen-wide violet pulse, gold tally, streak banner             |
| Per-Milestone | Tier 5 unlock fanfare, boss death slow-mo (0.5s), particle cascade |

- Damage numbers color-coded by type (coral for Fire, cool blue for Ice, etc.)
- Screen shake scales with damage dealt (light for arrows, heavy for cannon)
- Boss kills trigger brief slow-motion with radial particle burst

### 2. Near-Miss & Loss Aversion

Leverage loss aversion (Kahneman & Tversky) to keep players engaged through close calls.

- **"Almost!" popups** when enemies escape with <10% HP remaining
- **Perfect Wave streak** -- consecutive no-leak waves grant +5% cumulative gold bonus
- **Last Stand mode** -- at 1 life remaining: fog thickens, music shifts to minor key, heartbeat audio layer
- **Post-defeat "What If" panel** -- shows which upgrade would have killed the leaking enemy
- **Starlight earned on defeat** -- meta-currency from all runs softens the sting of losing

### 3. Variable Rewards & Discovery

Variable-ratio reinforcement (Skinner) keeps players curious and hunting for surprises.

| Mechanic             | Trigger                    | Reward                                  |
|----------------------|----------------------------|-----------------------------------------|
| Corrupted Enemies    | 3-5% spawn chance          | Violet-black glow, +50% HP, drops Twilight Shards |
| Treasure Caravans    | Every 8-12 waves (random)  | Fast, fragile convoy -- kill for bonus gold/items  |
| Synergy Discovery    | Place towers in proximity  | Hidden synergies revealed, logged in Grimoire      |
| Tower Evolutions     | Adjacent tier 4+ towers    | Merge into ultra-tower (e.g., Permafrost + Inferno = Obsidian Forge) |

- Synergy Grimoire: collectible screen tracking all discovered combos
- "???" silhouettes for undiscovered synergies hint at hidden depth

### 4. Compounding Power Fantasy

Players should feel increasingly powerful -- numbers going up is intrinsically satisfying.

- **Real-time DPS meter** with milestones at 1K / 5K / 10K DPS (visual flourish on each)
- **Per-tower kill counters** -- 100+ kills adds a subtle glow to the tower sprite
- **Gold interest** -- 5% interest on banked gold between waves (rewards saving)
- **Wave calling** -- send next wave early for +10-25% gold bonus (risk/reward)
- **Post-game stats screen** -- gold-per-wave graph, total damage, MVP tower

### 5. Meta-Progression

Cross-run progression that gives every session lasting value.

```
Starlight (meta-currency)
  └─ Earned from: completing waves, killing bosses, map stars, achievements
  └─ Spent on: Twilight Knowledge tree

Twilight Knowledge Tree (4 branches):
  ├── Martial   -- tower damage, fire rate, range
  ├── Arcane    -- new synergies, tower evolutions
  ├── Commerce  -- starting gold, interest rate, sell refund
  └── Fortitude -- extra lives, slow aura, Last Stand bonuses
```

| System             | Description                                                      |
|--------------------|------------------------------------------------------------------|
| Map Stars          | 3-star rating per map (complete / 15+ lives / par time)          |
| Tower Mastery      | Global XP bar per tower type -- cosmetic skins at milestones     |
| Bestiary           | Enemy encyclopedia with "???" silhouettes for undiscovered types |
| Constellation Map  | Visual star map that fills in with achievements                  |

- New players start with 50 Starlight (endowed progress effect -- motivates continued play)

### 6. Flow State Maintenance

Keep players in Csikszentmihalyi's flow channel -- never bored, never overwhelmed.

- **Active abilities** (cooldown-based, not passive):
  - Twilight Strike (30s) -- targeted AoE burst
  - Frost Veil (45s) -- slow all enemies for 3s
  - Gold Surge (60s) -- 2x gold for 10s
- **Wave preview** -- shows composition of next 2-3 waves for strategic planning
- **Speed control** -- 1x / 2x / 3x with auto-suggestion after idle periods
- **Hidden dynamic difficulty** -- ±10% enemy HP based on performance (never disclosed to player)

### 7. Roguelike Endgame (Twilight Trials)

Post-campaign endless mode with roguelike draft mechanics for infinite replayability.

- **Draft system** -- after each wave, choose 1 of 3 random towers/upgrades to add
- **Random map modifiers** -- fog zones, reversed paths, lava tiles, narrow chokepoints
- **Blood Moon Gambit** -- opt-in challenge (+50% enemy HP, 3x gold drops)
- **Challenge modifiers** with score multipliers (e.g., "No Ice towers", "Double speed")
- **Leaderboard** -- scored by waves survived × modifier multiplier

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
