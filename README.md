# Coberto's Server Resource Pack

Optional textures for TheCoberto's Paper plugins: Beverages, Skeleton Variants and Mystical Slots. Players are offered it when they join the server; saying no is fine, the items just keep their vanilla look.

- **Java** (`CobertoServerPack.zip`): drinks, the Mug, the Demolition Bow and Bow of Levitation (with draw animation), Explosive and Levitation Arrows, the Creeper Bomb, Candy Booties, and the Soda Vending Machine, Beverage Fountain and Slot Machine items. For Minecraft 1.21.4 and newer (made on 26.3).
- **Bedrock through Geyser** (`CobertoServerPack.mcpack` + `coberto_items.json`): drinks and the Mug.

Download the files from [Releases](../../releases).

## How it works

Each plugin gives its items a custom model data number. The pack picks a texture for those numbers and uses the normal vanilla model for everything else, so the plugins work the same with or without it.

| Number | Item | Base item |
| --- | --- | --- |
| 4101-4118 | Drinks (Beverages' drink order) | Potion |
| 4201 | Mug | Bowl |
| 4202 | Soda Vending Machine | Iron Block |
| 4203 | Beverage Fountain | Quartz Pillar |
| 4301, 4302 | Demolition Bow, Bow of Levitation | Bow |
| 4311, 4312 | Explosive Arrow, Levitation Arrow | Arrow |
| 4321 | Creeper Bomb | Snowball |
| 4331 | Candy Booties | Leather Boots |
| 4401 | Slot Machine | Red Glazed Terracotta |

Placed machines and slot machines keep the look of their block: a resource pack can't change one placed block without changing every block of that type.

## Server setup

- `server.properties`: `resource-pack=<the release's zip URL>`, `resource-pack-sha1=<sha1 from the release>`, `require-resource-pack=false`.
- Geyser: put the `.mcpack` in `plugins/Geyser-Spigot/packs` and `coberto_items.json` in `plugins/Geyser-Spigot/custom_mappings`, then restart.

## Building

`build.ps1` builds everything into `dist\` from the textures in the Bedrock add-on repos (expected at `..\..\Minecraft Bedrock\`) and prints the zip's SHA-1.

## Face Moon

`FaceMoonPack.zip` (Java) and `FaceMoonPack.mcpack` (Bedrock) turn every moon phase into TheCoberto's face, blended into a cratered moon. They aren't set in `server.properties` or Geyser's packs folder: CobertoUtilities (`/facemoon`) sends them on the nights it picks. Built by `moon.ps1` from `sources/sky-face.png`.
