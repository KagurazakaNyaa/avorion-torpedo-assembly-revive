# Maintenance Notes

## Avorion API audit baseline

- Audited against local shipped docs: `~/.local/share/Steam/steamapps/common/Avorion/Documentation/`.
- The shipped `index.html` explicitly says the generated API docs are **not necessarily complete**.
- For this mod, most core engine APIs in `Player`, `Entity`, `Plan`, `TorpedoLauncher`, callbacks, and UI classes are documented there.
- The main maintenance risk is the mod's dependency on **shipped Lua helper libraries** and a few **special helper surfaces** that are available in the game install but do **not** appear as standalone entries in the generated HTML documentation.

## Undocumented or under-documented APIs used by this mod

### 1. Shipped helper modules loaded with `include(...)`

These helpers exist in Avorion's shipped Lua sources, but their functions/tables are not indexed in the HTML API docs.

| Mod usage | Where used in this repo | Shipped source of truth | Notes |
| --- | --- | --- | --- |
| `include("utility")` | `data/scripts/lib/torpedo_assembly.lua:11` | `.../Avorion/data/scripts/lib/utility.lua` | Provides math/helper functions used directly by the mod. |
| `include("callable")` | `data/scripts/lib/torpedo_assembly.lua:12` | `.../Avorion/data/scripts/lib/callable.lua` | Provides RPC registration helpers for client/server command functions. |
| `include("damagetypeutility")` | `data/scripts/lib/torpedo_assembly.lua:13` | `.../Avorion/data/scripts/lib/damagetypeutility.lua` | Provides display helpers for damage types. |
| `include("torpedoutility")` | `data/scripts/lib/torpedo_assembly.lua:17` | `.../Avorion/data/scripts/lib/torpedoutility.lua` | Provides torpedo body/warhead enums and lookup tables. |
| `include("torpedogenerator")` | `data/scripts/lib/torpedo_assembly.lua:18` | `.../Avorion/data/scripts/lib/torpedogenerator.lua` | Provides torpedo generation logic used to build preview/production designs. |
| `include("buildingknowledgeutility")` | `data/scripts/lib/torpedo_assembly.lua:19` | `.../Avorion/data/scripts/lib/buildingknowledgeutility.lua` | Provides building knowledge checks used to gate options by material progression. |
| `include("galaxy")` as `Balancing` | `data/scripts/lib/torpedo_assembly.lua:16` | `.../Avorion/data/scripts/lib/galaxy.lua` | Exposes balancing helpers such as `GetTechLevel`, but not via the HTML reference. |

### 2. Specific undocumented helper functions/tables this mod relies on

#### `callable(namespace, func)`

- Mod dependency: `data/scripts/lib/torpedo_assembly.lua:12`
- Vanilla definition: `.../data/scripts/lib/callable.lua:4`
- Used throughout the command layer, for example:
  - `data/scripts/lib/torpedo_assembly.lua:1482`
  - `data/scripts/lib/torpedo_assembly.lua:1490`
- Why it matters: this is the glue that makes the mod's `invokeServerFunction(...)` command handlers callable from the client. If Boxelware changes `callable.lua`, the networking layer of this mod is a likely break point.

#### `lerp(...)` and `round(...)`

- Mod dependency: `data/scripts/lib/torpedo_assembly.lua:11`
- Vanilla definitions:
  - `.../data/scripts/lib/utility.lua:4` (`lerp`)
  - `.../data/scripts/lib/utility.lua:63` (`round`)
- Used in this mod at:
  - `data/scripts/lib/torpedo_assembly.lua:731-740`
  - `data/scripts/lib/torpedo_assembly.lua:1522`
- Why it matters: production cost scaling and fallback tech-distance conversion both depend on these helpers.

#### `getDamageTypeName(...)` and `getDamageTypeColor(...)`

- Mod dependency: `data/scripts/lib/torpedo_assembly.lua:13`
- Vanilla definitions:
  - `.../data/scripts/lib/damagetypeutility.lua:6`
  - `.../data/scripts/lib/damagetypeutility.lua:16`
- Used in this mod at:
  - `data/scripts/lib/torpedo_assembly.lua:805-806`
- Why it matters: the torpedo stat UI depends on these helpers for localized damage labels and colors.

#### `KnowledgeUtility.hasKnowledge(player, material)`

- Mod dependency: `data/scripts/lib/torpedo_assembly.lua:19`
- Vanilla definition: `.../data/scripts/lib/buildingknowledgeutility.lua:63`
- Used in this mod at:
  - `data/scripts/lib/torpedo_assembly.lua:720-722`
  - `data/scripts/lib/torpedo_assembly.lua:766-795`
- Why it matters: this is the progression gate that decides which torpedo rarities, bodies, and warheads the player can use.

#### `TorpedoUtility.BodyType`, `TorpedoUtility.WarheadType`, `TorpedoUtility.Bodies`, `TorpedoUtility.Warheads`

- Mod dependency: `data/scripts/lib/torpedo_assembly.lua:17,20-23`
- Vanilla definitions in `.../data/scripts/lib/torpedoutility.lua`:
  - `BodyType`: line 7
  - `WarheadType`: line 21
  - `Bodies`: line 36
  - `Warheads`: line 47
- Why it matters: the mod hardcodes costs and UI choices against these tables. If Avorion renames, reorders, or expands torpedo definitions, this mod may silently desync from vanilla torpedo data.

#### `TorpedoGenerator():generate(...)`

- Mod dependency: `data/scripts/lib/torpedo_assembly.lua:1528`
- Vanilla implementation: `.../data/scripts/lib/torpedogenerator.lua:101-175`
- Why it matters: torpedo preview generation and the produced torpedo template both come from this helper. Any generator output change can affect UI stats, costs, and storage behavior.

#### `Balancing.GetTechLevel(x, y)`

- Mod usage: `data/scripts/lib/torpedo_assembly.lua:1497`
- Vanilla export table: `.../data/scripts/lib/galaxy.lua:437-461`
- Underlying function: `.../data/scripts/lib/galaxy.lua:108-117` (`Balancing_GetTechLevel`)
- Why it matters: this is the mod's first-choice way to infer torpedo tech level from sector coordinates. It is shipped in vanilla scripts, but not surfaced in the generated HTML docs.

#### Additional balancing helpers used indirectly through `torpedogenerator.lua`

These are not called by the mod directly, but the mod depends on them through `TorpedoGenerator():generate(...)`:

- `Balancing_GetMaxCoordinates` — `.../data/scripts/lib/torpedogenerator.lua:36`
- `Balancing_GetSectorWeaponDPS` — `.../data/scripts/lib/torpedogenerator.lua:107`
- `Balancing_GetSectorTurretsUnrounded` — `.../data/scripts/lib/torpedogenerator.lua:108`

If Avorion changes balancing math, torpedo output can shift even when this mod's own code stays unchanged.

### 3. Under-documented special runtime surface

#### `callingPlayer`

- Used in this mod at:
  - `data/scripts/lib/torpedo_assembly.lua:472`
  - `data/scripts/lib/torpedo_assembly.lua:479`
- This variable is mentioned in the generated docs inside the description of `invokeServerFunction(...)`, but it is not a standalone API page/object.
- Why it matters: ownership and payment resolution on the server side depends on this variable being set correctly during client→server RPC calls.

## Confirmed documented APIs that are **not** part of the gap list

To keep future maintenance focused, the following important surfaces are present in the shipped HTML docs and were intentionally excluded from the undocumented list:

- `Player():addScriptOnce(...)`
- `player:registerCallback(...)`
- Player callbacks `onShipChanged(...)` and `onMaxBuildableMaterialChanged(...)`
- `Client().unpausedRuntime` / `Server().unpausedRuntime`
- `valid(...)`
- `Player` properties such as `craftIndex`, `craftFaction`, `allianceIndex`, `maxBuildableMaterial`, and `infiniteResources`
- `TorpedoLauncher` properties/functions such as `freeStorage`, `occupiedStorage`, `getShafts()`, `getNumTorpedoes()`, and `getMaxTorpedoes()`
- `TorpedoTemplate` properties used for stat display
- UI classes such as `ShipWindow`, `UIVerticalLister`, `UIVerticalMultiSplitter`, and `UIHorizontalMultiSplitter`

## Upgrade checklist

When updating to a new Avorion version, diff these vanilla files first:

1. `data/scripts/lib/callable.lua`
2. `data/scripts/lib/utility.lua`
3. `data/scripts/lib/damagetypeutility.lua`
4. `data/scripts/lib/buildingknowledgeutility.lua`
5. `data/scripts/lib/torpedoutility.lua`
6. `data/scripts/lib/torpedogenerator.lua`
7. `data/scripts/lib/galaxy.lua`

If the mod breaks after a game update, check these behaviors before touching the rest of the code:

1. RPC registration via `callable(...)`
2. Knowledge gating via `KnowledgeUtility.hasKnowledge(...)`
3. Torpedo generation output from `TorpedoGenerator():generate(...)`
4. Tech-level calculation via `Balancing.GetTechLevel(...)`
5. Cost math helpers `lerp(...)` / `round(...)`
