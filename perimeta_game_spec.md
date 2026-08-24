# PERIMETA — Game Design Document & Technical Architecture Specification

**Project Name:** Perimeta
**Genre:** Minimalist Incremental Tower Defense / Roguelite Meta-Progression
**Engine:** Godot Engine 4.x (Standard 64-bit / GDScript)
**Target Platform:** PC (Windows / Linux / Steam) & Web (HTML5 / WASM)
**Inspired By:** Outhold (Steam / Tellus Games)
**Document Version:** 1.0.0

---

## 1. Executive Summary & Vision

### 1.1 High Concept
Perimeta is a fast-paced, strategic incremental tower defense game blending tight perimeter defense mechanics with a deep, fully-refundable meta-progression skill tree. Players defend a central core against increasingly intense geometric swarms by placing specialized towers, unleashing active cursor abilities (e.g., Coin Gun), and continuously tuning dynamic stat multipliers between runs.

### 1.2 Core Pillars
1. **Mathematical Synergies over Complexity:** Clean geometric visual primitives paired with deep mathematical interactions (status effects, critical chains, exponential scaling).
2. **Frictionless Experimentation:** 100% free respecs on the meta-progression DAG (Directed Acyclic Graph) tree to encourage distinct min/max builds.
3. **Hybrid Gameplay:** Semi-automated strategic tower placement combined with high-impact active player cursor intervention.
4. **Lightweight & Snappy:** Instant boot times, native 2D 120+ FPS rendering, zero asset bloat.

---

## 2. Technical Stack & Engine Configuration

* **Game Engine:** Godot 4.3+ (GDScript Standard Build)
* **Rendering Pipeline:** Compatibility / Forward+ (Native 2D Canvas)
* **Target Viewport:** `1920 x 1080` (Base)
  * Stretch Mode: `canvas_items`
  * Stretch Aspect: `expand`
* **Default Clear Color:** `#0C0D12` (Deep Void Black)
* **Audio Engine:** Godot AudioServer with separate buses (`Master`, `BGM`, `SFX`, `UI`)

---

## 3. Project Directory Architecture

```text
res://
├── assets/
│   ├── audio/
│   │   ├── music/               # Ambient electronic & synth tracks
│   │   └── sfx/                 # Hit impacts, laser pulses, perk clicks
│   ├── fonts/                   # Clean geometric sans-serif fonts
│   └── shaders/                 # Dynamic glow, CRT vignette, neon outlines
├── resources/
│   ├── enemies/                 # Custom Resource (.tres) definitions for enemy types
│   ├── towers/                  # Base stats, projectile types, upgrade paths
│   ├── upgrades/                # Meta-tree perk node definitions
│   └── waves/                   # Wave distribution curves & configurations
├── scenes/
│   ├── combat/
│   │   ├── Arena.tscn           # Main combat board with Path2D waypoints
│   │   ├── CoreBase.tscn        # Central defensive objective
│   │   └── WaveSpawner.tscn     # Wave timeline controller
│   ├── enemies/
│   │   ├── EnemyBase.tscn       # PathFollow2D base entity
│   │   └── variants/            # Swarm, Tank, Speed, Boss archetypes
│   ├── towers/
│   │   ├── TowerBase.tscn       # Base turret with range detection
│   │   └── variants/            # Pulse, Laser, Slow, Chain, Mortar
│   ├── projectiles/             # Bullet, missile, chain bolt instances
│   └── ui/
│       ├── HUD.tscn             # Health, currency, active wave display
│       ├── SkillTree.tscn       # Draggable node-based perk interface
│       ├── BuildMenu.tscn       # In-run placement selector
│       └── GameOverModal.tscn   # Run summary and currency award
└── scripts/
    ├── autoload/
    │   ├── GlobalState.gd       # Run stats, player inventory, persistent currency
    │   ├── EventBus.gd          # Decoupled global signal dispatcher
    │   └── SaveManager.gd       # Persistent JSON / ConfigFile save/load
    └── core/
        ├── CombatResolver.gd    # Damage formulas, armor mitigation, critical hits
        ├── StatModifier.gd      # Additive and multiplicative perk calculation
        └── WaveCurve.gd         # Mathematical scaling for enemy HP / count