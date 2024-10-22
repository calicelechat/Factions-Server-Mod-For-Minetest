-- commands.lua
minetest.register_chatcommand(
    "f",
    {
        params = "<subcommand> <args>",
        description = "Commandes de factions",
        func = function(name, param)
            local args = param:split(" ")
            local subcommand = args[1]

            if subcommand == "create" then
                local faction_name = args[2]
                if not faction_name then
                    return false, "Vous devez spécifier un nom de faction."
                end
                local success, msg = factions.create(name, faction_name)
                return success, msg
            elseif subcommand == "menu" then
                factions.show_menu(name)
                return true
            elseif subcommand == "join" then
                local faction_name = args[2]
                if not faction_name then
                    return false, "Vous devez spécifier le nom de la faction à rejoindre."
                end
                local success, msg = factions.accept_invite(name, faction_name)
                return success, msg
            elseif subcommand == "refuse" then
                local faction_name = args[2]
                if not faction_name then
                    return false, "Vous devez spécifier le nom de la faction à refuser."
                end
                local success, msg = factions.refuse_invite(name, faction_name)
                return success, msg
            elseif subcommand == "kick" then
                local target_player = args[2]
                if not target_player then
                    return false, "Vous devez spécifier un joueur à expulser."
                end
                local faction_name = factions.get_player_faction(name)
                if not faction_name then
                    return false, "Vous n'êtes pas dans une faction."
                end
                local success, msg = factions.kick(name, faction_name, target_player)
                return success, msg
            elseif subcommand == "claim" then
                local faction_name = factions.get_player_faction(name)
                if not faction_name then
                    return false, "Vous n'êtes pas dans une faction."
                end
                local success, msg = factions.claim(name)
                return success, msg
            elseif subcommand == "claims" then
                factions.show_claims(name)
                return true
            elseif subcommand == "list" then
                local faction_list = factions.list_factions()
                minetest.chat_send_player(name, faction_list)
                return true
            elseif subcommand == "unclaim" then
                local success, message = factions.release_claim(name)
                minetest.chat_send_player(name, message)
                return true
            elseif subcommand == "clear_boundaries" then
                -- Vérifier si le joueur a le privilège "server"
                if not minetest.check_player_privs(name, {server = true}) then
                    return false, "Vous n'avez pas la permission d'exécuter cette commande."
                end

                for _, entities in pairs(factions.claims.boundary_entities) do
                    for _, entity in ipairs(entities) do
                        if entity and entity:get_luaentity() then
                            entity:remove()
                        end
                    end
                end

                -- Effacer la table des entités "boundary"
                factions.claims.boundary_entities = {}
                return true, "Toutes les entités de délimitation ont été supprimées."
            elseif subcommand == "help" then
                local help_text =
                    [[
Commandes disponibles:
/f create <nom> - Créer une faction
/f menu - Ouvrir le menu de faction
/f join <nom> - Rejoindre une faction
/f refuse <nom> - Refuser l'invitation à rejoindre une faction
/f claim - Revendiquer un territoire
/f claims - Afficher les territoires revendiqués
/f kick <nom> - Expulser un joueur de la faction
/f list - Lister les factions du serveur
/f clear_boundaries - Supprimer toutes les bordures de claims
/f relations <faction> - Affiche les relations de factions de la faction visée.
/f politique <faction> <allié|neutre|ennemi> - Définit le côté politiquede votre faction avec la faction concernée.
/fc <message> - Permet d'envoyer un message à l'entièretée de sa faction.
]]
                minetest.chat_send_player(name, help_text)
                return true
            elseif subcommand == "relations" then
                if not args[2] then
                    return false, "Nom de faction requis."
                end
                local faction_name = args[2]
                return true, relations.show_relations(faction_name)
            elseif subcommand == "politique" then
                local faction_name = factions.get_player_faction(name)
                local faction2 = args[2]
                local faction = factions.list[faction_name]
                if
                    not faction.members[name] or
                        faction.members[name] ~= "chefdefac" and faction.members[name] ~= "co-leader"
                 then
                    return false, "Vous n'avez pas la permission d'exécuter cette commande."
                end

                if args[2] == faction_name then
                    return false, "Vous ne pouvez pas définir un status politique pour votre propre faction."
                end

                local status = args[3]
                return relations.set_relation(name, faction_name, faction2, status)
            else
                return false, "Commande inconnue. Tapez /f help pour la liste des commandes."
            end
        end
    }
)

minetest.register_chatcommand(
    "fc",
    {
        params = "<message>",
        description = "Envoyer un message à sa faction.",
        func = function(name, param)
            -- Vérifie si le paramètre est vide
            if param == "" then
                return false, "Vous devez entrer un message à envoyer."
            end

            local args = param:split(" ")
            local message = table.concat(args, " ", 1) -- Récupérer le message complet

            local faction_name = factions.get_player_faction(name)
            if not faction_name then
                return false, "Vous n'êtes pas dans une faction."
            end

            for member_name in pairs(factions.list[faction_name].members) do
                minetest.chat_send_player(member_name, "[Faction] " .. name .. ": " .. message)
            end
            return true
        end
    }
)
