-- Visite guidée de l'addon (/pc visite) : une bulle par étape, à côté de l'élément présenté,
-- qui est entouré d'un cadre doré. Précédent / Suivant / Passer.
-- La visite montre les vraies données. Les textes décrivent, sans conseils.
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex

local LARGEUR = 330

-- Étapes : page à ouvrir, élément à entourer (fonction qui le renvoie), où poser la bulle,
-- titre, texte, et condition pour l'afficher (officiers…).
local function Menu(id)
  return function() return UI.boutons[id] end
end

local ETAPES = {
  { titre = "Bienvenue", texte = "Voici l'addon de la guilde Aux Ptits Casus. Cette visite présente chaque page. "
    .. "Une page peut être vide tant qu'aucune donnée n'a été reçue.", page = "stats" },
  { titre = "Le bouton de la minimap", cible = function() return UI.boutonMinimap end, cote = "gauche",
    si = function() return UI.boutonMinimap:IsShown() end,
    texte = "Clic : ouvrir ou fermer l'addon. Clic droit : les Réglages. Une pastille rouge signale du "
      .. "nouveau dans les commandes." },
  { page = "stats", cible = Menu("stats"), titre = "Statistiques",
    texte = "Les chiffres de la guilde : classes, grades et métiers. Survole un graphique pour son détail." },
  { page = "membres", cible = Menu("membres"), titre = "Membres",
    texte = "La liste des membres, triable par nom, grade, classe ou statut. Clic sur un membre : sa fiche, "
      .. "avec ses métiers. Ta fiche montre aussi ton équipement." },
  { page = "membres", cible = Menu("membres"), titre = "Le +0, côté officiers",
    si = function() return UI.Droits().officier end,
    texte = "La colonne +0 de la liste sert aux officiers à donner le +0 d'un joueur pour la soirée. "
      .. "Pour l'instant, seul l'officier qui le pose le voit." },
  { page = "metiers", cible = Menu("metiers"), titre = "Métiers",
    texte = "Les métiers et les niveaux des membres qui ont l'addon. La liste des recettes n'est pas encore "
      .. "active." },
  { page = "commandes", cible = Menu("commandes"), titre = "Commandes",
    texte = "En haut, tes commandes privées, reçues et envoyées : l'artisan les accepte, les refuse ou les "
      .. "marque « Faite ». En dessous, les commandes de guilde, visibles par tous : n'importe quel artisan "
      .. "peut s'en charger." },
  { page = "loot", cible = Menu("loot"), titre = "Loot en cours",
    texte = "Pour le raid : les objets du boss, les annonces et le résultat, avec une fenêtre réduite. "
      .. "Le maître du butin attribue chaque objet. Cette page n'est pas encore active." },
  { page = "historique", cible = Menu("historique"), titre = "Historique des loots",
    texte = "Les objets distribués, soirée par soirée. Cette page n'est pas encore active." },
  { page = "regles", cible = Menu("regles"), titre = "Règles du loot",
    texte = "La règle du loot de la guilde : les paliers +0, +1, +1 DL et +2, les égalités au /rand et le cas "
      .. "des PU." },
  { page = "reglages", cible = Menu("reglages"), titre = "Réglages",
    texte = "La taille de la fenêtre, le raccourci clavier, le bouton de la minimap et la liste des commandes "
      .. "du chat. Les officiers y trouvent aussi les réglages du loot." },
  { page = "reglages", cible = Menu("reglages"), titre = "Le maître du butin",
    si = function() return UI.Droits().officier end,
    texte = "Le maître de guilde ou un officier désigne le maître du butin, une fois pour toutes : ici, ou "
      .. "depuis sa fiche dans la page Membres." },
  { titre = "Fin de la visite", texte = "/pc visite relance cette visite.", page = "stats" },
}

-- Bulle de la visite.
local bulle = CreateFrame("Frame", "PtitsCasusVisite", UIParent, "BackdropTemplate")
bulle:SetWidth(LARGEUR)
bulle:SetFrameStrata("FULLSCREEN_DIALOG")
bulle:EnableMouse(true)
bulle:Hide()
UI.Habiller(bulle, "1e1a13", "ffd100", 2)
local titre = UI.Texte(bulle, UI.TITRE, 16, "ffd100")
titre:SetPoint("TOPLEFT", 14, -12)
local compteur = UI.Texte(bulle, UI.TEXTE, 11, "a89f8a")
compteur:SetPoint("TOPRIGHT", -14, -14)
local texte = UI.Paragraphe(bulle, 13, "e8e0cc", LARGEUR - 28, "")
texte:SetPoint("TOPLEFT", titre, "BOTTOMLEFT", 0, -8)
local suivant = UI.BoutonRouge(bulle, "Suivant")
suivant:SetHeight(28)
suivant:SetPoint("BOTTOMRIGHT", -12, 10)
local precedent = UI.BoutonSombre(bulle, "Précédent")
precedent:SetHeight(28)
precedent:SetPoint("RIGHT", suivant, "LEFT", -6, 0)
local passer = UI.BoutonSombre(bulle, "Passer")
passer:SetHeight(28)
passer:SetPoint("BOTTOMLEFT", 12, 10)

-- Cadre doré qui clignote doucement autour de l'élément présenté.
local cadre = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
cadre:SetFrameStrata("FULLSCREEN_DIALOG")
cadre:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
cadre:SetBackdropBorderColor(Hex("ffd100"))
cadre:Hide()
cadre:SetScript("OnUpdate", function(self)
  self:SetAlpha(0.6 + 0.4 * math.sin(GetTime() * 4))
end)

local etapes, numero = {}, 1

local function Terminer()
  bulle:Hide()
  cadre:Hide()
end

local function Afficher()
  local e = etapes[numero]
  if e.page then
    UI.AfficherPage(e.page)
  end
  titre:SetText(e.titre)
  compteur:SetText(numero .. " / " .. #etapes)
  texte:SetText(e.texte)
  bulle:SetHeight(12 + titre:GetStringHeight() + 8 + texte:GetStringHeight() + 16 + 28 + 10)
  precedent:SetShown(numero > 1)
  suivant.texte:SetText(numero == #etapes and "Terminer" or "Suivant")

  -- Bulle à côté de l'élément entouré, ou au centre du panneau s'il n'y en a pas.
  local cible = e.cible and e.cible()
  bulle:ClearAllPoints()
  cadre:ClearAllPoints()
  if cible then
    cadre:SetPoint("TOPLEFT", cible, "TOPLEFT", -4, 4)
    cadre:SetPoint("BOTTOMRIGHT", cible, "BOTTOMRIGHT", 4, -4)
    cadre:Show()
    if e.cote == "gauche" then
      bulle:SetPoint("TOPRIGHT", cible, "TOPLEFT", -14, 0)
    else
      bulle:SetPoint("TOPLEFT", cible, "TOPRIGHT", 18, 0)
    end
  else
    cadre:Hide()
    bulle:SetPoint("CENTER", UI.panneau, "CENTER")
  end
  bulle:Show()
end

suivant:SetScript("OnClick", function()
  if numero == #etapes then
    Terminer()
  else
    numero = numero + 1
    Afficher()
  end
end)
precedent:SetScript("OnClick", function()
  numero = math.max(1, numero - 1)
  Afficher()
end)
passer:SetScript("OnClick", Terminer)

-- Fermer le panneau (Échap, croix) arrête la visite.
UI.panneau:HookScript("OnHide", Terminer)

function UI.LancerVisite()
  etapes = {}
  for _, e in ipairs(ETAPES) do
    if not e.si or e.si() then
      table.insert(etapes, e)
    end
  end
  numero = 1
  UI.membreChoisi = nil
  UI.panneau:Show()
  UI.RafraichirTout()
  Afficher()
end
