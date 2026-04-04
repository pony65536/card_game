# Card Game Architecture

## Overview

This project follows a **four-layer architecture**:

Interaction Layer → Container Layer → Orchestrator Layer → Rule Layer

Goal: separate **user input, UI structure, game rules, and visual effects**.

---

## 1. Interaction Layer

### File: `card.gd`

**Responsibility**

- Render a single card
- Handle mouse input (drag, release, hover)
- Emit user intent signals

**Should Do**

- Visual updates
- Dragging logic
- Emit signals:
    - `play_requested(card)`
    - `drag_started(card)`
    - `drag_canceled(card)`

**Should NOT Do**

- Validate game rules
- Modify game state
- Call `BattleSystem`
- Destroy itself directly

**Role**

> Input collector

---

## 2. Container Layer

### File: `hand.gd`

**Responsibility**

- Manage all hand cards
- Layout cards dynamically
- Connect signals of dynamically created cards
- Forward events upward

**Core Features**

- Instantiate cards
- Maintain `cards` array
- Update layout (fan, overlap, curve)
- Translate card-level events → hand-level events

**Signals**

- `card_play_requested(card, card_data)`
- `card_selected(card)`

**Key Principle**

> Dynamic nodes are managed and connected inside their container

**Role**

> UI container + event dispatcher

---

## 3. Orchestrator Layer

### File: `game.gd`

**Responsibility**

- Connect major systems
- Translate UI events into game commands
- Bridge UI and rule system

**Connects**

- `Hand`
- `BattleSystem`

**Does**

1. Receive UI intent (`card_play_requested`)
2. Convert to `BattleCommand`
3. Submit to `BattleSystem`
4. Handle success/failure
5. Handle animation events
6. Handle state updates

**Does NOT**

- Handle per-card signals
- Execute game rules directly

**Role**

> Central coordinator (orchestrator)

---

## 4. Rule Layer

### File: `battle_system.gd`

**Responsibility**

- Core game logic
- Command queue processing
- State management
- Atomic resolution
- Death checks
- Emit animation events

**Signals**

- `animation_events_ready(events)`
- `game_state_changed(new_state)`

**State Machine**

WAITING_INPUT → RESOLVING → WAITING_INPUT / GAME_OVER

**Pipeline**

BattleCommand → AtomicActions → Execution → AnimationEvents

---

## 4.1 Command Layer

### File: `battle_command.gd`

**Purpose**

- Standardized input format for all player actions

**Types**

- `PLAY_MINION`
- `PLAY_SPELL`
- `MINION_ATTACK`
- `HERO_ATTACK`
- `HERO_POWER`
- `END_TURN`

**Data**

- `type`
- `source`
- `target`
- `card_data`

**Role**

> High-level player intent

---

## 4.2 Atomic Layer

### File: `atomic_action.gd`

**Purpose**

- Smallest executable unit of game logic

**Types**

- `DEAL_DAMAGE`
- `RESTORE_HEALTH`
- `SUMMON_MINION`
- `DESTROY_MINION`
- `SPEND_MANA`
- `DRAW_CARD`
- `APPLY_BUFF`
- `TRIGGER_DEATHRATTLE`

**Role**

> Step-by-step execution primitives

---

## 4.3 Animation Event Layer

### File: `animation_event.gd`

**Purpose**

- Decouple logic from presentation

**Structure**

- `event_type`
- `params`

**Examples**

- `"take_damage"`
- `"heal"`
- `"summon_minion"`
- `"destroy_minion"`

**Role**

> Output instructions for UI layer

---

## 5. Data Layer

### File: `card_data.gd`

**Type**

- `Resource`

**Purpose**

- Static card definitions

**Fields**

- `card_name`
- `attack`
- `health`
- `cost`
- `portrait`

---

### File: `game_entity.gd`

**Purpose**

- Runtime entities in battle

**Fields**

- `id`
- `entity_name`
- `hp`
- `max_hp`
- `attack`
- `owner_id`

**Methods**

- `take_damage()`
- `heal()`
- `is_dead()`

---

## 6. Full Event Flow

Card (input)
↓
Hand (container / forwarding)
↓
Game (orchestrator)
↓
BattleSystem (rules)
↓
AnimationEvents
↓
Game / UI rendering

---

## 7. Design Principles

### 1. Separation of Concerns

- UI does not execute rules
- Rules do not control UI

### 2. Single Responsibility

- Each layer has one clear role

### 3. Data Flow Direction

- Input flows downward
- Results flow upward

### 4. Dynamic Node Ownership

- Containers manage their children’s signals

### 5. Deterministic Rule Execution

- All logic goes through command queue + atomic actions

---

## 8. Key Constraints

- No direct `BattleSystem` calls from `card.gd`
- No direct state mutation from UI layer
- No direct node manipulation inside rule layer
- All actions must go through `BattleCommand`

---

## 9. Summary

| Layer        | File                 | Role                |
| ------------ | -------------------- | ------------------- |
| Interaction  | `card.gd`            | Input handling      |
| Container    | `hand.gd`            | Card management     |
| Orchestrator | `game.gd`            | System coordination |
| Rules        | `battle_system.gd`   | Game logic          |
| Command      | `battle_command.gd`  | Player intent       |
| Atomic       | `atomic_action.gd`   | Execution steps     |
| Animation    | `animation_event.gd` | UI instructions     |
| Data         | `card_data.gd`       | Static card         |
| Entity       | `game_entity.gd`     | Runtime object      |

---

## Core Idea

> UI produces intent → System converts to commands → Rules resolve → UI reflects results
