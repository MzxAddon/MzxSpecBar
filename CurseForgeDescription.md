# MzxSpecBar

**MzxSpecBar** restores your action bars exactly the way you arranged them — per class, per specialization, per hero talent tree. Save a layout once, and it comes back the next time you log in.

MzxSpecBar is a small, self-contained addon for World of Warcraft Retail (Midnight, Interface 120105). It does one job, and it does it predictably: it never creates, edits or deletes your spells, items or macros without telling you first, and it never wipes your bars and leaves them empty.

## Features

- **Per class, per specialization, per hero talent tree.** Each saved layout is keyed to your class, your current specialization and your active hero talent tree, so every spec keeps its own arrangement.
- **One-click save and apply.** `Save current specialization` takes a snapshot of all 180 action slots plus the pet bar; `Apply current specialization` puts them back.
- **Restores macros as well.** Macros are saved with their content and matched by content on restore. If a macro does not exist on the target character yet, it is created before the bars are arranged — character macros as character macros, general macros as general macros. A macro that already exists with the same content is reused, never duplicated, and existing macros are never edited or overwritten.
- **Honest, itemized reports.** Every restore tells you exactly how many slots were applied and why the remaining ones were skipped: unavailable spell, unavailable item, macro not placed, or a placement that failed verification. The chat frame lists each skipped slot with its slot number, action name, type and id.
- **Optional auto-apply on login.** Per character, you can let MzxSpecBar restore your layout automatically a moment after you log in. Characters that opt out keep their manual-only behaviour.
- **Talent switcher on the minimap.** Right-click the minimap button to open Blizzard's own specialization list: every talent tree, with the specialization configurations Blizzard keeps for it underneath. Picking a configuration switches to that tree, loads that configuration and then arranges your action bars. The names and the list are Blizzard's own, nothing is invented by the addon.
- **Verifies before it touches anything.** If none of the saved actions are available on the current character, MzxSpecBar gives up instead of clearing your bars. The pre-flight check runs before a single slot is touched.
- **Minimal, consistent UI.** A small minimap button and a flat, dark options window that look the same as the other Mzx addons.

## Usage

1. Open the options window with `/msb` or `/mzxspecbar`, or click the minimap button.
2. Arrange your action bars and pet bar however you like.
3. Press **Save current specialization**. The layout is stored for your current class, specialization and hero talent tree.
4. Press **Apply current specialization** to restore it at any time, or enable **Apply automatically** to have it restored shortly after you log in.
5. Right-click the minimap button to switch talents: pick a specialization configuration from the list, and the bars for the specialization you land on are arranged right after the switch.

To store a layout for a different specialization, switch to that specialization first and save again. Saving and applying never change your specialization or your talents — only the minimap talent switcher does, and only because you clicked a configuration.

## Slash commands

| Command | Description |
| --- | --- |
| `/msb` | Toggle the options window (alias: `/mzxspecbar`) |
| `/msb help` | Show the available commands |
| `/msb list` | List the saved layouts |
| `/msb on <key>` | Enable a module (`actionbars`) |
| `/msb off <key>` | Disable a module (`actionbars`) |

## Limitations

- Retail only (Interface 120105). No Classic, Anniversary or other client versions are supported.
- Characters below level 10 do not participate.
- A layout is stored for the specialization and hero talent tree that were active while saving. Switching specialization or hero talent tree means saving again — there is no "save every specialization" action, and the addon never touches your talents while saving or applying.
- The minimap talent switcher lists Blizzard's specialization configurations only. Blizzard's built-in starter configuration (the "entry talent configuration" entry in the talent panel) is not listed, so it can never be selected by accident.
- Equipment set buttons (`equipmentset` / `equipmacro`) and the built-in pet bar controls (Attack, Follow, Stay, Defensive, Passive) are not saved.
- Spells, items and macros that do not exist on the target character cannot be restored. They are reported one by one instead of failing silently.
- Macros are restored by content: a macro with different content but the same name is left untouched, and a new macro is created only when no macro with the same content exists.
- Action bars cannot be changed in combat, so saving and applying are refused while you are in combat.
- Applying a layout overwrites your current bars. MzxSpecBar does not keep a backup of the arrangement it replaces.

## Localization

- English (United States / United Kingdom)
- Deutsch
- Español (España / Latinoamérica)
- Français
- Italiano
- Português (Brasil)
- Русский
- 简体中文
- 繁體中文
- 한국어

The language follows your client automatically out of the box, and can be changed at any time on the **Language** tab of the options window.
