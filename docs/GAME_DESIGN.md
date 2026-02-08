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
