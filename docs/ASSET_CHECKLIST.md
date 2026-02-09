# Goligee -- Asset Checklist

> Track production status of every sprite needed. Update status as assets are completed.
> Status: `[ ]` pending, `[~]` in progress, `[x]` done

---

## Phase 1: Golden Standards (5 sprites)

| # | Asset | Size | File | Status |
|---|-------|------|------|--------|
| 1 | Ground tile (cracked asphalt) | 32x16 | `tiles/tile_ground_cracked.png` | [~] needs 2:1 iso ratio fix |
| 2 | Rubber Bullet Turret (idle) | 32x32 | `towers/tower_rubber_bullet_idle.png` | [x] |
| 3 | Rioter (walk SE) | 16x16 | `enemies/enemy_rioter_se_01.png` | [x] |
| 4 | Bullet tracer | 8x8 | `projectiles/proj_rubber_bullet.png` | [x] |
| 5 | Kinetic impact explosion | 16x16 | `effects/effect_explosion_kinetic_01.png` | [x] |

---

## Tiles (32x16)

| # | Tile | Variants | Files | Status |
|---|------|----------|-------|--------|
| 1 | Ground -- cracked asphalt | 2-3 | `tiles/tile_ground_*.png` | [ ] |
| 2 | Path -- warning yellow | 2 | `tiles/tile_path_*.png` | [ ] |
| 3 | Wall -- concrete | 2 | `tiles/tile_wall_*.png` | [ ] |
| 4 | Elevated -- platform | 1 | `tiles/tile_platform.png` | [ ] |
| 5 | Scorched ground | 1 | `tiles/tile_scorched.png` | [ ] |
| 6 | Flooded street | 1 | `tiles/tile_flooded.png` | [ ] |
| 7 | Toxic spill | 1 | `tiles/tile_toxic.png` | [ ] |
| 8 | Rubble | 1-2 | `tiles/tile_rubble_*.png` | [ ] |

**Estimated: ~12 tile sprites**

---

## Towers (32x32)

Each tower needs: idle + active states. Tier 5 variants in Phase 4.

| # | Tower | States | Files | Status |
|---|-------|--------|-------|--------|
| 1 | Rubber Bullet Turret | idle, active | `towers/tower_rubber_bullet_*.png` | [~] idle done, need active |
| 2 | Tear Gas Launcher | idle, active | `towers/tower_tear_gas_*.png` | [~] idle done, need active |
| 3 | Water Cannon | idle, active | `towers/tower_water_cannon_*.png` | [~] idle done, need active |
| 4 | Taser Grid | idle, active | `towers/tower_taser_grid_*.png` | [~] idle done, need active |
| 5 | Surveillance Hub | idle, active | `towers/tower_surveillance_*.png` | [ ] broken, needs regen |
| 6 | Pepper Spray Emitter | idle, active | `towers/tower_pepper_spray_*.png` | [ ] |
| 7 | LRAD Cannon | idle, active | `towers/tower_lrad_*.png` | [ ] |
| 8 | Microwave Emitter | idle, active | `towers/tower_microwave_*.png` | [ ] |

**Estimated: 16 tower sprites (8 towers x 2 states)**

### Tier 5 Variants (Phase 4)

| # | Tier 5 Tower | Path | File | Status |
|---|-------------|------|------|--------|
| 1 | DEADSHOT | Rubber Bullet A5 | `towers/tower_rubber_bullet_tier5a.png` | [ ] |
| 2 | BULLET HELL | Rubber Bullet B5 | `towers/tower_rubber_bullet_tier5b.png` | [ ] |
| 3 | EXPERIMENTAL ORDNANCE | Rubber Bullet C5 | `towers/tower_rubber_bullet_tier5c.png` | [ ] |
| 4 | NERVE AGENT DEPLOYER | Tear Gas A5 | `towers/tower_tear_gas_tier5a.png` | [ ] |
| 5 | ARC REACTOR | Taser Grid A5 | `towers/tower_taser_grid_tier5a.png` | [ ] |
| 6 | TSUNAMI CANNON | Water Cannon A5 | `towers/tower_water_cannon_tier5a.png` | [ ] |
| 7 | PANOPTICON | Surveillance A5 | `towers/tower_surveillance_tier5a.png` | [ ] |
| 8 | DEATH RAY | Microwave A5 | `towers/tower_microwave_tier5a.png` | [ ] |

**Estimated: 8 tier 5 sprites (1 per tower, most iconic path)**

---

## Standard Enemies (16x16)

Each enemy needs: 4-direction walk cycle (4 frames each = 16 frames per enemy).
Start with SE direction only, expand to 4 directions after style lock.

| # | Enemy | Directions | Frames/Dir | Files | Status |
|---|-------|------------|------------|-------|--------|
| 1 | Rioter | SE,SW,NE,NW | 4 | `enemies/enemy_rioter_*_*.png` | [~] SE frame 1 done |
| 2 | Masked Protestor | SE,SW,NE,NW | 4 | `enemies/enemy_masked_*_*.png` | [~] SE frame 1 done |
| 3 | Shield Wall | SE,SW,NE,NW | 4 | `enemies/enemy_shield_wall_*_*.png` | [~] SE frame 1 done |
| 4 | Molotov Thrower | SE,SW,NE,NW | 4 | `enemies/enemy_molotov_*_*.png` | [~] SE frame 1 done |
| 5 | Drone Operator | SE,SW,NE,NW | 4 | `enemies/enemy_drone_op_*_*.png` | [ ] broken, needs regen |
| 6 | Flash Mob | SE,SW,NE,NW | 4 | `enemies/enemy_flash_mob_*_*.png` | [~] SE frame 1 done |
| 7 | Street Medic | SE,SW,NE,NW | 4 | `enemies/enemy_street_medic_*_*.png` | [~] SE frame 1 done |
| 8 | Armored Van (24x16) | SE,SW,NE,NW | 4 | `enemies/enemy_armored_van_*_*.png` | [~] SE frame 1 done |
| 9 | Infiltrator | SE,SW,NE,NW | 4 | `enemies/enemy_infiltrator_*_*.png` | [~] SE frame 1 done |
| 10 | Social Media Swarm (8x8) | SE,SW,NE,NW | 4 | `enemies/enemy_swarm_*_*.png` | [~] SE frame 1 done |
| 11 | Tunnel Rat | SE,SW,NE,NW | 4 | `enemies/enemy_tunnel_rat_*_*.png` | [~] SE frame 1 done |
| 12 | Union Boss (20x20) | SE,SW,NE,NW | 4 | `enemies/enemy_union_boss_*_*.png` | [~] SE frame 1 done |
| 13 | Journalist | SE,SW,NE,NW | 4 | `enemies/enemy_journalist_*_*.png` | [~] SE frame 1 done |
| 14 | Grandma | SE,SW,NE,NW | 4 | `enemies/enemy_grandma_*_*.png` | [~] SE frame 1 done |
| 15 | Family | SE,SW,NE,NW | 4 | `enemies/enemy_family_*_*.png` | [~] SE frame 1 done |
| 16 | Student | SE,SW,NE,NW | 4 | `enemies/enemy_student_*_*.png` | [~] SE frame 1 done |

**Estimated: 256 enemy frames (16 enemies x 4 dirs x 4 frames)**

---

## Boss Enemies (48x48)

Each boss needs: idle + attack + death states (4 frames each).

| # | Boss | States | Files | Status |
|---|------|--------|-------|--------|
| 1 | The Demagogue | idle, attack, phase2, death | `bosses/boss_demagogue_*_*.png` | [ ] |
| 2 | The Hacktivist | idle, attack, death | `bosses/boss_hacktivist_*_*.png` | [ ] |
| 3 | The Barricade | idle, attack, death | `bosses/boss_barricade_*_*.png` | [ ] |
| 4 | The Influencer | idle, attack, split, death | `bosses/boss_influencer_*_*.png` | [ ] |
| 5 | Ghost Protocol | idle, attack, teleport, death | `bosses/boss_ghost_protocol_*_*.png` | [ ] |

**Estimated: ~60 boss frames (5 bosses x 3-4 states x 4 frames)**

---

## Projectiles (8x8 to 16x16)

| # | Projectile | Size | File | Status |
|---|-----------|------|------|--------|
| 1 | Rubber bullet tracer | 8x8 | `projectiles/proj_rubber_bullet.png` | [x] |
| 2 | Tear gas canister | 12x12 | `projectiles/proj_tear_gas.png` | [ ] |
| 3 | Water blast | 16x16 | `projectiles/proj_water_blast.png` | [ ] |
| 4 | Electric arc | 12x12 | `projectiles/proj_electric_arc.png` | [ ] |
| 5 | Sonic wave | 16x8 | `projectiles/proj_sonic_wave.png` | [ ] |
| 6 | Heat beam | 16x4 | `projectiles/proj_heat_beam.png` | [ ] |
| 7 | Pepper spray cloud | 16x16 | `projectiles/proj_pepper_spray.png` | [ ] |
| 8 | Surveillance ping | 8x8 | `projectiles/proj_surveillance_ping.png` | [ ] |

**Estimated: 8 projectile sprites**

---

## Effects (16x16 to 32x32)

### Impact/Explosion Effects (4 frames each)

| # | Effect | Size | Frames | Files | Status |
|---|--------|------|--------|-------|--------|
| 1 | Kinetic impact | 16x16 | 4 | `effects/effect_explosion_kinetic_*.png` | [~] frame 1 done |
| 2 | Chemical burst | 32x32 | 4 | `effects/effect_explosion_chemical_*.png` | [ ] |
| 3 | Fire explosion | 32x32 | 6 | `effects/effect_explosion_fire_*.png` | [ ] |
| 4 | Electric discharge | 24x24 | 4 | `effects/effect_explosion_electric_*.png` | [ ] |
| 5 | Water splash | 24x24 | 4 | `effects/effect_explosion_water_*.png` | [ ] |
| 6 | Sonic shockwave | 24x24 | 4 | `effects/effect_explosion_sonic_*.png` | [ ] |
| 7 | Energy flash | 24x24 | 4 | `effects/effect_explosion_energy_*.png` | [ ] |
| 8 | Cyber glitch | 16x16 | 4 | `effects/effect_explosion_cyber_*.png` | [ ] |

### Status Effect Overlays (2-4 frames each, looping)

| # | Status | Size | Frames | Files | Status |
|---|--------|------|--------|-------|--------|
| 1 | Stun stars | 16x16 | 4 | `effects/effect_status_stun_*.png` | [ ] |
| 2 | Freeze/slow | 16x16 | 2 | `effects/effect_status_freeze_*.png` | [ ] |
| 3 | Burn DOT | 16x16 | 4 | `effects/effect_status_burn_*.png` | [ ] |
| 4 | Poison DOT | 16x16 | 4 | `effects/effect_status_poison_*.png` | [ ] |
| 5 | Shield | 16x16 | 2 | `effects/effect_status_shield_*.png` | [ ] |

**Estimated: ~48 effect frames**

---

## UI Icons (16x16 or 32x32)

### Tower Build Menu Icons

| # | Icon | Size | File | Status |
|---|------|------|------|--------|
| 1 | Rubber Bullet Turret | 32x32 | `ui/icon_tower_rubber_bullet.png` | [ ] |
| 2 | Tear Gas Launcher | 32x32 | `ui/icon_tower_tear_gas.png` | [ ] |
| 3 | Water Cannon | 32x32 | `ui/icon_tower_water_cannon.png` | [ ] |
| 4 | Taser Grid | 32x32 | `ui/icon_tower_taser_grid.png` | [ ] |
| 5 | Surveillance Hub | 32x32 | `ui/icon_tower_surveillance.png` | [ ] |
| 6 | Pepper Spray Emitter | 32x32 | `ui/icon_tower_pepper_spray.png` | [ ] |
| 7 | LRAD Cannon | 32x32 | `ui/icon_tower_lrad.png` | [ ] |
| 8 | Microwave Emitter | 32x32 | `ui/icon_tower_microwave.png` | [ ] |

### Damage Type Icons

| # | Icon | Size | File | Status |
|---|------|------|------|--------|
| 1 | Kinetic | 16x16 | `ui/icon_dmg_kinetic.png` | [ ] |
| 2 | Chemical | 16x16 | `ui/icon_dmg_chemical.png` | [ ] |
| 3 | Hydraulic | 16x16 | `ui/icon_dmg_hydraulic.png` | [ ] |
| 4 | Electric | 16x16 | `ui/icon_dmg_electric.png` | [ ] |
| 5 | Sonic | 16x16 | `ui/icon_dmg_sonic.png` | [ ] |
| 6 | Directed Energy | 16x16 | `ui/icon_dmg_energy.png` | [ ] |
| 7 | Cyber | 16x16 | `ui/icon_dmg_cyber.png` | [ ] |
| 8 | Psychological | 16x16 | `ui/icon_dmg_psychological.png` | [ ] |

### HUD Icons

| # | Icon | Size | File | Status |
|---|------|------|------|--------|
| 1 | Budget (currency) | 16x16 | `ui/icon_budget.png` | [ ] |
| 2 | Approval (lives) | 16x16 | `ui/icon_approval.png` | [ ] |
| 3 | Wave counter | 16x16 | `ui/icon_incident.png` | [ ] |
| 4 | Speed 1x | 16x16 | `ui/icon_speed_1x.png` | [ ] |
| 5 | Speed 2x | 16x16 | `ui/icon_speed_2x.png` | [ ] |
| 6 | Speed 3x | 16x16 | `ui/icon_speed_3x.png` | [ ] |
| 7 | Upgrade arrow | 16x16 | `ui/icon_upgrade.png` | [ ] |
| 8 | Sell | 16x16 | `ui/icon_sell.png` | [ ] |
| 9 | Lock (path locked) | 16x16 | `ui/icon_locked.png` | [ ] |

### Active Ability Icons

| # | Icon | Size | File | Status |
|---|------|------|------|--------|
| 1 | Airstrike | 32x32 | `ui/icon_ability_airstrike.png` | [ ] |
| 2 | Flash Freeze | 32x32 | `ui/icon_ability_freeze.png` | [ ] |
| 3 | Emergency Funding | 32x32 | `ui/icon_ability_funding.png` | [ ] |

**Estimated: ~28 UI icon sprites**

---

## Environment Props

| # | Prop | Size | File | Status |
|---|------|------|------|--------|
| 1 | Concrete barricade | 32x24 | `props/prop_barricade.png` | [ ] |
| 2 | Burnt vehicle | 48x32 | `props/prop_burnt_car.png` | [ ] |
| 3 | Floodlight | 16x32 | `props/prop_floodlight.png` | [ ] |
| 4 | Razor wire | 32x8 | `props/prop_razor_wire.png` | [ ] |
| 5 | Rubble pile (small) | 16x16 | `props/prop_rubble_small.png` | [ ] |
| 6 | Rubble pile (large) | 32x24 | `props/prop_rubble_large.png` | [ ] |
| 7 | Dumpster | 24x16 | `props/prop_dumpster.png` | [ ] |
| 8 | Street lamp (broken) | 8x32 | `props/prop_street_lamp.png` | [ ] |
| 9 | Protest signs (ground) | 16x8 | `props/prop_signs_ground.png` | [ ] |
| 10 | Traffic cone | 8x8 | `props/prop_traffic_cone.png` | [ ] |
| 11 | Burning barrel | 16x16 | `props/prop_burning_barrel.png` | [ ] |
| 12 | Sandbag wall | 32x16 | `props/prop_sandbags.png` | [ ] |

**Estimated: 12 prop sprites**

---

## Total Asset Count

| Category | Sprites | Frames (incl. animation) | Done |
|----------|---------|--------------------------|------|
| Golden standards | 5 | 5 | 4/5 |
| Tiles | 12 | 12 | 0/12 (1 needs ratio fix) |
| Towers (base) | 16 | 16 | 4/16 idle (need active + 4 more) |
| Towers (tier 5) | 8 | 8 | 0/8 |
| Standard enemies | 16 | 256 | 15/16 SE frame 1 |
| Boss enemies | 5 | 60 | 0/5 |
| Projectiles | 8 | 8 | 1/8 |
| Effects | 13 | 48 | 1/13 (frame 1 only) |
| UI icons | 28 | 28 | 0/28 |
| Props | 12 | 12 | 0/12 |
| **TOTAL** | **~123 unique assets** | **~453 total frames** | **~25 files exist** |
