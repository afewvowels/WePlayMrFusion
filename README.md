# WePlay: Mr. Fusion

![Mr. Fusion thumbnail](thumbnail.png)

> *"Roads? Where we're going, we don't need roads."*

**Mr. Fusion** is a piece of personal equipment for [Factorio](https://factorio.com) 2.1, inspired by the home fusion reactor from *Back to the Future*. Slot it into your armor's equipment grid and it eats junk out of your logistic trash slots (and, optionally, items you pick from your main inventory) and turns it into power for the batteries in your grid.

Banana peels, spare gears, coal, the pipes you keep picking up by accident: into the hopper they go.

---

## Features

- **Burns your trash.** Anything that lands in your logistic trash slots gets fed into the reactor. Set item maximums in the logistics tab, and the overflow becomes power.
- **Optional inventory filter.** Pick up to 20 item types that Mr. Fusion should also burn straight from your main inventory.
- **Real fuel counts.** Items with a fuel value (coal, wood, solid fuel, rocket fuel, nuclear fuel…) give their actual fuel value, scaled by a configurable efficiency multiplier.
- **Junk still counts.** Items that aren't fuel give a flat, configurable amount of energy (200 kJ by default).
- **Nothing is wasted.** If one item gives more energy than your batteries can hold, the remainder is saved and paid out over the next few seconds before anything else is burned. Your 1.21 GJ nuclear fuel doesn't vanish into a half-empty battery.
- **Safe with items that carry data.** Armor with equipment inside, blueprints, items with their own inventories and so on are never burned.
- **Stacks.** Each Mr. Fusion in the grid adds to the burn rate.
- **Multiplayer friendly.** Filters and settings are stored per player.

---

## Getting started

1. Research **Modular armor**. The Mr. Fusion recipe unlocks with it. (If another mod removes that technology, the recipe is enabled from the start.)
2. Craft a Mr. Fusion:

   | Ingredient | Amount |
   |---|---|
   | Stone furnace | 1 |
   | Iron plate | 10 |
   | Electronic circuit | 5 |

   Crafting time: 5 seconds.
3. Put it in your armor grid (it's a **1×2** tile) **along with at least one battery**. Mr. Fusion doesn't store any energy itself; it fills the batteries around it.
4. Set some trash-slot limits in the logistics tab, or open the filter window from the shortcut bar and pick items to burn.

---

## In-game settings

All settings are **map settings** (runtime-global), so they can be changed mid-game.

| Setting | Default | Range | What it does |
|---|---|---|---|
| Items burned per second (per Mr. Fusion) | `2` | 1–100 | How many items each Mr. Fusion can burn every second. |
| Fuel efficiency | `1.0` | 0–10 | Multiplier on an item's fuel value. At `1.0`, one coal gives 4 MJ. |
| Energy from non-fuel items (kJ) | `200` | 0–1,000,000 | Energy given by items that aren't fuel. |

**Rough numbers at default settings, per Mr. Fusion:**

| Feeding it… | Energy per item | Power |
|---|---|---|
| Junk (gears, pipes, stone…) | 200 kJ | ~400 kW |
| Coal | 4 MJ | ~8 MW |
| Solid fuel | 12 MJ | ~24 MW |

---

## How it works

The mod is three small Lua files plus a locale file:

```
WePlayMrFusion/
├── info.json            -- mod metadata (Factorio 2.1, depends on base >= 2.1)
├── settings.lua         -- the three map settings
├── data.lua             -- equipment, item, recipe, shortcut, tech unlock
├── control.lua          -- burning logic and the filter GUI
├── locale/en/locale.cfg -- English strings
└── graphics/            -- equipment sprite and icon
```

### `data.lua`: the prototypes

**The equipment is a battery that holds nothing.** Mr. Fusion is defined as a `battery-equipment` with `buffer_capacity = "0J"` and zero input/output flow. That gives it a legal place in the armor grid without letting the game charge or drain it. All the real work happens in `control.lua`, which writes energy directly into the *other* batteries in the grid.

Other details:

- The grid shape is **1×2** so the tall reactor sprite (128×256 at 0.5 scale) fits without squishing.
- The item borrows the vanilla battery's item subgroup so it sorts next to the other energy equipment in the crafting menu.
- A `shortcut` prototype with `action = "lua"` adds a button to the shortcut bar that opens the filter GUI.
- The recipe is added to the `modular-armor` technology's effects. If that technology doesn't exist, the recipe is simply enabled.

### `control.lua`: the burn loop

Everything runs in a single `script.on_nth_tick(60, …)` handler, so once per second. For every connected player:

1. **Find the grid.** `get_grid()` checks that the player has a valid character and is wearing armor with an equipment grid.
2. **Scan it.** `scan()` walks the grid once and returns:
   - how many Mr. Fusions are installed,
   - a list of every *other* `battery-equipment` that still has room (modded batteries included),
   - the total free space across those batteries.

   If there are no Mr. Fusions, or every battery is full, the player is skipped and nothing is burned.
3. **Pay out the carry first.** Each player keeps a `carry` value: energy from the last burned item that didn't fit. `deposit()` pours as much of it as possible into the batteries. If any carry is left over, nothing new is burned this second.
4. **Work out the budget.** `budget = items_per_second × number_of_fusions`.
5. **Burn from trash** (if *Burn trash slots* is on). Each plain stack in `character_trash` is eaten one item at a time.
6. **Burn from the filter list** (if there's budget left). Same thing, but only for stacks in `character_main` whose name is on the player's filter list.

#### Burning one item

`burn_from()` takes one item off a stack, looks up its value, and deposits it straight away:

```lua
while budget > 0 and d.carry <= 0 and stack.valid_for_read and wanted(stack) do
  local value = value_of(stack.name)
  -- remove one item from the stack
  budget = budget - 1
  d.carry = deposit(batteries, value)
end
```

It stops as soon as the budget runs out **or** an item produced more energy than the batteries could take. That's what stops it from burning a whole stack of rocket fuel into a nearly-full battery: the leftover goes into `carry` and gets paid out over the next ticks before anything else is touched.

#### How much energy an item is worth

`value_of()` checks the item prototype:

- `fuel_value > 0` → `fuel_value × fuel efficiency`
- otherwise → `junk energy setting × 1000` (the setting is in kJ, energy is in joules)

#### What never gets burned

`is_plain()` returns true only when `stack.item_number == nil`. Items with an item number carry their own data (armor with a grid, blueprints and blueprint books, items with inventories, and so on), so they're always skipped, even if they land in trash or are on the filter list.

### Per-player data

Stored in `storage.players[player_index]`:

| Field | Type | Meaning |
|---|---|---|
| `filters` | `{ [item_name] = true }` | Items to also burn from the main inventory |
| `use_trash` | `boolean` | Whether to burn from trash slots (default `true`) |
| `carry` | `number` (J) | Leftover energy waiting to be deposited |

Entries are created on demand by `pdata()` and removed in `on_player_removed`.

### The filter GUI

Clicking the **Mr. Fusion filters** shortcut toggles a small window in `player.gui.screen`:

- A **Burn trash slots** checkbox (`on_gui_checked_state_changed` → `use_trash`).
- A 10-wide grid of **20 item picker buttons** (`choose-elem-button`, `elem_type = "item"`), filled with the current filters in alphabetical order.

Whenever any picker changes (`on_gui_elem_changed`), the mod rebuilds the filter set from all 20 buttons, so clearing a slot removes that item and duplicates collapse on their own. The window is set as `player.opened`, so **E** or **Esc** closes it like any other game window (`on_gui_closed` destroys it).

---

## Notes and limitations

- **You need a battery.** With no battery room in the grid, Mr. Fusion sits idle and burns nothing.
- **It only fills batteries.** Power reaches your shields, exoskeletons and so on the normal way, by drawing from the grid's batteries.
- **Speed is in whole items per second.** Burning happens once a second, so the power comes in one-second pulses.
- **Carry belongs to the player, not the armor.** If you swap armor while energy is still in the carry, it gets paid into the new armor's batteries.
- **No limit on what you put on the filter list.** If you add iron plates, it will happily burn your iron plates. Choose wisely.

---

## Compatibility

- Factorio **2.1** (`base >= 2.1`). Works with or without Space Age.
- Should work with modded batteries, since it fills any `battery-equipment` in the grid.
- Should work with modded fuels, since it reads `fuel_value` from the item prototype.

---

## Credits

Made by **afewvowels**, part of the *WePlay* mod series.

*Mr. Fusion* and *Back to the Future* belong to their respective owners. This is a fan-made homage and isn't affiliated with or endorsed by them.
