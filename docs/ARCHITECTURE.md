# Goligee -- Architecture & Technology Decision

## Recommendation: Godot 4.5+

After evaluating 6 frameworks (Phaser, PixiJS, Godot, LibGDX, Unity, Bevy), **Godot 4**
is the clear winner for this project.

---

## Framework Comparison Summary

| Criterion                    | Phaser 4 | PixiJS | **Godot 4** | LibGDX | Unity | Bevy |
|------------------------------|----------|--------|-------------|--------|-------|------|
| Cross-platform (Web+Android) | 7        | 7      | **8**       | 6      | 7     | 4    |
| Component System             | 3        | 2      | **7**       | 8      | 5-8   | 10   |
| Pixel Art Rendering          | 8        | 9      | **9**       | 7      | 7     | 6    |
| Particle System              | 7        | 9      | **8**       | 7      | 8     | 7    |
| Shader Support (fog, FX)     | 7        | 9      | **9**       | 7      | 9     | 7    |
| Community & Ecosystem        | 9        | 7      | **9**       | 6      | 9     | 6    |
| Mobile Performance           | 6        | 7      | **8**       | 8      | 8     | 5    |
| Ease of Adding Entities      | 7        | 5      | **9**       | 7      | 7     | 8    |
| **Overall**                  | 6.75     | 6.88   | **8.38**    | 7.0    | 7.63  | 6.63 |

---

## Why Godot Wins

### 1. True Cross-Platform from One Codebase
- **Android**: Native APK with OpenGL ES / Vulkan rendering (NOT a WebView wrapper)
- **Web**: WebAssembly + WebGL export (WASM SIMD in Godot 4.5+ for better perf)
- Same GDScript/scenes project targets both platforms

### 2. Built-in Isometric Tilemap
- `TileMapLayer` node with Isometric tile shape -- most complete out-of-the-box solution
- Auto-tiling, collision shapes per tile, tile metadata
- No third-party plugins needed for isometric rendering

### 3. Node Composition = Perfect for Tower Defense
- A Tower = `Sprite2D` + `Area2D` + `Timer` + custom script composed in a scene
- An Enemy = `Sprite2D` + `PathFollow2D` + `CollisionShape2D` + custom script
- New tower/enemy types = new `.tscn` scene files inheriting from base
- Visual editor for composing and tweaking entities in real time

### 4. GPUParticles2D + Powerful Shaders
- Hardware-accelerated particles with custom particle shaders
- Full shader language (GLSL-like) + visual shader editor
- Fog, atmospheric effects, post-processing all well-supported

### 5. MIT Licensed, No Royalties Ever
- Massive community momentum post-Unity pricing controversy
- Tower defense templates and full courses available
- Active development (4.5 released, 4.6 in beta)

---

## Godot Weaknesses to Mitigate

| Weakness | Mitigation |
|----------|------------|
| Web export file size (~10-40MB) | Build minification, loading screen, acceptable for a game |
| Web perf gap vs native | Test web early & often; use CPUParticles2D as fallback |
| No C# on web export | Use GDScript exclusively (fine for game logic) |
| GPU particles may fail on some web builds | CPUParticles2D fallback layer |

---

## Runner-Up Options

- **Phaser 4**: Best if web is primary and Android is secondary. Tiny footprint, fast browser loading. But no native Android rendering, no built-in isometric tilemaps.
- **PixiJS**: Best raw 2D web rendering performance (1M particles at 60fps). But you're building a custom engine from scratch -- massive dev effort.

---

## Project Architecture

### Language
**GDScript** for all game logic (required for web export compatibility)

### Scene/Node Hierarchy

```
Game (Node2D)
├── World (Node2D)
│   ├── TileMapLayer (Isometric map)
│   ├── Paths (Node2D)
│   │   ├── Path2D (enemy path 1)
│   │   └── Path2D (enemy path 2)
│   ├── Towers (Node2D, container for all placed towers)
│   ├── Enemies (Node2D, container for all active enemies)
│   ├── Projectiles (Node2D, container for active projectiles)
│   └── Effects (Node2D, particles and visual FX)
├── FogLayer (CanvasLayer + shader)
├── UI (CanvasLayer)
│   ├── HUD (gold, lives, wave counter)
│   ├── TowerMenu (build/upgrade panel)
│   └── WaveInfo (upcoming wave preview)
└── GameManager (Node, autoload singleton)
    ├── WaveManager
    ├── EconomyManager
    └── UpgradeRegistry
```

### Component Pattern (via Node Composition)

Each tower/enemy is a **PackedScene** composed of reusable child nodes:

```
BaseTower.tscn
├── Sprite2D (visual)
├── AnimationPlayer (animations)
├── Area2D + CollisionShape2D (range detection)
├── AttackTimer (Timer node)
├── WeaponComponent.gd (custom node -- damage, type, projectile)
├── TargetingComponent.gd (custom node -- priority, current target)
├── UpgradeComponent.gd (custom node -- paths, tiers, modifiers)
└── AudioStreamPlayer2D (SFX)

ArrowTower.tscn (inherits BaseTower)
├── [overrides: sprite, weapon stats, upgrade paths]
└── [adds: ArrowTrailEffect]

BaseEnemy.tscn
├── Sprite2D (visual)
├── AnimationPlayer
├── PathFollow2D (movement along path)
├── HealthComponent.gd (HP, armor, shield)
├── ResistanceComponent.gd (damage type multipliers)
├── StatusEffectManager.gd (active debuffs)
├── LootComponent.gd (gold, XP rewards)
└── HealthBar (Control node)
```

### Key Autoload Singletons

```
GameManager     -- Game state, pause, speed control
WaveManager     -- Wave definitions, spawning, progression
EconomyManager  -- Gold, income, costs
DamageCalculator -- Centralized damage formula with resistance matrix
UpgradeRegistry -- All upgrade definitions, stat modifier resolution
SignalBus       -- Global event bus (enemy_killed, wave_complete, etc.)
```

### Data-Driven Design

Tower, enemy, wave, and upgrade definitions stored as **Resources** (`.tres` files):

```gdscript
# tower_data.gd
class_name TowerData extends Resource

@export var tower_name: String
@export var icon: Texture2D
@export var build_cost: int
@export var base_damage: float
@export var base_range: float
@export var fire_rate: float
@export var damage_type: DamageType
@export var projectile_scene: PackedScene
@export var upgrade_paths: Array[UpgradePathData]
```

This allows designers to create new towers entirely in the Godot editor
without writing code -- just fill in a Resource and assign a scene.

---

## Recommended Godot Version

**Godot 4.5** (stable, released mid-2025)
- WASM SIMD for better web performance
- Shader baker for faster shader compilation
- Stencil buffer support
- Improved TileMapLayer performance

Upgrade to **4.6** when it reaches stable if needed.

---

## Directory Structure

```
goligee/
├── project.godot
├── moodboard/                  # Visual references & palette
├── docs/                       # Architecture & design docs
├── assets/
│   ├── sprites/
│   │   ├── towers/
│   │   ├── enemies/
│   │   ├── projectiles/
│   │   ├── effects/
│   │   ├── tiles/
│   │   └── ui/
│   ├── audio/
│   │   ├── sfx/
│   │   └── music/
│   └── shaders/
│       ├── fog.gdshader
│       ├── atmosphere.gdshader
│       └── damage_flash.gdshader
├── scenes/
│   ├── main/
│   │   ├── game.tscn
│   │   └── main_menu.tscn
│   ├── towers/
│   │   ├── base_tower.tscn
│   │   ├── arrow_tower.tscn
│   │   ├── cannon_tower.tscn
│   │   ├── lightning_tower.tscn
│   │   ├── ice_tower.tscn
│   │   └── necromancer_tower.tscn
│   ├── enemies/
│   │   ├── base_enemy.tscn
│   │   ├── goblin_scout.tscn
│   │   ├── skeleton_warrior.tscn
│   │   └── ...
│   ├── projectiles/
│   │   ├── arrow.tscn
│   │   ├── cannonball.tscn
│   │   └── lightning_bolt.tscn
│   ├── effects/
│   │   ├── explosion.tscn
│   │   ├── frost_effect.tscn
│   │   └── poison_cloud.tscn
│   ├── maps/
│   │   ├── map_01_forest.tscn
│   │   └── map_02_ruins.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── tower_menu.tscn
│       └── upgrade_panel.tscn
├── scripts/
│   ├── autoloads/
│   │   ├── game_manager.gd
│   │   ├── wave_manager.gd
│   │   ├── economy_manager.gd
│   │   ├── damage_calculator.gd
│   │   ├── upgrade_registry.gd
│   │   └── signal_bus.gd
│   ├── components/
│   │   ├── weapon_component.gd
│   │   ├── targeting_component.gd
│   │   ├── upgrade_component.gd
│   │   ├── health_component.gd
│   │   ├── resistance_component.gd
│   │   ├── status_effect_manager.gd
│   │   ├── loot_component.gd
│   │   └── path_follow_component.gd
│   ├── towers/
│   │   ├── base_tower.gd
│   │   └── tower_placer.gd
│   ├── enemies/
│   │   ├── base_enemy.gd
│   │   └── enemy_abilities.gd
│   ├── projectiles/
│   │   └── base_projectile.gd
│   └── ui/
│       ├── hud.gd
│       └── tower_menu.gd
├── data/
│   ├── towers/               # .tres Resource files
│   │   ├── arrow_tower.tres
│   │   ├── cannon_tower.tres
│   │   └── ...
│   ├── enemies/
│   │   ├── goblin_scout.tres
│   │   └── ...
│   ├── waves/
│   │   ├── map_01_waves.tres
│   │   └── ...
│   └── upgrades/
│       ├── arrow_path_a.tres
│       └── ...
└── export_presets/
    ├── android/
    └── web/
```
