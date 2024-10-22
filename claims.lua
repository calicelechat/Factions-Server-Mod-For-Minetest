-- claims.lua
factions.claims = {}
factions.claims.data = {}

-- Fonction pour obtenir les limites du chunk
function get_chunk_bounds(x, z)
    local chunk_size = 16
    local map_min = -30000
    local map_max = 30000

    -- Vérification des coordonnées
    if x < map_min or x > map_max or z < map_min or z > map_max then
        return nil, "Les coordonnées doivent être entre " .. map_min .. " et " .. map_max
    end

    -- Calculer le chunk
    local chunk_x = math.floor(x / chunk_size)
    local chunk_z = math.floor(z / chunk_size)

    -- Calculer les limites du chunk
    local x1 = chunk_x * chunk_size
    local z1 = chunk_z * chunk_size
    local x2 = x1 + chunk_size - 1
    local z2 = z1 + chunk_size - 1

    return x1, z1, x2, z2
end

-- Enregistrer l'entité de délimitation
minetest.register_entity(
    "factionminetest:boundary_entity",
    {
        initial_properties = {
            visual = "cube",
            textures = {
                "factions_boundary.png",
                "factions_boundary.png",
                "factions_boundary.png",
                "factions_boundary.png",
                "factions_boundary.png",
                "factions_boundary.png"
            },
            physical = false,
            collide_with_objects = false,
            collide_with_world = false,
            visual_size = {x = 1, y = 1, z = 1},
            glow = 10
        }
    }
)

-- Fonction pour charger les claims
function factions.claims.load_claims()
    local file = io.open(minetest.get_worldpath() .. "/claims.txt", "r")
    if file then
        for line in file:lines() do
            local x, z, faction_name = line:match("([^,]+),([^,]+),([^,]+)")
            -- Store as string key "x,z"
            factions.claims.data[x .. "," .. z] = faction_name
        end
        file:close()
    end
end

-- Fonction pour sauvegarder les claims
function factions.claims.save_claim(chunk_x, chunk_z, faction_name)
    local file = io.open(minetest.get_worldpath() .. "/claims.txt", "a")
    if file then
        file:write(chunk_x .. "," .. chunk_z .. "," .. faction_name .. "\n")
        file:close()
    end
    -- Update the data in memory as well
    factions.claims.data[chunk_x .. "," .. chunk_z] = faction_name
end

function factions.remove_claims(faction_name)
    local claims_to_remove = {}

    -- Trouver tous les claims associés à la faction
    for coords, owner_faction in pairs(factions.claims.data) do
        if owner_faction == faction_name then
            table.insert(claims_to_remove, coords)
        end
    end

    -- Supprimer les claims de la mémoire
    for _, coords in ipairs(claims_to_remove) do
        factions.claims.data[coords] = nil
    end

    -- Sauvegarder les nouveaux claims (sans ceux supprimés)
    factions.claims.save_all_claims()
end

-- Fonction pour sauvegarder tous les claims
function factions.claims.save_all_claims()
    local file = io.open(minetest.get_worldpath() .. "/claims.txt", "w")
    if file then
        for coords, faction_name in pairs(factions.claims.data) do
            local x, z = coords:match("([^,]+),([^,]+)")
            file:write(x .. "," .. z .. "," .. faction_name .. "\n")
        end
        file:close()
    end
end

-- Fonction pour revendiquer un territoire
function factions.claim(player_name)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        return false, "Vous devez être dans une faction pour revendiquer un territoire."
    end

    local player = minetest.get_player_by_name(player_name)
    if not player then
        return false, "Joueur non trouvé."
    end

    local faction = factions.list[faction_name]
    if
        faction.members[player_name] ~= "chefdefac" and faction.members[player_name] ~= "conseillé" and
            faction.members[player_name] ~= "co-leader"
     then
        return false, "Seul le conseillé, le co-leader ou le chef de faction a le droit de protéger une zone."
    end

    local pos = player:get_pos()
    local x1, z1, x2, z2 = get_chunk_bounds(pos.x, pos.z)

    -- Vérification des erreurs de get_chunk_bounds
    if not x1 then
        return false, z1 -- z1 contient le message d'erreur
    end

    -- Vérifier si le chunk est déjà revendiqué
    if
        factions.claims.data[x1 .. "," .. z1] and
            factions.claims.data[x1 .. "," .. z1] == factions.get_player_faction(player_name)
     then
        return false, "Ce chunk est déjà revendiqué par votre faction."
    elseif factions.claims.data[x1 .. "," .. z1] then
        return false, "Ce chunk est déjà revendiqué par une autre faction."
    end

    -- Sauvegarder le claim
    factions.claims.save_claim(x1, z1, faction_name)
    minetest.chat_send_player(player_name, "Vous venez de protéger ce territoire: (" .. x1 .. ", " .. z1 .. ").")

    -- Créer des entités de délimitation dans le monde (avec player_name)
    factions.create_boundaries(x1, z1, pos.y, player_name) -- Ajout de player_name ici

    return true, "Territoire revendiqué."
end

function factions.create_boundaries(chunk_x, chunk_z, player_y, player_name)
    local chunk_size = 16
    local min_x = chunk_x
    local max_x = chunk_x + chunk_size - 1
    local min_z = chunk_z
    local max_z = chunk_z + chunk_size - 1
    local entities = factions.claims.boundary_entities[player_name] or {}

    -- Créer des entités le long des bords du chunk
    for high = (player_y - 20), (player_y + 20) do
        for x = min_x, max_x do
            -- Créer des entités sur les bords Nord et Sud du chunk
            table.insert(entities, minetest.add_entity({x = x, y = high, z = min_z}, "factionminetest:boundary_entity"))
            table.insert(entities, minetest.add_entity({x = x, y = high, z = max_z}, "factionminetest:boundary_entity"))
        end
    end
    for high = (player_y - 20), (player_y + 20) do
        for z = min_z, max_z do
            -- Créer des entités sur les bords Ouest et Est du chunk
            table.insert(entities, minetest.add_entity({x = min_x, y = high, z = z}, "factionminetest:boundary_entity"))
            table.insert(entities, minetest.add_entity({x = max_x, y = high, z = z}, "factionminetest:boundary_entity"))
        end
    end

    -- Stocker les entités créées pour ce joueur
    factions.claims.boundary_entities[player_name] = entities

    -- Supprimer les entités après 20 secondes si nécessaire
    minetest.after(
        10,
        function()
            for _, entity in ipairs(entities) do
                if entity and entity:get_luaentity() then
                    entity:remove()
                end
            end
            factions.claims.boundary_entities[player_name] = nil
        end
    )
end

-- Enregistrer toutes les entités créées par les joueurs
factions.claims.boundary_entities = {}

-- Supprimer toutes les entités créées à la déconnexion du joueur
minetest.register_on_leaveplayer(
    function(player)
        local player_name = player:get_player_name()

        -- Récupérer les entités associées à ce joueur
        local entities = factions.claims.boundary_entities[player_name]

        -- Vérifier que des entités existent avant de les parcourir
        if entities then
            -- Si des entités ont été créées pour ce joueur, les supprimer
            for _, entity in ipairs(entities) do
                if entity and entity:get_luaentity() then
                    entity:remove()
                end
            end
        end

        -- Supprimer la référence aux entités du joueur
        factions.claims.boundary_entities[player_name] = nil
    end
)

local function is_position_claimed(pos)
    local x1, z1, x2, z2 = get_chunk_bounds(pos.x, pos.z)
    if not x1 then
        return false, z1
    end

    -- Vérifier si le chunk est déjà revendiqué
    if factions.claims.data[x1 .. "," .. z1] then
        return true
    else
        return false
    end
end

-- Vérifier si le joueur appartient à la faction qui possède la zone
local function player_can_modify(player_name, pos)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        return false -- Le joueur n'appartient à aucune faction
    end

    local x1, z1 = get_chunk_bounds(pos.x, pos.z)
    if not x1 then
        return false -- Erreur dans le calcul du chunk
    end

    local owner_faction = factions.claims.data[x1 .. "," .. z1]

    -- Vérifier si la faction qui possède la zone est celle du joueur
    if owner_faction == faction_name then
        return true
    else 
        return false
    end
end

local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
    if is_position_claimed(pos) and not player_can_modify(name, pos) then
        return true
    end
    return old_is_protected(pos, name)
end

function factions.release_claim(player_name)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        return false, "Vous devez être dans une faction pour libérer un territoire."
    end

    local player = minetest.get_player_by_name(player_name)
    if not player then
        return false, "Joueur non trouvé."
    end

    local faction = factions.list[faction_name]
    if faction.members[player_name] ~= "chefdefac" and faction.members[player_name] ~= "co-leader" then
        return false, "Seul le chef de faction ou le co-leader peut libérer un territoire."
    end

    local pos = player:get_pos()
    local x1, z1, x2, z2 = get_chunk_bounds(pos.x, pos.z)

    -- Vérification des erreurs de get_chunk_bounds
    if not x1 then
        return false, z1 -- z1 contient le message d'erreur
    end

    -- Vérifier si le chunk est revendiqué par la faction
    if factions.claims.data[x1 .. "," .. z1] ~= faction_name then
        return false, "Ce chunk n'est pas revendiqué par votre faction."
    end

    -- Supprimer le claim
    factions.claims.data[x1 .. "," .. z1] = nil
    factions.claims.save_all_claims() -- Sauvegarder les nouveaux claims

    minetest.chat_send_player(player_name, "Vous avez libéré le territoire: (" .. x1 .. ", " .. z1 .. ").")

    return true, "Territoire libéré."
end

function factions.show_claims(player_name)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        minetest.chat_send_player(player_name, "Vous n'êtes dans aucune faction.")
        return
    end

    local claims_list = "Territoires revendiqués:\n"
    local player_pos = minetest.get_player_by_name(player_name):get_pos()
    local player_chunk_x = math.floor(player_pos.x / 16)
    local player_chunk_z = math.floor(player_pos.z / 16)

    local has_claims = false

    for coords, faction in pairs(factions.claims.data) do
        if faction == faction_name then
            local x, z = coords:match("([^,]+),([^,]+)")
            x = tonumber(x)
            z = tonumber(z)

            -- Calcul de la distance réelle entre le joueur et le centre du chunk
            local chunk_center_x = x + 8 -- Centre du chunk en X
            local chunk_center_z = z + 8 -- Centre du chunk en Z

            local dist = math.sqrt((chunk_center_x - player_pos.x) ^ 2 + (chunk_center_z - player_pos.z) ^ 2)

            -- Vérification si la distance est inférieure à 100 blocs
            if dist <= 100 then
                claims_list = claims_list .. "Chunk (" .. x .. "," .. z .. ")\n"
                has_claims = true

                -- Créer des limites pour le chunk revendiqué
                factions.create_boundaries(x, z, player_pos.y, player_name)
            end
        end
    end

    if not has_claims then
        claims_list = claims_list .. "Aucun territoire revendiqué."
    end

    minetest.chat_send_player(player_name, claims_list)
end

factions.claims.load_claims() -- Chargement des claims au démarrage
