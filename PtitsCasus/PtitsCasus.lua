local _, ns = ...
local Api = ns.Api

local dernierEnvoi, dernierEquipement -- pour ne pas renvoyer deux fois la même chose

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

-- Dernières infos connues d'un membre, dans la sauvegarde.
local function Fiche(nom)
  local cle = Api.NomCourt(nom)
  PtitsCasusDB.membres[cle] = PtitsCasusDB.membres[cle] or { metiers = {} }
  return PtitsCasusDB.membres[cle]
end

local function Stocker(nom, metiers)
  local fiche = Fiche(nom)
  fiche.metiers = metiers
  fiche.maj = time()
  fiche.dateMetiers = Api.Heure() -- reçus du joueur lui-même : date d'origine pour le relais
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

-- Équipement, en un ou plusieurs messages : "E" date ~ numéro ~ total ~ ilvl ~ "tete:12345:62:r:0;cou:12346:60:u:1883"
-- (emplacement:identifiant:niveau d'objet:qualité:enchantement, 0 si aucun). Les morceaux partent à une seconde d'écart.
local TAILLE_MORCEAU = 170 -- place laissée devant pour le nom du joueur dans un message relayé

local function Decouper(parties, separateur)
  local morceaux, courant = {}, ""
  for _, element in ipairs(parties) do
    local partie = tostring(element)
    if #courant + #partie + 1 > TAILLE_MORCEAU then
      table.insert(morceaux, courant)
      courant = ""
    end
    courant = courant == "" and partie or (courant .. separateur .. partie)
  end
  table.insert(morceaux, courant)
  return morceaux
end

local function EnvoyerEquipement()
  local parties = {}
  for cle, objet in pairs(Api.LireEquipement()) do
    local id, enchantement = objet.lien:match("item:(%d+):(%d*)")
    if id then
      local enchant = enchantement ~= "" and enchantement or "0"
      table.insert(parties, table.concat({ cle, id, math.floor(objet.ilvl), objet.qualite, enchant }, ":"))
    end
  end
  table.sort(parties)
  local texte = table.concat(parties, ";")
  if texte == dernierEquipement then
    return
  end
  dernierEquipement = texte
  local date, ilvl = Api.Heure(), Api.MonNiveauObjet() or 0
  local morceaux = Decouper(parties, ";")
  for i, morceau in ipairs(morceaux) do
    C_Timer.After(i - 1, function()
      Api.EnvoyerGuilde(table.concat({ "E" .. date, i, #morceaux, ilvl, morceau }, "~"))
    end)
  end
end

-- Recettes, métier par métier, en plusieurs messages : "T" date ~ numéro ~ total ~ métier ~ "2329,2330,3170".
-- Elles ne partent en entier que quand elles changent ou à la demande : renvoyer toutes les recettes
-- de tout le monde à chaque connexion ferait beaucoup trop de messages. À une connexion, chacun annonce
-- seulement la date de ses listes ("V"), et ceux à qui il en manque une la demandent ("P").
-- Renvoie le délai à attendre avant d'envoyer autre chose.
local function EnvoyerRecettes(metier, delai)
  local liste = Fiche(Api.MonNom()).recettes[metier]
  local morceaux = Decouper(liste.ids, ",")
  for i, morceau in ipairs(morceaux) do
    C_Timer.After(delai + i - 1, function()
      Api.EnvoyerGuilde(table.concat({ "T" .. liste.date, i, #morceaux, metier, morceau }, "~"))
    end)
  end
  return delai + #morceaux
end

local function EnvoyerToutesRecettes()
  local fiche = Fiche(Api.MonNom())
  local delai = 0
  for metier in pairs(fiche.recettes or {}) do
    delai = EnvoyerRecettes(metier, delai)
  end
end

-- Message "VAlchimie:1800000000;Couture:1800000100".
local function AnnoncerRecettes()
  local parties = {}
  for metier, liste in pairs(Fiche(Api.MonNom()).recettes or {}) do
    table.insert(parties, metier .. ":" .. liste.date)
  end
  if #parties > 0 then
    Api.EnvoyerGuilde("V" .. table.concat(parties, ";"))
  end
end

-- Un membre annonce ses listes : on demande celles qu'on n'a pas, ou qui sont plus récentes
-- que les nôtres. Message "P" joueur ~ métier.
local function RecevoirAnnonce(texte, expediteur)
  local recettes = Fiche(expediteur).recettes or {}
  for metier, date in texte:sub(2):gmatch("([^:;~]+):(%d+)") do
    if not recettes[metier] or tonumber(date) > recettes[metier].date then
      C_Timer.After(math.random(1, 10), function()
        Api.EnvoyerGuilde("P" .. Api.NomCourt(expediteur) .. "~" .. metier)
      end)
    end
  end
end

-- Quelqu'un demande une de mes listes : envoyée une seule fois par minute, même si plusieurs la demandent,
-- et jamais en même temps qu'une autre.
local demandes, finEnvoi = {}, 0

local function RecevoirDemande(texte)
  local nom, metier = texte:match("^P([^~]+)~(.+)$")
  local moi = Api.NomCourt(Api.MonNom())
  if nom ~= moi or not (Fiche(moi).recettes or {})[metier] then
    return
  end
  local maintenant = GetTime()
  if demandes[metier] and maintenant - demandes[metier] < 60 then
    return
  end
  demandes[metier] = maintenant
  finEnvoi = maintenant + EnvoyerRecettes(metier, math.max(0, finEnvoi - maintenant))
end

-- Morceaux reçus, par joueur et par sujet. Rien n'est remplacé avant l'arrivée de tous les morceaux.
local enCours = {}

-- Renvoie tous les morceaux quand le dernier arrive, nil sinon.
local function Assembler(cle, date, i, total, morceau)
  -- Même date mais autre découpage (ancienne version de l'addon) : on repart de zéro.
  if not enCours[cle] or enCours[cle].date ~= date or enCours[cle].total ~= total then
    enCours[cle] = { date = date, total = total, morceaux = {}, recus = 0 }
  end
  local reception = enCours[cle]
  if not reception.morceaux[i] then
    reception.morceaux[i] = morceau
    reception.recus = reception.recus + 1
  end
  if reception.recus == total then
    enCours[cle] = nil
    return reception.morceaux
  end
end

local function Actualiser()
  if ns.UI.panneau:IsShown() then
    ns.UI.RafraichirTout()
  end
end

local function RecevoirEquipement(texte, expediteur)
  local date, i, total, ilvl, morceau = texte:match("^E(%d+)~(%d+)~(%d+)~(%d+)~(.*)$")
  date, i, total = tonumber(date), tonumber(i), tonumber(total)
  local fiche = Fiche(expediteur)
  if not date or i < 1 or i > total or total > 5 or date <= (fiche.dateEquipement or 0) then
    return -- message abîmé ou plus ancien que ce qu'on a déjà
  end
  local morceaux = Assembler("E:" .. Api.NomCourt(expediteur), date, i, total, morceau)
  if not morceaux then
    return
  end
  local equipement = {}
  for _, m in ipairs(morceaux) do
    for cle, id, niveau, qualite, enchant in m:gmatch("(%a[%w]*):(%d+):(%d+):([cure]):(%d+)") do
      if Api.EstEmplacement(cle) then
        -- Lien réduit à l'objet et son enchantement : la bulle du jeu affiche les deux.
        equipement[cle] = { lien = "item:" .. id .. ":" .. enchant, ilvl = tonumber(niveau), qualite = qualite }
      end
    end
  end
  fiche.equipement = equipement
  fiche.ilvl = tonumber(ilvl) > 0 and tonumber(ilvl) or nil
  fiche.dateEquipement = date
  Actualiser()
end

local function RecevoirRecettes(texte, expediteur)
  local date, i, total, metier, morceau = texte:match("^T(%d+)~(%d+)~(%d+)~([^~]+)~(.*)$")
  date, i, total = tonumber(date), tonumber(i), tonumber(total)
  if not date or i < 1 or i > total or total > 40 then
    return
  end
  local fiche = Fiche(expediteur)
  fiche.recettes = fiche.recettes or {}
  local ancienne = fiche.recettes[metier]
  if ancienne and date <= ancienne.date then
    return
  end
  local morceaux = Assembler("T:" .. Api.NomCourt(expediteur) .. ":" .. metier, date, i, total, morceau)
  if not morceaux then
    return
  end
  local ids = {}
  for id in table.concat(morceaux, ","):gmatch("%d+") do
    table.insert(ids, tonumber(id))
  end
  fiche.recettes[metier] = { ids = ids, date = date }
  Actualiser()
end

-- Relais : chacun retransmet les infos des autres membres qu'il a reçues, pour qu'elles circulent même
-- entre deux joueurs jamais connectés en même temps. Seuls les métiers, l'équipement et les recettes
-- sont relayés (jamais les commandes ni le loot), avec leur date d'origine : on garde toujours la plus
-- récente. Personne ne relaie d'infos sur moi : je suis la seule source des miennes.
-- "A" date ~ numéro ~ total ~ "Pastus Hoffman:métiers:équipement:recettes,..." : à ma connexion, la date
-- de ce que je connais de chacun. Ceux qui ont plus récent, ou un joueur que je n'ai pas, me l'envoient.
-- "X" joueur ~ message : une info relayée ("M" date ~ métiers, ou un message "E" ou "T" comme plus haut).
local ESPACEMENT_RELAIS = 1.5 -- secondes entre deux messages relayés
local file, fileEnCours = {}, false -- messages relayés en attente : { cle, date, texte }

local function DateMetiers(fiche)
  return fiche.dateMetiers or fiche.maj or 0
end

local function DateRecettes(fiche)
  local date = 0
  for _, liste in pairs(fiche.recettes or {}) do
    date = math.max(date, liste.date)
  end
  return date
end

local function ViderFile()
  local message = table.remove(file, 1)
  if not message then
    fileEnCours = false
    return
  end
  Api.EnvoyerGuilde(message.texte)
  C_Timer.After(ESPACEMENT_RELAIS, ViderFile)
end

-- Départ après une attente au hasard : le premier qui relaie une info, les autres l'annulent chez eux.
local function DemarrerFile()
  if #file > 0 and not fileEnCours then
    fileEnCours = true
    C_Timer.After(math.random(2, 10), ViderFile)
  end
end

local function Ajouter(cle, date, texte)
  for _, message in ipairs(file) do
    if message.texte == texte then
      return
    end
  end
  table.insert(file, { cle = cle, date = date, texte = texte })
end

-- Quelqu'un a déjà relayé cette info (aussi récente que la mienne) : inutile de la renvoyer.
local function Annuler(cle, date)
  for i = #file, 1, -1 do
    if file[i].cle == cle and file[i].date <= date then
      table.remove(file, i)
    end
  end
end

-- Met en file ce que je connais de ce joueur et qui est plus récent que les dates annoncées.
local function Relayer(nom, fiche, dateM, dateE, dateR)
  local entete = "X" .. nom .. "~"
  local date = DateMetiers(fiche)
  if #(fiche.metiers or {}) > 0 and date > dateM then
    Ajouter("M:" .. nom, date, entete .. "M" .. date .. "~" .. Encoder(fiche.metiers):sub(2))
  end
  if fiche.equipement and (fiche.dateEquipement or 0) > dateE then
    local parties = {}
    for cle, e in pairs(fiche.equipement) do
      local id, enchant = e.lien:match("item:(%d+):(%d+)")
      if id then
        table.insert(parties, table.concat({ cle, id, e.ilvl or 0, e.qualite or "c", enchant }, ":"))
      end
    end
    table.sort(parties)
    local morceaux = Decouper(parties, ";")
    for i, morceau in ipairs(morceaux) do
      Ajouter("E:" .. nom, fiche.dateEquipement, entete .. table.concat(
        { "E" .. fiche.dateEquipement, i, #morceaux, fiche.ilvl or 0, morceau }, "~"))
    end
  end
  for metier, liste in pairs(fiche.recettes or {}) do
    if liste.date > dateR then
      local morceaux = Decouper(liste.ids, ",")
      for i, morceau in ipairs(morceaux) do
        Ajouter("T:" .. nom .. ":" .. metier, liste.date, entete .. table.concat(
          { "T" .. liste.date, i, #morceaux, metier, morceau }, "~"))
      end
    end
  end
end

local function AnnoncerConnus()
  local moi = Api.NomCourt(Api.MonNom())
  local parties = {}
  for nom, fiche in pairs(PtitsCasusDB.membres) do
    if nom ~= moi then
      table.insert(parties, table.concat({ nom, DateMetiers(fiche), fiche.dateEquipement or 0, DateRecettes(fiche) }, ":"))
    end
  end
  local date = Api.Heure()
  local morceaux = Decouper(parties, ",")
  for i, morceau in ipairs(morceaux) do
    C_Timer.After(i - 1, function()
      Api.EnvoyerGuilde(table.concat({ "A" .. date, i, #morceaux, morceau }, "~"))
    end)
  end
end

local function RecevoirConnus(texte, expediteur)
  local moi, lui = Api.NomCourt(Api.MonNom()), Api.NomCourt(expediteur)
  local date, i, total, morceau = texte:match("^A(%d+)~(%d+)~(%d+)~(.*)$")
  date, i, total = tonumber(date), tonumber(i), tonumber(total)
  if lui == moi or not date or i < 1 or i > total or total > 20 then
    return
  end
  local morceaux = Assembler("A:" .. lui, date, i, total, morceau)
  if not morceaux then
    return
  end
  local connus = {}
  for nom, dateM, dateE, dateR in table.concat(morceaux, ","):gmatch("([^,:]+):(%d+):(%d+):(%d+)") do
    connus[nom] = { tonumber(dateM), tonumber(dateE), tonumber(dateR) }
  end
  for nom, fiche in pairs(PtitsCasusDB.membres) do
    if nom ~= moi and nom ~= lui and Api.EstMembre(nom) then
      local c = connus[nom] or { 0, 0, 0 }
      Relayer(nom, fiche, c[1], c[2], c[3])
    end
  end
  DemarrerFile()
end

local function RecevoirRelais(texte, expediteur)
  local moi = Api.NomCourt(Api.MonNom())
  local nom, interieur = texte:match("^X([^~]+)~(.+)$")
  if Api.NomCourt(expediteur) == moi or not nom or nom == moi or nom == Api.NomCourt(expediteur)
    or not Api.EstMembre(nom) then
    return -- mon propre relais, message abîmé, info sur moi-même ou sur un joueur hors guilde
  end
  local sorte, date = interieur:match("^([MET])(%d+)~")
  date = tonumber(date)
  if not date or date > Api.Heure() + 300 then
    return -- date dans le futur : refusée, elle ne pourrait plus jamais être remplacée
  end
  if sorte == "M" then
    Annuler("M:" .. nom, date)
    local fiche = Fiche(nom)
    if date > DateMetiers(fiche) then
      fiche.metiers = Decoder(interieur:match("^M%d+~(.*)$"))
      fiche.dateMetiers = date
      fiche.maj = time()
      Actualiser()
    end
  elseif sorte == "E" then
    Annuler("E:" .. nom, date)
    RecevoirEquipement(interieur, nom)
  else
    Annuler("T:" .. nom .. ":" .. (interieur:match("^T%d+~%d+~%d+~([^~]+)~") or ""), date)
    RecevoirRecettes(interieur, nom)
  end
end

-- Fenêtre de métier ouverte : garde les recettes et les envoie si elles ont changé.
local function CapturerRecettes()
  local metier, ids = Api.LireRecettes()
  if not metier then
    return
  end
  local fiche = Fiche(Api.MonNom())
  fiche.recettes = fiche.recettes or {}
  local ancienne = fiche.recettes[metier]
  if ancienne and table.concat(ancienne.ids, ",") == table.concat(ids, ",") then
    return
  end
  fiche.recettes[metier] = { ids = ids, date = Api.Heure() }
  EnvoyerRecettes(metier, 0)
  Actualiser()
end

-- Métiers, équipement et version de l'addon, même si rien n'a changé.
local function RenvoyerInfos()
  dernierEnvoi, dernierEquipement = nil, nil
  EnvoyerMetiers()
  EnvoyerEquipement()
  Api.EnvoyerGuilde("N" .. Api.VersionAddon())
end

-- "1.0.10" est plus récente que "1.0.9" : on compare nombre par nombre.
local function PlusRecente(a, b)
  local na, nb = {}, {}
  for n in a:gmatch("%d+") do table.insert(na, tonumber(n)) end
  for n in b:gmatch("%d+") do table.insert(nb, tonumber(n)) end
  for i = 1, math.max(#na, #nb) do
    if (na[i] or 0) ~= (nb[i] or 0) then
      return (na[i] or 0) > (nb[i] or 0)
    end
  end
  return false
end

-- Version la plus récente connue : la mienne ou celle d'un membre.
function ns.VersionRecente()
  local recente = Api.VersionAddon()
  for _, fiche in pairs(PtitsCasusDB.membres) do
    if fiche.version and PlusRecente(fiche.version, recente) then
      recente = fiche.version
    end
  end
  return recente
end

-- Une seule fois par session : prévient dans le chat qu'une version plus récente existe.
local versionSignalee = false
local function SignalerVersion()
  local recente = ns.VersionRecente()
  if not versionSignalee and recente ~= Api.VersionAddon() then
    versionSignalee = true
    print("|cffffd100Aux Ptits Casus|r : la version " .. recente .. " de l'addon existe (tu as la "
      .. Api.VersionAddon() .. "). Lien de téléchargement dans Réglages.")
  end
end

-- Bouton « Forcer ma synchronisation » des Réglages : renvoie tout.
function ns.ForcerSynchro()
  RenvoyerInfos()
  EnvoyerToutesRecettes()
end

-- Un membre vient de se connecter : on lui renvoie nos infos, après une attente au hasard
-- pour que tout le monde ne réponde pas en même temps.
local reponseEnAttente = false

local function RepondreConnexion()
  if reponseEnAttente then
    return
  end
  reponseEnAttente = true
  C_Timer.After(math.random(3, 20), function()
    reponseEnAttente = false
    RenvoyerInfos()
    AnnoncerRecettes()
  end)
end

-- Le jeu prévient souvent plusieurs fois de suite : une seule action, après ce délai.
local function ApresDelai(delai, action)
  local enAttente = false
  return function()
    if not enAttente then
      enAttente = true
      C_Timer.After(delai, function()
        enAttente = false
        action()
      end)
    end
  end
end

local EquipementChange = ApresDelai(2, EnvoyerEquipement)
local FenetreMetier = ApresDelai(1, CapturerRecettes)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("CHAT_MSG_ADDON")
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
    Api.InitMessages()
    ns.InitInterface()
    -- Petit délai : la guilde n'est pas toujours prête à la connexion.
    Fiche(Api.MonNom()).version = Api.VersionAddon()
    C_Timer.After(5, function()
      RenvoyerInfos()
      SignalerVersion() -- d'après les versions reçues lors des sessions précédentes
    end)
    C_Timer.After(15, AnnoncerRecettes)
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
    -- Commandes en attente : on réessaie chaque minute, au cas où le destinataire se reconnecte.
    C_Timer.NewTicker(60, ns.Commandes.ViderBoite)
    -- Demande les commandes de guilde à ceux qui sont déjà en ligne.
    C_Timer.After(8, ns.Commandes.DemanderGuilde)
    -- Annonce ce que je connais des autres : ceux qui ont plus récent me le relaient.
    C_Timer.After(12, AnnoncerConnus)
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    EquipementChange()
  elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
    FenetreMetier()
  elseif event == "SKILL_LINES_CHANGED" then
    if PtitsCasusDB then
      EnvoyerMetiers()
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefixe, texte, canal, expediteur = ...
    if ns.debug and Api.EstNotrePrefixe(prefixe) then
      print("Aux Ptits Casus reçu : [" .. tostring(expediteur) .. "] " .. tostring(canal) .. " " .. texte:sub(1, 40))
    end
    if not (Api.EstNotrePrefixe(prefixe) and PtitsCasusDB) then
      return
    end
    local sorte = texte:sub(1, 1)
    -- Le canal de guilde ne reçoit que des membres : un joueur extérieur ne peut pas s'y glisser.
    local guilde = canal == "GUILD"
    if sorte == "M" and guilde then
      Stocker(expediteur, Decoder(texte:sub(2)))
    elseif sorte == "E" and guilde then
      RecevoirEquipement(texte, expediteur)
    elseif sorte == "T" and guilde then
      RecevoirRecettes(texte, expediteur)
    elseif sorte == "V" and guilde then
      RecevoirAnnonce(texte, expediteur)
    elseif sorte == "P" and guilde then
      RecevoirDemande(texte)
    elseif sorte == "A" and guilde then
      RecevoirConnus(texte, expediteur)
    elseif sorte == "N" and guilde then
      Fiche(expediteur).version = texte:sub(2, 20)
      SignalerVersion()
    elseif sorte == "X" and guilde then
      RecevoirRelais(texte, expediteur)
    elseif ((sorte == "G" or sorte == "Q") and guilde) or ((sorte == "C" or sorte == "R") and canal == "WHISPER") then
      ns.Commandes.Recevoir(texte, expediteur) -- commande d'artisanat, réponse, commande de guilde
      if sorte == "Q" and Api.NomCourt(expediteur) ~= Api.NomCourt(Api.MonNom()) then
        RepondreConnexion()
      end
    end
  end
end)

-- /craft flacon : qui sait fabriquer une recette dont le nom contient ce texte.
local MAX_REPONSES = 10

SLASH_PTITSCASUSCRAFT1 = "/craft"
SlashCmdList.PTITSCASUSCRAFT = function(texte)
  local cherche = strtrim(texte):lower()
  if cherche == "" then
    print("Aux Ptits Casus : écris une partie du nom de la recette, par exemple /craft flacon.")
    return
  end
  local artisans = {} -- [recette] = { joueur, ... }
  for nom, fiche in pairs(PtitsCasusDB.membres) do
    for _, liste in pairs(fiche.recettes or {}) do
      for _, recette in ipairs(ns.UI.NomsRecettes(liste)) do
        if recette:lower():find(cherche, 1, true) then
          artisans[recette] = artisans[recette] or {}
          table.insert(artisans[recette], nom)
        end
      end
    end
  end
  local recettes = {}
  for recette in pairs(artisans) do
    table.insert(recettes, recette)
  end
  if #recettes == 0 then
    print("Aux Ptits Casus : aucune recette reçue pour « " .. cherche .. " ».")
    return
  end
  table.sort(recettes)
  for i = 1, math.min(#recettes, MAX_REPONSES) do
    table.sort(artisans[recettes[i]])
    print(recettes[i] .. " : " .. table.concat(artisans[recettes[i]], ", "))
  end
  if #recettes > MAX_REPONSES then
    print("… et " .. (#recettes - MAX_REPONSES) .. " autre(s) recette(s). Précise ta recherche.")
  end
end

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
