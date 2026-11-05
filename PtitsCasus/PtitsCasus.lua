local _, ns = ...
local Api = ns.Api

local dernierEnvoi -- pour ne pas renvoyer deux fois la même chose

-- Format du message : "M" puis "Alchimie:150:225;Cuisine:75:150"
local function Encoder(metiers)
  local parties = {}
  for _, m in ipairs(metiers) do
    table.insert(parties, m.nom .. ":" .. m.niveau .. ":" .. m.max)
  end
  return "M" .. table.concat(parties, ";")
end

local function Decoder(texte)
  local metiers = {}
  for nom, niveau, max in texte:gmatch("([^:;]+):(%d+):(%d+)") do
    table.insert(metiers, { nom = nom, niveau = tonumber(niveau), max = tonumber(max) })
  end
  return metiers
end

local function Stocker(nom, metiers)
  PtitsCasusDB.membres[Api.NomCourt(nom)] = { metiers = metiers, maj = time() }
end

local function EnvoyerMetiers()
  local metiers = Api.LireMetiers()
  local texte = Encoder(metiers)
  if texte == dernierEnvoi then
    return
  end
  dernierEnvoi = texte
  Stocker(Api.MonNom(), metiers)
  Api.EnvoyerGuilde(texte)
end

-- Bouton « Forcer la synchro » des Réglages : renvoie même si rien n'a changé.
function ns.ForcerSynchro()
  dernierEnvoi = nil
  EnvoyerMetiers()
  ns.UI.SynchroDroits()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    PtitsCasusDB = PtitsCasusDB or {}
    PtitsCasusDB.membres = PtitsCasusDB.membres or {}
    PtitsCasusDB.reglages = PtitsCasusDB.reglages or {}
    -- Anciens noms "Prénom-Royaume", d'avant la prise en compte du nom de famille.
    for nom in pairs(PtitsCasusDB.membres) do
      if nom:find("-", 1, true) then
        PtitsCasusDB.membres[nom] = nil
      end
    end
    if (PtitsCasusDB.reglages.maitreButin or ""):find("-", 1, true) then
      PtitsCasusDB.reglages.maitreButin = nil
    end
    Api.InitMessages()
    ns.InitInterface()
    -- Petit délai : la guilde n'est pas toujours prête à la connexion.
    C_Timer.After(5, EnvoyerMetiers)
    -- Commandes en attente : on réessaie chaque minute, au cas où le destinataire se reconnecte.
    C_Timer.NewTicker(60, ns.Commandes.ViderBoite)
    -- Demande les commandes de guilde à ceux qui sont déjà en ligne.
    C_Timer.After(8, ns.Commandes.DemanderGuilde)
    C_Timer.After(8, ns.UI.SynchroDroits)
  elseif event == "SKILL_LINES_CHANGED" then
    if PtitsCasusDB then
      EnvoyerMetiers()
    end
  elseif event == "GUILD_ROSTER_UPDATE" then
    ns.Commandes.ViderBoite() -- quelqu'un a pu se connecter
  elseif event == "CHAT_MSG_ADDON" then
    local prefixe, texte, _, expediteur = ...
    if not (Api.EstNotrePrefixe(prefixe) and PtitsCasusDB) then
      return
    end
    local sorte = texte:sub(1, 1)
    if sorte == "M" then
      Stocker(expediteur, Decoder(texte:sub(2)))
    elseif sorte == "C" or sorte == "R" or sorte == "G" or sorte == "Q" then
      ns.Commandes.Recevoir(texte, expediteur) -- commande d'artisanat, réponse, commande de guilde
    elseif sorte == "B" or sorte == "D" then
      ns.UI.RecevoirDroits(texte, expediteur) -- maître du butin
    end
  end
end)

SLASH_PTITSCASUSMETIERS1 = "/metiers"
SlashCmdList.PTITSCASUSMETIERS = function()
  local noms = {}
  for nom in pairs(PtitsCasusDB.membres) do
    table.insert(noms, nom)
  end
  if #noms == 0 then
    print("Aux Ptits Casus : aucun métier reçu pour l'instant.")
    return
  end
  table.sort(noms)
  for _, nom in ipairs(noms) do
    local parties = {}
    for _, m in ipairs(PtitsCasusDB.membres[nom].metiers) do
      table.insert(parties, m.nom .. " " .. m.niveau .. "/" .. m.max)
    end
    local liste = #parties > 0 and table.concat(parties, ", ") or "aucun métier"
    print(Api.NomCourt(nom) .. " : " .. liste)
  end
end
