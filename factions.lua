-- factions.lua
factions = {}
factions.list = {}

-- Fonction pour charger les factions à partir d'un fichier
function factions.load_factions()
    local file = io.open(minetest.get_worldpath() .. "/factions.txt", "r")
    if file then
        for line in file:lines() do
            local faction_name, leader, members_str = line:match("([^,]+),([^,]+),(.+)")
            factions.list[faction_name] = {
                name = faction_name,
                leader = leader,
                members = {},
                tax = 0
            }
            -- Ajouter les membres
            for member_info in members_str:gmatch("([^;]+)") do
                local member_name, role = member_info:match("([^:]+):([^:]+)")
                if member_name and role then
                    factions.list[faction_name].members[member_name] = role
                end
            end
        end
        file:close()
    end
end

-- Fonction pour sauvegarder les factions dans un fichier
function factions.save_factions()
    local file = io.open(minetest.get_worldpath() .. "/factions.txt", "w")
    for faction_name, faction in pairs(factions.list) do
        local members_str = ""
        for member_name, role in pairs(faction.members) do
            members_str = members_str .. member_name .. ":" .. role .. ";"
        end
        -- Retire la dernière virgule et écrit dans le fichier
        members_str = members_str:sub(1, -2)
        file:write(faction_name .. "," .. faction.leader .. "," .. members_str .. "\n")
    end
    file:close()
end

-- Fonction pour créer une faction
function factions.create(player_name, faction_name)
    if factions.list[faction_name] then
        return false, "La faction existe déjà."
    end

    -- Vérification si le joueur est déjà dans une faction
    if factions.get_player_faction(player_name) then
        return false, "Vous êtes déjà dans une faction."
    end

    factions.list[faction_name] = {
        name = faction_name,
        leader = player_name,
        members = {[player_name] = "chefdefac"},
        tax = 0
    }
    return true, "Faction '" .. faction_name .. "' créée avec succès."
end

-- Inviter un joueur dans la faction
function factions.invite(player_name, faction_name, target_player)
    if not factions.list[faction_name] then
        return false, "Faction introuvable."
    end

    local faction = factions.list[faction_name]
    if faction.leader ~= player_name then
        return false, "Vous n'êtes pas le chef de cette faction."
    end

    if faction.members[target_player] then
        return false, target_player .. " est déjà membre de la faction ou a déjà été invité."
    end

    faction.members[target_player] = "attente" -- Attribuer le rôle "attente" à l'invité

    -- Envoie un message au joueur invité s'il est en ligne
    local target_player_obj = minetest.get_player_by_name(target_player)
    if target_player_obj then
        minetest.chat_send_player(
            target_player,
            "Vous avez été invité à rejoindre la faction '" ..
                faction_name .. "'. Tapez /f join " .. faction_name .. " pour rejoindre ou /f refuse pour refuser."
        )
    else
        -- S'il n'est pas connecté, un message sera envoyé à la prochaine connexion
        minetest.register_on_joinplayer(
            function(player)
                if player:get_player_name() == target_player then
                    minetest.chat_send_player(
                        target_player,
                        "Vous avez été invité à rejoindre la faction '" ..
                            faction_name ..
                                "'. Tapez /f join " .. faction_name .. " pour rejoindre ou /f refuse pour refuser."
                    )
                end
            end
        )
    end

    return true, "Invitation envoyée à " .. target_player
end

-- Fonction pour accepter une invitation
function factions.accept_invite(player_name, faction_name)
    if not factions.list[faction_name] then
        return false, "Faction introuvable."
    end

    local faction = factions.list[faction_name]
    if faction.members[player_name] ~= "attente" then
        return false, "Vous n'avez pas d'invitation active à rejoindre cette faction."
    end

    if factions.get_player_faction(player_name) ~= nil then
        return false, "Vous êtes déjà dans une faction."
    end

    faction.members[player_name] = "membre" -- Changer le rôle à "membre"
    return true, "Vous avez rejoint la faction '" .. faction_name .. "'."
end

-- Fonction pour refuser une invitation
function factions.refuse_invite(player_name, faction_name)
    if not factions.list[faction_name] then
        return false, "Faction introuvable."
    end

    local faction = factions.list[faction_name]
    if faction.members[player_name] ~= "attente" then
        return false, "Vous n'avez pas d'invitation active à cette faction."
    end

    faction.members[player_name] = nil -- Supprimer le rôle d'attente
    return true, "Vous avez refusé l'invitation à la faction '" .. faction_name .. "'."
end

function factions.kick(player_name, faction_name, target_player)
    if not factions.list[faction_name] then
        return false, "Faction introuvable."
    end

    local faction = factions.list[faction_name]
    if faction.leader ~= player_name and faction.members[player_name] ~= "co-leader" then
        return false, "Vous n'avez pas l'autorité pour expulser des joueurs."
    end

    -- Vérification si le joueur cible est un membre
    if not faction.members[target_player] then
        return false, target_player .. " n'est pas membre de la faction."
    end

    -- Ajout de la vérification pour éviter qu'un joueur s'expulse lui-même
    if target_player == player_name then
        return false, "Vous ne pouvez pas vous expulser de votre propre faction."
    end

    if target_player == faction.leader then
        return false, target_player .. " ne peut pas être expulsé car il est le chef."
    end

    faction.members[target_player] = nil
    return true, target_player .. " a été expulsé de la faction."
end

-- Liste des factions présentes sur le serveur
function factions.list_factions()
    local faction_list = "Factions présentes :\n"
    for faction_name, _ in pairs(factions.list) do
        faction_list = faction_list .. faction_name .. "\n"
    end
    return faction_list
end

-- Afficher le menu de faction
function factions.show_menu(player_name)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        minetest.chat_send_player(player_name, "Vous n'êtes dans aucune faction.")
        return
    end

    local faction = factions.list[faction_name]
    local members = ""
    for member, rank in pairs(faction.members) do
        members = members .. member .. " (" .. rank .. ")\n"
    end

    -- Menu principal de la faction
    local formspec =
        "size[10,8]" ..
        "background[-4,-3;18,14;background1.png]" ..
            "label[0,1;Faction: " ..
                faction_name ..
                    "]" ..
                        "label[0,2;Chef: " ..
                            faction.leader ..
                                "]" ..
                                    "label[0,3;Membres:]" ..
                                        "textarea[0.5,4;9.5,3;;;" ..
                                            members ..
                                                "]" ..
                                                    "image_button[0,6;3,1;invitation.png;invite;]" ..
                                                        "image_button[3,6;3,1;quitter.png;quitfac;]"

    local player_rank = faction.members[player_name]
    print("Le rang du joueur " .. player_name .. " est : " .. tostring(player_rank))

    -- Vérifiez le rôle du joueur pour afficher les options appropriées
    if faction.leader == player_name or player_rank == "co-leader" then
        formspec = formspec .. "image_button[6,5;3,1;expulser.png;kick;]"
    end

    if faction.leader == player_name or player_rank == "co-leader" then
        formspec = formspec .. "image_button[6,6;3,1;roles.png;roles;]"
    end
    minetest.show_formspec(player_name, "factions:menu", formspec)
end

function factions.show_roles_form(player_name)
    local faction_name = factions.get_player_faction(player_name)
    local faction = factions.list[faction_name]

    local member_list = ""
    local role_list = ""

    -- Get the player's role
    local player_role = faction.members[player_name] or ""

    if player_role == "chefdefac" then
        role_list = "co-leader,membre,conseillé"
    elseif player_role == "co-leader" then
        role_list = "membre,conseillé"
    end

    for member, info in pairs(faction.members) do
        if info ~= "chefdefac" and info ~= "attente" then
            member_list = member_list .. member .. ","
        end
    end

    member_list = member_list:sub(1, -2) -- Remove the last comma

    local formspec =
        "size[4,4]" ..
        "background[-2,-2;9,9;background1.png]" ..
            "label[1.5,0;Attribuer des rôles]" ..
                "dropdown[0.9,1;3.5;target_member;" ..
                    member_list ..
                        ";0]" ..
                            "dropdown[0.9,2.1;3.5;target_role;" ..
                                role_list .. ";0]" .. "image_button[1,3.1;3,1;attribuer.png;assign_role;]"

    minetest.show_formspec(player_name, "factions:roles", formspec)
end

function factions.show_invite_form(player_name)
    local formspec =
        "size[4,2]" ..
        "background[-2,-1.5;8,6;background5.png]" ..
            "label[0,0;Inviter un joueur]" ..
                "field[0.5,1;3.5,1;target_player;Nom du joueur;]" ..
                    "image_button[0.5,1.6;3,1;Valider.png;invite_confirm;]"

    minetest.show_formspec(player_name, "factions:invite", formspec)
end

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "factions:invite" then
            if fields.invite_confirm then
                local target_player = fields.target_player
                if target_player and target_player ~= "" then
                    local success, msg =
                        factions.invite(player_name, factions.get_player_faction(player_name), target_player)
                    minetest.chat_send_player(player_name, msg)
                end

                -- Retour au menu après avoir invité
                factions.show_menu(player_name)
            elseif fields.cancel then
                factions.show_menu(player_name) -- Retour au menu de faction
            end
        end
    end
)

local function is_chefdefac(player)
    local faction_name = factions.get_player_faction(player)
    if not faction_name then
        return false, "Vous n'êtes dans aucune faction."
    end

    local faction = factions.list[faction_name]
    local player_name = player:get_player_name()
    if player_name == faction.leader then
        return true
    end
end

minetest.register_on_punchplayer(
    function(puncher, victim)
        if not puncher or not victim then
            return
        end

        local puncher_name = victim:get_player_name()
        local victim_name = puncher:get_player_name()

        -- Obtenez les factions des joueurs
        local puncher_faction = factions.get_player_faction(puncher_name)
        local victim_faction = factions.get_player_faction(victim_name)

        -- Vérifiez si les joueurs appartiennent à la même faction
        if puncher_faction and victim_faction and puncher_faction == victim_faction then
            -- Annulez le coup
            minetest.chat_send_player(puncher_name, "Vous ne pouvez pas frapper un membre de votre propre faction.")
            return true -- Indique que l'action a été annulée
        end
    end
)

local function show_quit_confirmation(player)
    local formspec =
        "size[5,3]" ..
        "background[-2,-2;9,7;background1.png]" ..
            "label[0.5,0.5;Êtes-vous sûr de vouloir quitter la faction ?]" ..
                "image_button[0.5,2;2,0.8;Valider.png;confirm_quit;]" ..
                    "image_button[2.5,2;2,0.8;Annuler.png;cancel_quit;]"
    minetest.show_formspec(player:get_player_name(), "quit_confirmation", formspec)
end

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        player_name = player:get_player_name()
        if formname == "quit_confirmation" then
            if fields.confirm_quit then
                -- Ici, ajoutez votre logique pour quitter la fac
                minetest.chat_send_player(player:get_player_name(), "Vous avez quitté la fac.")
            elseif fields.cancel_quit then
                factions.show_menu(player_name)
            end
        end

        -- Si le joueur clique sur "Quitter la fac"
        if fields.quit_fac and not is_chefdefac(player) then
            show_quit_confirmation(player)
        end
    end
)

function factions.show_kick_form(player_name)
    local formspec =
        "size[8,5]" ..
        "background[-2,-2;12,9;background1.png]" ..
            "field[1,1.5;6,1;target_player;Nom du joueur;]" ..
                "label[2,0.5;Entrez le nom du joueur à expulser]" ..
                    "image_button[0.8,2.2;3,1;Confirmer_expulsion.png;kick_confirm;]" ..
                        "image_button[3.8,2.2;3,1;Annuler.png;cancel;]"

    minetest.show_formspec(player_name, "factions:kick", formspec)
end

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "factions:kick" then
            if fields.kick_confirm then
                local target_player = fields.target_player
                local faction_name = factions.get_player_faction(player_name)

                if target_player and target_player ~= "" then
                    local success, msg = factions.kick(player_name, faction_name, target_player)
                    minetest.chat_send_player(player_name, msg)
                else
                    minetest.chat_send_player(player_name, "Erreur : veuillez entrer un nom valide.")
                end

                -- Retour au menu après avoir expulsé un joueur
                factions.show_menu(player_name)
            elseif fields.cancel then
                factions.show_menu(player_name) -- Retour au menu de faction
            end
        end
    end
)

function factions.promote_to_chefdefac(player_name, target_member)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        return false, "Vous n'êtes pas dans une faction."
    end

    local faction = factions.list[faction_name]

    -- Vérifiez que le joueur cible est un membre de la faction
    if not faction.members[target_member] then
        return false, target_member .. " n'est pas membre de la faction."
    end

    local formspec =
        "size[5,3]" ..
        "background[-2,-2;9,7;background1.png]" ..
            "label[0.5,0.5;Êtes-vous sûr de vouloir promouvoir " ..
                target_member ..
                    " au rôle de chef de faction ?]" ..
                        "button[0.5,1.5;2,1;confirm_promote;Confirmer]" .. "button[2.5,1.5;2,1;cancel_promote;Annuler]"

    -- Ajoutez le membre cible au contexte pour pouvoir l'utiliser plus tard
    minetest.show_formspec(player_name, "promote_confirmation", formspec)
end

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "promote_confirmation" then
            if fields.confirm_promote then
                -- Récupérer le joueur cible
                local target_member = fields.target_member -- Vous devez définir cela
                local faction_name = factions.get_player_faction(player_name)

                -- Effectuer la promotion
                local faction = factions.list[faction_name]
                faction.members[target_member] = "chefdefac"
                faction.leader = target_member -- Mettre à jour le chef actuel
                minetest.chat_send_player(player_name, target_member .. " a été promu chef de faction.")
            elseif fields.cancel_promote then
                factions.show_menu(player_name)
            end
        end
    end
)

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "promote_confirmation" then
            if fields.confirm_promote then
                -- Récupérer le joueur cible
                local target_member = fields.target_member
                local faction_name = factions.get_player_faction(player_name)

                -- Effectuer la promotion
                local faction = factions.list[faction_name]
                faction.members[target_member] = "chefdefac"
                faction.members[player_name] = "co-leader" -- Mettre à jour le rôle du chef actuel
                minetest.chat_send_player(player_name, target_member .. " a été promu chef de faction.")
            elseif fields.cancel_promote then
                factions.show_menu(player_name)
            end
        end
    end
)

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "factions:roles" then
            if fields.role_confirm then
                local target_member = fields.target_member
                local target_role = fields.target_role
                local faction_name = factions.get_player_faction(player_name)

                if target_member and target_role then
                    local success, msg = factions.assign_role(player_name, faction_name, target_member, target_role)
                    minetest.chat_send_player(player_name, msg)
                end

                -- Retour au menu après avoir attribué un rôle
                factions.show_menu(player_name)
            elseif fields.cancel then
                factions.show_menu(player_name) -- Retour au menu de faction
            end
        end
    end
)

function factions.quit(player_name)
    local faction_name = factions.get_player_faction(player_name)
    if not faction_name then
        return false, "Vous n'êtes dans aucune faction."
    end

    local faction = factions.list[faction_name]
    local player_rank = faction.members[player_name]

    -- Si le joueur est le chef de la faction
    if player_name == faction.leader then
        -- Vérifiez s'il y a des co-leaders
        local co_leaders = {}
        for member, role in pairs(faction.members) do
            if role == "co-leader" then
                table.insert(co_leaders, member)
            end
        end

        if #co_leaders > 0 then
            -- Si des co-leaders existent, demander au chef de choisir un nouveau leader
            factions.show_quit_form(player_name, co_leaders)
        else
            -- Dissoudre la faction uniquement si le chef quitte et qu'il n'y a pas de co-leaders
            factions.list[faction_name] = nil
            factions.remove_claims(faction_name)
            minetest.chat_send_player(
                player_name,
                "La faction '" .. faction_name .. "' a été dissoute car il n'y a pas de co-leaders."
            )
            return true
        end
    else
        -- Si un membre ordinaire ou un co-leader quitte, il quitte simplement la faction
        faction.members[player_name] = nil
        minetest.chat_send_player(player_name, "Vous avez quitté la faction '" .. faction_name .. "'.")
        return true
    end
end

function factions.show_quit_form(player_name, co_leaders)
    local co_leader_list = table.concat(co_leaders, ",")

    local formspec =
        "size[5,3]" ..
        "background[-2,-2;9,7;background1.png]" ..
            "label[0,0;      Choisissez un nouveau chef de faction \n                    parmi les co-leaders :]" ..
                "dropdown[0.5,1;4,1;new_leader;" ..
                    co_leader_list ..
                        ";1]" ..
                            "image_button[0.5,2;2,0.8;Valider.png;confirm_leader_quit;]" ..
                                "image_button[2.5,2;2,0.8;Annuler.png;cancel_quit;]"
     --

    --[[local formspec = "size[5,3]" ..
        "label[0,0;Choisissez un nouveau chef de faction parmi les co-leaders :]" ..
        "dropdown[0.5,1;4,1;new_leader;" .. co_leader_list .. ";1]" ..
        "button[0.5,2;2,1;confirm_leader_quit;Confirmer]" ..
        "button[2.5,2;2,1;cancel_quit;Annuler]"]] minetest.show_formspec(
        player_name,
        "factions:quit_leader",
        formspec
    )
end

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()
        local faction_name = factions.get_player_faction(player_name)
        if formname == "factions:quit_leader" then
            if fields.confirm_leader_quit then
                local target_member = fields.new_leader
                local role = "chefdefac"
                if target_member and role then
                    local success, msg = factions.assign_role(player_name, target_member, role)
                    minetest.chat_send_player(player_name, msg)
                    local faction = factions.list[faction_name]
                    faction.members[player_name] = nil
                    faction.leader = target_member
                end
                factions.show_menu(player_name)
            elseif fields.cancel_quit then
                factions.show_menu(player_name)
            end
        end
    end
)

function show_quit_confirmation(player_name)
    local formspec =
        "size[5,3]" ..
        "background[-2,-2;9,7;background1.png]" ..
            "label[0.5,0.5;Êtes-vous sûr de vouloir quitter la faction ?]" ..
                "image_button[0.5,2;2,0.8;Valider.png;confirm_quit;]" ..
                    "image_button[2.5,2;2,0.8;Annuler.png;cancel_quit;]"
    minetest.show_formspec(player_name, "quit_confirmation", formspec)
end

function factions.assign_role(player_name, target_member, role)
    local faction_name = factions.get_player_faction(player_name)

    if not faction_name then
        return false, "Vous n'êtes pas dans une faction."
    end

    local faction = factions.list[faction_name]

    if not faction.members[target_member] then
        return false, target_member .. " n'est pas membre de la faction."
    end

    faction.members[target_member] = role -- Remplacer directement le rôle
    return true, target_member .. " a été attribué au rôle " .. role .. "."
end

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "factions:roles" then
            if fields.assign_role then
                local target_member = fields.target_member -- Corrigé ici
                local role = fields.target_role -- Corrigé ici
                if target_member and role then
                    local success, msg = factions.assign_role(player_name, target_member, role)
                    minetest.chat_send_player(player_name, msg)
                end
                factions.show_menu(player_name)
            end
        end
    end
)

minetest.register_on_player_receive_fields(
    function(player, formname, fields)
        local player_name = player:get_player_name()

        if formname == "factions:menu" then
            if fields.invite then
                factions.show_invite_form(player_name) -- Ouvre le formulaire d'invitation
            elseif fields.kick then
                factions.show_kick_form(player_name) -- Ouvre le formulaire d'expulsion
            elseif fields.quitfac then
                show_quit_confirmation(player_name)
            elseif fields.roles then
                factions.show_roles_form(player_name) -- Ouvre le formulaire d'attribution de rôles
            end
        elseif formname == "quit_confirmation" then
            if fields.confirm_quit then
                factions.quit(player_name) -- Appelle la fonction de quitter la faction
                return true
            elseif fields.cancel_quit then
                factions.show_menu(player_name) -- Retour au menu de faction
            end
        elseif formname == "factions:invite" then
            if fields.invite_confirm then
                local target_player = fields.target_player
                if target_player and target_player ~= "" then
                    local success, msg =
                        factions.invite(player_name, factions.get_player_faction(player_name), target_player)
                    minetest.chat_send_player(player_name, msg)
                end
            elseif target_player == "" then
                minetest.chat_send_player(player_name, "Veullez entrer un nombre valide")
                factions.show_menu(player_name)
                factions.show_menu(player_name) -- Retour au menu après avoir invité
            elseif fields.cancel then
                factions.show_menu(player_name) -- Retour au menu de faction
            end
        elseif formname == "factions:roles" then
            if fields.assign_role then
                local target_member = fields.target_member -- Corrigé ici
                local role = fields.target_role -- Corrigé ici
                if target_member and role then
                    local success, msg = factions.assign_role(player_name, target_member, role)
                    minetest.chat_send_player(player_name, msg)
                end
            end
        end
    end
)

-- Fonction pour obtenir la faction d'un joueur
function factions.get_player_faction(player_name)
    for faction_name, faction in pairs(factions.list) do
        if faction.members[player_name] then
            return faction_name
        end
    end
    return nil
end

factions.load_factions()

-- Enregistrer les factions à l'arrêt du serveur
minetest.register_on_shutdown(
    function()
        factions.save_factions()
    end
)
