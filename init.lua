-- init.lua

factions = {}
factions.claims = {}
factions.roles = {}

-- Charger les autres fichiers
dofile(minetest.get_modpath("factionminetest").."/commands.lua")
dofile(minetest.get_modpath("factionminetest").."/factions.lua")
dofile(minetest.get_modpath("factionminetest").."/claims.lua")
dofile(minetest.get_modpath("factionminetest") .. "/relations.lua")

-- Initialiser les claims
factions.claims.load_claims()
factions.load_factions()