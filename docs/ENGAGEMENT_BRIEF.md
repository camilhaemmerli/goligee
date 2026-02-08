# Goligee -- Engagement & Psychological Systems Brief

A research-backed design brief covering the psychological principles, competitive analysis,
and implementation specifications for Goligee's engagement systems.

---

## Table of Contents

1. [System 1: Game Juice & Feedback](#system-1-game-juice--feedback)
2. [System 2: Near-Miss & Loss Aversion](#system-2-near-miss--loss-aversion)
3. [System 3: Variable Rewards & Discovery](#system-3-variable-rewards--discovery)
4. [System 4: Compounding Power Fantasy](#system-4-compounding-power-fantasy)
5. [System 5: Meta-Progression](#system-5-meta-progression)
6. [System 6: Flow State Maintenance](#system-6-flow-state-maintenance)
7. [System 7: Roguelike Endgame](#system-7-roguelike-endgame)
8. [Competitive Analysis](#competitive-analysis)
9. [Implementation Priority](#implementation-priority)
10. [Sources](#sources)

---

## System 1: Game Juice & Feedback

### Psychological Principle

**Operant Conditioning & Sensory Reinforcement.** Every player action should produce
immediate, satisfying feedback. Jan Willem Nijman's GDC talk "The Art of Screenshake"
demonstrated that identical game mechanics feel dramatically different based on the
feedback layer alone. Players rate "juicy" games as more fun even when the underlying
systems are unchanged.

The principle relies on **positive reinforcement** (Skinner, 1938) -- rewarding actions
with sensory pleasure to increase the likelihood of repetition. In TD games, the "action"
is placing and upgrading towers; the "reward" is watching them destroy enemies with
satisfying effects.

### Research Sources

- Nijman, J.W. (2013). ["The Art of Screenshake"](https://www.youtube.com/watch?v=AJdEqssNZ-U) -- GDC/Vlambeer talk on game feel
- Juul, J. (2010). [*A Casual Revolution*](https://mitpress.mit.edu/books/casual-revolution) -- MIT Press, on feedback loops in casual games
- Swink, S. (2008). [*Game Feel: A Game Designer's Guide to Virtual Sensation*](https://www.gamefeelbook.com/) -- Morgan Kaufmann
- Brown, M. (2016). ["Secrets of Game Feel and Juice"](https://www.youtube.com/watch?v=216_5nu4aVQ) -- Game Maker's Toolkit

### How Top TD Games Use It

- **BTD6**: Bloons popping has distinct audio per type, screen fills with particle effects at high rounds, Tier 5 abilities produce screen-filling spectacles
- **Kingdom Rush**: Enemies ragdoll on death, gold coins burst from corpses with a satisfying "clink", hero abilities have dramatic wind-up animations
- **Arknights**: Operator deployment has weighty animations, skills activate with full-screen effects, damage numbers stack visually

### Goligee Implementation

#### Per-Shot Feedback
- Tower recoil animation: 1-2px knockback, 2 frames, snap-back
- Muzzle flash: 1-frame bright pixel at barrel (color matches damage type)
- Projectile trails: 3-4px fading tail using tower's color palette
- Audio: unique fire sound per tower type (8-bit chirps, not realistic)

#### Per-Hit Feedback
Type-specific impact effects (4-frame animations):

| Damage Type | Impact Effect                  | Particles           |
|-------------|--------------------------------|----------------------|
| Physical    | White spark burst              | 2-3 pixel shards     |
| Fire        | Ember burst, brief ignite glow | Rising ember pixels   |
| Ice         | Crystal shatter, frost ring    | Ice crystal scatter   |
| Lightning   | Flash + chain arc              | Electric pixel sparks |
| Poison      | Toxic splash, drip effect      | Green drip particles  |
| Magic       | Arcane sigil flash             | Purple swirl pixels   |
| Holy        | Golden radiance burst          | Rising light motes    |
| Dark        | Void rift pulse                | Dark pixel implosion  |

- Floating damage numbers: color-coded by damage type, drift upward, fade over 0.8s
- Critical hits: larger font, "!" suffix, brief white flash on enemy sprite
- Enemy hit-flash: 1-frame white overlay on sprite (using `damage_flash.gdshader`)

#### Per-Kill Feedback
- Gold coin particles: 3-5 pixel coins fly from corpse position to HUD gold counter
- Coin audio: 8-bit "clink" sound, pitch-randomized ±10%
- Corpse dissolve: 4-frame fade-out, color shifts to ground tone
- Kill feed (optional HUD element): scrolling list of recent kills

#### Per-Wave Feedback
- Wave complete banner: "Wave X Complete!" slides in from top, 2s display
- Screen-wide violet pulse: subtle full-screen flash using atmosphere shader
- Gold tally: animated counter showing total wave earnings
- Perfect Wave bonus: golden border on banner if no enemies leaked
- Streak counter: "Perfect x3!" with escalating visual intensity

#### Milestone Feedback
- Tier 5 unlock: 1s fanfare, tower sprite briefly enlarges, particle ring
- Boss death: 0.5s slow-motion, radial particle cascade, unique death sound
- Achievement popup: corner notification with Starlight reward preview

#### Key Files
- `scripts/components/weapon_component.gd` -- recoil, muzzle flash triggers
- `scripts/enemies/base_enemy.gd` -- hit flash, death effects
- `scripts/autoloads/signal_bus.gd` -- feedback event signals
- `assets/shaders/damage_flash.gdshader` -- hit flash shader

---

## System 2: Near-Miss & Loss Aversion

### Psychological Principle

**Loss Aversion** (Kahneman & Tversky, 1979). People feel losses approximately twice as
strongly as equivalent gains. A close defeat is more motivating than an easy victory
because it activates loss aversion -- the player *almost* won, so they feel compelled to
try again.

**Near-miss effect** (Reid, 1986): near-misses activate reward pathways similarly to wins,
creating a "just one more try" compulsion. Slot machines exploit this extensively, but game
designers can use it ethically by making near-misses genuinely informative (showing *what*
would have worked).

**Streak psychology** (Alter & Oppenheimer, 2006): maintaining a streak creates increasing
commitment. Breaking a streak feels like a loss, so players work harder to maintain it.

### Research Sources

- Kahneman, D. & Tversky, A. (1979). ["Prospect Theory: An Analysis of Decision Under Risk"](https://www.jstor.org/stable/1914185) -- *Econometrica*, 47(2), 263-291
- Reid, R.L. (1986). ["The Psychology of the Near Miss"](https://doi.org/10.1007/BF01019859) -- *Journal of Gambling Behavior*, 2(1), 32-39
- Alter, A.L. & Oppenheimer, D.M. (2006). ["From a fixation on sports to an exploration of mechanism"](https://doi.org/10.1016/j.tics.2006.08.001) -- *Trends in Cognitive Sciences*
- Clark, L. et al. (2009). ["Gambling Near-Misses Enhance Motivation to Gamble"](https://doi.org/10.1016/j.neuron.2009.01.025) -- *Neuron*, 61(3), 481-490

### How Top TD Games Use It

- **BTD6**: "X bloons leaked" counter creates urgency, lives system means close rounds feel tense, free-play mode after winning lets players push limits
- **Kingdom Rush**: star rating system (1-3 stars) makes near-perfect runs feel like losses, hero near-death voice lines add urgency
- **Arknights**: practice mode shows what *would* have worked, DP (deployment cost) pressure creates constant near-miss tension

### Goligee Implementation

#### "Almost!" Popup System
- Trigger: enemy reaches exit with <10% HP remaining
- Display: "Almost!" text in coral (#C87878) with HP bar showing remaining health
- Additional info: "X more damage would have killed it" -- connects to upgrade motivation
- Frequency cap: max 3 per wave to avoid annoyance

#### Perfect Wave Streak
- Track consecutive waves with 0 leaks
- Visual: streak counter in HUD corner, escalating glow (3+ = golden, 5+ = pulsing)
- Reward: +5% cumulative gold bonus per perfect wave (resets on leak)
- Streak break: brief "crack" sound effect, counter shatters visually

#### Last Stand Mode
Activates when player reaches 1 remaining life:

| Element         | Change                                              |
|-----------------|-----------------------------------------------------|
| Fog             | Density increases 30%, darker tint                  |
| Music           | Shifts to minor key variant, lower tempo            |
| Audio           | Heartbeat layer added, increases with enemy proximity|
| HUD             | Life counter pulses red                             |
| Camera          | Subtle 0.5% zoom-in (claustrophobia)                |

- Creates intense memorable moments without changing gameplay difficulty
- If player survives: "Survivor" bonus Starlight reward

#### Post-Defeat "What If" Panel
- Shown on game over screen (not intrusive during play)
- Calculates: "Upgrading your Arrow Tower to Tier 3 would have added X DPS"
- Shows the specific enemy that leaked and its remaining HP
- One-tap "Retry" button positioned prominently
- Subtle: "You earned X Starlight this run" -- loss still produced progress

#### Key Files
- `scripts/autoloads/game_manager.gd` -- life tracking, Last Stand trigger
- `scripts/autoloads/wave_manager.gd` -- streak tracking, perfect wave detection
- `scripts/ui/hud.gd` -- streak display, Last Stand UI changes
- `scripts/autoloads/signal_bus.gd` -- `enemy_near_miss`, `streak_broken` signals

---

## System 3: Variable Rewards & Discovery

### Psychological Principle

**Variable-Ratio Reinforcement** (Skinner, 1957). Unpredictable rewards create the
strongest behavioral persistence. A pigeon pecking a lever that *sometimes* dispenses food
pecks far more than one that *always* does. This is the core mechanism behind loot boxes,
rare drops, and gacha systems.

**Curiosity Drive** (Berlyne, 1960). Humans are intrinsically motivated to resolve
information gaps. Showing players that hidden content *exists* (silhouettes, locked entries,
"???") creates a persistent itch to discover it.

**Collector's Motivation** (Bartle, 1996): "Explorer" and "Achiever" player types are
driven by completion -- filling out a bestiary or synergy grimoire taps this directly.

### Research Sources

- Skinner, B.F. (1957). [*Schedules of Reinforcement*](https://archive.org/details/schedulesofrei00skin) -- Appleton-Century-Crofts
- Berlyne, D.E. (1960). [*Conflict, Arousal, and Curiosity*](https://doi.org/10.1037/11164-000) -- McGraw-Hill
- Bartle, R. (1996). ["Hearts, Clubs, Diamonds, Spades: Players Who Suit MUDs"](https://mud.co.uk/richard/hcds.htm)
- King, D. et al. (2010). ["Video Game Structural Characteristics"](https://doi.org/10.1007/s11469-009-9206-1) -- *International Journal of Mental Health and Addiction*
- Hopson, J. (2001). ["Behavioral Game Design"](https://www.gamedeveloper.com/design/behavioral-game-design) -- Gamasutra

### How Top TD Games Use It

- **BTD6**: random loot crates from events, collection events with rare cosmetics, hidden achievements for obscure tower interactions
- **Kingdom Rush**: hidden enemies on each map, achievement hunting for unusual strategies, Iron/Heroic challenge variants per map
- **Vampire Survivors**: entire weapon evolution system is discovery-based, arcanas add variable modifiers, hidden characters/stages drive exploration
- **Arknights**: gacha system (controversial but effective), base building has random bonus events, enemy intel fills out gradually

### Goligee Implementation

#### Corrupted Enemies
- Spawn chance: 3-5% per enemy (checked at spawn time)
- Visual: violet-black glow overlay, subtle particle trail
- Stats: +50% HP, +20% speed over base variant
- Drop: Twilight Shards (meta-currency, 1-3 per kill)
- Audio: distinct spawn sound (lower-pitched variant of normal spawn)
- Design intent: every wave has a *chance* of something special happening

#### Treasure Caravans
- Timing: appears every 8-12 waves (randomized interval)
- Composition: 5-8 fast, low-HP "Treasure Beetle" enemies on a direct path
- Behavior: they try to *cross* the map, not attack -- escaping means you lose the loot
- Reward: bonus gold (2-3x wave value) + chance of rare Twilight Shards
- Visual: golden glow, trailing sparkle particles
- Audio: jingling coin sounds while alive
- Design intent: sudden moments of excitement, player scrambles to redirect towers

#### Synergy Discovery System
- Hidden synergies exist beyond the documented ones in `GAME_DESIGN.md`
- First discovery: "New Synergy Discovered!" popup with name and effect
- Grimoire screen: collectible log of all discovered synergies
- Undiscovered synergies shown as "???" with vague hints ("Something stirs between ice and darkness...")
- Total synergies: ~20 (5 documented, 15 hidden)
- Design intent: encourages experimentation, gives players something to hunt for

#### Tower Evolutions
- Trigger: two adjacent towers both at tier 4 or higher with specific type combinations
- Process: merge animation (2s), towers combine into a single ultra-tower
- Ultra-tower occupies one tile, other tile freed for new placement
- Visual: unique sprite, combined particle effects from both source towers

| Tower A (Tier 4+) | Tower B (Tier 4+) | Evolution              | Special Effect              |
|--------------------|--------------------|------------------------|-----------------------------|
| Ice (Permafrost)   | Fire (Inferno)     | Obsidian Forge         | Thermal shock AoE, converts ground to obsidian |
| Lightning (Storm)  | Arcane (Mystic)    | Astral Conduit         | Chain lightning that ignores all armor |
| Necromancer (Death)| Poison (Blight)    | Plague Lord            | Undead minions spread poison on contact |
| Arrow (Deadshot)   | Lightning (Tesla)  | Railgun Emplacement    | Hitscan pierces entire map, 5s cooldown |
| Cannon (Siege)     | Ice (Glacier)      | Avalanche Engine       | Explosive ice boulders that freeze and shatter |

- Design intent: aspirational goals, dramatic power spike, encourages diverse builds

#### Key Files
- `scripts/autoloads/wave_manager.gd` -- corrupted enemy spawn rolls, caravan scheduling
- `scripts/enemies/base_enemy.gd` -- corrupted variant visuals/stats
- `data/enemies/` -- corrupted variant `.tres` definitions
- New: `scripts/systems/synergy_grimoire.gd` -- discovery tracking
- New: `scripts/systems/tower_evolution.gd` -- merge detection and execution

---

## System 4: Compounding Power Fantasy

### Psychological Principle

**Self-Efficacy & Mastery** (Bandura, 1977). Watching your own effectiveness grow over
time is deeply satisfying. The "numbers go up" phenomenon taps into our need for
competence -- one of Deci & Ryan's three basic psychological needs (Self-Determination
Theory, 1985).

**Goal Gradient Effect** (Hull, 1932): people accelerate effort as they approach a goal.
Visible progress toward milestones (1K DPS, 100 kills) naturally increases engagement
as the player gets closer.

**Risk-Reward Framing**: wave calling (sending waves early for bonus gold) creates a
voluntary risk that makes the reward feel *earned*, not given.

### Research Sources

- Bandura, A. (1977). ["Self-Efficacy: Toward a Unifying Theory of Behavioral Change"](https://doi.org/10.1037/0033-295X.84.2.191) -- *Psychological Review*, 84(2), 191-215
- Deci, E.L. & Ryan, R.M. (1985). [*Intrinsic Motivation and Self-Determination in Human Behavior*](https://doi.org/10.1007/978-1-4899-2271-7) -- Plenum Press
- Hull, C.L. (1932). ["The Goal-Gradient Hypothesis and Maze Learning"](https://doi.org/10.1037/h0072640) -- *Psychological Review*, 39(1), 25-43
- Przybylski, A.K. et al. (2010). ["A Motivational Model of Video Game Engagement"](https://doi.org/10.1037/a0019440) -- *Review of General Psychology*, 14(2), 154-166

### How Top TD Games Use It

- **BTD6**: pop count per tower visible on hover, total pops tracked globally, "2 Million Pops" achievement creates long-term goals, MOAB-class bloons make late-game feel epic
- **Kingdom Rush**: damage dealt visible in tower info, kill counts accumulate, hero levels up mid-match showing concrete power growth
- **Vampire Survivors**: entire game *is* compounding power fantasy -- weapon evolutions, damage numbers filling screen, kill counter in thousands

### Goligee Implementation

#### Real-Time DPS Meter
- Small graph in HUD corner showing team DPS over last 30 seconds
- Visual milestones with flourish animations:

| DPS Threshold | Visual Effect                          |
|---------------|----------------------------------------|
| 1,000 DPS     | Bronze frame appears around meter      |
| 5,000 DPS     | Silver frame, brief particle burst     |
| 10,000 DPS    | Gold frame, screen-edge glow           |
| 25,000 DPS    | Violet-gold frame, "TWILIGHT POWER!" banner |

#### Per-Tower Kill Counter
- Displayed on tower info panel when selected
- Visual progression:

| Kills | Effect                                    |
|-------|-------------------------------------------|
| 25    | Small notch appears on tower base         |
| 50    | Tower name turns bold in UI               |
| 100   | Subtle ambient glow on tower sprite       |
| 250   | Glow intensifies, "Veteran" title         |
| 500   | "Elite" title, unique idle animation      |
| 1000  | "Legendary" title, permanent particle aura|

#### Gold Interest System
- Between waves: 5% interest on current gold, rounded down
- Minimum balance for interest: 50 gold (prevents trivial gains)
- Cap: max 100 gold interest per wave (prevents hoarding strats from dominating)
- Visual: gold counter briefly glows and ticks up at wave end
- Design intent: rewards strategic saving without punishing spending

#### Wave Calling
- "Send Next Wave" button available during any wave
- Bonus gold scales with how early you send:

```
bonus_multiplier = 1.0 + (remaining_time / total_wave_time) * 0.25
# Example: calling wave at 50% remaining time = +12.5% gold
# Maximum: +25% gold (calling immediately)
```

- Multiple concurrent waves stack difficulty but also stack gold bonus
- Visual: button pulses gently when available, gold bonus preview on hover
- Risk indicator: color-coded (green = safe, yellow = risky, red = dangerous) based on current enemy count

#### Post-Game Statistics
- Displayed on win/lose screen
- Stats tracked: total damage, total kills, gold earned, gold spent, DPS peak, MVP tower (highest kills), waves survived, perfect waves, time played
- Gold-per-wave bar graph showing economic progression
- "Tower Performance" breakdown: damage/kills/efficiency per tower

#### Key Files
- `scripts/ui/hud.gd` -- DPS meter, kill counter display
- `scripts/autoloads/economy_manager.gd` -- interest calculation, wave calling bonus
- `scripts/autoloads/wave_manager.gd` -- wave calling logic, timing
- `scripts/towers/base_tower.gd` -- kill tracking, visual progression
- New: `scripts/ui/stats_screen.gd` -- post-game statistics

---

## System 5: Meta-Progression

### Psychological Principle

**Endowed Progress Effect** (Nunes & Dreze, 2006). People are more motivated to complete
a task when they feel they've already made progress. Giving new players 50 Starlight
immediately makes the progression system feel "started" rather than "empty."

**Sunk Cost Fallacy** (Arkes & Blumer, 1985). The more a player has invested in
meta-progression, the harder it is to stop playing. This is ethical when the progression
itself is enjoyable, not just a retention trap.

**Completion Drive** (Zeigarnik, 1927). Uncompleted tasks create psychological tension.
A bestiary at 73% completion is more motivating than one at 0% or 100% -- the gap creates
a pull to fill it.

**Mastery Motivation** (Dweck, 1986). Tracking mastery per tower type rewards players for
deepening their skill, not just progressing linearly.

### Research Sources

- Nunes, J.C. & Dreze, X. (2006). ["The Endowed Progress Effect"](https://doi.org/10.1086/500480) -- *Journal of Consumer Research*, 32(4), 504-512
- Arkes, H.R. & Blumer, C. (1985). ["The Psychology of Sunk Cost"](https://doi.org/10.1016/0749-5978(85)90049-4) -- *Organizational Behavior and Human Decision Processes*, 35(1), 124-140
- Zeigarnik, B. (1927). ["On Finished and Unfinished Tasks"](https://psychclassics.yorku.ca/Zeigarnik/) -- *Psychologische Forschung*, 9, 1-85
- Dweck, C.S. (1986). ["Motivational Processes Affecting Learning"](https://doi.org/10.1037/0003-066X.41.10.1040) -- *American Psychologist*, 41(10), 1040-1048
- Hamari, J. et al. (2014). ["Does Gamification Work?"](https://doi.org/10.1109/HICSS.2014.377) -- *HICSS 2014*

### How Top TD Games Use It

- **BTD6**: monkey knowledge tree (passive upgrades), collection events, player level with XP, trophy store cosmetics, hero XP -- multiple interlocking progression systems
- **Kingdom Rush**: stars unlock powers on skill tree, hero levels persist across maps, iron/heroic challenge modes per map, achievements with gem rewards
- **Arknights**: operator trust system (relationship meter), base building progression, story unlocks, material farming loop
- **Vampire Survivors**: permanent weapon/character unlocks, achievement-gated content, PowerUp shop with gold persistence

### Goligee Implementation

#### Starlight Currency
- Earned from every run (win or lose):

| Source                  | Starlight Earned        |
|-------------------------|-------------------------|
| Wave completed          | 1 per wave              |
| Boss killed             | 10-25 (scales with boss)|
| Map star earned         | 15 per star             |
| Perfect wave streak (5+)| 5 bonus                 |
| Corrupted enemy killed  | 2 per kill              |
| First-time synergy found| 10 per discovery        |
| Defeat (consolation)    | 25% of what was earned  |

- New players receive 50 Starlight on first launch (endowed progress)
- Starlight cannot be purchased with real money (premium currency is separate if monetized)

#### Twilight Knowledge Tree
Four branches, each with 8-10 nodes:

**Martial Branch** (combat power):
- Sharpened Edges: +5% tower damage globally
- Quick Draw: +5% fire rate globally
- Eagle Eye: +5% tower range globally
- Battle Hardened: towers gain +1% damage per 50 kills (per-run)
- Master Tactician: +1 tower placement slot on each map

**Arcane Branch** (discovery & synergies):
- Attunement: +2 hidden synergies revealed as hints
- Resonance: synergy bonuses increased by 15%
- Transmutation: 10% chance corrupted enemies drop double shards
- Arcane Sight: wave preview shows 3 waves ahead (instead of 2)
- Evolution Catalyst: tower evolutions require tier 3+ (instead of tier 4+)

**Commerce Branch** (economy):
- Seed Money: +50 starting gold
- Compound Interest: gold interest 7% (instead of 5%)
- Efficient Recycling: tower sell refund 80% (instead of 70%)
- Treasure Hunter: treasure caravan frequency +25%
- Golden Age: wave calling gold bonus +10%

**Fortitude Branch** (defense & survival):
- Thick Walls: +2 starting lives
- Slow Aura: enemies within 2 tiles of exit move 10% slower
- Last Stand Mastery: Last Stand mode grants +10% tower damage
- Resilience: first leak per wave deals 0 damage (1 freebie)
- Twilight Bastion: +5 max lives

#### Map Stars (3 per map)
| Star | Condition              | Difficulty |
|------|------------------------|------------|
| 1    | Complete the map       | Normal     |
| 2    | Complete with 15+ lives| Hard       |
| 3    | Complete under par time and gold | Expert |

- Star count unlocks later campaign maps
- Visual: constellation map screen showing all maps as connected stars

#### Tower Mastery
- Each tower type has a global XP bar (persists across all runs)
- XP earned from damage dealt and kills by that tower type
- Milestones at levels 5, 10, 15, 20, 25

| Level | Reward                                        |
|-------|-----------------------------------------------|
| 5     | Alternate color palette unlock                |
| 10    | Mastery border (silver) on tower portrait     |
| 15    | Unique idle animation                         |
| 20    | Mastery border (gold), "Master" title         |
| 25    | Prestige skin (twilight-themed visual overhaul)|

- Design intent: players develop expertise and identity with specific tower types

#### Bestiary
- All enemy types listed, but undiscovered ones shown as "???" silhouettes
- Defeating an enemy type fills in its entry (sprite, name, stats, lore)
- Lore snippets written in atmospheric Goligee style (twilight mythology)
- Completion percentage shown prominently (leverages Zeigarnik effect)
- Special entries for corrupted variants and bosses

#### Constellation Map
- Overworld screen showing campaign progression
- Each map is a "star" connected by constellation lines
- Stars glow brighter with more stars earned (0 = dim, 3 = brilliant)
- Hidden constellation patterns emerge as maps are completed
- Total star count displayed as a prestige badge in multiplayer/leaderboards

#### Key Files
- New: `scripts/autoloads/progression_manager.gd` -- Starlight, knowledge tree, mastery
- New: `scripts/ui/knowledge_tree.gd` -- skill tree UI
- New: `scripts/ui/constellation_map.gd` -- campaign map screen
- New: `scripts/ui/bestiary.gd` -- enemy encyclopedia
- New: `data/progression/knowledge_tree.tres` -- tree structure and costs
- `scripts/autoloads/game_manager.gd` -- Starlight earning hooks

---

## System 6: Flow State Maintenance

### Psychological Principle

**Flow Theory** (Csikszentmihalyi, 1990). Flow occurs when challenge and skill are
balanced -- too easy causes boredom, too hard causes anxiety. TD games naturally risk
breaking flow during idle periods (waiting for waves) or difficulty spikes (surprise
compositions).

**Autonomy** (Deci & Ryan, 1985). Players should feel in control of pacing. Speed controls
and wave calling give agency; forced waiting creates frustration.

**Active Engagement** (Malone, 1981). Active abilities prevent "set and forget" gameplay,
keeping the player's hands and mind engaged between placement decisions.

**Dynamic Difficulty Adjustment** (Hunicke, 2005). Subtle, hidden adjustments prevent
frustration without undermining skill. The key word is *hidden* -- players who detect DDA
feel cheated.

### Research Sources

- Csikszentmihalyi, M. (1990). [*Flow: The Psychology of Optimal Experience*](https://www.harpercollins.com/products/flow-mihaly-csikszentmihalyi) -- Harper & Row
- Deci, E.L. & Ryan, R.M. (2000). ["The 'What' and 'Why' of Goal Pursuits"](https://doi.org/10.1207/S15327965PLI1104_01) -- *Psychological Inquiry*, 11(4), 227-268
- Malone, T.W. (1981). ["Toward a Theory of Intrinsically Motivating Instruction"](https://doi.org/10.1207/s15516709cog0504_2) -- *Cognitive Science*, 5(4), 333-369
- Hunicke, R. (2005). ["The Case for Dynamic Difficulty Adjustment in Games"](https://doi.org/10.1145/1178477.1178573) -- *ACE 2005*
- Chen, J. (2007). ["Flow in Games"](https://doi.org/10.1145/1232743.1232769) -- *Communications of the ACM*, 50(4)

### How Top TD Games Use It

- **BTD6**: fast-forward button, active abilities on heroes, Monkey Knowledge passives reduce downtime, cash drops are active engagement during slow waves
- **Kingdom Rush**: hero is directly controllable (active engagement), reinforcements ability on cooldown, rain of fire ability, speed controls
- **Arknights**: operators are deployed in real-time, skill activation is manual, auto-deploy for replays (respects player time)
- **Vampire Survivors**: game speed naturally escalates, no downtime by design, treasure chests require manual pickup

### Goligee Implementation

#### Active Abilities (3 abilities, shared across all runs)

| Ability         | Cooldown | Effect                                | Visual                      |
|-----------------|----------|---------------------------------------|-----------------------------|
| Twilight Strike | 30s      | Targeted AoE: 500 Magic damage in 2-tile radius | Violet meteor impact  |
| Frost Veil      | 45s      | All enemies slowed 50% for 3s         | Blue-white screen overlay    |
| Gold Surge      | 60s      | 2x gold from kills for 10s            | Golden shimmer on all enemies|

- Abilities unlock via Twilight Knowledge tree (Martial branch)
- Cooldowns visible in HUD, abilities activated by tap/click on target area
- Abilities do NOT pause gameplay -- must be used tactically during waves
- Audio: distinct activation sound per ability, satisfying and atmospheric

#### Wave Preview
- Shows composition of next 2-3 upcoming waves (3 with Arcane Sight upgrade)
- Displayed as a compact sidebar or overlay panel
- Icons for enemy types with count numbers
- Special indicators for: boss waves, horde waves, elite waves, treasure caravans
- Design intent: allows strategic planning, reduces "surprise frustration"
- Player can tap an enemy icon for full bestiary info (if discovered)

#### Speed Control
- Three speeds: 1x (default), 2x, 3x
- Speed persists between waves until manually changed
- Auto-suggestion: if no enemies on screen for 5+ seconds, a subtle "Speed up?" prompt appears
- Speed resets to 1x on boss waves (can be overridden)
- Keyboard shortcuts: 1/2/3 keys (desktop), double-tap pause area (mobile)

#### Hidden Dynamic Difficulty
- Adjusts enemy HP by ±10% based on recent performance
- Performance metric: average leak percentage over last 3 waves

```
if avg_leak > 30%:
    hp_modifier = 0.90   # -10% HP (easier)
elif avg_leak > 15%:
    hp_modifier = 0.95   # -5% HP
elif avg_leak == 0% for 5+ waves:
    hp_modifier = 1.05   # +5% HP (slightly harder)
else:
    hp_modifier = 1.00   # no change
```

- **NEVER disclosed to player** -- must feel natural, not patronizing
- Cap: only applies to standard enemies, never bosses
- Resets each new map attempt
- Design intent: keeps casual players from hitting a wall, keeps skilled players from getting bored

#### Key Files
- New: `scripts/systems/ability_manager.gd` -- active ability cooldowns and effects
- `scripts/ui/hud.gd` -- speed controls, wave preview, ability buttons
- `scripts/autoloads/wave_manager.gd` -- wave preview data, speed multiplier
- `scripts/autoloads/game_manager.gd` -- DDA tracking and HP modifier

---

## System 7: Roguelike Endgame

### Psychological Principle

**Procedural Generation & Novelty** (Berlyne, 1960). Novel stimuli inherently attract
attention and engagement. Roguelike elements ensure no two runs are identical, which
sustains interest far beyond static content.

**Meaningful Choice** (Sid Meier). Draft mechanics force interesting decisions -- every
choice has a trade-off, which creates engagement through agency and identity.

**Voluntary Challenge** (Deterding, 2011). Players who *choose* to make the game harder
(Blood Moon Gambit) feel more accomplished when succeeding. The challenge must be
opt-in, not forced.

**Social Comparison** (Festinger, 1954). Leaderboards create extrinsic motivation through
comparison, but should be opt-in to avoid discouraging casual players.

### Research Sources

- Berlyne, D.E. (1960). [*Conflict, Arousal, and Curiosity*](https://doi.org/10.1037/11164-000) -- McGraw-Hill
- Deterding, S. et al. (2011). ["From Game Design Elements to Gamefulness"](https://doi.org/10.1145/2181037.2181040) -- *MindTrek 2011*
- Festinger, L. (1954). ["A Theory of Social Comparison Processes"](https://doi.org/10.1177/001872675400700202) -- *Human Relations*, 7(2), 117-140
- Rogue Basin Wiki. ["What a Roguelike Is"](http://www.roguebasin.com/index.php?title=What_a_roguelike_is)
- Kremers, R. (2009). [*Level Design: Concept, Theory, and Practice*](https://www.routledge.com/Level-Design/Kremers/p/book/9781568813387) -- A K Peters

### How Top TD Games Use It

- **BTD6**: boss events and contested territory add procedural elements, collection events have unique rulesets, co-op introduces social play
- **Kingdom Rush**: heroic/iron challenges add modifiers to existing maps, endless mode on select maps
- **Vampire Survivors**: entire game is roguelike -- weapon selection is a draft, arcanas add variability, inverse mode after beating Death
- **Arknights**: Integrated Strategies (roguelike mode) is enormously popular -- node selection, relic collection, branching paths

### Goligee Implementation

#### Twilight Trials (Core Mode)
- Unlocked after completing the campaign
- Endless waves on procedurally modified maps
- No pre-built loadout -- start with 1 random basic tower

**Draft System:**
- After each wave, choose 1 of 3 randomly offered options:
  - New tower (spawned on a random valid tile)
  - Upgrade for an existing tower (random eligible tower + random path)
  - Resource bonus (gold, ability cooldown reset, extra life)
- Options weighted by wave number (early = basic, late = powerful)
- Reroll option: spend 50 gold to reroll all 3 choices (once per wave)

**Map Modifiers (1-2 per run, random):**

| Modifier          | Effect                                          |
|-------------------|-------------------------------------------------|
| Fog of War        | Only see enemies within tower range             |
| Reversed Paths    | Enemies enter from exit, exit from entrance     |
| Lava Fields       | Random tiles become lava (damage enemies AND block towers) |
| Narrow Passages   | Extra chokepoints but fewer placement tiles     |
| Twilight Eclipse   | All enemies gain stealth for first 3s on spawn  |
| Cursed Ground     | Towers lose 1% HP per wave (yes, towers can die)|

#### Blood Moon Gambit
- Optional challenge offered every 5 waves
- Player can accept or decline (no penalty for declining)
- Acceptance: enemies get +50% HP for the next wave
- Reward: 3x gold drops, guaranteed Twilight Shard drop
- Visual: screen tints blood-red, moon changes color in background
- Stacking: multiple accepted gambits stack multiplicatively
- Design intent: skilled players can accelerate progression, creates dramatic moments

#### Challenge Modifiers (Score Multipliers)

| Modifier             | Effect                     | Score Multiplier |
|----------------------|----------------------------|------------------|
| No Ice Towers        | Ice towers cannot be drafted| 1.2x            |
| Double Speed         | Permanent 2x game speed   | 1.3x             |
| Glass Cannon         | Towers deal 2x damage, have 50% HP | 1.5x     |
| Pacifist Start       | No towers for first 3 waves| 1.4x            |
| Blood Moon Always    | Gambit active every wave   | 2.0x             |
| True Twilight        | All modifiers active       | 5.0x             |

- Players select modifiers before starting a Twilight Trial run
- Modifiers are unlocked by reaching wave milestones (wave 10, 20, 30, etc.)

#### Leaderboard
- Score formula: `waves_survived * modifier_multiplier * (1 + perfect_waves * 0.05)`
- Separate leaderboards for: overall, per-modifier, weekly, friends
- Opt-in: leaderboard submission is manual ("Submit Score?" after run)
- Display: top 100 global, top 10 friends, personal best highlighted

#### Key Files
- New: `scripts/modes/twilight_trials.gd` -- draft logic, modifier application
- New: `scripts/modes/blood_moon.gd` -- gambit system
- New: `scripts/ui/draft_panel.gd` -- draft choice UI
- New: `scripts/ui/leaderboard.gd` -- score display and submission
- New: `data/trials/modifiers.tres` -- modifier definitions

---

## Competitive Analysis

### Bloons TD 6 (BTD6)

**What makes it addictive:**
- Depth of tower interactions (crosspathing creates 15 builds per tower)
- Collection events and limited-time content create urgency (FOMO)
- Co-op mode adds social engagement
- Boss events provide aspirational content
- Monkey Knowledge tree gives permanent power growth
- Pop count tracking satisfies completionist and power fantasy needs

**What Goligee should borrow:**
- Crosspathing depth (already in design -- 3 paths with 5 tiers)
- Pop/kill tracking per tower and globally
- Knowledge tree concept (adapted as Twilight Knowledge)
- Event-based content rotation (adapted as Twilight Trials modifiers)

**What Goligee should avoid:**
- BTD6's UI is cluttered and overwhelming for new players
- Excessive monetization layers (hero skins, cash drops, continues)
- Late-game visual noise makes gameplay unreadable

### Kingdom Rush (Series)

**What makes it addictive:**
- Hero system provides player identity and progression
- Star-based rating system drives replay (loss aversion on missed stars)
- Hand-drawn art creates emotional attachment to the world
- Campaign structure with escalating difficulty maintains flow
- Encyclopedia/bestiary satisfies explorer motivation

**What Goligee should borrow:**
- Star rating per map (3-star system, adapted for constellation map)
- Bestiary with gradual discovery
- Strong art direction creating emotional connection (Goligee's twilight aesthetic)
- Active abilities (rain of fire -> Twilight Strike)

**What Goligee should avoid:**
- Kingdom Rush's hero system can become a crutch (players rely on hero, not towers)
- In-app purchases for heroes feel pay-to-win
- Limited endgame (once all stars earned, little reason to replay)

### Arknights

**What makes it addictive:**
- Operator collection (gacha) creates variable reward loop
- Integrated Strategies (roguelike mode) has enormous depth and replayability
- Story and worldbuilding create emotional investment
- Trust system (relationship meter) drives "one more mission" behavior
- Base building provides idle progression between active play
- Challenge modes (Contingency Contract) provide aspirational difficulty

**What Goligee should borrow:**
- Roguelike mode concept (adapted as Twilight Trials)
- Depth of strategic options in challenges
- World-building through bestiary lore and atmospheric storytelling
- Operator trust concept (adapted as Tower Mastery)

**What Goligee should avoid:**
- Gacha monetization is predatory (Goligee should never gate power behind gambling)
- Stamina/energy systems are anti-player
- Complexity barrier is very high for new players

### Vampire Survivors

**What makes it addictive:**
- Compounding power fantasy is the entire game loop (numbers go up, screen fills)
- Discovery-driven progression (hidden weapons, evolutions, characters, stages)
- Sessions are short (30 min) making "one more run" frictionless
- Weapon evolution system creates exciting mid-run power spikes
- Arcana system adds roguelike variability
- Minimal UI -- gameplay speaks for itself

**What Goligee should borrow:**
- Discovery as core motivation (adapted as Synergy Discovery, Tower Evolutions)
- Power fantasy escalation (DPS meter milestones, kill counter visuals)
- Short session potential (Twilight Trials can be designed for 15-30 min runs)
- Evolution system concept (adapted as Tower Evolutions)

**What Goligee should avoid:**
- Vampire Survivors has no strategic depth -- Goligee is a *strategy* game first
- Pure power fantasy without challenge becomes boring (Goligee needs difficulty)
- No social features limits long-term engagement

### Cross-Game Insights

| Principle                  | BTD6 | KR  | AK  | VS  | Goligee Approach              |
|----------------------------|------|-----|-----|-----|-------------------------------|
| Meta-progression           | Yes  | Yes | Yes | Yes | Twilight Knowledge tree       |
| Variable rewards           | Mod  | Low | High| High| Corrupted enemies, discovery  |
| Active abilities           | Yes  | Yes | Yes | No  | 3 cooldown abilities          |
| Roguelike mode             | Mod  | No  | Yes | Yes | Twilight Trials               |
| Power fantasy escalation   | High | Mod | Mod | Ext | DPS meter, kill counters      |
| Collection/completion      | High | Mod | High| High| Bestiary, Grimoire, Mastery   |
| Social/competitive         | Yes  | No  | Mod | No  | Leaderboards (opt-in)         |

---

## Implementation Priority

| Priority | System                    | Player Impact | Dev Effort | Dependencies        | Ship Target      |
|----------|---------------------------|---------------|------------|---------------------|------------------|
| 1        | Game Juice & Feedback     | Very High     | Medium     | Core systems exist  | Alpha             |
| 2        | Near-Miss & Loss Aversion | High          | Low        | HUD, WaveManager    | Alpha             |
| 3        | Compounding Power Fantasy | High          | Low-Medium  | HUD, EconomyManager| Alpha             |
| 4        | Variable Rewards          | Very High     | Medium     | EnemyData, Synergies| Beta              |
| 5        | Flow Maintenance          | High          | Medium     | HUD, WaveManager    | Beta              |
| 6        | Meta-Progression          | Very High     | High       | Save system, UI     | Beta/Launch       |
| 7        | Roguelike Endgame         | High          | High       | All core systems    | Post-launch DLC   |

### Rationale

1. **Game Juice first** because it makes every other system *feel* better. A DPS meter
   without satisfying hit effects is just a number. Loss aversion without impactful "Almost!"
   popups is just text. Juice is the foundation.

2. **Near-Miss & Loss Aversion second** because these are small systems with outsized
   psychological impact. An "Almost!" popup takes hours to implement but can be the
   difference between a player quitting and retrying.

3. **Compounding Power Fantasy third** because kill counters and DPS meters are simple
   to build and immediately rewarding. Wave calling adds strategic depth with minimal code.

4. **Variable Rewards fourth** because corrupted enemies and treasure caravans transform
   routine waves into exciting events. This is Goligee's core differentiator from generic TD.

5. **Flow Maintenance fifth** because active abilities and speed controls are mid-priority --
   they improve sessions but aren't the primary hook.

6. **Meta-Progression sixth** because it requires significant infrastructure (save system,
   UI screens, balance) but is critical for long-term retention. Ship with core loops first.

7. **Roguelike Endgame last** because it requires all other systems to be polished. Twilight
   Trials is the endgame carrot -- it only works if the journey there is satisfying.

---

## Sources

### Academic / Psychology

1. Bandura, A. (1977). ["Self-Efficacy: Toward a Unifying Theory of Behavioral Change"](https://doi.org/10.1037/0033-295X.84.2.191) -- *Psychological Review*, 84(2), 191-215
2. Berlyne, D.E. (1960). [*Conflict, Arousal, and Curiosity*](https://doi.org/10.1037/11164-000) -- McGraw-Hill
3. Csikszentmihalyi, M. (1990). [*Flow: The Psychology of Optimal Experience*](https://www.harpercollins.com/products/flow-mihaly-csikszentmihalyi) -- Harper & Row
4. Deci, E.L. & Ryan, R.M. (1985). [*Intrinsic Motivation and Self-Determination in Human Behavior*](https://doi.org/10.1007/978-1-4899-2271-7) -- Plenum Press
5. Deci, E.L. & Ryan, R.M. (2000). ["The 'What' and 'Why' of Goal Pursuits"](https://doi.org/10.1207/S15327965PLI1104_01) -- *Psychological Inquiry*, 11(4), 227-268
6. Dweck, C.S. (1986). ["Motivational Processes Affecting Learning"](https://doi.org/10.1037/0003-066X.41.10.1040) -- *American Psychologist*, 41(10), 1040-1048
7. Festinger, L. (1954). ["A Theory of Social Comparison Processes"](https://doi.org/10.1177/001872675400700202) -- *Human Relations*, 7(2), 117-140
8. Hull, C.L. (1932). ["The Goal-Gradient Hypothesis and Maze Learning"](https://doi.org/10.1037/h0072640) -- *Psychological Review*, 39(1), 25-43
9. Kahneman, D. & Tversky, A. (1979). ["Prospect Theory: An Analysis of Decision Under Risk"](https://www.jstor.org/stable/1914185) -- *Econometrica*, 47(2), 263-291
10. Nunes, J.C. & Dreze, X. (2006). ["The Endowed Progress Effect"](https://doi.org/10.1086/500480) -- *Journal of Consumer Research*, 32(4), 504-512
11. Reid, R.L. (1986). ["The Psychology of the Near Miss"](https://doi.org/10.1007/BF01019859) -- *Journal of Gambling Behavior*, 2(1), 32-39
12. Skinner, B.F. (1957). [*Schedules of Reinforcement*](https://archive.org/details/schedulesofrei00skin) -- Appleton-Century-Crofts
13. Zeigarnik, B. (1927). ["On Finished and Unfinished Tasks"](https://psychclassics.yorku.ca/Zeigarnik/) -- *Psychologische Forschung*, 9, 1-85

### Game Design / Industry

14. Alter, A.L. & Oppenheimer, D.M. (2006). ["From a fixation on sports to an exploration of mechanism"](https://doi.org/10.1016/j.tics.2006.08.001) -- *Trends in Cognitive Sciences*
15. Arkes, H.R. & Blumer, C. (1985). ["The Psychology of Sunk Cost"](https://doi.org/10.1016/0749-5978(85)90049-4) -- *Organizational Behavior and Human Decision Processes*, 35(1), 124-140
16. Bartle, R. (1996). ["Hearts, Clubs, Diamonds, Spades: Players Who Suit MUDs"](https://mud.co.uk/richard/hcds.htm)
17. Chen, J. (2007). ["Flow in Games"](https://doi.org/10.1145/1232743.1232769) -- *Communications of the ACM*, 50(4)
18. Clark, L. et al. (2009). ["Gambling Near-Misses Enhance Motivation to Gamble"](https://doi.org/10.1016/j.neuron.2009.01.025) -- *Neuron*, 61(3), 481-490
19. Deterding, S. et al. (2011). ["From Game Design Elements to Gamefulness"](https://doi.org/10.1145/2181037.2181040) -- *MindTrek 2011*
20. Hamari, J. et al. (2014). ["Does Gamification Work?"](https://doi.org/10.1109/HICSS.2014.377) -- *HICSS 2014*
21. Hopson, J. (2001). ["Behavioral Game Design"](https://www.gamedeveloper.com/design/behavioral-game-design) -- Gamasutra
22. Hunicke, R. (2005). ["The Case for Dynamic Difficulty Adjustment in Games"](https://doi.org/10.1145/1178477.1178573) -- *ACE 2005*
23. Juul, J. (2010). [*A Casual Revolution*](https://mitpress.mit.edu/books/casual-revolution) -- MIT Press
24. King, D. et al. (2010). ["Video Game Structural Characteristics"](https://doi.org/10.1007/s11469-009-9206-1) -- *International Journal of Mental Health and Addiction*
25. Kremers, R. (2009). [*Level Design: Concept, Theory, and Practice*](https://www.routledge.com/Level-Design/Kremers/p/book/9781568813387) -- A K Peters
26. Malone, T.W. (1981). ["Toward a Theory of Intrinsically Motivating Instruction"](https://doi.org/10.1207/s15516709cog0504_2) -- *Cognitive Science*, 5(4), 333-369
27. Przybylski, A.K. et al. (2010). ["A Motivational Model of Video Game Engagement"](https://doi.org/10.1037/a0019440) -- *Review of General Psychology*, 14(2), 154-166
28. Swink, S. (2008). [*Game Feel: A Game Designer's Guide to Virtual Sensation*](https://www.gamefeelbook.com/) -- Morgan Kaufmann

### Talks / Videos

29. Brown, M. (2016). ["Secrets of Game Feel and Juice"](https://www.youtube.com/watch?v=216_5nu4aVQ) -- Game Maker's Toolkit
30. Nijman, J.W. (2013). ["The Art of Screenshake"](https://www.youtube.com/watch?v=AJdEqssNZ-U) -- GDC/Vlambeer
31. Rogue Basin Wiki. ["What a Roguelike Is"](http://www.roguebasin.com/index.php?title=What_a_roguelike_is)
