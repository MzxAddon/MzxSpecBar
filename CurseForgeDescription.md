# MzxSpecBar

**MzxSpecBar** restores your action bars exactly the way you arranged them — per class, per specialization, per hero talent tree. Save a layout once and it comes back whenever you return to that setup.

MzxSpecBar is a small, self-contained World of Warcraft addon. It does one job and it does it predictably: it tells you exactly what it did, and it never leaves your bars empty.

## Features

- **Per class, per specialization, per hero talent tree.** Every saved layout is keyed to your class, your current specialization and your active hero talent tree, so each setup keeps its own arrangement.
- **One-click save and apply.** Saving stores every action slot and the pet bar in one step; applying puts them back.
- **Spells, items and macros.** Macros are saved with their content and matched by content on restore: an existing macro with the same content is reused, never duplicated, and existing macros are never edited or overwritten. A macro the target character does not have yet is created before the bars are arranged — as a character macro or a general macro, depending on how it was saved.
- **Honest, itemized reports.** Every restore tells you how many slots were applied and why the others were skipped: spell unavailable, item unavailable, macro not placed, or a placement that failed verification. The chat frame lists each skipped slot with its slot number, action name, type and id.
- **Optional auto-apply on login.** Per character, you can let MzxSpecBar restore your layout shortly after you log in. Characters that opt out stay manual.
- **Blizzard talent switcher on the minimap button.** Right-click the minimap button to see Blizzard's talent trees, each with the specialization configurations Blizzard keeps for it. Picking a configuration switches to that tree, loads that configuration and then arranges your action bars. Every name in that list comes from Blizzard; only Blizzard's own saved configurations are offered, so the game's built-in starter configuration can never be picked by accident.
- **Applying a saved layout switches specialization first.** Clicking a saved layout moves to the specialization it belongs to and only then arranges the bars, instead of asking you to switch by hand.
- **Verifies before it touches anything.** If none of the saved actions exist on the current character, MzxSpecBar gives up instead of clearing your bars. The check runs before a single slot is touched.
- **A UI that matches the rest of the Mzx family.** One minimap button and one flat, dark options window, styled the same way as the other Mzx addons.

## Usage

1. Open the options window from the minimap button or with the slash command listed below.
2. Arrange your action bars and pet bar however you like.
3. Press the save button. The layout is stored for your current class, specialization and hero talent tree.
4. Press the apply button to restore it at any time, or enable automatic applying to have it restored shortly after you log in.
5. Right-click the minimap button to switch talents: pick a specialization configuration and your bars are arranged right after the switch.

Saving and applying never change your specialization or your talents. Only the minimap talent switcher does, and only because you picked a configuration. To store a layout for a different specialization, switch to that specialization first and save again.

## Slash commands

| Command | Description |
| --- | --- |
| `/msb` | Toggle the options window (alias: `/mzxspecbar`) |
| `/msb help` | Show the full list of available commands |
| `/msb list` | List your saved layouts |
| `/msb on <module>` | Enable an addon module |
| `/msb off <module>` | Disable an addon module |

## Limitations

- World of Warcraft Retail only. Other game versions are not supported.
- A layout belongs to the specialization and hero talent tree that were active when it was saved, so switching either one means saving again. There is no "save every specialization at once" action.
- Very new characters cannot store a layout yet.
- Actions the game does not expose as restorable slots — equipment set buttons and the built-in pet bar controls, for example — are not part of a layout.
- Spells, items and macros that do not exist on the target character cannot be restored. They are reported one by one instead of failing silently.
- Macros are matched by content: a macro with different content but the same name is left untouched, and a new macro is created only when no macro with the same content exists.
- Action bars cannot be changed in combat, so saving and applying are refused while you are in combat.
- Applying a layout overwrites your current bars. MzxSpecBar does not keep a backup of the arrangement it replaces.

## Localization

The language follows your client automatically and can be changed at any time on the **Language** tab of the options window, where the full list is shown. Shipped translations include English, Deutsch, Español, Français, Italiano, Português, Русский, 简体中文, 繁體中文 and 한국어.