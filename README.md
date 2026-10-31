# Chicanery

*dont be a fool, be a tool*

A 2D top-down RPG prototype built with **Godot 4.7** (Forward Plus renderer), where the player character **AE** bumps into enemies to trigger a turn-based battle and defeats them.

> Status: early prototype. Scenes under `scenes/test/` are test content, and some menu options (e.g. ARTICLE) are not implemented yet.

## Getting started

1. Install [Godot 4.7](https://godotengine.org/download) (the project is configured for 4.7).
2. Clone this repository.
3. Open Godot, click **Import**, and select `project.godot`.
4. Press **F5** (Run Project) to start from the configured main scene.

## Controls

### Overworld

| Action | Keys |
| --- | --- |
| Move | `W` `A` `S` `D` or arrow keys |
| Sprint | `Shift` |
| Interact | `Z` |

### Battle

| Action | Keys |
| --- | --- |
| Move selection | `Up` / `Down` |
| Confirm / dismiss text | `Enter` (`ui_accept`) |

## Main features

### Exploration
- Player movement driven by a node-based state machine (idle / walk) in `scripts/node_state_machine/`.
- NPCs (e.g. Anfugel, Lignolus) and scene transitions between test locations (outside the player's house, first and second floor).
- Touching an enemy in the overworld starts a battle. Enemies you defeat stay defeated when you return (tracked by position in the `State` autoload).

### Turn-based battle (`scenes/test/battle/battle.gd`)
- **Turn order** is decided by ERL (higher goes first); ties are broken with d30 rolls.
- **Player actions**
  - **ASSAULT**: basic attack. Damage is `(VHM + EB) * EM * pi_ACM` with a ±5% random variance.
  - **EXERT**: opens the exertion submenu:
    - **FORBEAR**: skip your turn.
    - **FORSAKE**: TBC
    - **FORDOOM**: drop your own WN to 0.
  - **BRACE**: applies the *Bracing* condition, roughly halving the next incoming exertion hit.
  - **ARTICLE**: placeholder, not yet implemented.
- **Enemy exertions** are chosen at random from each enemy's list:
  - **ROCK** applies *Constricted* (hides your menu and the enemy acts again). It can't be used twice in a row.
  - **PINK** / **RIVE** deal direct damage.
  - **PROJECT** deals reduced damage, applies *Conflagrant* (burn damage each turn), and is locked from reuse for a few turns.
- **Status conditions** (Bracing, Constricted, Conflagrant) show as icons and labels on the player panel and tick down each turn.
- Floating damage numbers appear over the player when hit.
- **WN** is the health stat. Reach 0 and you're "slimed out" and sent back to the first-floor scene with full WN.

## Project layout

| Path | Contents |
| --- | --- |
| `scenes/characters/` | Player (AE) and NPC scenes and scripts |
| `scenes/test/act1/` | Overworld test scenes (house, outside area) |
| `scenes/test/battle/` | Battle scene and logic |
| `scenes/test/transition/` | Scene transition nodes |
| `scripts/stats/` | `State` (global player/battle state), `BaseEnemy`, `BaseAlly`, `StatusEffect` autoload/resources |
| `scripts/res/enemies/` | Enemy resources (`.tres`) |
| `scripts/res/conditions/` | Status effect resources (`.tres`) |
| `scripts/node_state_machine/` | Generic node-based state machine |
| `uxui/font/` | Fonts (Almendra, Cinzel, EB Garamond) |

## Adding a new enemy

1. Create an enemy resource in `scripts/res/enemies/` (see `anfugel.tres` / `lignolus.tres`) with its WN, VHM, ERL, texture and exertion list.
2. Register its ID in `_resolve_enemy_resource_for_id()` in `battle.gd`.
3. Place the enemy in an overworld scene so contact sets `State.active_enemy_id` and starts the battle.
