-- Appels à l'API du jeu. Si WoW Forever se comporte autrement, on corrige seulement ce fichier.
local _, ns = ...
local Api = {}
ns.Api = Api

local PREFIXE = "PtitsCasus"

function Api.InitMessages()
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIXE)
end

function Api.EstNotrePrefixe(prefixe)
  return prefixe == PREFIXE
end

function Api.EnvoyerGuilde(texte)
  if IsInGuild() then
    C_ChatInfo.SendAddonMessage(PREFIXE, texte, "GUILD")
  end
end

-- Heure du serveur, la même pour tous les joueurs (en secondes).
function Api.Heure()
  return GetServerTime()
end

-- Message d'addon à un seul joueur (invisible dans son chat).
function Api.EnvoyerA(nom, texte)
  C_ChatInfo.SendAddonMessage(PREFIXE, texte, "WHISPER", nom)
end

-- Ouvre la ligne de chat sur un chuchotement à ce joueur, sans texte : le joueur écrit lui-même.
function Api.OuvrirChuchotement(nom)
  ChatFrame_OpenChat("/w " .. nom .. " ")
end

-- Nom d'un joueur (unité du jeu). Sur Forever, le jeu donne le prénom puis le nom de famille : "Hamax Budok".
local function NomUnite(unite)
  local prenom, nomFamille = UnitNameUnmodified(unite)
  if nomFamille and nomFamille ~= "" then
    return prenom .. " " .. nomFamille
  end
  return prenom
end

-- Mon nom, écrit comme dans la liste de guilde.
function Api.MonNom()
  return NomUnite("player")
end

-- "Nom-Royaume" -> "Nom" si même royaume.
function Api.NomCourt(nom)
  return Ambiguate(nom, "guild")
end

-- Renvoie { ["Nom"] = { classe = "MAGE", rang = "Officier", rangIndex = 1, niveau = 60, enLigne = true }, ... }
-- rangIndex : 0 pour le maître de guilde, puis 1, 2… en descendant.
-- Le joueur lui-même est toujours inclus, même hors guilde, avec sa race et son niveau d'objet.
function Api.LireGuilde()
  local membres = {}
  if IsInGuild() then
    C_GuildInfo.GuildRoster() -- demande une mise à jour pour la prochaine fois
    for i = 1, GetNumGuildMembers() do
      local nom, rang, rangIndex, niveau, _, _, _, _, enLigne, _, classe = GetGuildRosterInfo(i)
      if nom then
        membres[Api.NomCourt(nom)] = { classe = classe, rang = rang, rangIndex = rangIndex, niveau = niveau, enLigne = enLigne }
      end
    end
  end
  local moi = membres[Api.MonNom()] or {}
  local _, monRang, monRangIndex = GetGuildInfo("player")
  moi.classe = select(2, UnitClass("player"))
  moi.rang = moi.rang or monRang
  moi.rangIndex = moi.rangIndex or monRangIndex
  moi.niveau = UnitLevel("player")
  moi.race = UnitRace("player")
  local _, ilvl = GetAverageItemLevel()
  moi.ilvl = ilvl and math.floor(ilvl)
  moi.enLigne = true
  membres[Api.MonNom()] = moi
  return membres
end

-- Rangs de la guilde, du plus haut au plus bas : { { nom = "Officier", membres = 4 }, ... }
function Api.LireRangs()
  local rangs = {}
  if IsInGuild() then
    for i = 1, GuildControlGetNumRanks() do
      rangs[i] = { nom = GuildControlGetRankName(i), membres = 0 }
    end
    for i = 1, GetNumGuildMembers() do
      local _, _, index = GetGuildRosterInfo(i)
      local rang = rangs[index + 1] -- les index du jeu commencent à 0
      if rang then
        rang.membres = rang.membres + 1
      end
    end
  end
  return rangs
end

-- Unité du jeu ("target"…) d'un joueur dont le modèle 3D peut s'afficher : pour l'instant,
-- seulement s'il est ta cible. nil sinon.
function Api.UniteVisible(nom)
  if UnitExists("target") and NomUnite("target") == nom then
    return "target"
  end
end

-- Icône de la classe ("DRUID" -> Interface\Icons\ClassIcon_Druid), point d'interrogation si inconnue.
function Api.IconeClasse(classe)
  if not classe then
    return "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  return "Interface\\Icons\\ClassIcon_" .. classe:sub(1, 1) .. classe:sub(2):lower()
end

-- Nom de la classe dans la langue du jeu ("MAGE" -> "Mage").
function Api.NomClasse(classe)
  return classe and LOCALIZED_CLASS_NAMES_MALE[classe] or ""
end

-- Couleur de la classe (r, g, b), ou couleur du texte si inconnue.
function Api.CouleurClasse(classe)
  local c = classe and RAID_CLASS_COLORS[classe]
  if c then
    return c.r, c.g, c.b
  end
  return 0.91, 0.88, 0.8
end

-- Renvoie { { nom = "Alchimie", niveau = 150, max = 225 }, ... }
-- Forever utilise l'API du WoW moderne (Retail), pas celle de l'ancien Classic.
function Api.LireMetiers()
  local metiers = {}
  local index = { GetProfessions() }
  for i = 1, 6 do
    if index[i] then
      local nom, _, niveau, max = GetProfessionInfo(index[i])
      table.insert(metiers, { nom = nom, niveau = niveau, max = max })
    end
  end
  return metiers
end

local EMPLACEMENTS = {
  tete = 1, cou = 2, epaules = 3, chemise = 4, torse = 5, taille = 6, jambes = 7, pieds = 8, poignets = 9, mains = 10,
  doigt1 = 11, doigt2 = 12, bijou1 = 13, bijou2 = 14, dos = 15, arme = 16, mainGauche = 17, relique = 18, tabard = 19,
}
local QUALITE = { [0] = "c", [1] = "c", [2] = "u", [3] = "r" } -- au-delà : épique

-- Mon équipement : { tete = { nom, lien, qualite = "r", ilvl = 62, icone = 123456 }, ... }
function Api.LireEquipement()
  local equipement = {}
  for cle, slot in pairs(EMPLACEMENTS) do
    local lien = GetInventoryItemLink("player", slot)
    if lien then
      equipement[cle] = {
        nom = lien:match("%[(.-)%]"),
        lien = lien,
        qualite = QUALITE[GetInventoryItemQuality("player", slot) or 1] or "e",
        ilvl = C_Item.GetDetailedItemLevelInfo(lien) or 1,
        icone = GetInventoryItemTexture("player", slot),
      }
    end
  end
  return equipement
end

local RACCOURCI = "PTITSCASUS_OUVRIR" -- action déclarée dans Bindings.xml

function Api.LireRaccourci()
  return (GetBindingKey(RACCOURCI))
end

-- « touche » : la touche pressée (les Alt, Ctrl, Maj tenus sont ajoutés). nil : retire le raccourci.
function Api.DefinirRaccourci(touche)
  if InCombatLockdown() then
    print("Aux Ptits Casus : impossible de changer le raccourci en combat.")
    return
  end
  for _, ancienne in ipairs({ GetBindingKey(RACCOURCI) }) do
    SetBinding(ancienne, nil)
  end
  if touche then
    local combinaison = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
      .. (IsShiftKeyDown() and "SHIFT-" or "") .. touche
    local avant = GetBindingAction(combinaison)
    if avant ~= "" then
      print("Aux Ptits Casus : " .. combinaison .. " servait à : " .. (_G["BINDING_NAME_" .. avant] or avant) .. ".")
    end
    SetBinding(combinaison, RACCOURCI)
  end
  SaveBindings(GetCurrentBindingSet())
end

-- Début du nom des images de fond de la fiche de personnage du jeu, pour la race de cette unité.
-- Les quatre morceaux se terminent par 1, 2, 3, 4. nil si l'unité n'est pas disponible.
function Api.FondRace(unite)
  local _, race = UnitRace(unite or "none")
  return race and "Interface\\DressUpFrame\\DressUpBackground-" .. race
end
