<#
.SYNOPSIS
  Builds the server resource packs from the Bedrock add-ons' textures.

.DESCRIPTION
  Makes, in dist\:
    - CobertoServerPack.zip      Java resource pack (server.properties resource-pack)
    - CobertoServerPack.mcpack   Bedrock pack for Geyser (plugins\Geyser-Spigot\packs)
    - coberto_items.json         Geyser item mappings (plugins\Geyser-Spigot\custom_mappings)
  and prints the zip's SHA-1 for server.properties (resource-pack-sha1).

  The Paper plugins give each custom item a custom model data number. The Java pack
  shows that number's texture and falls back to the vanilla model for everything else,
  so the plugins work the same without the pack.

  Textures are copied from the Bedrock add-on repos next to this one's parent folder
  (..\..\Minecraft Bedrock\...), so the Java and Bedrock looks stay the same.
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$bedrock = Join-Path $root '..\..\Minecraft Bedrock' | Resolve-Path
$bev = Join-Path $bedrock "beverages-minecraft-bedrock\TheCoberto's Beverages\Beverages RP\textures"
$skel = Join-Path $bedrock "skeleton-variants\TheCoberto's Skeleton Variants\RP Skeleton Variants\textures"
$slots = Join-Path $bedrock "mystical-slots\TheCoberto's Mystical Slots\Mystical Slots RP\textures"

# ---------- What's in the pack ----------
# Item textures: name -> source png. Model numbers must match the Paper plugins.
$drinks = 'haste_potion', 'soda', 'apple_cider', 'iced_tea', 'coffee', 'sweet_berry_smoothie', 'hot_cocoa', 'glow_berry_juice'
# Beverages' Drink enum order: the 8 drinks, then Strong and Extended of the upgradable ones (same texture).
$drinkOrder = $drinks + @('haste_potion', 'haste_potion', 'soda', 'soda', 'apple_cider', 'apple_cider', 'iced_tea', 'iced_tea', 'coffee', 'coffee')
$drinkIds = $drinks + @('haste_potion_strong', 'haste_potion_long', 'soda_strong', 'soda_long', 'apple_cider_strong', 'apple_cider_long',
    'iced_tea_strong', 'iced_tea_long', 'coffee_strong', 'coffee_long')
$drinkNames = @{ haste_potion = 'Haste Potion'; soda = 'Soda'; apple_cider = 'Apple Cider'; iced_tea = 'Iced Tea'; coffee = 'Coffee'
    sweet_berry_smoothie = 'Sweet Berry Smoothie'; hot_cocoa = 'Hot Cocoa'; glow_berry_juice = 'Glow Berry Juice' }

$textures = [ordered]@{}
foreach ($d in $drinks) { $textures["item/$d"] = "$bev\items\$d.png" }
$textures['item/mug'] = "$bev\items\mug.png"
foreach ($b in 'explosive_bow', 'levitation_bow') {
    $textures["item/$b"] = "$skel\items\$b.png"
    foreach ($i in 0..2) { $textures["item/${b}_pulling_$i"] = "$skel\items\${b}_pulling_$i.png" }
}
$textures['item/explosive_arrow'] = "$skel\items\arrow\explosive_arrow.png"
$textures['item/levitation_arrow'] = "$skel\items\arrow\levitation_arrow.png"
$textures['item/creeper_bomb'] = "$skel\items\throwable\creeper_bomb.png"
$textures['item/candy_booties'] = "$skel\items\candy_booties.png"
foreach ($f in 'front', 'side', 'top') {
    $textures["block/vending_machine_$f"] = "$bev\blocks\vending_machine_$f.png"
    $textures["block/beverage_fountain_$f"] = "$bev\blocks\beverage_fountain_$f.png"
}
foreach ($f in 'front', 'side', 'top', 'bottom') { $textures["block/slot_machine_$f"] = "$slots\blocks\slot_machine_$f.png" }

# ---------- Helpers ----------
function Write-Json($path, $value) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
}
function Model($name) { @{ type = 'minecraft:model'; model = "coberto:$name" } }
# Picks a model by the item's custom model data; anything else gets the vanilla model.
function Dispatch($fallback, $entries) {
    $list = @($entries | ForEach-Object { @{ threshold = $_[0]; model = $_[1] } })
    # Range dispatch uses the highest threshold at or below the value, so numbers past ours (other
    # plugins' items) would get our last texture. This entry sends them back to vanilla.
    $list += @{ threshold = ($list | ForEach-Object threshold | Measure-Object -Maximum).Maximum + 1; model = $fallback }
    @{ model = @{
            type     = 'minecraft:range_dispatch'
            property = 'minecraft:custom_model_data'
            index    = 0
            fallback = $fallback
            entries  = $list
        }
    }
}
function Bow($name) {
    @{
        type     = 'minecraft:condition'
        property = 'minecraft:using_item'
        on_false = Model "item/$name"
        on_true  = @{
            type     = 'minecraft:range_dispatch'
            property = 'minecraft:use_duration'
            scale    = 0.05
            fallback = Model "item/${name}_pulling_0"
            entries  = @(@{ threshold = 0.65; model = Model "item/${name}_pulling_1" }, @{ threshold = 0.9; model = Model "item/${name}_pulling_2" })
        }
    }
}

# ---------- Java pack ----------
$out = Join-Path $root 'build\java'
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
$assets = Join-Path $out 'assets'

Write-Json "$out\pack.mcmeta" @{ pack = @{
        description       = "Coberto's server: drinks, bows and slot machines"
        min_format        = 46
        max_format        = 97
        pack_format       = 46
        supported_formats = @(46, 97)
    }
}
foreach ($t in $textures.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $t.Value)) { throw "Missing texture: $($t.Value)" }
    $dest = "$assets\coberto\textures\$($t.Key).png"
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item -LiteralPath $t.Value $dest
}

# Item models
foreach ($name in @($drinks) + 'mug', 'explosive_arrow', 'levitation_arrow', 'creeper_bomb', 'candy_booties') {
    Write-Json "$assets\coberto\models\item\$name.json" @{ parent = 'minecraft:item/generated'; textures = @{ layer0 = "coberto:item/$name" } }
}
foreach ($b in 'explosive_bow', 'levitation_bow') {
    foreach ($suffix in '', '_pulling_0', '_pulling_1', '_pulling_2') {
        Write-Json "$assets\coberto\models\item\$b$suffix.json" @{ parent = 'minecraft:item/bow'; textures = @{ layer0 = "coberto:item/$b$suffix" } }
    }
}
foreach ($m in 'vending_machine', 'beverage_fountain') {
    Write-Json "$assets\coberto\models\item\$m.json" @{ parent = 'minecraft:block/orientable'
        textures = @{ front = "coberto:block/${m}_front"; side = "coberto:block/${m}_side"; top = "coberto:block/${m}_top" } }
}
Write-Json "$assets\coberto\models\item\slot_machine.json" @{ parent = 'minecraft:block/orientable_with_bottom'
    textures = @{ front = 'coberto:block/slot_machine_front'; side = 'coberto:block/slot_machine_side'
        top = 'coberto:block/slot_machine_top'; bottom = 'coberto:block/slot_machine_bottom' } }

# Item definitions: the vanilla definition (copied from the 26.3 client) as the fallback.
$items = "$assets\minecraft\items"
$potionVanilla = @{ type = 'minecraft:model'; model = 'minecraft:item/potion'; tints = @(@{ type = 'minecraft:potion'; default = -13083194 }) }
$entries = for ($i = 0; $i -lt $drinkOrder.Count; $i++) { , @((4101 + $i), (Model "item/$($drinkOrder[$i])")) }
Write-Json "$items\potion.json" (Dispatch $potionVanilla $entries)
Write-Json "$items\bowl.json" (Dispatch (@{ type = 'minecraft:model'; model = 'minecraft:item/bowl' }) @(, @(4201, (Model 'item/mug'))))
Write-Json "$items\iron_block.json" (Dispatch (@{ type = 'minecraft:model'; model = 'minecraft:block/iron_block' }) @(, @(4202, (Model 'item/vending_machine'))))
Write-Json "$items\quartz_pillar.json" (Dispatch (@{ type = 'minecraft:model'; model = 'minecraft:block/quartz_pillar' }) @(, @(4203, (Model 'item/beverage_fountain'))))
Write-Json "$items\red_glazed_terracotta.json" (Dispatch (@{ type = 'minecraft:model'; model = 'minecraft:block/red_glazed_terracotta' }) @(, @(4401, (Model 'item/slot_machine'))))
Write-Json "$items\arrow.json" (Dispatch (@{ type = 'minecraft:model'; model = 'minecraft:item/arrow' }) @(@(4311, (Model 'item/explosive_arrow')), @(4312, (Model 'item/levitation_arrow'))))
Write-Json "$items\snowball.json" (Dispatch (@{ type = 'minecraft:model'; model = 'minecraft:item/snowball' }) @(, @(4321, (Model 'item/creeper_bomb'))))

$bowVanilla = @{
    type     = 'minecraft:condition'
    property = 'minecraft:using_item'
    on_false = @{ type = 'minecraft:model'; model = 'minecraft:item/bow' }
    on_true  = @{
        type     = 'minecraft:range_dispatch'
        property = 'minecraft:use_duration'
        scale    = 0.05
        fallback = @{ type = 'minecraft:model'; model = 'minecraft:item/bow_pulling_0' }
        entries  = @(@{ threshold = 0.65; model = @{ type = 'minecraft:model'; model = 'minecraft:item/bow_pulling_1' } },
            @{ threshold = 0.9; model = @{ type = 'minecraft:model'; model = 'minecraft:item/bow_pulling_2' } })
    }
}
Write-Json "$items\bow.json" (Dispatch $bowVanilla @(@(4301, (Bow 'explosive_bow')), @(4302, (Bow 'levitation_bow'))))

# Leather boots: keep vanilla's trims and dye for ordinary boots.
$tint = @(@{ type = 'minecraft:dye'; default = -6265536 })
$trims = 'quartz', 'iron', 'netherite', 'redstone', 'copper', 'gold', 'emerald', 'diamond', 'lapis', 'amethyst', 'resin'
$bootsVanilla = @{
    type     = 'minecraft:select'
    property = 'minecraft:trim_material'
    cases    = @($trims | ForEach-Object { @{ when = "minecraft:$_"; model = @{ type = 'minecraft:model'; model = "minecraft:item/leather_boots_${_}_trim"; tints = $tint } } })
    fallback = @{ type = 'minecraft:model'; model = 'minecraft:item/leather_boots'; tints = $tint }
}
Write-Json "$items\leather_boots.json" (Dispatch $bootsVanilla @(, @(4331, (Model 'item/candy_booties'))))

# ---------- Face Moon pack (FaceMoonPack.zip) ----------
# Its own pack: CobertoUtilities sends it to Java players on face nights and removes it at sunrise.
# See moon.ps1. The moon is drawn additively, so black is see-through.
. "$root\moon.ps1"
$fout = Join-Path $root 'build\facemoon'
if (Test-Path $fout) { Remove-Item $fout -Recurse -Force }
Write-Json "$fout\pack.mcmeta" @{ pack = @{ description = 'The moon is watching'; min_format = 46; max_format = 97; pack_format = 46; supported_formats = @(46, 97) } }
Save-Moon "$fout\assets\minecraft\textures\environment\celestial\moon" Files   # 1.21.11+
Save-Moon "$fout\assets\minecraft\textures\environment" Grid                    # 1.21.4-1.21.10


# ---------- Bedrock pack for Geyser ----------
# Only drinks and the Mug: they're simple items. Bows, arrows, the bomb, booties and machine blocks
# stay vanilla-looking for Bedrock players, because Bedrock custom items can't shoot, be used as
# ammo, be worn or place blocks the way the Java items do.
$bout = Join-Path $root 'build\bedrock'
if (Test-Path $bout) { Remove-Item $bout -Recurse -Force }
Write-Json "$bout\manifest.json" @{
    format_version = 2
    header         = @{ name = "Coberto's Server Pack"; description = 'Drinks for Geyser players'; uuid = '8f4c2a6e-3b1d-4e7a-9c55-2d6b1f0a7e31'
        version = @(1, 3, 0); min_engine_version = @(1, 21, 0) }
    modules        = @(@{ type = 'resources'; uuid = 'c7a19e52-6f0b-4d38-8e21-5b9d3c4f6a08'; version = @(1, 3, 0) })
}
$tex = [ordered]@{}
foreach ($n in @($drinks) + 'mug') {
    Copy-Item -LiteralPath $textures["item/$n"] (New-Item -ItemType Directory -Force "$bout\textures\items").FullName
    $tex["coberto.$n"] = @{ textures = "textures/items/$n" }
}
Write-Json "$bout\textures\item_texture.json" @{ resource_pack_name = 'coberto'; texture_name = 'atlas.items'; texture_data = $tex }

$potionDefs = for ($i = 0; $i -lt $drinkIds.Count; $i++) {
    $id = $drinkIds[$i]; $tx = $drinkOrder[$i]
    $label = $drinkNames[$tx]
    if ($id -like '*_strong') { $label = "Strong $label" } elseif ($id -like '*_long') { $label = "Extended $label" }
    @{ type = 'legacy'; custom_model_data = 4101 + $i; bedrock_identifier = "coberto:$id"; display_name = $label
        bedrock_options = @{ icon = "coberto.$tx"; creative_category = 'none' } }
}
$mappings = @{ format_version = 2; items = @{
        'minecraft:potion' = @($potionDefs)
        'minecraft:bowl'   = @(@{ type = 'legacy'; custom_model_data = 4201; bedrock_identifier = 'coberto:mug'; display_name = 'Mug'
                bedrock_options = @{ icon = 'coberto.mug'; creative_category = 'none' } })
    }
}



# Face Moon for Bedrock (FaceMoonPack.mcpack): CobertoUtilities has Geyser add it for
# Bedrock players who join during a face night.
$fbout = Join-Path $root 'build\facemoon-bedrock'
if (Test-Path $fbout) { Remove-Item $fbout -Recurse -Force }
Write-Json "$fbout\manifest.json" @{
    format_version = 2
    header         = @{ name = 'Face Moon'; description = 'The moon is watching'; uuid = '3e9b7c21-5a4d-4f86-b0e2-7c1d9a6f4b53'
        version = @(1, 0, 0); min_engine_version = @(1, 21, 0) }
    modules        = @(@{ type = 'resources'; uuid = 'a4f0d6e8-91c3-4b27-8d5e-2f6a0b9c1e74'; version = @(1, 0, 0) })
}
Save-Moon "$fbout\textures\environment" Grid
# ---------- Package ----------
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
# Not ZipFile.CreateFromDirectory: in Windows PowerShell it writes paths with '\', and
# Minecraft and Geyser only find files whose zip paths use '/'.
function New-PackZip([string]$folder, [string]$zipPath) {
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    $base = (Resolve-Path $folder).Path.TrimEnd('\') + '\'
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem $folder -Recurse -File | Sort-Object FullName) {
            $name = $file.FullName.Substring($base.Length).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $name)
        }
    } finally {
        $zip.Dispose()
    }
}
New-PackZip $out "$dist\CobertoServerPack.zip"
New-PackZip $bout "$dist\CobertoServerPack.mcpack"
New-PackZip $fout "$dist\FaceMoonPack.zip"
New-PackZip $fbout "$dist\FaceMoonPack.mcpack"
Write-Json "$dist\coberto_items.json" $mappings
$sha = (Get-FileHash "$dist\CobertoServerPack.zip" -Algorithm SHA1).Hash.ToLower()
$faceSha = (Get-FileHash "$dist\FaceMoonPack.zip" -Algorithm SHA1).Hash.ToLower()
Write-Host "Built dist\CobertoServerPack.zip (sha1 $sha), dist\CobertoServerPack.mcpack and dist\coberto_items.json"
Write-Host "Built dist\FaceMoonPack.zip (sha1 $faceSha): /facemoon pack <its url> $faceSha"
$sha
