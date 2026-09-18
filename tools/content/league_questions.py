#!/usr/bin/env python3
"""League-of-Legends question pack for Monkey Money.

Generates >= 2500 German quiz questions (easy … ULTRAHARD) from structured
Runeterra data — champions (title, region, role, resource, release year,
species, passive + Q/W/E/R), esports history (Worlds, MSI, MVPs, hosts),
lore, game mechanics and culture (skins, music, Arcane, Riot) — plus a
hand-written core. Deterministic (seeded), so re-runs produce the same pack.

Usage:  python3 tools/content/league_questions.py            # merge into fragen.json + taxonomie.json
        python3 tools/content/league_questions.py --dry-run  # only print the statistics
"""
import json
import random
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "MonkeyMoney/ios/Resources/Content"
RNG = random.Random(20240918)

# ---------------------------------------------------------------------------
# Champions: name | title (EN client) | region | main role | resource | year | species | passive | Q | W | E | R
# Empty fields are skipped by the templates. Ability names are the English client names.
# ---------------------------------------------------------------------------
CHAMPS_RAW = """
Alistar|the Minotaur|Runeterra|Support|Mana|2009|Minotaurus|Triumphant Roar|Pulverize|Headbutt|Trample|Unbreakable Will
Annie|the Dark Child|Noxus|Mid|Mana|2009|Mensch|Pyromania|Disintegrate|Incinerate|Molten Shield|Summon: Tibbers
Ashe|the Frost Archer|Freljord|ADC|Mana|2009|Mensch|Frost Shot|Ranger's Focus|Volley|Hawkshot|Enchanted Crystal Arrow
Fiddlesticks|the Ancient Fear|Runeterra|Jungle|Mana|2009|Dämon|A Harmless Scarecrow|Terrify|Bountiful Harvest|Reap|Crowstorm
Jax|Grandmaster at Arms|Runeterra|Top|Mana|2009|Mensch|Relentless Assault|Leap Strike|Empower|Counter Strike|Grandmaster's Might
Kayle|the Righteous|Demacia|Top|Mana|2009|Himmelswesen|Divine Ascent|Radiant Blast|Celestial Blessing|Starfire Spellblade|Divine Judgment
Master Yi|the Wuju Bladesman|Ionia|Jungle|Mana|2009|Mensch|Double Strike|Alpha Strike|Meditate|Wuju Style|Highlander
Morgana|the Fallen|Demacia|Support|Mana|2009|Himmelswesen|Soul Siphon|Dark Binding|Tormented Shadow|Black Shield|Soul Shackles
Nunu & Willump|the Boy and His Yeti|Freljord|Jungle|Mana|2009|Yeti|Call of the Freljord|Consume|Biggest Snowball Ever!|Snowball Barrage|Absolute Zero
Ryze|the Rune Mage|Runeterra|Mid|Mana|2009|Mensch|Arcane Mastery|Overload|Rune Prison|Spell Flux|Realm Warp
Sion|the Undead Juggernaut|Noxus|Top|Mana|2009|Untoter|Glory in Death|Decimating Smash|Soul Furnace|Roar of the Slayer|Unstoppable Onslaught
Sivir|the Battle Mistress|Shurima|ADC|Mana|2009|Mensch|Fleet of Foot|Boomerang Blade|Ricochet|Spell Shield|On the Hunt
Soraka|the Starchild|Targon|Support|Mana|2009|Himmelswesen|Salvation|Starcall|Astral Infusion|Equinox|Wish
Teemo|the Swift Scout|Bandle City|Top|Mana|2009|Yordle|Guerrilla Warfare|Blinding Dart|Move Quick|Toxic Shot|Noxious Trap
Tristana|the Yordle Gunner|Bandle City|ADC|Mana|2009|Yordle|Draw a Bead|Rapid Fire|Rocket Jump|Explosive Charge|Buster Shot
Twisted Fate|the Card Master|Bilgewater|Mid|Mana|2009|Mensch|Loaded Dice|Wild Cards|Pick a Card|Stacked Deck|Destiny
Warwick|the Uncaged Wrath of Zaun|Zaun|Jungle|Mana|2009|Chimäre|Eternal Hunger|Jaws of the Beast|Blood Hunt|Primal Howl|Infinite Duress
Singed|the Mad Chemist|Zaun|Top|Mana|2009|Mensch|Noxious Slipstream|Poison Trail|Mega Adhesive|Fling|Insanity Potion
Zilean|the Chronokeeper||Support|Mana|2009|Mensch|Time in a Bottle|Time Bomb|Rewind|Time Warp|Chronoshift
Evelynn|Agony's Embrace|Runeterra|Jungle|Mana|2009|Dämon|Demon Shade|Hate Spike|Allure|Whiplash|Last Caress
Tryndamere|the Barbarian King|Freljord|Top|Wut|2009|Mensch|Battle Fury|Bloodlust|Mocking Shout|Spinning Slash|Undying Rage
Twitch|the Plague Rat|Zaun|ADC|Mana|2009|Ratte|Deadly Venom|Ambush|Venom Cask|Contaminate|Spray and Pray
Karthus|the Deathsinger|Shadow Isles|Jungle|Mana|2009|Untoter|Death Defied|Lay Waste|Wall of Pain|Defile|Requiem
Amumu|the Sad Mummy|Shurima|Jungle|Mana|2009|Untoter|Cursed Touch|Bandage Toss|Despair|Tantrum|Curse of the Sad Mummy
Cho'Gath|the Terror of the Void|Void|Top|Mana|2009|Leerenwesen|Carnivore|Rupture|Feral Scream|Vorpal Spikes|Feast
Anivia|the Cryophoenix|Freljord|Mid|Mana|2009|Kryophönix|Rebirth|Flash Frost|Crystallize|Frostbite|Glacial Storm
Rammus|the Armordillo|Shurima|Jungle|Mana|2009|Gürteltier|Rolling Armordillo|Powerball|Defensive Ball Curl|Frenzying Taunt|Soaring Slam
Veigar|the Tiny Master of Evil|Bandle City|Mid|Mana|2009|Yordle|Phenomenal Evil Power|Baleful Strike|Dark Matter|Event Horizon|Primordial Burst
Kassadin|the Void Walker|Void|Mid|Mana|2009|Mensch|Void Stone|Null Sphere|Nether Blade|Force Pulse|Riftwalk
Gangplank|the Saltwater Scourge|Bilgewater|Top|Mana|2009|Mensch|Trial by Fire|Parrrley|Remove Scurvy|Powder Keg|Cannon Barrage
Taric|the Shield of Valoran|Targon|Support|Mana|2009|Aspekt|Bravado|Starlight's Touch|Bastion|Dazzle|Cosmic Radiance
Blitzcrank|the Great Steam Golem|Zaun|Support|Mana|2009|Golem|Mana Barrier|Rocket Grab|Overdrive|Power Fist|Static Field
Dr. Mundo|the Madman of Zaun|Zaun|Top|Leben|2009|Mensch|Goes Where He Pleases|Infected Bonesaw|Heart Zapper|Blunt Force Trauma|Maximum Dosage
Janna|the Storm's Fury|Zaun|Support|Mana|2009|Windgeist|Tailwind|Howling Gale|Zephyr|Eye of the Storm|Monsoon
Malphite|Shard of the Monolith|Ixtal|Top|Mana|2009|Steinwesen|Granite Shield|Seismic Shard|Thunderclap|Ground Slam|Unstoppable Force
Corki|the Daring Bombardier|Bandle City|Mid|Mana|2009|Yordle|Hextech Munitions|Phosphorus Bomb|Valkyrie|Gatling Gun|Missile Barrage
Katarina|the Sinister Blade|Noxus|Mid|Keine|2009|Mensch|Voracity|Bouncing Blade|Preparation|Shunpo|Death Lotus
Nasus|the Curator of the Sands|Shurima|Top|Mana|2009|Aufgestiegener|Soul Eater|Siphoning Strike|Wither|Spirit Fire|Fury of the Sands
Heimerdinger|the Revered Inventor|Piltover|Top|Mana|2009|Yordle|Hextech Affinity|H-28G Evolution Turret|Hextech Micro-Rockets|CH-2 Electron Storm Grenade|UPGRADE!!!
Shaco|the Demon Jester|Runeterra|Jungle|Mana|2009|Dämon|Backstab|Deceive|Jack in the Box|Two-Shiv Poison|Hallucinate
Udyr|the Spirit Walker|Freljord|Jungle|Mana|2009|Mensch|Bridge Between|Wilding Claw|Iron Mantle|Blazing Stampede|Wingborne Storm
Nidalee|the Bestial Huntress|Ixtal|Jungle|Mana|2009|Mensch|Prowl|Javelin Toss|Bushwhack|Primal Surge|Aspect of the Cougar
Poppy|Keeper of the Hammer|Demacia|Top|Mana|2010|Yordle|Iron Ambassador|Hammer Shock|Steadfast Presence|Heroic Charge|Keeper's Verdict
Gragas|the Rabble Rouser|Freljord|Jungle|Mana|2010|Mensch|Happy Hour|Barrel Roll|Drunken Rage|Body Slam|Explosive Cask
Pantheon|the Unbreakable Spear|Targon|Top|Mana|2010|Mensch|Mortal Will|Comet Spear|Shield Vault|Aegis Assault|Grand Starfall
Mordekaiser|the Iron Revenant|Noxus|Top|Keine|2010|Untoter|Darkness Rise|Obliterate|Indestructible|Death's Grasp|Realm of Death
Ezreal|the Prodigal Explorer|Piltover|ADC|Mana|2010|Mensch|Rising Spell Force|Mystic Shot|Essence Flux|Arcane Shift|Trueshot Barrage
Shen|the Eye of Twilight|Ionia|Top|Energie|2010|Mensch|Ki Barrier|Twilight Assault|Spirit's Refuge|Shadow Dash|Stand United
Kennen|the Heart of the Tempest|Ionia|Top|Energie|2010|Yordle|Mark of the Storm|Thundering Shuriken|Electrical Surge|Lightning Rush|Slicing Maelstrom
Garen|the Might of Demacia|Demacia|Top|Keine|2010|Mensch|Perseverance|Decisive Strike|Courage|Judgment|Demacian Justice
Akali|the Rogue Assassin|Ionia|Mid|Energie|2010|Mensch|Assassin's Mark|Five Point Strike|Twilight Shroud|Shuriken Flip|Perfect Execution
Malzahar|the Prophet of the Void|Void|Mid|Mana|2010|Mensch|Void Shift|Call of the Void|Void Swarm|Malefic Visions|Nether Grasp
Olaf|the Berserker|Freljord|Top|Mana|2010|Mensch|Berserker Rage|Undertow|Vicious Strikes|Reckless Swing|Ragnarok
Kog'Maw|the Mouth of the Abyss|Void|ADC|Mana|2010|Leerenwesen|Icathian Surprise|Caustic Spittle|Bio-Arcane Barrage|Void Ooze|Living Artillery
Xin Zhao|the Seneschal of Demacia|Demacia|Jungle|Mana|2010|Mensch|Determination|Three Talon Strike|Wind Becomes Lightning|Audacious Charge|Crescent Guard
Vladimir|the Crimson Reaper|Noxus|Mid|Leben|2010|Mensch|Crimson Pact|Transfusion|Sanguine Pool|Tides of Blood|Hemoplague
Galio|the Colossus|Demacia|Mid|Mana|2010|Koloss|Colossal Smash|Winds of War|Shield of Durand|Justice Punch|Hero's Entrance
Urgot|the Dreadnought|Zaun|Top|Mana|2010|Mensch|Echoing Flames|Corrosive Charge|Purge|Disdain|Fear Beyond Death
Miss Fortune|the Bounty Hunter|Bilgewater|ADC|Mana|2010|Mensch|Love Tap|Double Up|Strut|Make it Rain|Bullet Time
Sona|Maven of the Strings|Demacia|Support|Mana|2010|Mensch|Power Chord|Hymn of Valor|Aria of Perseverance|Song of Celerity|Crescendo
Swain|the Noxian Grand General|Noxus|Mid|Mana|2010|Mensch|Ravenous Flock|Death's Hand|Vision of Empire|Nevermove|Demonic Ascension
Lux|the Lady of Luminosity|Demacia|Mid|Mana|2010|Mensch|Illumination|Light Binding|Prismatic Barrier|Lucent Singularity|Final Spark
LeBlanc|the Deceiver|Noxus|Mid|Mana|2010|Mensch|Mirror Image|Sigil of Malice|Distortion|Ethereal Chains|Mimic
Irelia|the Blade Dancer|Ionia|Top|Mana|2010|Mensch|Ionian Fervor|Bladesurge|Defiant Dance|Flawless Duet|Vanguard's Edge
Trundle|the Troll King|Freljord|Jungle|Mana|2010|Troll|King's Tribute|Chomp|Frozen Domain|Pillar of Ice|Subjugate
Cassiopeia|the Serpent's Embrace|Noxus|Mid|Mana|2010|Mensch|Serpentine Grace|Noxious Blast|Miasma|Twin Fang|Petrifying Gaze
Caitlyn|the Sheriff of Piltover|Piltover|ADC|Mana|2011|Mensch|Headshot|Piltover Peacemaker|Yordle Snap Trap|90 Caliber Net|Ace in the Hole
Renekton|the Butcher of the Sands|Shurima|Top|Wut|2011|Aufgestiegener|Reign of Anger|Cull the Meek|Ruthless Predator|Slice and Dice|Dominus
Karma|the Enlightened One|Ionia|Support|Mana|2011|Mensch|Gathering Fire|Inner Flame|Focused Resolve|Inspire|Mantra
Maokai|the Twisted Treant|Shadow Isles|Support|Mana|2011|Baumgeist|Sap Magic|Bramble Smash|Twisted Advance|Sapling Toss|Nature's Grasp
Jarvan IV|the Exemplar of Demacia|Demacia|Jungle|Mana|2011|Mensch|Martial Cadence|Dragon Strike|Golden Aegis|Demacian Standard|Cataclysm
Nocturne|the Eternal Nightmare|Runeterra|Jungle|Mana|2011|Dämon|Umbra Blades|Duskbringer|Shroud of Darkness|Unspeakable Horror|Paranoia
Lee Sin|the Blind Monk|Ionia|Jungle|Energie|2011|Mensch|Flurry|Sonic Wave|Safeguard|Tempest|Dragon's Rage
Brand|the Burning Vengeance|Runeterra|Support|Mana|2011|Mensch|Blaze|Sear|Pillar of Flame|Conflagration|Pyroclasm
Rumble|the Mechanized Menace|Bandle City|Top|Hitze|2011|Yordle|Junkyard Titan|Flamespitter|Scrap Shield|Electro Harpoon|The Equalizer
Vayne|the Night Hunter|Demacia|ADC|Mana|2011|Mensch|Night Hunter|Tumble|Silver Bolts|Condemn|Final Hour
Orianna|the Lady of Clockwork|Piltover|Mid|Mana|2011|Automat|Clockwork Windup|Command: Attack|Command: Dissonance|Command: Protect|Command: Shockwave
Yorick|Shepherd of Souls|Shadow Isles|Top|Mana|2011|Mensch|Shepherd of Souls|Last Rites|Dark Procession|Mourning Mist|Eulogy of the Isles
Leona|the Radiant Dawn|Targon|Support|Mana|2011|Aspekt|Sunlight|Shield of Daybreak|Eclipse|Zenith Blade|Solar Flare
Wukong|the Monkey King|Ionia|Jungle|Mana|2011|Vastaya|Stone Skin|Crushing Blow|Warrior Trickster|Nimbus Strike|Cyclone
Skarner|the Primordial Sovereign|Ixtal|Jungle|Mana|2011|Brackern|Threads of Vibration|Shattered Earth|Seismic Bastion|Ixtal's Impact|Impale
Talon|the Blade's Shadow|Noxus|Mid|Mana|2011|Mensch|Blade's End|Noxian Diplomacy|Rake|Assassin's Path|Shadow Assault
Riven|the Exile|Noxus|Top|Keine|2011|Mensch|Runic Blade|Broken Wings|Ki Burst|Valor|Blade of the Exile
Xerath|the Magus Ascendant|Shurima|Mid|Mana|2011|Aufgestiegener|Mana Surge|Arcanopulse|Eye of Destruction|Shocking Orb|Rite of the Arcane
Graves|the Outlaw|Bilgewater|Jungle|Mana|2011|Mensch|New Destiny|End of the Line|Smoke Screen|Quickdraw|Collateral Damage
Shyvana|the Half-Dragon|Demacia|Jungle|Wut|2011|Halbdrache|Fury of the Dragonborn|Twin Bite|Burnout|Flame Breath|Dragon's Descent
Fizz|the Tidal Trickster|Bilgewater|Mid|Mana|2011|Amphibienwesen|Nimble Fighter|Urchin Strike|Seastone Trident|Playful / Trickster|Chum the Waters
Volibear|the Relentless Storm|Freljord|Top|Mana|2011|Halbgott|The Relentless Storm|Thundering Smash|Frenzied Maul|Sky Splitter|Stormbringer
Ahri|the Nine-Tailed Fox|Ionia|Mid|Mana|2011|Vastaya|Essence Theft|Orb of Deception|Fox-Fire|Charm|Spirit Rush
Viktor|the Herald of the Arcane|Zaun|Mid|Mana|2011|Mensch|Glorious Evolution|Siphon Power|Gravity Field|Hextech Ray|Arcane Storm
Sejuani|Fury of the North|Freljord|Jungle|Mana|2012|Mensch|Fury of the North|Arctic Assault|Winter's Wrath|Permafrost|Glacial Prison
Ziggs|the Hexplosives Expert|Zaun|Mid|Mana|2012|Yordle|Short Fuse|Bouncing Bomb|Satchel Charge|Hexplosive Minefield|Mega Inferno Bomb
Nautilus|the Titan of the Depths|Bilgewater|Support|Mana|2012|Untoter|Staggering Blow|Dredge Line|Titan's Wrath|Riptide|Depth Charge
Fiora|the Grand Duelist|Demacia|Top|Mana|2012|Mensch|Duelist's Dance|Lunge|Riposte|Bladework|Grand Challenge
Lulu|the Fae Sorceress|Bandle City|Support|Mana|2012|Yordle|Pix, Faerie Companion|Glitterlance|Whimsy|Help, Pix!|Wild Growth
Hecarim|the Shadow of War|Shadow Isles|Jungle|Mana|2012|Untoter|Warpath|Rampage|Spirit of Dread|Devastating Charge|Onslaught of Shadows
Varus|the Arrow of Retribution|Ionia|ADC|Mana|2012|Darkin|Living Vengeance|Piercing Arrow|Blighted Quiver|Hail of Arrows|Chain of Corruption
Darius|the Hand of Noxus|Noxus|Top|Mana|2012|Mensch|Hemorrhage|Decimate|Crippling Strike|Apprehend|Noxian Guillotine
Draven|the Glorious Executioner|Noxus|ADC|Mana|2012|Mensch|League of Draven|Spinning Axe|Blood Rush|Stand Aside|Whirling Death
Jayce|the Defender of Tomorrow|Piltover|Top|Mana|2012|Mensch|Hextech Capacitor|To the Skies! / Shock Blast|Lightning Field / Hyper Charge|Thundering Blow / Acceleration Gate|Mercury Cannon / Mercury Hammer
Zyra|Rise of the Thorns|Ixtal|Support|Mana|2012|Pflanzenwesen|Garden of Thorns|Deadly Spines|Rampant Growth|Grasping Roots|Stranglethorns
Diana|Scorn of the Moon|Targon|Jungle|Mana|2012|Aspekt|Moonsilver Blade|Crescent Strike|Pale Cascade|Lunar Rush|Moonfall
Rengar|the Pridestalker|Ixtal|Jungle|Wildheit|2012|Vastaya|Unseen Predator|Savagery|Battle Roar|Bola Strike|Thrill of the Hunt
Syndra|the Dark Sovereign|Ionia|Mid|Mana|2012|Mensch|Transcendent|Dark Sphere|Force of Will|Scatter the Weak|Unleashed Power
Kha'Zix|the Voidreaver|Void|Jungle|Mana|2012|Leerenwesen|Unseen Threat|Taste Their Fear|Void Spike|Leap|Void Assault
Elise|the Spider Queen|Shadow Isles|Jungle|Mana|2012|Mensch|Spider Queen|Neurotoxin / Venomous Bite|Volatile Spiderling / Skittering Frenzy|Cocoon / Rappel|Spider Form / Human Form
Zed|the Master of Shadows|Ionia|Mid|Energie|2012|Mensch|Contempt for the Weak|Razor Shuriken|Living Shadow|Shadow Slash|Death Mark
Nami|the Tidecaller||Support|Mana|2012|Vastaya|Surging Tides|Aqua Prison|Ebb and Flow|Tidecaller's Blessing|Tidal Wave
Vi|the Piltover Enforcer|Piltover|Jungle|Mana|2012|Mensch|Blast Shield|Vault Breaker|Denting Blows|Relentless Force|Cease and Desist
Thresh|the Chain Warden|Shadow Isles|Support|Mana|2013|Untoter|Damnation|Death Sentence|Dark Passage|Flay|The Box
Quinn|Demacia's Wings|Demacia|Top|Mana|2013|Mensch|Harrier|Blinding Assault|Heightened Senses|Vault|Behind Enemy Lines
Zac|the Secret Weapon|Zaun|Jungle|Leben|2013|Schleimwesen|Cell Division|Stretching Strikes|Unstable Matter|Elastic Slingshot|Let's Bounce!
Lissandra|the Ice Witch|Freljord|Mid|Mana|2013|Mensch|Iceborn Subjugation|Ice Shard|Ring of Frost|Glacial Path|Frozen Tomb
Aatrox|the Darkin Blade|Shurima|Top|Keine|2013|Darkin|Deathbringer Stance|The Darkin Blade|Infernal Chains|Umbral Dash|World Ender
Lucian|the Purifier|Demacia|ADC|Mana|2013|Mensch|Lightslinger|Piercing Light|Ardent Blaze|Relentless Pursuit|The Culling
Jinx|the Loose Cannon|Zaun|ADC|Mana|2013|Mensch|Get Excited!|Switcheroo!|Zap!|Flame Chompers!|Super Mega Death Rocket!
Yasuo|the Unforgiven|Ionia|Mid|Fluss|2013|Mensch|Way of the Wanderer|Steel Tempest|Wind Wall|Sweeping Blade|Last Breath
Vel'Koz|the Eye of the Void|Void|Mid|Mana|2014|Leerenwesen|Organic Deconstruction|Plasma Fission|Void Rift|Tectonic Disruption|Life Form Disintegration Ray
Braum|the Heart of the Freljord|Freljord|Support|Mana|2014|Mensch|Concussive Blows|Winter's Bite|Stand Behind Me|Unbreakable|Glacial Fissure
Gnar|the Missing Link|Freljord|Top|Wut|2014|Yordle|Rage Gene|Boomerang Throw / Boulder Toss|Hyper / Wallop|Hop / Crunch|GNAR!
Azir|the Emperor of the Sands|Shurima|Mid|Mana|2014|Aufgestiegener|Shurima's Legacy|Conquering Sands|Arise!|Shifting Sands|Emperor's Divide
Kalista|the Spear of Vengeance|Shadow Isles|ADC|Mana|2014|Untoter|Martial Poise|Pierce|Sentinel|Rend|Fate's Call
Rek'Sai|the Void Burrower|Void|Jungle|Wut|2014|Leerenwesen|Fury of the Xer'Sai|Queen's Wrath / Prey Seeker|Burrow / Unburrow|Furious Bite / Tunnel|Void Rush
Bard|the Wandering Caretaker|Runeterra|Support|Mana|2015|Himmelswesen|Traveler's Call|Cosmic Binding|Caretaker's Shrine|Magical Journey|Tempered Fate
Ekko|the Boy Who Shattered Time|Zaun|Mid|Mana|2015|Mensch|Z-Drive Resonance|Timewinder|Parallel Convergence|Phase Dive|Chronobreak
Tahm Kench|the River King|Bilgewater|Support|Mana|2015|Dämon|An Acquired Taste|Tongue Lash|Abyssal Dive|Thick Skin|Devour
Kindred|the Eternal Hunters|Runeterra|Jungle|Mana|2015|Geist|Mark of the Kindred|Dance of Arrows|Wolf's Frenzy|Mounting Dread|Lamb's Respite
Illaoi|the Kraken Priestess|Bilgewater|Top|Mana|2015|Mensch|Prophet of an Elder God|Tentacle Smash|Harsh Lesson|Test of Spirit|Leap of Faith
Jhin|the Virtuoso|Ionia|ADC|Mana|2016|Mensch|Whisper|Dancing Grenade|Deadly Flourish|Captive Audience|Curtain Call
Aurelion Sol|the Star Forger|Targon|Mid|Mana|2016|Himmelsdrache|Cosmic Creator|Breath of Light|Astral Flight|Singularity|Falling Star / The Skies Descend
Taliyah|the Stoneweaver|Shurima|Jungle|Mana|2016|Mensch|Rock Surfing|Threaded Volley|Seismic Shove|Unraveled Earth|Weaver's Wall
Kled|the Cantankerous Cavalier|Noxus|Top|Mut|2016|Yordle|Skaarl the Cowardly Lizard|Beartrap on a Rope / Pocket Pistol|Violent Tendencies|Jousting|Chaaaaaaaarge!!!
Ivern|the Green Father|Ionia|Jungle|Mana|2016|Baumgeist|Friend of the Forest|Rootcaller|Brushmaker|Triggerseed|Daisy!
Camille|the Steel Shadow|Piltover|Top|Mana|2016|Mensch|Adaptive Defenses|Precision Protocol|Tactical Sweep|Hookshot|The Hextech Ultimatum
Rakan|the Charmer|Ionia|Support|Mana|2017|Vastaya|Fey Feathers|Gleaming Quill|Grand Entrance|Battle Dance|The Quickness
Xayah|the Rebel|Ionia|ADC|Mana|2017|Vastaya|Clean Cuts|Double Daggers|Deadly Plumage|Bladecaller|Featherstorm
Kayn|the Shadow Reaper|Ionia|Jungle|Mana|2017|Mensch|The Darkin Scythe|Reaping Slash|Blade's Reach|Shadow Step|Umbral Trespass
Ornn|the Fire below the Mountain|Freljord|Top|Mana|2017|Halbgott|Living Forge|Volcanic Rupture|Bellows Breath|Searing Charge|Call of the Forge God
Zoe|the Aspect of Twilight|Targon|Mid|Mana|2017|Aspekt|More Sparkles!|Paddle Star|Spell Thief|Sleepy Trouble Bubble|Portal Jump
Kai'Sa|Daughter of the Void|Void|ADC|Mana|2018|Mensch|Second Skin|Icathian Rain|Void Seeker|Supercharge|Killer Instinct
Pyke|the Bloodharbor Ripper|Bilgewater|Support|Mana|2018|Untoter|Gift of the Drowned Ones|Bone Skewer|Ghostwater Dive|Phantom Undertow|Death from Below
Neeko|the Curious Chameleon|Ixtal|Mid|Mana|2018|Vastaya|Inherent Glamour|Blooming Burst|Shapesplitter|Tangle-Barbs|Pop Blossom
Sylas|the Unshackled|Demacia|Mid|Mana|2019|Mensch|Petricite Burst|Chain Lash|Kingslayer|Abscond / Abduct|Hijack
Yuumi|the Magical Cat|Bandle City|Support|Mana|2019|Katze|Feline Friendship|Prowling Projectile|You and Me!|Zoomies|Final Chapter
Qiyana|Empress of the Elements|Ixtal|Mid|Mana|2019|Mensch|Royal Privilege|Edge of Ixtal / Elemental Wrath|Terrashape|Audacity|Supreme Display of Talent
Senna|the Redeemer||Support|Mana|2019|Mensch|Absolution|Piercing Darkness|Last Embrace|Curse of the Black Mist|Dawning Shadow
Aphelios|the Weapon of the Faithful|Targon|ADC|Mana|2019|Mensch|The Hitman and the Seer||Phase|Weapon Queue System|Moonlight Vigil
Sett|the Boss|Ionia|Top|Mut|2020|Halb-Vastaya|Pit Grit|Knuckle Down|Haymaker|Facebreaker|The Show Stopper
Lillia|the Bashful Bloom|Ionia|Jungle|Mana|2020|Fae|Dream-Laden Bough|Blooming Blows|Watch Out! Eep!|Swirlseed|Lilting Lullaby
Yone|the Unforgotten|Ionia|Mid|Keine|2020|Mensch|Way of the Hunter|Mortal Steel|Spirit Cleave|Soul Unbound|Fate Sealed
Samira|the Desert Rose|Noxus|ADC|Mana|2020|Mensch|Daredevil Impulse|Flair|Blade Whirl|Wild Rush|Inferno Trigger
Seraphine|the Starry-Eyed Songstress|Piltover|Support|Mana|2020|Mensch|Stage Presence|High Note|Surround Sound|Beat Drop|Encore
Rell|the Iron Maiden|Noxus|Support|Mana|2020|Mensch|Break the Mold|Shattering Strike|Ferromancy: Crash Down / Mount Up|Full Tilt|Magnet Storm
Viego|the Ruined King|Shadow Isles|Jungle|Keine|2021|Untoter|Sovereign's Domination|Blade of the Ruined King|Spectral Maw|Harrowed Path|Heartbreaker
Gwen|the Hallowed Seamstress|Shadow Isles|Top|Mana|2021|Puppe|A Thousand Cuts|Snip Snip!|Hallowed Mist|Skip 'n Slash|Needlework
Akshan|the Rogue Sentinel|Shurima|Mid|Mana|2021|Mensch|Dirty Fighting|Avengerang|Going Rogue|Heroic Swing|Comeuppance
Vex|the Gloomist|Shadow Isles|Mid|Mana|2021|Yordle|Doom 'n Gloom|Mistral Bolt|Personal Space|Looming Darkness|Shadow Surge
Zeri|the Spark of Zaun|Zaun|ADC|Mana|2022|Mensch|Living Battery|Burst Fire|Ultrashock Laser|Spark Surge|Lightning Crash
Renata Glasc|the Chem-Baroness|Zaun|Support|Mana|2022|Mensch|Leverage|Handshake|Bailout|Loyalty Program|Hostile Takeover
Bel'Veth|the Empress of the Void|Void|Jungle|Keine|2022|Leerenwesen|Death in Lavender|Void Surge|Above and Below|Royal Maelstrom|Endless Banquet
Nilah|the Joy Unbound|Bilgewater|ADC|Mana|2022|Mensch|Joy Unending|Formless Blade|Jubilant Veil|Slipstream|Apotheosis
K'Sante|the Pride of Nazumah|Shurima|Top|Mana|2022|Mensch|Dauntless Instinct|Ntofo Strikes|Path Maker|Footwork|All Out
Milio|the Gentle Flame|Ixtal|Support|Mana|2023|Mensch|Fired Up!|Ultra Mega Fire Kick|Cozy Campfire|Warm Hugs|Breath of Life
Naafiri|the Hound of a Hundred Bites|Shurima|Mid|Mana|2023|Darkin|We Are More|Darkin Daggers|Hounds' Pursuit|Eviscerate|The Call of the Pack
Briar|the Restrained Hunger|Noxus|Jungle|Leben|2023|Mensch|Crimson Curse|Head Rush|Blood Frenzy / Snack Attack|Chilling Scream|Certain Death
Hwei|the Visionary|Ionia|Mid|Mana|2023|Mensch|Signature of the Visionary|Subject: Disaster|Subject: Serenity|Subject: Torment|Spiraling Despair
Smolder|the Fiery Fledgling|Camavor|ADC|Mana|2024|Drache|Dragon Practice|Super Scorcher Breath|Achooo!|Flap, Flap, Flap|MMOOOMMMM!
Aurora|the Witch Between Worlds|Freljord|Mid|Mana|2024|Vastaya|Spirit Abjuration|Twofold Hex|Across the Veil|The Weirding|Between Worlds
Ambessa|Matriarch of War|Noxus|Top|Energie|2024|Mensch|Drakehound's Step|Cunning Sweep|Repudiation|Lacerate / Sundering Slam|Public Execution
Mel|the Soul's Reflection|Noxus|Mid|Mana|2025|Mensch|Searing Brilliance|Radiant Volley|Rebuttal|Solar Snare|Golden Eclipse
"""

FIELDS = ["name", "title", "region", "role", "resource", "year", "species", "passive", "q", "w", "e", "r"]
CHAMPS = []
for line in CHAMPS_RAW.strip().splitlines():
    parts = [p.strip() for p in line.split("|")]
    assert len(parts) == len(FIELDS), line
    c = dict(zip(FIELDS, parts))
    c["year"] = int(c["year"])
    CHAMPS.append(c)
BY_NAME = {c["name"]: c for c in CHAMPS}

# Popularity tiers → difficulty offsets (A = everybody knows them, C = connoisseur picks).
_TIER_A_NAMES = ["Ahri", "Yasuo", "Lux", "Garen", "Jinx", "Ezreal", "Lee Sin", "Zed", "Darius", "Teemo", "Thresh", "Vayne", "Katarina", "Miss Fortune", "Master Yi", "Ashe", "Annie", "Caitlyn", "Vi", "Jhin", "Ekko", "Yone", "Sett", "Akali", "Irelia", "Riven", "Kai'Sa", "Lucian", "Leona", "Blitzcrank", "Morgana", "Sona", "Nasus", "Malphite", "Warwick", "Jax", "Tryndamere", "Veigar", "Zac", "Zoe", "Pyke", "Senna", "Viego", "Aphelios", "Samira", "Seraphine", "Viktor", "Heimerdinger", "Singed", "Jayce", "Ambessa", "Mel", "Draven", "Fizz", "Fiora", "Camille", "Kayn", "Rakan", "Xayah", "Sylas", "Yuumi", "Lulu", "Nami", "Janna", "Braum", "Gragas", "Volibear", "Sejuani", "Cho'Gath", "Kha'Zix", "Kog'Maw", "Vel'Koz", "Kassadin", "Malzahar", "Twisted Fate", "Gangplank", "Graves", "Nautilus", "Tahm Kench", "Illaoi", "Kindred", "Bard", "Azir", "Xerath", "Renekton", "Sivir", "Taliyah", "Rammus", "Amumu", "Aatrox", "Varus", "Soraka", "Kayle", "Mordekaiser", "Pantheon", "Shen", "Sion", "Zilean", "Evelynn", "Twitch", "Karthus", "Anivia", "Alistar", "Dr. Mundo", "Nunu & Willump", "Poppy", "Tristana", "Ryze", "Swain", "Vladimir", "Galio", "Cassiopeia", "LeBlanc", "Olaf", "Fiddlesticks"]
TIER_A = set(_TIER_A_NAMES)
TIER_C = {"Skarner", "Kled", "Ivern", "Rek'Sai", "Quinn", "Yorick", "Trundle", "Urgot", "Udyr", "Corki", "Rumble", "Kennen", "Karma", "Maokai", "Nocturne", "Brand", "Talon", "Shyvana", "Wukong", "Ziggs", "Hecarim", "Zyra", "Diana", "Rengar", "Syndra", "Elise", "Lissandra", "Gnar", "Kalista", "Ornn", "Neeko", "Qiyana", "Lillia", "Rell", "Gwen", "Akshan", "Vex", "Zeri", "Renata Glasc", "Bel'Veth", "Nilah", "K'Sante", "Milio", "Naafiri", "Briar", "Hwei", "Smolder", "Aurora", "Xin Zhao", "Orianna", "Taric", "Shaco", "Nidalee"}
for n in TIER_A | TIER_C:
    assert n in BY_NAME, n

LEVELS = ["easy", "medium", "hard", "ultrahard"]
OFF = {0: -1, 1: 0, 2: 1}


def tier(c):
    return 0 if c["name"] in TIER_A else (2 if c["name"] in TIER_C else 1)


def bump(level, steps):
    return LEVELS[max(0, min(3, LEVELS.index(level) + steps))]


REGION_HINT = {
    "Demacia": "Petricit, Ritterorden und ein Königreich, das Magie misstraut.", "Noxus": "Ein Imperium, in dem nur Stärke zählt.",
    "Ionia": "Die Erste Länder — Geister, Balance und Kampfkunst.", "Freljord": "Ewiges Eis, drei rivalisierende Stämme.",
    "Piltover": "Die Stadt des Fortschritts — Hextech und Handel.", "Zaun": "Die Unterstadt voller Chemtech und Schmutzgrün.",
    "Shurima": "Ein versunkenes Wüstenreich mit Sonnenscheibe.", "Bilgewater": "Hafenstadt der Piraten und Kopfgeldjäger.",
    "Shadow Isles": "Schwarzer Nebel und untote Seelen.", "Targon": "Der höchste Berg, Heimat der Aspekte.",
    "Ixtal": "Verborgener Dschungel der Elementarmagie.", "Void": "Das Nichts jenseits der Realität — Leere.",
    "Bandle City": "Heimat der Yordles, versteckt im Geisterreich.", "Runeterra": "Ohne feste Heimat — wandert durch ganz Runeterra.",
    "Camavor": "Ein Königreich jenseits des Meeres, durch den Ruin untergegangen.",
}
REGION_DE = {"Void": "der Leere", "Shadow Isles": "den Schatteninseln", "Bandle City": "Bandle City", "Runeterra": "ganz Runeterra"}
REGIONS = sorted({c["region"] for c in CHAMPS if c["region"]})
RESOURCES_DE = {"Mana": "Mana", "Energie": "Energie", "Wut": "Wut", "Keine": "keine Ressource", "Leben": "Leben (Gesundheit)", "Fluss": "Fluss (Flow)", "Hitze": "Hitze", "Mut": "Mut (Grit/Courage)", "Wildheit": "Wildheit (Ferocity)"}
ROLE_DE = {"Top": "Toplane", "Jungle": "Jungle", "Mid": "Midlane", "ADC": "Botlane (Schütze/ADC)", "Support": "Support"}

SUB_CHAMP, SUB_LORE, SUB_ESPORT, SUB_MECH, SUB_KULTUR, SUB_ALL = "lol_champions", "lol_lore", "lol_esports", "lol_mechanik", "lol_kultur", "league_of_legends"

QUESTIONS = []
_seq = Counter()


def add(sub, schw, typ, text, erkl, *, antworten=None, korrekt=None, tipps=None, region="global", **extra):
    _seq[sub] += 1
    q = {"id": f"q_gaming_{sub}_{_seq[sub]:06d}", "kat": "gaming", "sub": sub, "schw": schw, "region": region, "typ": typ, "alter": "ab0",
         "text": text, "tipps": tipps or [], "erkl": erkl}
    if antworten is not None:
        q["antworten"] = antworten
        q["korrekt"] = korrekt
    q.update(extra)
    QUESTIONS.append(q)


def choice(sub, schw, text, correct, wrongs, erkl, tipps=None, region="global"):
    wrongs = [w for w in dict.fromkeys(wrongs) if w != correct][:3]
    assert len(wrongs) == 3, (text, wrongs)
    opts = wrongs + [correct]
    RNG.shuffle(opts)
    add(sub, schw, "choice", text, erkl, antworten=opts, korrekt=opts.index(correct), tipps=tipps, region=region)


def wahr_falsch(sub, schw, text, value, erkl, tipps=None):
    add(sub, schw, "wahr_falsch", text, erkl, tipps=tipps, korrektBool=value)


def schaetz(sub, schw, text, wert, einheit, tol, lo, hi, erkl, tipps=None):
    add(sub, schw, "schaetz", text, erkl, tipps=tipps, schaetz={"richtwert": wert, "einheit": einheit, "toleranz": tol, "min": lo, "max": hi, "skala": "linear"})


def sortier(sub, schw, text, items, erkl, tipps=None):
    """items: list of (label, sort value, shown value) in correct order."""
    idx = list(range(len(items)))
    shuffled = idx[:]
    RNG.shuffle(shuffled)
    elemente = [items[i][0] for i in shuffled]
    # reihenfolge = for each element (in displayed order) its position in the correct order
    reihenfolge = [shuffled.index(i) for i in idx]
    add(sub, schw, "sortier", text, erkl, tipps=tipps, elemente=elemente, reihenfolge=reihenfolge, werte=[items[i][2] for i in idx])


def others(field, exclude, n=3, pool=None, like=None):
    """Distractors for `field`: two from champions with the same role as `like` (plausible), one from anywhere."""
    def pick(src, k, taken):
        vals = [c[field] for c in src if c[field] and c[field] != exclude and c[field] not in taken]
        vals = list(dict.fromkeys(vals))
        RNG.shuffle(vals)
        return vals[:k]
    if like is None:
        return pick(pool or CHAMPS, n, set())
    same = [c for c in CHAMPS if c["role"] == like["role"] and c is not like]
    out = pick(same, 2, set())
    out += pick(CHAMPS, n - len(out), set(out))
    return out


def champ_desc(c):
    parts = [f"{c['name']} ist „{c['title']}“"]
    if c["region"]:
        parts.append(f"aus {REGION_DE.get(c['region'], c['region'])}")
    parts.append(f"— {ROLE_DE[c['role']]}, erschienen {c['year']}.")
    return " ".join(parts)


# ---------------------------------------------------------------------------
# 1) Champion templates
# ---------------------------------------------------------------------------
def gen_champions():
    for c in CHAMPS:
        t = tier(c)
        name = c["name"]
        # title → champion / champion → title
        choice(SUB_CHAMP, bump("medium", OFF[t]), f"Welcher Champion trägt den Titel „{c['title']}“ (englischer Client)?", name,
               others("name", name, like=c), champ_desc(c),
               tipps=([REGION_HINT[c["region"]]] if c["region"] else []) + [f"Position: {ROLE_DE[c['role']]}.", f"Erschienen {c['year']}."])
        choice(SUB_CHAMP, bump("medium", OFF[t]), f"Welchen Titel trägt {name} im englischen Client?", c["title"],
               others("title", c["title"], like=c), champ_desc(c))
        # region
        if c["region"]:
            choice(SUB_LORE, bump("easy", t), f"Aus welcher Region Runeterras stammt {name}?", c["region"],
                   [r for r in RNG.sample(REGIONS, len(REGIONS)) if r != c["region"]][:3], champ_desc(c), tipps=[REGION_HINT[c["region"]]])
        # role
        choice(SUB_CHAMP, bump("easy", max(0, t - 1)), f"Auf welcher Position wird {name} klassischerweise gespielt?", ROLE_DE[c["role"]],
               [ROLE_DE[r] for r in ROLE_DE if r != c["role"]], champ_desc(c))
        # resource (interesting for non-mana; a sample of mana champions keeps the answer honest)
        if c["resource"] != "Mana" or RNG.random() < 0.25:
            choice(SUB_CHAMP, bump("medium", t - 1 if c["resource"] != "Mana" else t), f"Welche Ressource nutzt {name} für seine Fähigkeiten?", RESOURCES_DE[c["resource"]],
                   [RESOURCES_DE[r] for r in RESOURCES_DE if r != c["resource"]], f"{name} nutzt {RESOURCES_DE[c['resource']]}. " + champ_desc(c))
        # ultimate
        if c["r"]:
            choice(SUB_CHAMP, bump("medium", t), f"Wie heißt die ultimative Fähigkeit (R) von {name}?", c["r"],
                   others("r", c["r"], like=c), f"Die Ultimate von {name} heißt „{c['r']}“. " + champ_desc(c), tipps=["Englischer Fähigkeitsname."])
            choice(SUB_CHAMP, bump("hard", t - 1), f"Zu welchem Champion gehört die Ultimate „{c['r']}“?", name,
                   others("name", name, like=c), f"„{c['r']}“ ist die R von {name}. " + champ_desc(c))
        # passive (connoisseur territory)
        if c["passive"]:
            choice(SUB_CHAMP, bump("hard", 1 if t else 0), f"Wie heißt die passive Fähigkeit von {name}?", c["passive"],
                   others("passive", c["passive"], like=c), f"Die Passive von {name} heißt „{c['passive']}“. " + champ_desc(c))
        # Q
        if c["q"]:
            choice(SUB_CHAMP, bump("hard", 1 if t == 2 else 0), f"Wie heißt die Q-Fähigkeit von {name}?", c["q"], others("q", c["q"], like=c),
                   f"Die Q von {name} heißt „{c['q']}“. " + champ_desc(c))
        # "not one of X's abilities"
        own = [a for a in (c["q"], c["w"], c["e"], c["r"]) if a]
        if len(own) == 4:
            foreign = others("w", c["w"])[0]
            opts = RNG.sample(own, 3) + [foreign]
            choice(SUB_CHAMP, bump("hard", 0 if t == 0 else 1), f"Welche dieser Fähigkeiten gehört NICHT zu {name}?", foreign, opts[:3],
                   f"„{foreign}“ gehört einem anderen Champion; {name} hat {', '.join(own[:3])} und {own[3]}.")
        # release year (estimate)
        schaetz(SUB_CHAMP, "hard" if t < 2 else "ultrahard", f"In welchem Jahr erschien {name} in League of Legends?", c["year"], "", 1, 2009, 2025,
                champ_desc(c), tipps=["League of Legends startete 2009.", f"{name} kam {'zu den ersten Champions' if c['year'] == 2009 else ('in den frühen Jahren' if c['year'] <= 2012 else ('in der Mitte des Jahrzehnts' if c['year'] <= 2017 else 'in den letzten Jahren'))}."])
        # species
        if c["species"] in ("Yordle", "Vastaya", "Darkin", "Leerenwesen", "Aufgestiegener", "Dämon", "Untoter", "Aspekt"):
            spec_de = {"Yordle": "Yordle", "Vastaya": "Vastaya", "Darkin": "Darkin", "Leerenwesen": "Leerenwesen", "Aufgestiegener": "Aufgestiegener (Ascended)", "Dämon": "Dämon", "Untoter": "Untoter / Geist", "Aspekt": "Aspekt von Targon"}
            choice(SUB_LORE, bump("medium", t), f"Zu welcher Art von Wesen gehört {name}?", spec_de[c["species"]],
                   [spec_de[s] for s in spec_de if s != c["species"]], f"{name} ist ein {spec_de[c['species']]}. " + champ_desc(c))


def gen_region_sets():
    by_region = {}
    for c in CHAMPS:
        if c["region"]:
            by_region.setdefault(c["region"], []).append(c)
    for region, members in by_region.items():
        if len(members) < 3:
            continue
        outsiders = [c for c in CHAMPS if c["region"] and c["region"] != region]
        for _ in range(min(6, len(members))):
            m = RNG.choice(members)
            wrong = [c["name"] for c in RNG.sample(outsiders, 3)]
            choice(SUB_LORE, bump("medium", tier(m) - 1), f"Welcher dieser Champions stammt aus {REGION_DE.get(region, region)}?", m["name"], wrong,
                   f"{m['name']} kommt aus {REGION_DE.get(region, region)}; die anderen stammen aus {', '.join(sorted({BY_NAME[w]['region'] for w in wrong}))}.", tipps=[REGION_HINT[region]])
        # mehrfach: two from the region
        if len(members) >= 2:
            pair = RNG.sample(members, 2)
            wrong = RNG.sample(outsiders, 2)
            opts = [p["name"] for p in pair] + [w["name"] for w in wrong]
            RNG.shuffle(opts)
            add(SUB_LORE, "hard", "mehrfach", f"Welche ZWEI dieser Champions stammen aus {REGION_DE.get(region, region)}?",
                f"{pair[0]['name']} und {pair[1]['name']} stammen aus {REGION_DE.get(region, region)}.", antworten=opts,
                korrektMehrfach=sorted(opts.index(p["name"]) for p in pair), tipps=[REGION_HINT[region]])
    # resource groups
    for res in ("Energie", "Wut", "Keine", "Leben", "Mut"):
        users = [c for c in CHAMPS if c["resource"] == res]
        mana = [c for c in CHAMPS if c["resource"] == "Mana"]
        for _ in range(4):
            m = RNG.choice(users)
            choice(SUB_MECH, "medium", f"Welcher dieser Champions nutzt {RESOURCES_DE[res]} statt Mana?", m["name"], [c["name"] for c in RNG.sample(mana, 3)],
                   f"{m['name']} spielt mit {RESOURCES_DE[res]}; die anderen drei nutzen Mana.")
    # species groups
    for species, label in (("Yordle", "ein Yordle"), ("Vastaya", "ein Vastaya"), ("Darkin", "ein Darkin"), ("Leerenwesen", "ein Wesen aus der Leere"), ("Aufgestiegener", "ein Aufgestiegener Shurimas")):
        members = [c for c in CHAMPS if c["species"] == species]
        humans = [c for c in CHAMPS if c["species"] == "Mensch"]
        for _ in range(min(5, len(members))):
            m = RNG.choice(members)
            choice(SUB_LORE, "medium", f"Welcher dieser Champions ist {label}?", m["name"], [c["name"] for c in RNG.sample(humans, 3)],
                   f"{m['name']} ist {label}; die anderen drei sind Menschen.")


def gen_true_false():
    for c in CHAMPS:
        t = tier(c)
        if c["region"] and RNG.random() < 0.6:
            if RNG.random() < 0.5:
                wahr_falsch(SUB_LORE, bump("easy", t), f"{c['name']} stammt aus {REGION_DE.get(c['region'], c['region'])}.", True, champ_desc(c))
            else:
                wrong = RNG.choice([r for r in REGIONS if r != c["region"]])
                wahr_falsch(SUB_LORE, bump("easy", t), f"{c['name']} stammt aus {REGION_DE.get(wrong, wrong)}.", False, f"Falsch — {champ_desc(c)}")
        if RNG.random() < 0.35 and c["r"]:
            if RNG.random() < 0.5:
                wahr_falsch(SUB_CHAMP, bump("medium", t), f"„{c['r']}“ ist die ultimative Fähigkeit von {c['name']}.", True, f"Stimmt — {champ_desc(c)}")
            else:
                other = others("r", c["r"])[0]
                wahr_falsch(SUB_CHAMP, bump("medium", t), f"„{other}“ ist die ultimative Fähigkeit von {c['name']}.", False, f"Falsch — die R von {c['name']} heißt „{c['r']}“.")
        if RNG.random() < 0.3:
            other = RNG.choice([x for x in CHAMPS if x["year"] != c["year"]])
            earlier = c["year"] < other["year"]
            wahr_falsch(SUB_CHAMP, "hard", f"{c['name']} erschien vor {other['name']}.", earlier, f"{c['name']}: {c['year']}, {other['name']}: {other['year']}.")


def gen_sortier():
    for _ in range(70):
        picks = RNG.sample(CHAMPS, 6)
        seen, group = set(), []
        for p in picks:
            if p["year"] not in seen:
                seen.add(p["year"])
                group.append(p)
            if len(group) == 4:
                break
        if len(group) < 4:
            continue
        group.sort(key=lambda c: c["year"])
        names = ", ".join(c["name"] for c in group[:-1]) + f" und {group[-1]['name']}"
        sortier(SUB_CHAMP, "hard" if all(tier(c) < 2 for c in group) else "ultrahard", f"Sortiere {names} nach ihrem Erscheinungsjahr — vom ältesten zum neuesten Champion.",
                [(c["name"], c["year"], str(c["year"])) for c in group],
                " · ".join(f"{c['name']} {c['year']}" for c in group), tipps=[f"{group[0]['name']} ist der älteste der vier.", f"{group[-1]['name']} kam zuletzt."])


# ---------------------------------------------------------------------------
# 2) Esports
# ---------------------------------------------------------------------------
WORLDS = [  # year, winner, runner-up, final MVP, host city, country
    (2011, "Fnatic", "against All authority", None, "Jönköping", "Schweden"),
    (2012, "Taipei Assassins", "Azubu Frost", None, "Los Angeles", "USA"),
    (2013, "SK Telecom T1", "Royal Club", None, "Los Angeles", "USA"),
    (2014, "Samsung White", "Star Horn Royal Club", "Mata", "Seoul", "Südkorea"),
    (2015, "SK Telecom T1", "KOO Tigers", "MaRin", "Berlin", "Deutschland"),
    (2016, "SK Telecom T1", "Samsung Galaxy", "Faker", "Los Angeles", "USA"),
    (2017, "Samsung Galaxy", "SK Telecom T1", "Ruler", "Peking", "China"),
    (2018, "Invictus Gaming", "Fnatic", "Ning", "Incheon", "Südkorea"),
    (2019, "FunPlus Phoenix", "G2 Esports", "Tian", "Paris", "Frankreich"),
    (2020, "DAMWON Gaming", "Suning", "Canyon", "Shanghai", "China"),
    (2021, "EDward Gaming", "DWG KIA", "Scout", "Reykjavík", "Island"),
    (2022, "DRX", "T1", "Kingen", "San Francisco", "USA"),
    (2023, "T1", "Weibo Gaming", "Zeus", "Seoul", "Südkorea"),
    (2024, "T1", "Bilibili Gaming", "Faker", "London", "Großbritannien"),
]
ORG = {"SK Telecom T1": "T1"}
MSI = [(2015, "EDward Gaming"), (2016, "SK Telecom T1"), (2017, "SK Telecom T1"), (2018, "Royal Never Give Up"), (2019, "G2 Esports"), (2021, "Royal Never Give Up"), (2022, "Royal Never Give Up"), (2023, "JD Gaming"), (2024, "Gen.G")]
ANTHEMS = [(2014, "Warriors", "Imagine Dragons"), (2015, "Worlds Collide", "Nicki Taylor"), (2016, "Ignite", "Zedd"), (2017, "Legends Never Die", "Against the Current"),
           (2018, "RISE", "The Glitch Mob, Mako & The Word Alive"), (2019, "Phoenix", "Cailin Russo & Chrissy Costanza"), (2020, "Take Over", "Jeremy McKinnon, MAX & Henry"),
           (2021, "Burn It All Down", "PVRIS"), (2022, "Star Walkin'", "Lil Nas X"), (2023, "GODS", "NewJeans"), (2024, "Heavy Is The Crown", "Linkin Park")]
TEAMS_POOL = sorted({w for _, w, r, *_ in WORLDS for w in (w, r)} | {"Cloud9", "Team Liquid", "Rogue", "MAD Lions", "Gen.G", "JD Gaming", "Royal Never Give Up", "Top Esports", "100 Thieves", "TSM", "Unicorns of Love", "Schalke 04", "Vitality", "Excel", "KT Rolster", "Hanwha Life Esports", "LNG Esports", "PSG Talon", "GAM Esports"})
PLAYERS = [("Faker", "T1", "Mid", "Lee Sang-hyeok"), ("Caps", "G2 Esports", "Mid", "Rasmus Winther"), ("Rekkles", "Fnatic", "ADC", "Martin Larsson"), ("Perkz", "G2 Esports", "Mid", "Luka Perković"),
           ("Uzi", "Royal Never Give Up", "ADC", "Jian Zi-Hao"), ("Chovy", "Gen.G", "Mid", "Jeong Ji-hoon"), ("ShowMaker", "DWG KIA", "Mid", "Heo Su"), ("Canyon", "DWG KIA", "Jungle", "Kim Geon-bu"),
           ("Ruler", "Gen.G", "ADC", "Park Jae-hyuk"), ("Zeus", "T1", "Top", "Choi Woo-je"), ("Oner", "T1", "Jungle", "Mun Hyeon-jun"), ("Gumayusi", "T1", "ADC", "Lee Min-hyeong"),
           ("Keria", "T1", "Support", "Ryu Min-seok"), ("Jankos", "G2 Esports", "Jungle", "Marcin Jankowski"), ("Bwipo", "Fnatic", "Top", "Gabriël Rau"), ("Hylissang", "Fnatic", "Support", "Zdravets Galabov"),
           ("Doublelift", "Team Liquid", "ADC", "Yiliang Peng"), ("Bjergsen", "TSM", "Mid", "Søren Bjerg"), ("Knight", "Bilibili Gaming", "Mid", "Zhuo Ding"), ("Deft", "DRX", "ADC", "Kim Hyuk-kyu")]


def gen_esports():
    for year, winner, runner, mvp, city, country in WORLDS:
        others_w = [t for t in TEAMS_POOL if t not in (winner, runner)]
        choice(SUB_ESPORT, "medium" if year in (2011, 2013, 2016, 2018, 2019, 2023, 2024) else "hard", f"Wer gewann die League-of-Legends-Weltmeisterschaft {year}?", winner,
               RNG.sample(others_w, 3), f"{winner} besiegte {runner} im Finale der Worlds {year} ({city}).", tipps=[f"Das Finale fand in {city} statt.", f"Der Finalgegner war {runner}."])
        choice(SUB_ESPORT, "hard", f"Wer verlor das Finale der Worlds {year}?", runner, RNG.sample([t for t in TEAMS_POOL if t not in (winner, runner)], 3),
               f"{runner} unterlag {winner} im Worlds-Finale {year}.", tipps=[f"Der Sieger war {winner}."])
        choice(SUB_ESPORT, "hard" if year >= 2014 else "ultrahard", f"In welcher Stadt wurde das Finale der Worlds {year} gespielt?", city,
               RNG.sample(sorted({c for _, _, _, _, c, _ in WORLDS if c != city} | {"Madrid", "Tokio", "Sydney", "Köln"}), 3), f"Worlds {year}: Finale in {city} ({country}), Sieger {winner}.")
        if mvp:
            choice(SUB_ESPORT, "ultrahard", f"Wer wurde beim Worlds-Finale {year} zum MVP gewählt?", mvp,
                   RNG.sample(sorted({w[3] for w in WORLDS if w[3] and w[3] != mvp} | {"Bang", "Wolf", "Deft", "Chovy"}), 3), f"{mvp} ({winner}) war Finals-MVP der Worlds {year}.")
        org = ORG.get(winner, winner)
        wins = [y for y, w, *_ in WORLDS if ORG.get(w, w) == org]
        if len(wins) == 1:
            choice(SUB_ESPORT, "hard", f"In welchem Jahr gewann {winner} die Worlds?", str(year),
                   [str(y) for y in RNG.sample([y for y, *_ in WORLDS if y not in wins], 3)], f"{winner} holte den Titel {year} in {city}.")
        elif year == wins[0]:
            choice(SUB_ESPORT, "hard", f"In welchem Jahr gewann {org} zum ERSTEN Mal die Worlds?", str(year),
                   [str(y) for y in RNG.sample([y for y, *_ in WORLDS if y not in wins], 3)], f"{org} holte den ersten von {len(wins)} Titeln {year} in {city}.")
    for year, winner in MSI:
        choice(SUB_ESPORT, "hard", f"Wer gewann das Mid-Season Invitational (MSI) {year}?", winner, RNG.sample([t for t in TEAMS_POOL if t != winner], 3),
               f"{winner} gewann das MSI {year}.", tipps=["Das MSI ist das internationale Turnier zur Saisonmitte."])
    for year, song, artist in ANTHEMS:
        choice(SUB_KULTUR, "hard", f"Wie hieß der offizielle Worlds-Song {year}?", song, RNG.sample([s for _, s, _ in ANTHEMS if s != song], 3), f"„{song}“ ({artist}) war der Worlds-Song {year}.")
        choice(SUB_KULTUR, "hard", f"Von wem stammt der Worlds-Song „{song}“ ({year})?", artist, RNG.sample([a for _, _, a in ANTHEMS if a != artist], 3), f"„{song}“ stammt von {artist} — Worlds {year}.")
    for nick, team, role, real in PLAYERS:
        choice(SUB_ESPORT, "hard", f"Auf welcher Position spielt(e) der Profi {nick}?", ROLE_DE[role], [ROLE_DE[r] for r in ROLE_DE if r != role], f"{nick} ({real}) ist als {ROLE_DE[role]} bekannt, u. a. bei {team}.")
        choice(SUB_ESPORT, "ultrahard", f"Wie lautet der bürgerliche Name des Profis {nick}?", real, RNG.sample([r for *_, r in PLAYERS if r != real], 3), f"{nick} heißt {real} — bekannt von {team}.")
    # Worlds chronology
    for _ in range(8):
        picks = RNG.sample(WORLDS, 4)
        picks.sort(key=lambda w: w[0])
        sortier(SUB_ESPORT, "ultrahard", "Sortiere diese Worlds-Sieger chronologisch — vom frühesten Titel zum spätesten: " + ", ".join(w[1] for w in picks) + ".",
                [(f"{w[1]} ({w[4]})", w[0], str(w[0])) for w in picks], " · ".join(f"{w[1]} {w[0]}" for w in picks))


# ---------------------------------------------------------------------------
# 3) Hand-written core: mechanics, lore, culture, German scene
# ---------------------------------------------------------------------------
HAND = [
    # (sub, schw, text, correct, [wrong1, wrong2, wrong3], erkl, region)
    (SUB_MECH, "easy", "Wie heißt die Hauptkarte von League of Legends im deutschen Client?", "Kluft der Beschwörer", ["Heulende Schlucht", "Gewundener Wald", "Kristallnarbe"], "Die Kluft der Beschwörer (Summoner's Rift) ist die klassische 5-gegen-5-Karte."),
    (SUB_MECH, "easy", "Was muss ein Team zerstören, um ein Spiel zu gewinnen?", "Den gegnerischen Nexus", ["Alle gegnerischen Türme", "Den Baron Nashor", "Alle Inhibitoren"], "Fällt der Nexus, ist das Spiel vorbei — Türme und Inhibitoren sind nur der Weg dorthin."),
    (SUB_MECH, "easy", "Wie heißt der mächtige Boss in der oberen Flusshälfte, den es ab Minute 20 gibt?", "Baron Nashor", ["Ältester Drache", "Herold der Kluft", "Krabbler"], "Baron Nashor erscheint ab 20:00 und gewährt den Buff „Hand des Barons“."),
    (SUB_MECH, "easy", "Wie viele Ränge (Level) kann ein Champion in einem Spiel maximal erreichen?", "18", ["16", "20", "30"], "Level 18 ist das Maximum im Spiel; das Beschwörerkonto levelt separat."),
    (SUB_MECH, "easy", "Wie heißt der Beschwörerzauber, der einen kurzen Sprung (Teleport über kurze Distanz) erlaubt?", "Blitz (Flash)", ["Geist (Ghost)", "Heilung", "Barriere"], "Blitz/Flash ist der wichtigste Beschwörerzauber — Abklingzeit 300 Sekunden."),
    (SUB_MECH, "medium", "Wie lang ist die Abklingzeit von Blitz (Flash) in Sekunden?", "300", ["180", "240", "360"], "Blitz hat 300 Sekunden Abklingzeit — mit Kosmischer Einsicht verkürzt sie sich."),
    (SUB_MECH, "medium", "Welcher Beschwörerzauber wird typischerweise nur vom Jungler genommen?", "Zerschmettern (Smite)", ["Zünder (Ignite)", "Erschöpfung (Exhaust)", "Teleport"], "Zerschmettern verursacht hohen Schaden an Monstern und ist für den Dschungel Pflicht."),
    (SUB_MECH, "medium", "Was bewirkt der Beschwörerzauber Zünder (Ignite)?", "Verursacht absoluten Schaden über Zeit und reduziert Heilung", ["Erhöht das Lauftempo", "Blockt den nächsten Zauber", "Stellt Mana wieder her"], "Zünder verursacht absoluten Schaden über fünf Sekunden und verringert die Heilung des Ziels."),
    (SUB_MECH, "medium", "Wie viele Drachen-Seelen kann ein Team in einem Spiel maximal bekommen?", "1", ["2", "3", "4"], "Nach dem vierten Drachen eines Teams gibt es genau eine Drachen-Seele — danach erscheint der Älteste Drache."),
    (SUB_MECH, "medium", "Wie viele Elementardrachen muss ein Team töten, um die Drachen-Seele zu erhalten?", "4", ["3", "5", "2"], "Vier Drachen für ein Team bringen die Seele des dritten Drachen-Elements der Partie."),
    (SUB_MECH, "medium", "Welches Objekt vergibt bei Zerstörung Gold für „Turmplatten“?", "Äußere Türme vor Minute 14", ["Inhibitoren", "Nexus-Türme", "Der Baron"], "Bis Minute 14 haben äußere Türme fünf Platten, die einzeln Gold geben."),
    (SUB_MECH, "medium", "Wann verschwinden die Turmplatten der äußeren Türme?", "Minute 14", ["Minute 10", "Minute 20", "Minute 8"], "Die Platten fallen um 14:00 ab — danach sind die Türme leichter zu zerstören."),
    (SUB_MECH, "medium", "Was gibt der Ältere Drache (Elder Dragon) dem Team, das ihn tötet?", "Einen Buff, der Gegner mit wenig Leben sofort hinrichtet", ["Einen zweiten Nexus", "Doppeltes Gold", "Unsichtbarkeit"], "Der Ältester-Drachen-Buff verbrennt und exekutiert Gegner unter einer Lebensschwelle."),
    (SUB_MECH, "hard", "In welcher Minute erscheint der erste Elementardrache?", "5:00", ["2:30", "8:00", "10:00"], "Der erste Drache erscheint um 5:00; Wiedererscheinen nach fünf Minuten."),
    (SUB_MECH, "hard", "Wie viele Runen-Pfade (Baum-Kategorien) gibt es im Runensystem?", "5", ["3", "4", "6"], "Präzision, Dominanz, Zauberei, Entschlossenheit und Inspiration."),
    (SUB_MECH, "hard", "Welcher Runenpfad enthält den Schlussstein „Eroberer“ (Conqueror)?", "Präzision", ["Dominanz", "Zauberei", "Entschlossenheit"], "Eroberer ist ein Schlussstein des Präzisions-Pfads, ebenso wie Tödliches Tempo."),
    (SUB_MECH, "hard", "Welcher Runenpfad enthält den Schlussstein „Elektrisieren“ (Electrocute)?", "Dominanz", ["Präzision", "Zauberei", "Inspiration"], "Elektrisieren (drei Treffer = Extra-Schaden) gehört zur Dominanz."),
    (SUB_MECH, "hard", "Wie heißt der Schlussstein, bei dem der erste Treffer Nahkampf-Champions Bonusschaden nach einem Sprint-Trigger gibt — „Nachbeben“ gehört zu welchem Pfad?", "Entschlossenheit", ["Präzision", "Dominanz", "Inspiration"], "Nachbeben (Aftershock) ist der Tank-Schlussstein der Entschlossenheit."),
    (SUB_MECH, "medium", "Wie nennt man das Töten aller fünf Gegner durch einen einzelnen Spieler in kurzer Zeit?", "Pentakill", ["Quadra Kill", "Ace", "Rampage"], "Fünf Kills in Folge = Pentakill; „Ace“ bedeutet nur, dass das gesamte Gegnerteam tot ist."),
    (SUB_MECH, "easy", "Wie heißen die kleinen Einheiten, die alle 30 Sekunden aus dem Nexus laufen?", "Vasallen (Minions)", ["Wächter", "Krabbler", "Vasen"], "Vasallen-Wellen spawnen ab 1:05 alle 30 Sekunden auf allen drei Lanes."),
    (SUB_MECH, "medium", "Was zeigt ein Kontrollauge (Control Ward) zusätzlich zur normalen Sicht an?", "Gegnerische Augen und Fallen in Reichweite", ["Den Standort des Barons", "Die Gold-Werte der Gegner", "Unsichtbare Champions dauerhaft"], "Kontrollaugen enthüllen und deaktivieren gegnerische Augen sowie Fallen."),
    (SUB_MECH, "medium", "Wie heißt der neutrale Boss im oberen Fluss VOR dem Baron (ab Minute 14)?", "Herold der Kluft", ["Ältester Drache", "Roter Bruiser", "Blauer Wächter"], "Der Herold der Kluft erscheint zur Spielmitte und kann als „Auge“ auf Türme geworfen werden."),
    (SUB_MECH, "hard", "Was passiert, wenn man das „Auge des Herolds“ einsetzt?", "Der Herold wird beschworen und rammt gegnerische Bauwerke", ["Man erhält den Baron-Buff", "Alle Türme werden 60 s lang deaktiviert", "Der Drache wechselt sein Element"], "Das Auge beschwört den Herold, der auf Türme zustürmt und hohen Schaden verursacht."),
    (SUB_MECH, "medium", "Wie heißt die schnelle Spielvariante mit einer einzigen Lane und zufälligen Champions?", "ARAM (Heulende Schlucht)", ["URF", "Nexus Blitz", "Teamfight Tactics"], "ARAM = All Random All Mid auf der Heulenden Schlucht."),
    (SUB_MECH, "medium", "Wofür steht der Spielmodus „URF“?", "Ultra Rapid Fire", ["Ultimate Random Fight", "Unlimited Rune Frenzy", "Unranked Fast Fun"], "URF: nahezu keine Abklingzeiten, keine Kosten — der Chaos-Spaßmodus."),
    (SUB_MECH, "medium", "Welche Stufe ist die höchste im Ranglisten-System?", "Herausforderer (Challenger)", ["Großmeister", "Meister", "Diamant"], "Eisen, Bronze, Silber, Gold, Platin, Smaragd, Diamant, Meister, Großmeister, Herausforderer."),
    (SUB_MECH, "hard", "Welche Ranglisten-Stufe wurde 2023 NEU zwischen Platin und Diamant eingeführt?", "Smaragd", ["Kristall", "Obsidian", "Saphir"], "Smaragd (Emerald) kam 2023 mit dem Split-Update ins Ranglistensystem."),
    (SUB_MECH, "medium", "Wie viele Bann-Wahlen (Bans) hat jedes Team im Draft-Modus?", "5", ["3", "4", "6"], "Seit 2017 bannt jedes Team fünf Champions — zehn insgesamt."),
    (SUB_MECH, "hard", "Wie viel Gold erhält man zu Spielbeginn?", "500", ["475", "600", "300"], "Jeder Champion startet mit 500 Gold — genug für einen Doran-Gegenstand und einen Trank."),
    (SUB_MECH, "hard", "Wann spawnen die ersten Vasallen auf der Kluft der Beschwörer?", "1:05", ["0:30", "1:30", "2:00"], "Die erste Welle erscheint um 1:05 am Nexus und trifft etwa um 1:35 in der Lane-Mitte ein."),
    (SUB_MECH, "hard", "Wie viele Vasallen enthält eine normale Welle (ohne Belagerungsvasall)?", "6", ["4", "5", "8"], "Drei Nahkampf- und drei Fernkampf-Vasallen; jede dritte Welle bringt zusätzlich einen Belagerungsvasallen."),
    (SUB_MECH, "medium", "Was bewirkt „Absoluter Schaden“ (True Damage)?", "Er ignoriert Rüstung und Magieresistenz", ["Er trifft immer kritisch", "Er heilt den Angreifer", "Er kann nicht ausgewichen werden, wird aber halbiert"], "Absoluter Schaden wird durch keine Resistenz reduziert — nur durch Schilde."),
    (SUB_MECH, "medium", "Welcher Gegenstand ist das klassische Start-Item für Nahkämpfer mit Lebensraub?", "Dorans Klinge", ["Dorans Ring", "Dorans Schild", "Rubinkristall"], "Dorans Klinge gibt Angriffsschaden, Leben und Lebensraub-ähnliche Heilung."),
    (SUB_MECH, "medium", "Welche Statistik erhöht den Magieschaden von Zaubern?", "Fähigkeitsstärke (AP)", ["Angriffsschaden (AD)", "Rüstung", "Angriffstempo"], "Fähigkeitsstärke (Ability Power) skaliert Zauberschaden und Heilungen."),
    (SUB_MECH, "hard", "Was verhindert der Effekt „Grievous Wounds“ (Schwere Wunden)?", "Heilung — sie wird um 40 % reduziert", ["Bewegung", "Kritische Treffer", "Manaregeneration"], "Schwere Wunden reduzieren jegliche Heilung des Ziels um 40 %."),
    (SUB_MECH, "hard", "Wie heißt der Gegenstand, der Magiern nach dem Kauf Schwere Wunden zufügen lässt?", "Morellonomikon", ["Rabadons Todeskappe", "Lichbann", "Zhonyas Stundenglas"], "Morellonomikon verursacht bei Magieschaden Schwere Wunden."),
    (SUB_MECH, "medium", "Welcher Gegenstand macht seinen Träger für 2,5 Sekunden unverwundbar und unbeweglich (Stasis)?", "Zhonyas Stundenglas", ["Wächterengel", "Bannschleier", "Sterakhs Pegel"], "Zhonyas Stundenglas versetzt den Träger in Stasis — der Klassiker gegen Zed und Fizz."),
    (SUB_MECH, "medium", "Welcher Gegenstand lässt den Träger nach dem Tod wiederbeleben?", "Wächterengel", ["Zhonyas Stundenglas", "Frostherz", "Todestanz"], "Der Wächterengel (Guardian Angel) belebt einmal pro 5 Minuten wieder."),
    (SUB_MECH, "hard", "Welcher Gegenstand erhöht Fähigkeitsstärke prozentual (der größte AP-Multiplikator)?", "Rabadons Todeskappe", ["Leerenstab", "Nashors Zahn", "Morellonomikon"], "Rabadons Todeskappe gibt viel AP und erhöht die gesamte Fähigkeitsstärke prozentual."),
    (SUB_MECH, "hard", "Welcher Gegenstand gewährt Magiedurchdringung in Prozent?", "Leerenstab", ["Rylais Kristallzepter", "Banshees Schleier", "Rabadons Todeskappe"], "Der Leerenstab (Void Staff) durchdringt einen Teil der Magieresistenz prozentual."),
    (SUB_MECH, "medium", "Was ist ein „Gank“?", "Ein überraschender Angriff auf eine Lane, meist durch den Jungler", ["Das Zerstören eines Inhibitors", "Ein Wechsel der Lane", "Das Farmen neutraler Monster"], "Gank: der Jungler (oder ein Roamer) fällt einer Lane in den Rücken."),
    (SUB_MECH, "medium", "Was bedeutet „CS“ im LoL-Jargon?", "Creep Score — getötete Vasallen und Monster", ["Champion Select", "Critical Strike", "Control Ward Score"], "CS zählt getötete Vasallen/Monster — die wichtigste Goldquelle."),
    (SUB_MECH, "medium", "Was bedeutet „Backdoor“?", "Gegnerische Bauwerke ohne Vasallen angreifen, während die Gegner woanders sind", ["Über die Basis-Rückseite fliehen", "Einen Gank aus dem eigenen Dschungel", "Einen Turm mit dem Herold zerstören"], "Ein Backdoor ist der heimliche Angriff auf Türme oder Nexus hinter dem Rücken der Gegner."),
    (SUB_MECH, "hard", "Wie heißt der Effekt, dass ein Champion nach dem Tod eine bestimmte Zeit warten muss?", "Todeszeit (Death Timer)", ["Respawn-Sperre", "Rückzug", "Cooldown"], "Die Todeszeit steigt mit Level und Spielzeit — spät im Spiel sind es über eine Minute."),
    (SUB_MECH, "medium", "Welche Farbe hat das Team, das auf der unteren linken Seite der Karte startet?", "Blau", ["Rot", "Lila", "Grün"], "Das blaue Team startet unten links, das rote Team oben rechts."),
    (SUB_MECH, "hard", "Wie heißt der Dschungel-Buff des blauen Wächters (Blue Sentinel)?", "Mana- und Energieregeneration plus Fähigkeitstempo", ["Schaden-Verbrennung bei Angriffen", "Erhöhtes Lauftempo", "Schild pro Kill"], "Der blaue Buff (Crest of Insight) regeneriert Mana und gibt Fähigkeitstempo; der rote Buff verbrennt und verlangsamt."),
    (SUB_MECH, "medium", "Welcher Champion ist berühmt für seine Fähigkeit, Ziele mit einem Haken heranzuziehen — „Rocket Grab“?", "Blitzcrank", ["Thresh", "Nautilus", "Pyke"], "Blitzcranks Q „Rocket Grab“ ist der bekannteste Hook im Spiel; Thresh, Nautilus und Pyke haben eigene Haken."),
    (SUB_MECH, "medium", "Welcher Champion baut sich mit Q „Siphoning Strike“ unendlich viele Stacks auf?", "Nasus", ["Veigar", "Sion", "Cho'Gath"], "Nasus' Q gewinnt pro Kill dauerhaft Schaden — die berühmten Q-Stacks."),
    (SUB_MECH, "medium", "Welcher Champion sammelt Stacks mit seiner Q „Baleful Strike“ und wird dadurch immer stärker?", "Veigar", ["Nasus", "Kindred", "Thresh"], "Veigar erhält pro Kill mit Q Fähigkeitsstärke — der Tiny Master of Evil skaliert unendlich."),
    (SUB_MECH, "hard", "Welcher Champion sammelt Seelen mit seiner Laterne bzw. seinem Passiv „Damnation“?", "Thresh", ["Karthus", "Yorick", "Senna"], "Thresh sammelt Seelen für Rüstung und Fähigkeitsstärke; Senna sammelt Nebel."),
    (SUB_MECH, "hard", "Welcher Champion wird durch das Töten von Champions und Vasallen mit „Feast“ größer?", "Cho'Gath", ["Zac", "Tahm Kench", "Sion"], "Cho'Gaths R „Feast“ gibt Stacks, die ihn wachsen lassen."),
    (SUB_MECH, "medium", "Welcher Champion kann mit „Chronoshift“ einen Verbündeten nach dem Tod wiederbeleben?", "Zilean", ["Soraka", "Kayle", "Renata Glasc"], "Zileans R belebt das Ziel wieder, wenn es innerhalb der Wirkung stirbt."),
    (SUB_MECH, "medium", "Welcher Champion macht sein Team mit „Stand United“ von überall her mit einem Schild sicher?", "Shen", ["Galio", "Twisted Fate", "Pantheon"], "Shen teleportiert sich global zu einem Verbündeten und schildet ihn."),
    (SUB_MECH, "hard", "Welches Trio hat Ultimates, mit denen es über weite Distanzen direkt in Kämpfe reist?", "Twisted Fate, Shen und Pantheon", ["Zed, Fizz und Talon", "Lux, Xerath und Jinx", "Ashe, Ezreal und Draven"], "TF (Destiny), Shen (Stand United) und Pantheon (Grand Starfall) reisen über weite Distanzen."),
    (SUB_MECH, "medium", "Wie heißt Jinx' Fähigkeit, mit der sie ihre Rakete quer über die Karte schießt?", "Super Mega Death Rocket!", ["Zap!", "Flame Chompers!", "Switcheroo!"], "Jinx' R fliegt global und macht mehr Schaden an Zielen mit weniger Leben."),
    (SUB_MECH, "medium", "Welcher Champion kann mit „Wind Wall“ Geschosse blocken?", "Yasuo", ["Braum", "Samira", "Yone"], "Yasuos W blockt alle gegnerischen Geschosse; Braum blockt mit Unbreakable, Samira mit Blade Whirl."),
    (SUB_MECH, "hard", "Welcher Champion kann die Ultimate anderer Champions stehlen?", "Sylas", ["Zoe", "Viego", "Neeko"], "Sylas' R „Hijack“ kopiert die gegnerische Ultimate; Zoe stiehlt Beschwörerzauber, Viego übernimmt Champions."),
    (SUB_MECH, "medium", "Welcher Champion kann sich in andere Champions verwandeln (mit ihrem Aussehen)?", "Neeko", ["Sylas", "LeBlanc", "Shaco"], "Neekos Passive „Inherent Glamour“ lässt sie wie ein Verbündeter aussehen."),
    (SUB_MECH, "medium", "Welcher Champion kann mit seiner Ultimate fünf Sekunden lang nicht sterben?", "Tryndamere", ["Olaf", "Garen", "Darius"], "Tryndameres „Undying Rage“ verhindert seinen Tod für fünf Sekunden."),
    (SUB_MECH, "medium", "Welcher Champion kann Wände mit „Riftwalk“ überspringen und wird mit jedem Level mächtiger gegen Magier?", "Kassadin", ["Ezreal", "Katarina", "Talon"], "Kassadins R ist ein kurzer Teleport mit steigenden Manakosten."),
    (SUB_MECH, "easy", "Wie heißt der Teddybär, den Annie mit ihrer Ultimate beschwört?", "Tibbers", ["Willump", "Skaarl", "Daisy"], "Tibbers ist Annies Bär — Willump gehört Nunu, Skaarl Kled, Daisy Ivern."),
    (SUB_MECH, "easy", "Welcher Champion reitet auf einem Yeti?", "Nunu", ["Kled", "Sejuani", "Rell"], "Nunu reitet auf dem Yeti Willump; Kled reitet Skaarl, Sejuani den Eber Bristle."),
    (SUB_MECH, "medium", "Wie heißt Kleds Reittier?", "Skaarl", ["Bristle", "Willump", "Tibbers"], "Skaarl, die feige Echse, ist Kleds Reittier und zugleich seine Ressource."),
    (SUB_MECH, "medium", "Wie heißt Sejuanis Eber?", "Bristle", ["Skaarl", "Willump", "Kog"], "Sejuani reitet den Eber Bristle."),
    (SUB_MECH, "medium", "Welcher Champion kann sich in einen Cougar (Puma) verwandeln?", "Nidalee", ["Rengar", "Neeko", "Udyr"], "Nidalees R „Aspect of the Cougar“ wechselt in die Puma-Form."),
    (SUB_MECH, "medium", "Welcher Champion kann sich in eine Spinne verwandeln?", "Elise", ["Zyra", "Kha'Zix", "Nidalee"], "Elises R wechselt zwischen Menschen- und Spinnenform."),
    (SUB_MECH, "medium", "Welcher Champion kann sich als Yordle in ein riesiges Monster (Mega-Form) verwandeln?", "Gnar", ["Rumble", "Kled", "Teemo"], "Gnar wird bei voller Wut zu Mega Gnar."),
    (SUB_MECH, "medium", "Welche Katze kann sich an Verbündete heften und mit ihnen mitreisen?", "Yuumi", ["Rengar", "Nidalee", "Kindred"], "Yuumis W „You and Me!“ hängt sie an einen Verbündeten."),
    (SUB_MECH, "medium", "Welcher Champion kann sich mit „Playful / Trickster“ auf seinem Dreizack unangreifbar machen?", "Fizz", ["Nami", "Pyke", "Nautilus"], "Fizz springt mit E auf seinen Dreizack und wird für den Moment unangreifbar."),
    (SUB_MECH, "hard", "Wie viele Champions gab es beim Start von League of Legends im Oktober 2009?", "40", ["20", "60", "17"], "Zum Release am 27. Oktober 2009 standen 40 Champions zur Verfügung."),
    (SUB_MECH, "medium", "Wie oft kann man Blitz (Flash) pro Spiel verwenden?", "Beliebig oft — nur die Abklingzeit begrenzt", ["Genau dreimal", "Einmal pro Level", "Fünfmal"], "Beschwörerzauber haben keine Nutzungsgrenze, nur Abklingzeiten."),
    (SUB_MECH, "medium", "Welche Statistik reduziert physischen Schaden?", "Rüstung", ["Magieresistenz", "Zähigkeit", "Lebensraub"], "Rüstung mindert physischen, Magieresistenz magischen Schaden; Zähigkeit verkürzt Kontrolleffekte."),
    (SUB_MECH, "hard", "Was reduziert die Statistik „Zähigkeit“ (Tenacity)?", "Die Dauer von Kontrolleffekten wie Betäubungen", ["Erlittenen Schaden", "Die Todeszeit", "Abklingzeiten"], "Zähigkeit verkürzt Betäubungen, Verlangsamungen und ähnliche Effekte — nicht Hochschleudern."),
    (SUB_MECH, "hard", "Welcher Kontrolleffekt kann NICHT durch Zähigkeit verkürzt werden?", "Hochschleudern (Knock-up)", ["Betäubung", "Verlangsamung", "Angst"], "Luftbewegungen wie Knock-ups und Verschiebungen ignorieren Zähigkeit."),
    (SUB_MECH, "medium", "Was bewirkt Kindreds Ultimate „Lamb's Respite“?", "Niemand in der Zone kann sterben — auch Gegner nicht", ["Kindred wird unsichtbar", "Alle Gegner werden verlangsamt", "Verbündete werden vollständig geheilt"], "Kindreds R verhindert für alle in der Zone das Sterben — Freund wie Feind."),
    (SUB_MECH, "medium", "Was bedeutet „Ace“ im Spiel?", "Alle fünf Gegner sind gleichzeitig tot", ["Ein Spieler hat 5 Kills", "Der erste Turm fiel", "Ein Team hat 100 CS"], "Ace: das gesamte gegnerische Team ist ausgeschaltet — der Moment für Objectives."),
    (SUB_MECH, "hard", "Wie heißt das Ranglisten-Format, bei dem man Ligapunkte (LP) sammelt, um aufzusteigen?", "Solo/Duo-Rangliste", ["Flex 3v3", "Clash", "Arena"], "In Solo/Duo sammelt man LP; bei 100 LP steigt man eine Division auf."),
    (SUB_MECH, "medium", "Wie viele Spieler dürfen in „Flex“ gemeinsam als Vorgruppe antreten?", "Bis zu fünf", ["Nur zwei", "Nur drei", "Genau vier"], "Flex erlaubt Gruppen von 1, 2, 3 oder 5 Spielern."),
    (SUB_MECH, "hard", "Welches Turnier-Format bietet Riot regelmäßig für organisierte Amateurteams im Client an?", "Clash", ["Arena", "Nexus Blitz", "Doom Bots"], "Clash ist das Turnier-Wochenende im Client für 5er-Teams."),
    (SUB_MECH, "medium", "Wie heißt der 2v2v2v2-Modus, der 2023 eingeführt wurde?", "Arena", ["Nexus Blitz", "URF", "Tempest"], "Arena: vier Zweierteams kämpfen in Runden mit Augments."),
    (SUB_MECH, "medium", "Welche Farbe hat das Team, dessen Basis oben rechts liegt?", "Rot", ["Blau", "Gelb", "Lila"], "Das rote Team startet oben rechts auf der Kluft."),
    (SUB_MECH, "medium", "Wo befindet sich der Baron Nashor auf der Karte?", "Im oberen Fluss (Seite des roten Teams näher)", ["Im unteren Fluss", "In der Mitte der Midlane", "In der Basis"], "Baron ist oben im Fluss, die Drachengrube unten."),
    (SUB_MECH, "medium", "Wo befindet sich die Drachengrube?", "Im unteren Fluss", ["Im oberen Fluss", "Hinter der Toplane", "In der Midlane"], "Drache unten, Baron oben — die zwei großen Objectives."),
    (SUB_MECH, "hard", "Wie viele Sekunden liegen zwischen zwei Vasallenwellen?", "30", ["20", "45", "60"], "Alle 30 Sekunden startet eine neue Welle."),
    (SUB_MECH, "medium", "Was ist „Last Hitting“?", "Vasallen mit dem letzten Treffer töten, um das Gold zu bekommen", ["Den letzten Turm zerstören", "Einen Gegner mit 1 Leben fliehen lassen", "Als Letzter im Teamfight sterben"], "Gold bekommt nur, wer den tödlichen Treffer auf einen Vasallen setzt."),
    (SUB_MECH, "medium", "Was bedeutet „Freeze“ in der Lane?", "Die Vasallenwelle nahe dem eigenen Turm halten, damit der Gegner nicht sicher farmen kann", ["Einen Gegner mit Eis-Fähigkeiten festhalten", "Eine Pause im Spiel", "Den Bildschirm einfrieren"], "Beim Freeze hält man die Welle vor dem eigenen Turm und zwingt den Gegner nach vorne."),
    (SUB_MECH, "hard", "Wie viele Inhibitoren hat jedes Team?", "3", ["1", "2", "5"], "Einer pro Lane — zerstörte Inhibitoren spawnen Super-Vasallen."),
    (SUB_MECH, "medium", "Was passiert, wenn ein Inhibitor zerstört wird?", "Das gegnerische Team bekommt Super-Vasallen auf dieser Lane", ["Der Nexus wird sofort angreifbar", "Alle Türme des Teams fallen", "Man gewinnt 1000 Gold"], "Super-Vasallen sind stärker und tanken Türme — bis der Inhibitor nach fünf Minuten neu erscheint."),
    (SUB_MECH, "hard", "Wie lange bleibt ein zerstörter Inhibitor zerstört, bevor er neu erscheint?", "5 Minuten", ["2 Minuten", "8 Minuten", "Für immer"], "Inhibitoren respawnen nach fünf Minuten."),
    # Lore
    (SUB_LORE, "easy", "Wie heißt die Welt, in der die Geschichten von League of Legends spielen?", "Runeterra", ["Valoran", "Azeroth", "Tamriel"], "Runeterra ist die Welt; Valoran ist ihr größter Kontinent."),
    (SUB_LORE, "medium", "Wie heißt der größte Kontinent Runeterras?", "Valoran", ["Shurima", "Ionia", "Camavor"], "Valoran umfasst u. a. Demacia, Noxus, den Freljord, Piltover und Zaun."),
    (SUB_LORE, "easy", "Welche zwei Städte bilden zusammen die „Zwillingsstädte“ — oben Fortschritt, unten Chemtech?", "Piltover und Zaun", ["Demacia und Noxus", "Bilgewater und die Schatteninseln", "Ionia und Shurima"], "Piltover liegt oben, Zaun darunter — der Schauplatz der Serie Arcane."),
    (SUB_LORE, "medium", "Wie heißt das magische Material, mit dem Demacia Magie unterdrückt?", "Petricit", ["Hextech", "Chemtech", "Weltrunen"], "Petricit ist ein Stein, der Magie absorbiert — Demacias Mauern bestehen daraus."),
    (SUB_LORE, "medium", "Wie heißt die Technologie Piltovers, die Magie mit Kristallen nutzbar macht?", "Hextech", ["Chemtech", "Petricit", "Schattenmagie"], "Hextech verbindet Kristalle mit Technik — Chemtech ist Zauns schmutzige Variante."),
    (SUB_LORE, "medium", "Wer ist Garens Schwester?", "Lux", ["Sona", "Fiora", "Quinn"], "Luxanna Crownguard ist Garens jüngere Schwester — eine heimliche Magierin in Demacia."),
    (SUB_LORE, "medium", "Welche zwei Champions sind Schwestern, deren Geschichte in Arcane erzählt wird?", "Vi und Jinx", ["Lux und Garen", "Kayle und Morgana", "Xayah und Rakan"], "Vi und Powder/Jinx wuchsen gemeinsam in Zaun auf."),
    (SUB_LORE, "medium", "Welche zwei Champions sind Schwestern und zugleich rivalisierende Aspekte?", "Kayle und Morgana", ["Diana und Leona", "Vi und Jinx", "Lissandra und Ashe"], "Kayle und Morgana sind Zwillinge — Gerechtigkeit gegen Vergebung."),
    (SUB_LORE, "medium", "Wie heißt der Bruder von Yasuo?", "Yone", ["Zed", "Shen", "Kayn"], "Yasuo wurde beschuldigt, seinen Meister getötet zu haben; im Duell tötete er seinen Bruder Yone, der später aus dem Geisterreich zurückkehrte."),
    (SUB_LORE, "medium", "Wer ist der Bruder von Darius?", "Draven", ["Swain", "Sion", "Talon"], "Darius und Draven sind Brüder aus Noxus — der General und der Henker."),
    (SUB_LORE, "medium", "Welches Paar aus Ionia ist verheiratet?", "Xayah und Rakan", ["Ahri und Yasuo", "Irelia und Zed", "Karma und Shen"], "Die Vastaya Xayah und Rakan sind das bekannteste Paar Runeterras."),
    (SUB_LORE, "medium", "Wer ist der „Ruined King“ (Verderbte König)?", "Viego", ["Mordekaiser", "Karthus", "Thresh"], "Viego, König von Camavor, löste durch seine Trauer die Verderbnis der Schatteninseln aus."),
    (SUB_LORE, "hard", "Wie hieß Viegos Frau, deren Tod die Verderbnis auslöste?", "Isolde", ["Senna", "Gwen", "Kalista"], "Isolde wurde vergiftet; Viegos Versuch, sie zurückzuholen, schuf die Schatteninseln. Gwen ist ihre lebendig gewordene Puppe."),
    (SUB_LORE, "medium", "Wer ist Lucians Frau, die er aus Threshs Laterne befreite?", "Senna", ["Sona", "Karma", "Lux"], "Senna war jahrelang in Threshs Laterne gefangen, bis Lucian sie befreite."),
    (SUB_LORE, "medium", "Welche Waffe teilt sich Kayn mit dem Darkin Rhaast?", "Eine Sense", ["Ein Schwert", "Ein Bogen", "Ein Speer"], "Rhaast ist der Darkin in Kayns Sense — beide ringen um die Kontrolle."),
    (SUB_LORE, "hard", "In welcher Waffe steckt der Darkin Varus?", "In einem Bogen", ["In einer Klinge", "In einer Sense", "In einem Dolch"], "Varus ist ein Darkin-Bogen, getragen von den Ionier-Jägern Valmar und Kai."),
    (SUB_LORE, "medium", "Wer ist der Kaiser von Shurima, der nach Jahrtausenden wiederauferstand?", "Azir", ["Nasus", "Xerath", "Renekton"], "Azir stieg beim Versuch der Aufstiegs-Zeremonie auf und erweckte Shurima."),
    (SUB_LORE, "medium", "Welche zwei Aufgestiegenen sind Brüder, von denen einer den anderen im Wahnsinn jagt?", "Nasus und Renekton", ["Azir und Xerath", "Aatrox und Varus", "Pantheon und Taric"], "Renekton opferte sich, um Xerath einzusperren, und verfiel dem Wahnsinn — sein Bruder Nasus sucht ihn."),
    (SUB_LORE, "hard", "Wer verriet Azir bei seinem Aufstieg und stahl die Macht?", "Xerath", ["Nasus", "Renekton", "Sivir"], "Xerath, Azirs Sklave und Magier, sabotierte den Aufstieg."),
    (SUB_LORE, "hard", "Welcher Champion ist eine Nachfahrin Azirs?", "Sivir", ["Taliyah", "Samira", "Akshan"], "Sivir trägt das Blut der shurimanischen Kaiser — ihr Blut erweckte Azir."),
    (SUB_LORE, "medium", "Welche Champions sind die drei Schwestern des Freljord aus der Legende?", "Avarosa, Serylda und Lissandra", ["Ashe, Sejuani und Anivia", "Lissandra, Ashe und Braum", "Anivia, Ornn und Volibear"], "Lissandra ist die letzte der drei Schwestern; Ashe folgt Avarosa, Sejuani Serylda."),
    (SUB_LORE, "hard", "Wie heißen die Wächter des Freljord, die Lissandra einst herbeirief?", "Die Beobachter (Watchers)", ["Die Darkin", "Die Aspekte", "Die Leerenmutter"], "Die Beobachter sind Wesen der Leere, von Lissandra unter ewigem Eis gefangen."),
    (SUB_LORE, "medium", "Welche Halbgötter des Freljord sind Brüder und Rivalen?", "Ornn und Volibear", ["Braum und Tryndamere", "Anivia und Udyr", "Olaf und Gragas"], "Ornn, der Schmied, und Volibear, der Sturm, sind Geschwister — wie auch Anivia."),
    (SUB_LORE, "medium", "Welcher Champion ist Noxus' Großgeneral und Anführer des Trifarix?", "Swain", ["Darius", "Sion", "LeBlanc"], "Jericho Swain führt Noxus; das Trifarix besteht aus Vision (Swain), Stärke (Darius) und Schläue (LeBlanc)."),
    (SUB_LORE, "hard", "Wie heißt die Geheimorganisation, die LeBlanc anführt?", "Die Schwarze Rose", ["Der Eiserne Orden", "Die Sentinels", "Die Schattenmeister"], "Die Schwarze Rose ist Noxus' geheimer Magier-Zirkel."),
    (SUB_LORE, "medium", "Wer ist Zeds ehemaliger Meister und Shens Vater?", "Kusho", ["Jhin", "Doran", "Karma"], "Meister Kusho führte den Kinkou-Orden; Zed ermordete ihn und gründete den Schattenorden."),
    (SUB_LORE, "hard", "Welchen Serienmörder jagten Zed, Shen und Kusho gemeinsam?", "Jhin (Khada Jhin)", ["Talon", "Pyke", "Shaco"], "Jhin, der Goldene Dämon, wurde gefasst — und später von Ionias Rat wieder freigelassen."),
    (SUB_LORE, "medium", "Welcher Orden hütet das Gleichgewicht in Ionia und wird von Shen geführt?", "Kinkou-Orden", ["Schattenorden", "Wuju-Orden", "Sentinels des Lichts"], "Shen ist das Auge der Dämmerung des Kinkou-Ordens; Zed führt den Schattenorden."),
    (SUB_LORE, "medium", "Welche Insel-Nation wurde von Noxus überfallen — mit Irelia als Widerstandskämpferin?", "Ionia", ["Demacia", "Bilgewater", "Bandle City"], "Die noxianische Invasion Ionias ist der zentrale Konflikt in Irelias, Karmas und Yasuos Geschichte."),
    (SUB_LORE, "medium", "Welche Stadt ist die Heimat der Piraten und der Familie Fortune?", "Bilgewater", ["Piltover", "Zaun", "Ionia"], "Sarah Fortune jagt in Bilgewater den Piratenkönig Gangplank."),
    (SUB_LORE, "hard", "Wer tötete Miss Fortunes Mutter?", "Gangplank", ["Pyke", "Graves", "Twisted Fate"], "Gangplank ermordete Sarahs Mutter — ihre Rache treibt sie an."),
    (SUB_LORE, "hard", "Welche zwei Champions sind ein berühmtes Gauner-Duo aus Bilgewater?", "Graves und Twisted Fate", ["Pyke und Nautilus", "Gangplank und Illaoi", "Fizz und Nami"], "Malcolm Graves und Tobias Felix (TF) sind Partner mit langer, komplizierter Geschichte."),
    (SUB_LORE, "hard", "Welchem Gott dient Illaoi?", "Nagakabouros", ["Dem Ertrunkenen", "Der Sonne", "Der Leere"], "Illaoi ist Priesterin des Krakengottes Nagakabouros — Gott des Lebens und der Bewegung."),
    (SUB_LORE, "medium", "Wie heißt die Erscheinung, die von den Schatteninseln ausgeht und Seelen raubt?", "Der Schwarze Nebel", ["Der Eisige Hauch", "Der Ruin-Sturm", "Die Leere"], "Der Schwarze Nebel bringt jährlich die Heimsuchung über Bilgewater."),
    (SUB_LORE, "medium", "Welcher Champion ist die Wächterin und Puppe, die aus Isoldes Nähzeug lebendig wurde?", "Gwen", ["Yuumi", "Neeko", "Zoe"], "Gwen, die heilige Näherin, entstand aus einer Puppe, die Isolde einst nähte."),
    (SUB_LORE, "hard", "Aus welchem Reich stammte Viego, der Verderbte König?", "Camavor", ["Demacia", "Shurima", "Bilgewater"], "Camavor lag jenseits des Meeres — ein Königreich, das mit Viego unterging."),
    (SUB_LORE, "medium", "Welcher Champion ist Zauns berühmtester Wissenschaftler mit der Vision der „Glorious Evolution“?", "Viktor", ["Jayce", "Singed", "Heimerdinger"], "Viktor will die Menschheit durch Technik vervollkommnen — sein Gegenspieler ist Jayce."),
    (SUB_LORE, "medium", "Welcher Zaun-Chemiker erschuf Warwick durch grausame Experimente?", "Singed", ["Viktor", "Mundo", "Renata Glasc"], "Singed verwandelte den Mann Warwick in die Chimäre."),
    (SUB_LORE, "hard", "Wie heißt der Yordle-Wissenschaftler, der Piltovers Akademie prägte?", "Heimerdinger", ["Corki", "Ziggs", "Rumble"], "Cecil B. Heimerdinger ist Erfinder und Professor in Piltover."),
    (SUB_LORE, "medium", "Welcher Champion ist der „Kartenspieler“ aus Bilgewater, der mit Karten teleportiert?", "Twisted Fate", ["Graves", "Pyke", "Gangplank"], "Tobias Felix — Twisted Fate — ist der Kartenmeister."),
    (SUB_LORE, "medium", "Aus welcher Familie stammt Lux?", "Crownguard", ["Laurent", "Buvelle", "Lightshield"], "Luxanna Crownguard; Fiora ist eine Laurent, Sona eine Buvelle, Jarvan ein Lightshield."),
    (SUB_LORE, "hard", "Wie heißt Demacias Königsfamilie?", "Lightshield", ["Crownguard", "Laurent", "Medarda"], "Jarvan IV. ist Prinz aus dem Haus Lightshield."),
    (SUB_LORE, "hard", "Welcher Champion wurde als Magier in Demacia eingesperrt und führt nun den Aufstand der Magier?", "Sylas", ["Xerath", "Ryze", "Vladimir"], "Sylas von Dregbourne brach aus dem Kerker aus und kämpft gegen Demacias Magiehass."),
    (SUB_LORE, "medium", "Welcher Champion ist eine Vastaya-Füchsin, die Lebensessenz raubt?", "Ahri", ["Nidalee", "Neeko", "Xayah"], "Ahri, die neunschwänzige Füchsin, sucht in Ionia nach ihrer Herkunft."),
    (SUB_LORE, "medium", "Wie heißen die Geistwesen, zu denen Ahri, Xayah oder Rakan gehören?", "Vastaya", ["Yordle", "Darkin", "Aspekte"], "Vastaya sind chimärische Geistwesen Ionias."),
    (SUB_LORE, "medium", "Was sind die Darkin ursprünglich gewesen?", "Aufgestiegene Krieger Shurimas, die in Waffen gebannt wurden", ["Dämonen aus der Leere", "Yordle-Magier", "Piraten aus Bilgewater"], "Die Darkin waren Aufgestiegene, die nach dem Leerenkrieg in Waffen eingesperrt wurden."),
    (SUB_LORE, "hard", "Welcher Champion ist die „Leerenmutter“ / Kaiserin der Leere?", "Bel'Veth", ["Kai'Sa", "Rek'Sai", "Vel'Koz"], "Bel'Veth entstand aus dem Untergang der Stadt Belveth in Shurima."),
    (SUB_LORE, "medium", "Welche Stadt ist die Heimat der Yordles?", "Bandle City", ["Piltover", "Ixtal", "Zaun"], "Bandle City liegt im Geisterreich, erreichbar über versteckte Portale."),
    (SUB_LORE, "medium", "Welcher Champion ist der „Wandernde Hüter“, der Runeterras Gleichgewicht bewahrt?", "Bard", ["Zilean", "Kindred", "Aurelion Sol"], "Bard sammelt Chimes und Meeps und hält das kosmische Gleichgewicht."),
    (SUB_LORE, "medium", "Wer verkörpert den Tod in Runeterra als Lamm und Wolf?", "Kindred", ["Thresh", "Karthus", "Kalista"], "Kindred: das Lamm bringt den sanften Tod, der Wolf jagt die Flüchtenden."),
    (SUB_LORE, "hard", "Welcher Sterndrache wurde von den Aspekten Targons versklavt?", "Aurelion Sol", ["Shyvana", "Smolder", "Anivia"], "Aurelion Sol trägt eine Krone, die ihn an Targon bindet."),
    (SUB_LORE, "medium", "Welcher Champion ist der Aspekt der Sonne?", "Leona", ["Diana", "Zoe", "Taric"], "Leona trägt den Aspekt der Sonne, Diana den des Mondes, Zoe den der Dämmerung, Taric den Schutz."),
    (SUB_LORE, "medium", "Welcher Champion ist der Aspekt des Mondes?", "Diana", ["Leona", "Aphelios", "Soraka"], "Diana ist Aspekt des Mondes; Aphelios ist ein Waffenträger des Mondkults."),
    (SUB_LORE, "hard", "Wie heißt der Sterbliche, der nach dem Tod des Aspekts des Krieges als Pantheon weiterkämpft?", "Atreus", ["Kusho", "Valmar", "Jarvan"], "Atreus trug den Aspekt des Krieges; Aatrox tötete den Aspekt — Atreus kämpft seither mit sterblichem Willen als Pantheon."),
    (SUB_LORE, "hard", "Wie heißt Apheliosʼ Schwester, die über ihn wacht?", "Alune", ["Isolde", "Serylda", "Mihira"], "Alune leitet Aphelios aus dem Geisterreich — daher seine Waffenwechsel."),
    (SUB_LORE, "medium", "Welches Königreich ist bekannt für seinen Hass auf Magie und seine weißen Mauern?", "Demacia", ["Noxus", "Ionia", "Targon"], "Demacia, gegründet von Flüchtlingen der Runenkriege, misstraut jeder Magie."),
    (SUB_LORE, "hard", "Wie nennt man die großen Kriege, in denen Weltrunen Runeterra fast zerstörten?", "Die Runenkriege", ["Die Leerenkriege", "Die Sonnenkriege", "Die Eiskriege"], "Ryze sammelt seither die Weltrunen ein, um neue Runenkriege zu verhindern."),
    (SUB_LORE, "medium", "Welcher Champion reist durch Runeterra, um die gefährlichen Weltrunen einzusammeln?", "Ryze", ["Zilean", "Bard", "Xerath"], "Ryze, der Runenmagier, versteckt die Weltrunen vor Machthungrigen."),
    (SUB_LORE, "hard", "Wie nennen die Bewohner Ionias ihre Heimat?", "Die Ersten Länder", ["Das Ewige Reich", "Die Sonneninseln", "Das Geisterland"], "Ionia ist ein Archipel östlich von Valoran — seine Bewohner nennen es „Die Ersten Länder“."),
    (SUB_LORE, "hard", "Welche Stadt in Ixtal ist die verborgene Hauptstadt der Elementarmagie?", "Ixaocan", ["Nazumah", "Helia", "Qiyanas Hof"], "Ixaocan ist Qiyanas Heimatstadt in den Dschungeln Ixtals."),
    (SUB_LORE, "hard", "Wie heißt die Stadt in Shurima, aus der K'Sante stammt?", "Nazumah", ["Bel'Veth", "Icathia", "Ixaocan"], "Nazumah ist eine unabhängige Oasenstadt, die K'Sante als Champion verteidigt."),
    (SUB_LORE, "hard", "Welche untergegangene Stadt war einst Sitz der Gelehrten und wurde zu den Schatteninseln?", "Helia", ["Camavor", "Icathia", "Nazumah"], "Auf den Gesegneten Inseln lag Helia; Viegos Ritual verwandelte sie in die Schatteninseln."),
    (SUB_LORE, "hard", "Welches Land öffnete als erstes ein Tor zur Leere und wurde dabei vernichtet?", "Icathia", ["Camavor", "Helia", "Nazumah"], "Icathia rebellierte gegen Shurima und rief die Leere — das Ende der Stadt."),
    # Culture: skins, music, Arcane, Riot
    (SUB_KULTUR, "easy", "Welche Firma entwickelt League of Legends?", "Riot Games", ["Blizzard", "Valve", "Ubisoft"], "Riot Games wurde 2006 in Los Angeles gegründet."),
    (SUB_KULTUR, "medium", "In welchem Jahr erschien League of Legends?", "2009", ["2007", "2011", "2012"], "Release: 27. Oktober 2009."),
    (SUB_KULTUR, "medium", "Wer gründete Riot Games?", "Brandon Beck und Marc Merrill", ["Gabe Newell und Mike Harrington", "Tim Sweeney und Mark Rein", "Markus Persson und Jens Bergensten"], "Beck und Merrill gründeten Riot 2006 in Los Angeles."),
    (SUB_KULTUR, "medium", "Welchem Konzern gehört Riot Games vollständig?", "Tencent", ["Microsoft", "Sony", "Netflix"], "Tencent übernahm 2011 die Mehrheit und 2015 den Rest von Riot Games."),
    (SUB_KULTUR, "medium", "Welches Spiel wurde als Vorbild von League of Legends genannt — eine Warcraft-III-Mod?", "Defense of the Ancients (DotA)", ["Counter-Strike", "StarCraft", "Age of Empires"], "LoL entstand aus der Idee, DotA als eigenständiges Spiel weiterzuentwickeln."),
    (SUB_KULTUR, "medium", "Wie heißt die Netflix-Serie im LoL-Universum über Vi und Jinx?", "Arcane", ["Legends of Runeterra", "Ruined King", "Convergence"], "Arcane (Staffel 1: 2021, Staffel 2: 2024) spielt in Piltover und Zaun."),
    (SUB_KULTUR, "medium", "Welches Animationsstudio produzierte Arcane?", "Fortiche", ["Pixar", "Studio Ghibli", "Illumination"], "Fortiche Production aus Paris animierte beide Staffeln."),
    (SUB_KULTUR, "medium", "Wie heißt der Song von Imagine Dragons aus dem Arcane-Intro?", "Enemy", ["Warriors", "Believer", "Legends Never Die"], "„Enemy“ (Imagine Dragons feat. JID) ist das Titellied von Arcane; „Warriors“ war der Worlds-Song 2014."),
    (SUB_KULTUR, "hard", "Welche Schauspielerin spricht Jinx in Arcane (englische Fassung)?", "Ella Purnell", ["Hailee Steinfeld", "Katie Leung", "Toks Olagundoye"], "Ella Purnell spricht Jinx, Hailee Steinfeld Vi, Katie Leung Caitlyn."),
    (SUB_KULTUR, "hard", "Wer spricht Vi in der englischen Fassung von Arcane?", "Hailee Steinfeld", ["Ella Purnell", "Katie Leung", "Mia Sinclair Jenness"], "Hailee Steinfeld leiht Vi ihre Stimme."),
    (SUB_KULTUR, "hard", "Wie heißt der Antagonist der ersten Arcane-Staffel, Jinx' Ziehvater in Zaun?", "Silco", ["Vander", "Singed", "Marcus"], "Silco führt Zauns Unterwelt und nimmt Powder als Jinx unter seine Fittiche."),
    (SUB_KULTUR, "hard", "Wie heißt der Ziehvater von Vi und Powder in Arcane, der später zu Warwick wird?", "Vander", ["Silco", "Benzo", "Sevika"], "Vander wird von Singed zu Warwick gemacht — Staffel 2 zeigt ihn als Bestie."),
    (SUB_KULTUR, "medium", "In welchem Jahr erschien die erste Staffel von Arcane?", "2021", ["2019", "2020", "2022"], "Arcane startete im November 2021 auf Netflix."),
    (SUB_KULTUR, "medium", "Welches Ratsmitglied aus Arcane wurde 2025 als Champion spielbar?", "Mel", ["Ambessa", "Vander", "Silco"], "Mel Medarda erschien im Januar 2025, ihre Mutter Ambessa bereits im November 2024."),
    (SUB_KULTUR, "medium", "Wie heißt die virtuelle K-Pop-Gruppe aus LoL-Champions?", "K/DA", ["True Damage", "Pentakill", "Heartsteel"], "K/DA debütierte 2018 mit „POP/STARS“ bei den Worlds."),
    (SUB_KULTUR, "medium", "Welche vier Champions bildeten die ursprüngliche K/DA-Besetzung?", "Ahri, Akali, Evelynn und Kai'Sa", ["Ahri, Lux, Jinx und Sona", "Akali, Yasuo, Ekko und Senna", "Seraphine, Miss Fortune, Vayne und Zoe"], "K/DA: Ahri, Akali, Evelynn, Kai'Sa — Seraphine kam 2020 als Gast dazu."),
    (SUB_KULTUR, "medium", "Wie hieß die Debütsingle von K/DA?", "POP/STARS", ["MORE", "GIANTS", "Legends Never Die"], "„POP/STARS“ erschien 2018 zur Worlds-Eröffnung."),
    (SUB_KULTUR, "hard", "Welche Hip-Hop-Skin-Gruppe mit Ekko, Qiyana, Senna, Akali und Yasuo stellte Riot 2019 vor?", "True Damage", ["Heartsteel", "K/DA", "Pentakill"], "True Damage debütierte 2019 mit „GIANTS“."),
    (SUB_KULTUR, "medium", "Wie heißt die Metal-Band aus LoL-Champions?", "Pentakill", ["True Damage", "K/DA", "Heartsteel"], "Pentakill: Karthus, Mordekaiser, Olaf, Sona, Yorick, Kayle — später auch Viego."),
    (SUB_KULTUR, "hard", "Welche Boyband-Skinreihe stellte Riot 2023 vor (u. a. Kayn, Ezreal, Sett)?", "Heartsteel", ["True Damage", "K/DA", "Pentakill"], "Heartsteel: Kayn, Ezreal, Sett, Aphelios, Yone und K'Sante."),
    (SUB_KULTUR, "medium", "Zu welcher Skinreihe gehören magische Mädchen wie Lux, Jinx und Ahri mit Sternen-Kostümen?", "Sternenwächter (Star Guardian)", ["PROJECT", "Blutmond", "Odyssee"], "Star Guardian ist Riots Magical-Girl-Reihe."),
    (SUB_KULTUR, "medium", "Zu welcher Skinreihe gehören die futuristischen Cyborg-Skins mit Visieren (Yasuo, Zed, Lucian)?", "PROJECT", ["Pulsfeuer", "Sternenwächter", "Arcade"], "PROJECT ist die Cyberpunk-Reihe — PROJECT: Yasuo war der erste."),
    (SUB_KULTUR, "hard", "Welche Skinreihe zeigt Champions als Cowboys und Dämonen im Wilden Westen?", "High Noon", ["Blutmond", "Kriegsgott", "Odyssee"], "High Noon: Lucian, Thresh, Yasuo, Ashe, Senna …"),
    (SUB_KULTUR, "hard", "Welche Skinreihe verwandelt Champions in 8-Bit-Videospielfiguren?", "Arcade", ["PROJECT", "Pulsfeuer", "Battle Academia"], "Arcade Sona, Arcade Miss Fortune, Arcade Ahri — und die Gegenspieler „Battle Boss“."),
    (SUB_KULTUR, "hard", "Welcher Skin gilt als einer der seltensten, weil er nur zum Launch/Beta verteilt wurde — der schwarze Alistar?", "Black Alistar", ["Silver Kayle", "Rusty Blitzcrank", "Championship Riven"], "Black Alistar gab es nur für Vorbesteller der Collector's Edition."),
    (SUB_KULTUR, "hard", "Welche Skin-Reihe bekommt das Siegerteam der Worlds jedes Jahr — mit selbst gewählten Champions?", "Weltmeister-Skins (z. B. SKT T1 Zed)", ["Victorious-Skins", "Prestige-Skins", "Challenger-Skins"], "Jedes Siegerteam gestaltet eine eigene Skin-Reihe; Victorious-Skins gibt es für die Ranglisten-Saison."),
    (SUB_KULTUR, "medium", "Welchen Skin bekommen Spieler am Ende einer Saison, wenn sie mindestens Gold erreicht haben (bis 2022 klassisch)?", "Victorious-Skin", ["Prestige-Skin", "Weltmeister-Skin", "Ultimativer Skin"], "Der Victorious-Skin (z. B. Victorious Jarvan IV 2011) belohnt die Ranglisten-Saison."),
    (SUB_KULTUR, "medium", "Wie heißt das Autobattler-Spiel von Riot, das im LoL-Client startete?", "Teamfight Tactics", ["Legends of Runeterra", "Wild Rift", "Valorant"], "TFT erschien 2019 als Modus im LoL-Client."),
    (SUB_KULTUR, "medium", "Wie heißt die Mobile-Version von League of Legends?", "Wild Rift", ["League Mobile", "Runeterra GO", "Pocket Rift"], "League of Legends: Wild Rift erschien 2020 für Handys."),
    (SUB_KULTUR, "medium", "Welches Kartenspiel im LoL-Universum veröffentlichte Riot 2020?", "Legends of Runeterra", ["Hearthstone", "Gwent", "Artifact"], "Legends of Runeterra ist Riots digitales Sammelkartenspiel."),
    (SUB_KULTUR, "hard", "Wie heißt das rundenbasierte Rollenspiel um Miss Fortune, Illaoi, Braum, Yasuo, Ahri und Pyke (2021)?", "Ruined King: A League of Legends Story", ["Convergence", "Song of Nunu", "Mageseeker"], "Ruined King von Airship Syndicate erschien 2021."),
    (SUB_KULTUR, "hard", "Wie heißt das Spiel von Riot Forge, in dem man Ekko durch Zaun springt und die Zeit zurückdreht?", "Convergence", ["Ruined King", "Song of Nunu", "The Mageseeker"], "Convergence: A League of Legends Story (2023) erzählt Ekkos Geschichte."),
    (SUB_KULTUR, "medium", "Wie heißt der Taktik-Shooter von Riot Games?", "Valorant", ["Overwatch", "Apex Legends", "Counter-Strike"], "Valorant erschien 2020 — kein LoL-Spiel, aber Riots zweiter großer Titel."),
    (SUB_KULTUR, "medium", "Was bedeutet die Abkürzung „LEC“?", "League of Legends EMEA Championship", ["League European Cup", "Legends Esports Circuit", "League Elite Competition"], "Die LEC ist die europäische Topliga (früher EU LCS), seit 2023 EMEA."),
    (SUB_KULTUR, "medium", "Was bedeutet „LCK“?", "League of Legends Champions Korea", ["League Champions Kingdom", "Legends Challenge Korea", "League Cup Korea"], "Die LCK ist die südkoreanische Liga — Heimat von T1 und Gen.G."),
    (SUB_KULTUR, "medium", "In welcher Stadt hat Riot Games seinen Hauptsitz?", "Los Angeles", ["Seattle", "San Francisco", "Austin"], "Riot sitzt in Los Angeles (Kalifornien)."),
    (SUB_KULTUR, "hard", "Wie heißt die interaktive Welt-Website, auf der Riot die Lore veröffentlicht?", "Universe", ["Runeterra Wiki", "Loreverse", "Codex"], "Auf universe.leagueoflegends.com stehen alle Champion-Biografien und Kurzgeschichten."),
    (SUB_KULTUR, "medium", "Was ist die Ingame-Währung, die man mit echtem Geld kauft?", "Riot Points (RP)", ["Blaue Essenz", "Orange Essenz", "Gold"], "RP kauft Skins; Blaue Essenz kauft Champions."),
    (SUB_KULTUR, "medium", "Mit welcher Währung kauft man Champions im Shop?", "Blaue Essenz", ["Riot Points", "Orange Essenz", "Mythische Essenz"], "Blaue Essenz verdient man durch Spielen und Level-Ups."),
    (SUB_KULTUR, "hard", "Wie heißt die Währung für Prestige-Skins, die aus Ereignis-Pässen kommt?", "Mythische Essenz", ["Orange Essenz", "Blaue Essenz", "Ereignismarken"], "Mythische Essenz kauft Prestige- und Mythische Skins."),
    (SUB_KULTUR, "hard", "Welcher Champion war der erste mit einem „Ultimativen Skin“ (Ultimate Skin) — Pulsfeuer?", "Ezreal", ["Lux", "Udyr", "Miss Fortune"], "Pulsfeuer-Ezreal (2012) war der erste Ultimate-Skin; Spirit Guard Udyr folgte 2013."),
    (SUB_KULTUR, "hard", "Wie heißt der Ultimate-Skin von Lux mit zehn Elementarformen?", "Elementar-Lux (Elementalist Lux)", ["Sternenwächter-Lux", "Pulsfeuer-Lux", "Kosmische Lux"], "Elementalist Lux (2016) wechselt zwischen zehn Elementen."),
    (SUB_KULTUR, "medium", "Wie heißen die kleinen kosmetischen Begleiter für Teamfight Tactics?", "Little Legends", ["Wards", "Poros", "Meeps"], "Little Legends sind die Avatare in TFT; Poros sind die Freljord-Wesen der Heulenden Schlucht."),
    (SUB_KULTUR, "easy", "Wie heißen die flauschigen Wesen, die auf der Heulenden Schlucht herumlaufen und Kekse lieben?", "Poros", ["Meeps", "Yordles", "Rift Scuttler"], "Poros sind die Maskottchen des Freljord und der Heulenden Schlucht."),
    # German scene
    (SUB_ESPORT, "hard", "Wie heißt die deutsche nationale Liga (Tier 2 unter der LEC)?", "Prime League", ["Bundesliga Esports", "DACH Masters", "ESL Meisterschaft LoL"], "Die Prime League startete 2020 für Deutschland, Österreich und die Schweiz."),
    (SUB_ESPORT, "hard", "Welche Kölner Organisation ist einer der ältesten deutschen Esport-Clubs und spielte in der LEC/EU LCS?", "SK Gaming", ["BIG", "Eintracht Spandau", "mousesports"], "SK Gaming (gegründet 1997) ist Gründungsmitglied der LEC-Franchise."),
    (SUB_ESPORT, "hard", "Welcher Fußball-Bundesligist hatte von 2016 bis 2021 ein LoL-Team in der europäischen Topliga?", "FC Schalke 04", ["Borussia Dortmund", "VfL Wolfsburg", "RB Leipzig"], "Schalke 04 Esports spielte in EU LCS und LEC, verkaufte den Slot 2021."),
    (SUB_ESPORT, "hard", "Wie heißt das Berliner Esport-Team des Streamers HandOfBlood in der Prime League?", "Eintracht Spandau", ["Hertha Esports", "Berlin International Gaming", "Unicorns of Love"], "Eintracht Spandau wurde 2021 gegründet."),
    (SUB_ESPORT, "hard", "In welcher Stadt befindet sich das LEC-Studio?", "Berlin", ["Köln", "Paris", "London"], "Die LEC wird aus dem Studio in Berlin-Adlershof übertragen."),
    (SUB_ESPORT, "hard", "Wie heißt die deutsche Community-Plattform und der Cast rund um Freaks 4U Gaming für LoL?", "Summoner's Inn", ["Rocket Beans", "Lolesports DE", "Rift Radio"], "Summoner's Inn produziert die deutschen Übertragungen von LEC und Prime League."),
    (SUB_ESPORT, "medium", "Wie heißt der bekannteste Spieler der LoL-Geschichte, „Faker“?", "Lee Sang-hyeok", ["Rasmus Winther", "Jian Zi-Hao", "Søren Bjerg"], "Faker spielt seit 2013 für T1 und hält fünf Worlds-Titel."),
    (SUB_ESPORT, "medium", "Für welches Team spielt Faker seit 2013?", "T1 (SK Telecom T1)", ["Gen.G", "Samsung Galaxy", "G2 Esports"], "Faker ist der Inbegriff von T1."),
    (SUB_ESPORT, "hard", "Wie viele Worlds-Titel hatte Faker nach den Worlds 2024?", "5", ["3", "4", "6"], "2013, 2015, 2016, 2023 und 2024."),
    (SUB_ESPORT, "medium", "Welches europäische Team ist Rekord-Champion der LEC/EU LCS?", "G2 Esports", ["Fnatic", "Team Vitality", "Rogue"], "G2 hält die meisten europäischen Titel, Fnatic ist Zweiter."),
    (SUB_ESPORT, "hard", "Welches europäische Team stand 2019 als bisher letztes im Worlds-Finale?", "G2 Esports", ["Fnatic", "MAD Lions", "Origen"], "G2 verlor 2019 in Paris 0:3 gegen FunPlus Phoenix."),
    (SUB_ESPORT, "hard", "Welche Region hat die meisten Worlds-Titel gewonnen?", "Südkorea (LCK)", ["China (LPL)", "Europa (LEC)", "Nordamerika (LCS)"], "Korea führt klar; China holte 2018, 2019 und 2021."),
    (SUB_ESPORT, "hard", "Wie heißt Nordamerikas Topliga?", "LCS", ["LCK", "LPL", "CBLOL"], "Die LCS ist die nordamerikanische Liga, die LPL die chinesische."),
    (SUB_ESPORT, "hard", "Wie heißt die Trophäe der Weltmeisterschaft?", "Summoner's Cup", ["Nexus Trophy", "Baron Cup", "Rift Trophy"], "Der Summoner's Cup wiegt rund 20 Kilogramm."),
    (SUB_ESPORT, "hard", "Welches Team gewann 2022 die Worlds als erstes Team, das sich über die Play-Ins qualifiziert hatte?", "DRX", ["T1", "Gen.G", "JD Gaming"], "DRX schrieb 2022 mit Deft und Kingen das Märchen von San Francisco."),
    (SUB_ESPORT, "hard", "Welcher Spieler gewann 2024 mit T1 die Worlds und ist der einzige mit fünf Titeln?", "Faker", ["Zeus", "Keria", "Gumayusi"], "Faker hält als einziger fünf Worlds-Titel."),
    (SUB_ESPORT, "hard", "Welches Team gewann die Worlds 2020 in Shanghai?", "DAMWON Gaming", ["Suning", "Top Esports", "G2 Esports"], "DAMWON besiegte Suning 3:1 im Pudong Football Stadium."),
]

HAND_TF = [
    (SUB_MECH, "easy", "In League of Legends spielen zwei Teams mit je fünf Spielern gegeneinander.", True, "5 gegen 5 auf der Kluft der Beschwörer."),
    (SUB_MECH, "medium", "Der Baron Nashor erscheint bereits in Minute 15.", False, "Baron erscheint um 20:00."),
    (SUB_MECH, "medium", "Zerschmettern (Smite) kann nur auf Monster und Vasallen angewendet werden — nicht auf Champions.", True, "Smite trifft Monster; die Champion-Version wurde 2021 entfernt."),
    (SUB_MECH, "medium", "Absoluter Schaden wird durch Rüstung reduziert.", False, "Absoluter Schaden ignoriert Rüstung und Magieresistenz."),
    (SUB_MECH, "easy", "Blitz (Flash) hat eine Abklingzeit von 300 Sekunden.", True, "Fünf Minuten — daher „Flash ist unten“."),
    (SUB_MECH, "hard", "Ein Team kann in einem Spiel zwei Drachen-Seelen bekommen.", False, "Maximal eine Seele — danach kommt der Älteste Drache."),
    (SUB_MECH, "medium", "Turmplatten verschwinden um 14:00.", True, "Danach ist der Turm nicht mehr durch Platten geschützt."),
    (SUB_MECH, "medium", "Der Herold der Kluft kann als „Auge“ auf gegnerische Türme geworfen werden.", True, "Das Auge des Herolds beschwört ihn zum Rammen."),
    (SUB_MECH, "hard", "Es gibt in der Rangliste eine Stufe namens „Smaragd“.", True, "Smaragd (Emerald) wurde 2023 zwischen Platin und Diamant eingefügt."),
    (SUB_MECH, "medium", "Man startet jedes Spiel mit 500 Gold.", True, "500 Startgold für den ersten Einkauf."),
    (SUB_LORE, "medium", "Lux ist die Schwester von Garen.", True, "Luxanna Crownguard, Garens jüngere Schwester."),
    (SUB_LORE, "medium", "Jinx und Vi sind Schwestern.", True, "Die Geschichte der Schwestern erzählt Arcane."),
    (SUB_LORE, "medium", "Yasuo tötete seinen Bruder Yone im Duell.", True, "Yone hielt Yasuo für den Mörder ihres Meisters und forderte ihn — Yasuo tötete ihn; Yone kehrte später aus dem Geisterreich zurück."),
    (SUB_LORE, "hard", "Demacia nutzt Petricit, um Magie zu unterdrücken.", True, "Petricit absorbiert Magie."),
    (SUB_LORE, "medium", "Teemo ist ein Yordle.", True, "Der flinke Späher aus Bandle City."),
    (SUB_LORE, "medium", "Ahri ist ein Yordle.", False, "Ahri ist eine Vastaya."),
    (SUB_LORE, "hard", "Aatrox ist ein Darkin.", True, "Die Darkin-Klinge — ein in seine Waffe gebannter Aufgestiegener."),
    (SUB_LORE, "medium", "Bilgewater ist eine Hafenstadt der Piraten.", True, "Heimat von Gangplank, Miss Fortune und Graves."),
    (SUB_LORE, "medium", "Der Schwarze Nebel stammt aus dem Freljord.", False, "Der Schwarze Nebel kommt von den Schatteninseln."),
    (SUB_LORE, "hard", "Viego war der König von Camavor.", True, "Der Verderbte König stammt aus Camavor."),
    (SUB_KULTUR, "easy", "League of Legends wird von Riot Games entwickelt.", True, "Riot Games, gegründet 2006."),
    (SUB_KULTUR, "medium", "Arcane wurde von Pixar animiert.", False, "Arcane stammt vom französischen Studio Fortiche."),
    (SUB_KULTUR, "medium", "K/DA ist eine virtuelle Metal-Band.", False, "K/DA ist K-Pop; Pentakill ist die Metal-Band."),
    (SUB_KULTUR, "medium", "Teamfight Tactics startete im LoL-Client.", True, "TFT erschien 2019 als Modus im Client."),
    (SUB_KULTUR, "hard", "Riot Games gehört zu Tencent.", True, "Tencent hält seit 2015 100 %."),
    (SUB_ESPORT, "medium", "Faker hat mehr als drei Weltmeistertitel gewonnen.", True, "Fünf Titel bis 2024."),
    (SUB_ESPORT, "hard", "G2 Esports hat die Weltmeisterschaft gewonnen.", False, "G2 stand 2019 im Finale, verlor aber gegen FunPlus Phoenix."),
    (SUB_ESPORT, "hard", "Fnatic gewann die allererste Weltmeisterschaft 2011.", True, "In Jönköping auf der DreamHack."),
    (SUB_ESPORT, "hard", "Die Worlds 2015 fanden ihr Finale in Berlin.", True, "In der Mercedes-Benz Arena — SKT gegen KOO Tigers."),
    (SUB_ESPORT, "hard", "Das MSI 2020 wurde ausgetragen.", False, "Das MSI 2020 fiel wegen der Pandemie aus."),
]

HAND_SCHAETZ = [
    (SUB_MECH, "medium", "Wie viele Sekunden beträgt die Abklingzeit von Blitz (Flash)?", 300, "Sekunden", 30, 60, 600, "Fünf Minuten."),
    (SUB_MECH, "medium", "In welcher Minute erscheint der Baron Nashor?", 20, "Minute", 1, 5, 40, "Baron ab 20:00."),
    (SUB_MECH, "hard", "Wie viel Startgold hat jeder Champion?", 500, "Gold", 50, 100, 1500, "500 Gold zum Spielstart."),
    (SUB_MECH, "hard", "Wie viele Champions gab es beim Release 2009?", 40, "Champions", 5, 10, 100, "40 Champions zum Start."),
    (SUB_MECH, "medium", "Wie viele Champions gibt es ungefähr (Stand Anfang 2025)?", 170, "Champions", 8, 100, 250, "Mit Mel (Januar 2025) waren es 170 Champions."),
    (SUB_MECH, "hard", "Nach wie vielen Sekunden erscheint die erste Vasallenwelle am Nexus?", 65, "Sekunden", 5, 30, 180, "1:05."),
    (SUB_MECH, "hard", "In welcher Minute fallen die Turmplatten?", 14, "Minute", 1, 5, 30, "14:00."),
    (SUB_MECH, "ultrahard", "Wie viel Gold gibt eine einzelne Turmplatte ungefähr?", 160, "Gold", 40, 25, 400, "Je nach Patch 125–175 Gold pro Platte — fünf Platten pro äußerem Turm."),
    (SUB_MECH, "hard", "Wie viele Sekunden beträgt die Abklingzeit von Zünder (Ignite)?", 180, "Sekunden", 20, 60, 400, "Drei Minuten."),
    (SUB_MECH, "hard", "Wie viele Sekunden beträgt die Abklingzeit von Teleport?", 360, "Sekunden", 40, 60, 600, "Teleport: 360 Sekunden."),
    (SUB_KULTUR, "medium", "In welchem Jahr wurde Riot Games gegründet?", 2006, "", 1, 1995, 2015, "Gründung 2006 in Los Angeles."),
    (SUB_KULTUR, "hard", "In welchem Jahr erschien die zweite Staffel von Arcane?", 2024, "", 1, 2019, 2026, "Staffel 2 lief im November 2024."),
    (SUB_KULTUR, "hard", "In welchem Jahr debütierte K/DA mit „POP/STARS“?", 2018, "", 1, 2010, 2025, "Bei der Worlds-Eröffnung 2018 in Incheon."),
    (SUB_ESPORT, "medium", "In welchem Jahr fand die erste LoL-Weltmeisterschaft statt?", 2011, "", 1, 2008, 2016, "2011 auf der DreamHack in Jönköping."),
    (SUB_ESPORT, "hard", "Wie hoch war das Preisgeld der ersten Weltmeisterschaft 2011 (in US-Dollar)?", 100000, "US-Dollar", 30000, 10000, 1000000, "Die ersten Worlds hatten 100.000 US-Dollar Preisgeld — Fnatic gewann 50.000."),
    (SUB_ESPORT, "hard", "Wie viele Weltmeistertitel hatte T1/SKT nach den Worlds 2024?", 5, "Titel", 0, 1, 10, "2013, 2015, 2016, 2023, 2024."),
    (SUB_ESPORT, "ultrahard", "Wie schwer ist der Summoner's Cup ungefähr (Kilogramm)?", 25, "kg", 12, 5, 60, "Der alte Pokal wog rund 32 kg, der neue von Tiffany (seit 2022) etwa 20 kg."),
    (SUB_ESPORT, "hard", "In welchem Jahr startete die Prime League (DACH)?", 2020, "", 1, 2012, 2025, "Die Prime League löste 2020 die ESL Meisterschaft ab."),
]

HAND_SORT = [
    (SUB_MECH, "medium", "Sortiere diese Objectives nach ihrem frühesten Erscheinen im Spiel.", [("Erster Drache", 5, "5:00"), ("Herold der Kluft", 14, "14:00"), ("Baron Nashor", 20, "20:00"), ("Ältester Drache (nach der Drachen-Seele)", 26, "frühestens ca. 26:00")], "Drache 5:00 · Herold 14:00 · Baron 20:00 · Ältester Drache nach der Drachen-Seele."),
    (SUB_MECH, "hard", "Sortiere diese Beschwörerzauber nach ihrer Abklingzeit — von kurz nach lang.", [("Zünder (Ignite)", 180, "180 s"), ("Heilung", 240, "240 s"), ("Blitz (Flash)", 300, "300 s"), ("Teleport", 360, "360 s")], "Zünder 180 s · Heilung 240 s · Blitz 300 s · Teleport 360 s."),
    (SUB_MECH, "medium", "Sortiere die Ranglisten-Stufen aufsteigend.", [("Silber", 2, "2."), ("Gold", 3, "3."), ("Smaragd", 5, "5."), ("Meister", 7, "7.")], "Eisen, Bronze, Silber, Gold, Platin, Smaragd, Diamant, Meister, Großmeister, Herausforderer."),
    (SUB_KULTUR, "hard", "Sortiere diese Riot-Veröffentlichungen chronologisch.", [("League of Legends", 2009, "2009"), ("Teamfight Tactics", 2019, "2019"), ("Valorant", 2020, "2020"), ("Arcane (Staffel 1)", 2021, "2021")], "LoL 2009 · TFT 2019 · Valorant 2020 · Arcane 2021."),
    (SUB_KULTUR, "hard", "Sortiere diese Musik-Gruppen aus LoL nach ihrem Debüt.", [("Pentakill", 2014, "2014"), ("K/DA", 2018, "2018"), ("True Damage", 2019, "2019"), ("Heartsteel", 2023, "2023")], "Pentakill 2014 · K/DA 2018 · True Damage 2019 · Heartsteel 2023."),
    (SUB_ESPORT, "hard", "Sortiere diese Worlds-Finalstädte chronologisch.", [("Jönköping", 2011, "2011"), ("Berlin", 2015, "2015"), ("Paris", 2019, "2019"), ("London", 2024, "2024")], "2011 Jönköping · 2015 Berlin · 2019 Paris · 2024 London."),
    (SUB_LORE, "hard", "Sortiere diese Champions nach ihrer Lore-Zugehörigkeit von Norden nach Süden Valorans — beginne im ewigen Eis.", [("Ashe (Freljord)", 1, "Freljord"), ("Garen (Demacia)", 2, "Demacia"), ("Caitlyn (Piltover)", 3, "Piltover"), ("Azir (Shurima)", 4, "Shurima")], "Freljord liegt im Norden, Demacia westlich-mittig, Piltover an der Meerenge, Shurima im Süden."),
]


def gen_hand():
    for sub, schw, text, correct, wrongs, erkl, *rest in HAND:
        region = rest[0] if rest else "global"
        de = sub == SUB_ESPORT and any(k in text for k in ("deutsch", "Berlin", "Köln", "Prime League", "Schalke", "Spandau", "Summoner's Inn"))
        choice(sub, schw, text, correct, wrongs, erkl, region="de" if de else region)
    for sub, schw, text, val, erkl in HAND_TF:
        wahr_falsch(sub, schw, text, val, erkl)
    for sub, schw, text, wert, einheit, tol, lo, hi, erkl in HAND_SCHAETZ:
        schaetz(sub, schw, text, wert, einheit, tol, lo, hi, erkl)
    for sub, schw, text, items, erkl in HAND_SORT:
        sortier(sub, schw, text, items, erkl)


def gen_extra_champion_facts():
    """Second wave of champion templates for volume: same-year pairs, W/E names, role pairs."""
    for c in CHAMPS:
        t = tier(c)
        same = [x for x in CHAMPS if x["year"] == c["year"] and x is not c]
        if same and RNG.random() < 0.7:
            m = RNG.choice(same)
            wrong = [x["name"] for x in RNG.sample([x for x in CHAMPS if x["year"] != c["year"] and x is not c], 3)]
            choice(SUB_CHAMP, "ultrahard", f"Welcher Champion erschien im selben Jahr wie {c['name']} ({c['year']})?", m["name"], wrong,
                   f"{m['name']} und {c['name']} kamen beide {c['year']}.")
        if c["w"] and RNG.random() < 0.55:
            choice(SUB_CHAMP, bump("hard", 1 if t == 2 else 0), f"Wie heißt die W-Fähigkeit von {c['name']}?", c["w"], others("w", c["w"], like=c), f"Die W von {c['name']} heißt „{c['w']}“. " + champ_desc(c))
        if c["e"] and RNG.random() < 0.55:
            choice(SUB_CHAMP, bump("hard", 1 if t == 2 else 0), f"Wie heißt die E-Fähigkeit von {c['name']}?", c["e"], others("e", c["e"], like=c), f"Die E von {c['name']} heißt „{c['e']}“. " + champ_desc(c))
        if c["region"] and RNG.random() < 0.5:
            same_r = [x for x in CHAMPS if x["region"] == c["region"] and x is not c]
            if same_r:
                m = RNG.choice(same_r)
                wrong = [x["name"] for x in RNG.sample([x for x in CHAMPS if x["region"] and x["region"] != c["region"]], 3)]
                choice(SUB_LORE, bump("medium", t), f"Welcher Champion stammt aus derselben Region wie {c['name']}?", m["name"], wrong,
                       f"{m['name']} und {c['name']} stammen beide aus {REGION_DE.get(c['region'], c['region'])}.", tipps=[REGION_HINT[c["region"]]])
        if RNG.random() < 0.4:
            same_role = [x for x in CHAMPS if x["role"] == c["role"] and x is not c]
            m = RNG.choice(same_role)
            wrong = [x["name"] for x in RNG.sample([x for x in CHAMPS if x["role"] != c["role"]], 3)]
            choice(SUB_CHAMP, bump("easy", t), f"Welcher Champion wird wie {c['name']} klassisch auf der {ROLE_DE[c['role']]} gespielt?", m["name"], wrong,
                   f"{m['name']} und {c['name']} sind beide {ROLE_DE[c['role']]}-Champions.")


def build():
    gen_champions()
    gen_region_sets()
    gen_true_false()
    gen_sortier()
    gen_esports()
    gen_hand()
    gen_extra_champion_facts()
    # de-duplicate identical texts
    seen, out = set(), []
    for q in QUESTIONS:
        key = q["text"]
        if key in seen:
            continue
        seen.add(key)
        out.append(q)
    return out


SUBS = [
    {"id": SUB_ALL, "ober": "gaming", "name": "LoL · Allgemein"},
    {"id": SUB_CHAMP, "ober": "gaming", "name": "LoL · Champions & Fähigkeiten"},
    {"id": SUB_LORE, "ober": "gaming", "name": "LoL · Lore & Runeterra"},
    {"id": SUB_ESPORT, "ober": "gaming", "name": "LoL · Esports & Pro-Szene"},
    {"id": SUB_MECH, "ober": "gaming", "name": "LoL · Spielmechanik & Items"},
    {"id": SUB_KULTUR, "ober": "gaming", "name": "LoL · Skins, Musik & Arcane"},
]


def main():
    dry = "--dry-run" in sys.argv
    new = build()
    stats = Counter(q["schw"] for q in new)
    subs = Counter(q["sub"] for q in new)
    types = Counter(q["typ"] for q in new)
    print(f"generated {len(new)} questions")
    print("difficulty:", dict(stats))
    print("subs:", dict(subs))
    print("types:", dict(types))
    if dry:
        return
    fragen_path, tax_path = CONTENT / "fragen.json", CONTENT / "taxonomie.json"
    data = json.loads(fragen_path.read_text(encoding="utf-8"))
    kept = [q for q in data["fragen"] if not q["sub"].startswith("lol_")]
    ids = {q["id"] for q in kept}
    texts = {q["text"] for q in kept}
    for q in new:
        assert q["id"] not in ids, q["id"]
    new = [q for q in new if q["text"] not in texts]  # the hand-written LoL core already has it
    data["fragen"] = kept + new
    fragen_path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    tax = json.loads(tax_path.read_text(encoding="utf-8"))
    tax["unter"] = [u for u in tax["unter"] if u["id"] not in {s["id"] for s in SUBS}]
    tax["unter"].extend(SUBS)
    tax_path.write_text(json.dumps(tax, ensure_ascii=False), encoding="utf-8")
    total_lol = sum(1 for q in data["fragen"] if q["sub"] in {s["id"] for s in SUBS})
    print(f"fragen.json now has {len(data['fragen'])} questions, {total_lol} League of Legends")


if __name__ == "__main__":
    main()
