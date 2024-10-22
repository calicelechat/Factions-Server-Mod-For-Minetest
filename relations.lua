relations = {
    data = {} -- Stockage des relations
}

-- Fonction pour charger les relations à partir du fichier
function relations.load_relations()
    local file = io.open(minetest.get_worldpath() .. "/relations.txt", "r")
    if file then
        for line in file:lines() do
            local faction_name, relations_str = line:match("([^,]+), (.+)")
            if faction_name and relations_str then
                relations.data[faction_name] = {}
                for relation in relations_str:gmatch("([^, ]+): ([^, ]+)") do
                    local faction, status = relation:match("([^:]+): (.+)")
                    if faction and status then
                        relations.data[faction_name][faction] = status
                    end
                end
            end
        end
        file:close()
    end
end

-- Fonction pour sauvegarder les relations dans le fichier
function relations.save_relations()
    local file = io.open(minetest.get_worldpath() .. "/relations.txt", "w") -- Ouvrir le fichier en mode écriture
    if file then
        for faction_name, relations_table in pairs(relations.data) do
            local relations_str = ""
            for other_faction, status in pairs(relations_table) do
                relations_str = relations_str .. other_faction .. ": " .. status .. ", "
            end
            -- Supprimer la dernière virgule et l'espace
            relations_str = relations_str:sub(1, -3)
            file:write(faction_name .. ", " .. relations_str .. "\n")
        end
        file:close()
    else
        print("Erreur lors de l'ouverture du fichier relations.txt pour écriture.")
    end
end

-- Fonction pour définir les relations
function relations.set_relation(player_name, faction1, faction2, status)
    local faction_name = factions.get_player_faction(player_name)
    local faction = factions.list[faction_name]
    if not faction.members[player_name] or faction.members[player_name] ~= "chefdefac" then
        return false, "Vous devez être le chef ou un co-leader de la faction pour définir une relation."
    end

    if not relations.data[faction1] then
        relations.data[faction1] = {}
    end
    relations.data[faction1][faction2] = status
    relations.data[faction2][faction1] = status

    relations.save_relations()

    return true, "Relation entre " .. faction1 .. " et " .. faction2 .. " définie en tant que " .. status .. "."
end

-- Fonction pour obtenir la relation entre deux factions
function relations.get_relation(faction1, faction2)
    if relations.data[faction1] and relations.data[faction1][faction2] then
        return relations.data[faction1][faction2]
    end
    return "neutre" -- Retourne "neutre" si aucune relation n'est définie
end

-- Fonction pour afficher les relations d'une faction
function relations.show_relations(faction_name)
    if not relations.data[faction_name] then
        return "Faction " .. faction_name .. " non trouvée.\nAucune relation définie."
    end

    local relation_list = "Relations de la faction " .. faction_name .. ":\n"
    for other_faction, status in pairs(relations.data[faction_name]) do
        relation_list = relation_list .. other_faction .. ": " .. status .. "\n"
    end
    return relation_list
end

-- Charger les relations au démarrage
relations.load_relations()

return relations
