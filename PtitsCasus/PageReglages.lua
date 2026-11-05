-- Page Réglages : « Mon affichage » (personnel) et les réglages d'officier
-- (maître du butin, loot, synchronisation). Les choix sont enregistrés dans la sauvegarde.
-- Pour l'instant, seuls la taille de la fenêtre, le bouton de la minimap et
-- « Forcer la synchro » ont un effet ; les autres choix seront utilisés plus tard.
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local contenu = UI.Defilant(UI.pages.reglages)

local L = UI.LARGEUR
local DEMI = (L - 14) / 2
local aRafraichir = {} -- fonctions qui remettent chaque contrôle à jour depuis la sauvegarde

local titre = UI.Texte(contenu, UI.TITRE, 22, "ffd100")
titre:SetPoint("TOPLEFT")
titre:SetText("Réglages")
local sous = UI.Paragraphe(contenu, 13, "a89f8a", L,
  "« Mon affichage » ne concerne que toi. Le reste est réservé aux officiers.")
sous:SetPoint("TOPLEFT", 0, -titre:GetStringHeight() - 6)
local HAUT = -titre:GetStringHeight() - 6 - sous:GetStringHeight() - 18

-- Carte avec son titre et une puce à droite (Personnel, Officiers…).
local function Carte(titreCarte, puce)
  local carte = UI.Carte(contenu)
  carte:SetWidth(DEMI)
  local fs = UI.Texte(carte, UI.TITRE, 15, "e8e0cc")
  fs:SetPoint("TOPLEFT", 14, -14)
  fs:SetText(titreCarte)
  local p = puce == "Personnel" and UI.Puce(carte, puce, "16130e", "a89f8a") or UI.Puce(carte, puce, "2a2316", UI.ACCENT)
  p:SetPoint("TOPRIGHT", -14, -12)
  if puce ~= "Personnel" then
    table.insert(UI.surAccent, function() p.texte:SetTextColor(Hex(UI.ACCENT)) end)
  end
  carte.y = -14 - fs:GetStringHeight() - 10
  return carte
end

-- Largeur réservée à droite pour chaque type de contrôle.
local CONTROLE = { case = 30, choix = 170, taille = 140, bouton = 210 }

-- Ligne de réglage : libellé et indication à gauche, coupés à la ligne pour ne pas
-- passer sous le contrôle ; le contrôle (de largeur « largeurControle ») se place à droite.
local function Ligne(carte, largeurControle, libelle, indication, couleurIndication)
  local ligne = CreateFrame("Frame", nil, carte)
  ligne:SetPoint("TOPLEFT", 14, carte.y)
  ligne:SetPoint("TOPRIGHT", -14, carte.y)
  local trait = ligne:CreateTexture(nil, "ARTWORK")
  trait:SetPoint("TOPLEFT")
  trait:SetPoint("TOPRIGHT")
  trait:SetHeight(1)
  trait:SetColorTexture(Hex("241f17"))
  local largeurTexte = DEMI - 28 - largeurControle - 12
  local fs = UI.Paragraphe(ligne, 14, "e8e0cc", largeurTexte, libelle)
  fs:SetPoint("TOPLEFT", 0, -7)
  local h = 7 + fs:GetStringHeight() + 8
  if indication then
    local ind = UI.Paragraphe(ligne, 12, couleurIndication or "a89f8a", largeurTexte, indication)
    ind:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
    h = h + ind:GetStringHeight() + 2
  end
  h = math.max(h, 36)
  ligne:SetHeight(h)
  carte.y = carte.y - h
  return ligne
end

-- Case à cocher enregistrée sous « cle ». « auClic » reçoit la nouvelle valeur.
local function CaseReglage(ligne, cle, defaut, auClic)
  local case = UI.Case(ligne)
  case:SetPoint("RIGHT")
  case:SetScript("OnClick", function(self)
    UI.Regler(cle, self:GetChecked())
    if auClic then
      auClic(self:GetChecked())
    end
  end)
  table.insert(aRafraichir, function() case:SetChecked(UI.Reglage(cle, defaut)) end)
  return case
end

-- Bouton qui passe d'un choix au suivant à chaque clic.
local function Choix(ligne, cle, options)
  local bouton = UI.BoutonSombre(ligne, options[1])
  bouton:SetWidth(170)
  bouton:SetPoint("RIGHT")
  local function Afficher()
    bouton.texte:SetText(UI.Reglage(cle, options[1]))
  end
  bouton:SetScript("OnClick", function()
    local actuel = UI.Reglage(cle, options[1])
    local suivant = options[1]
    for i, o in ipairs(options) do
      if o == actuel then
        suivant = options[i % #options + 1]
      end
    end
    UI.Regler(cle, suivant)
    Afficher()
  end)
  table.insert(aRafraichir, Afficher)
end

-- Mon affichage.
local affichage = Carte("Mon affichage", "Personnel")
affichage:SetPoint("TOPLEFT", 0, HAUT)

local ligneTaille = Ligne(affichage, CONTROLE.taille, "Taille de la fenêtre")
local plus = UI.BoutonSombre(ligneTaille, "+")
plus:SetWidth(34)
plus:SetPoint("RIGHT")
local valeurTaille = UI.Texte(ligneTaille, UI.TEXTE, 13, "c9bfa8")
valeurTaille:SetPoint("RIGHT", plus, "LEFT", -10, 0)
local moins = UI.BoutonSombre(ligneTaille, "-")
moins:SetWidth(34)
moins:SetPoint("RIGHT", plus, "LEFT", -60, 0)
local function Taille(ecart)
  local taille = math.min(130, math.max(70, UI.Reglage("taille", 100) + ecart))
  UI.Regler("taille", taille)
  UI.panneau:SetScale(taille / 100 * UI.ECHELLE)
  valeurTaille:SetText(taille .. " %")
end
plus:SetScript("OnClick", function() Taille(10) end)
moins:SetScript("OnClick", function() Taille(-10) end)
table.insert(aRafraichir, function() Taille(0) end)

local ligneRaccourci = Ligne(affichage, CONTROLE.choix, "Raccourci clavier", "Clic : choisir les touches · Clic droit : retirer")
local raccourci = UI.BoutonSombre(ligneRaccourci, "")
raccourci:SetWidth(CONTROLE.choix)
raccourci:SetPoint("RIGHT")
raccourci:RegisterForClicks("LeftButtonUp", "RightButtonUp")
local function AfficherRaccourci()
  raccourci:EnableKeyboard(false)
  raccourci.texte:SetText(ns.Api.LireRaccourci() or "Aucun")
end
raccourci:SetScript("OnClick", function(self, clic)
  if clic == "RightButton" then
    ns.Api.DefinirRaccourci(nil)
    AfficherRaccourci()
  else
    self.texte:SetText("Appuie sur les touches…")
    self:EnableKeyboard(true)
  end
end)
raccourci:SetScript("OnKeyDown", function(_, touche)
  if touche:find("SHIFT$") or touche:find("CTRL$") or touche:find("ALT$") then
    return -- on attend la touche qui accompagne Alt, Ctrl ou Maj
  end
  if touche ~= "ESCAPE" then
    ns.Api.DefinirRaccourci(touche)
  end
  AfficherRaccourci()
end)
raccourci:SetScript("OnHide", AfficherRaccourci)
table.insert(aRafraichir, AfficherRaccourci)

CaseReglage(Ligne(affichage, CONTROLE.case, "Bouton autour de la minimap", "Clic droit dessus : Réglages"), "minimap", true,
  function(affiche) UI.boutonMinimap:SetShown(affiche) end)
CaseReglage(Ligne(affichage, CONTROLE.case, "Son à l'ouverture des annonces"), "son", false)
if ns.admin then
  CaseReglage(Ligne(affichage, CONTROLE.case, "Admin", "Mêmes droits que le maître de guilde"), "admin", false,
    function() UI.RafraichirTout() end)
end
affichage:SetHeight(-affichage.y + 10)

-- Loot (officiers).
local loot = Carte("Loot", "Officiers")
loot:SetPoint("TOPLEFT", affichage, "BOTTOMLEFT", 0, -14)
Choix(Ligne(loot, CONTROLE.choix, "Qualité minimale annoncée", "En dessous, l'objet n'entre pas dans la file"), "qualiteMin",
  { "Épique", "Rare et plus", "Peu commun et plus" })
Choix(Ligne(loot, CONTROLE.choix, "Durée des annonces", "Pas de chrono : le maître du butin ferme les annonces"), "duree",
  { "Sans limite", "Avec un chrono" })
CaseReglage(Ligne(loot, CONTROLE.case, "Compter un +1 comme +1 DL", "Si le joueur a déjà looté ce soir"), "corrigerDL", true)
CaseReglage(Ligne(loot, CONTROLE.case, "Un +0 qui gagne en +1 face à un PU perd son +0"),
  "zeroPerduPU", true)
CaseReglage(Ligne(loot, CONTROLE.case, "Annonces en avertissement de raid + canal raid"), "avertissement", true)
CaseReglage(Ligne(loot, CONTROLE.case, "Annoncer le gagnant dans le canal raid", "« Kéliane remporte [objet] »"), "annoncerGagnant", true)
loot:SetHeight(-loot.y + 10)

-- Droits : rangs de la guilde (lus dans le jeu) et maître du butin désigné.
-- Les rangs sont lus à chaque affichage.
local droits = Carte("Droits et maître du butin", "Officiers")
droits:SetPoint("TOPLEFT", DEMI + 14, HAUT)
local explication = UI.Paragraphe(droits, 12, "a89f8a", DEMI - 28,
  "Rangs lus dans la guilde. Le rang juste sous le maître de guilde a les droits d'officier.")
explication:SetPoint("TOPLEFT", 14, droits.y + 4)
local yEntete = droits.y - explication:GetStringHeight() - 8
local COLONNES = { { "RANG", 14 } }
for _, c in ipairs(COLONNES) do
  local fs = UI.Texte(droits, UI.TEXTE, 11, "a89f8a")
  fs:SetPoint("TOPLEFT", c[2], yEntete)
  fs:SetText(c[1])
end
local colMembres = UI.Texte(droits, UI.TEXTE, 11, "a89f8a")
colMembres:SetPoint("TOPRIGHT", -14, yEntete)
colMembres:SetText("MEMBRES")
local noteDroits = UI.Paragraphe(droits, 12, "a89f8a", DEMI - 28,
  "Officier : coche les +0. Maître du butin : annonce et attribue les objets ; il garde ce rôle d'un raid à l'autre.")

-- Ligne « Maître du butin » : son nom et le bouton pour en choisir un autre.
local ligneButin = CreateFrame("Frame", nil, droits)
ligneButin:SetHeight(40)
local libelleButin = UI.Texte(ligneButin, UI.TEXTE, 14, "e8e0cc")
libelleButin:SetPoint("LEFT")
libelleButin:SetText("Maître du butin :")
local nomButin = UI.Texte(ligneButin, UI.TEXTE, 14, "e8e0cc")
nomButin:SetPoint("LEFT", libelleButin, "RIGHT", 8, 0)
local changerButin = UI.BoutonSombre(ligneButin, "Changer")
changerButin:SetHeight(28)
changerButin:SetPoint("RIGHT")

-- Petite liste des membres pour désigner le maître du butin.
local choix = UI.Carte(UIParent, "13110d", "8c6a3c")
choix:SetSize(260, 360)
choix:SetFrameStrata("DIALOG")
choix:EnableMouse(true)
choix:Hide()
local titreChoix = UI.Texte(choix, UI.TITRE, 14, "ffd100")
titreChoix:SetPoint("TOPLEFT", 12, -12)
titreChoix:SetText("Choisir le maître du butin")
local fermerChoix = UI.BoutonSombre(choix, "Fermer")
fermerChoix:SetHeight(26)
fermerChoix:SetPoint("BOTTOMRIGHT", -10, 10)
fermerChoix:SetScript("OnClick", function() choix:Hide() end)
local zoneChoix = CreateFrame("Frame", nil, choix)
zoneChoix:SetPoint("TOPLEFT", 10, -40)
zoneChoix:SetPoint("BOTTOMRIGHT", -16, 44)
local listeChoix = UI.Defilant(zoneChoix, 234)
local lignesChoix = {}
local Rafraichir

changerButin:SetScript("OnClick", function()
  local membres = UI.Membres()
  local noms = {}
  for nom in pairs(membres) do
    table.insert(noms, nom)
  end
  table.sort(noms)
  for _, b in ipairs(lignesChoix) do
    b:Hide()
  end
  for i, nom in ipairs(noms) do
    if not lignesChoix[i] then
      local b = CreateFrame("Button", nil, listeChoix)
      b:SetSize(234, 24)
      UI.Survol(b)
      b.texte = UI.Texte(b, UI.TEXTE, 14, "e8e0cc")
      b.texte:SetPoint("LEFT", 6, 0)
      lignesChoix[i] = b
    end
    local b = lignesChoix[i]
    b:SetPoint("TOPLEFT", 0, -(i - 1) * 24)
    b.texte:SetText(nom)
    b.texte:SetTextColor(ns.Api.CouleurClasse(membres[nom].classe))
    b:SetScript("OnClick", function()
      UI.DesignerMaitreButin(nom)
      choix:Hide()
      UI.RafraichirTout()
    end)
    b:Show()
  end
  listeChoix:SetHeight(#noms * 24)
  choix:ClearAllPoints()
  choix:SetPoint("TOPLEFT", changerButin, "BOTTOMRIGHT", 8, 0)
  choix:Show()
end)
local lignesRangs = {}

local function NouvelleLigneRang()
  local ligne = CreateFrame("Frame", nil, droits)
  ligne:SetHeight(34)
  local trait = ligne:CreateTexture(nil, "ARTWORK")
  trait:SetPoint("TOPLEFT")
  trait:SetPoint("TOPRIGHT")
  trait:SetHeight(1)
  trait:SetColorTexture(Hex("241f17"))
  ligne.nom = UI.TexteCourt(ligne, 14, "e8e0cc", DEMI - 300)
  ligne.nom:SetPoint("LEFT", 0, 0)
  ligne.membres = UI.Texte(ligne, UI.TEXTE, 14, "c9bfa8")
  ligne.membres:SetPoint("RIGHT")
  return ligne
end

-- Synchronisation (tout le monde).
local synchro = Carte("Synchronisation", "Tous")
synchro:SetPoint("TOPLEFT", droits, "BOTTOMLEFT", 0, -14)
local ligneSynchro = Ligne(synchro, CONTROLE.bouton, "Synchronisation", " ")
local indicationSynchro = UI.Texte(ligneSynchro, UI.TEXTE, 12, "a89f8a")
indicationSynchro:SetPoint("BOTTOMLEFT", 0, 10)
local forcer = UI.BoutonRouge(ligneSynchro, "Forcer la synchro")
forcer:SetPoint("RIGHT")
forcer:SetScript("OnClick", function()
  ns.ForcerSynchro()
  print("Aux Ptits Casus : métiers et maître du butin renvoyés à la guilde.")
end)
synchro:SetHeight(-synchro.y + 10)

-- Commandes du chat que tous les joueurs peuvent utiliser.
local commandesJoueurs = Carte("Commandes", "Tous")
local listeJoueurs = UI.Paragraphe(commandesJoueurs, 13, "c9bfa8", DEMI - 28, table.concat({
  "/pc ou /ig : ouvrir ou fermer la fenêtre",
  "/metiers : métiers reçus, dans le chat",
  "/pc loot : rouvrir la fenêtre de loot",
  "/pc skin : skin EllesmereUI (recharge l'interface)",
}, "\n"))
listeJoueurs:SetPoint("TOPLEFT", 14, commandesJoueurs.y)
commandesJoueurs:SetHeight(-commandesJoueurs.y + listeJoueurs:GetStringHeight() + 14)

-- Commandes de test (mode admin : case Admin cochée).
local commandes = Carte("Commandes de test", "Admin")
local listeCommandes = UI.Paragraphe(commandes, 13, "c9bfa8", DEMI - 28, table.concat({
  "/pc test : données de démo",
  "/pc demo : visite guidée",
  "/pc maitre, officier, butin, raideur, recrue : simuler un grade (même commande : arrêter)",
}, "\n"))
listeCommandes:SetPoint("TOPLEFT", 14, commandes.y)
commandes:SetHeight(-commandes.y + listeCommandes:GetStringHeight() + 14)

function Rafraichir()
  for _, f in ipairs(aRafraichir) do
    f()
  end

  -- Raideurs et recrues : « Mon affichage » et Synchronisation.
  -- Officiers : en plus, Loot sous Synchronisation.
  -- Officiers et maître de guilde : en plus, les droits (modifiables par le maître de guilde seul)
  -- et le maître du butin sous « Mon affichage ».
  local d = UI.Droits()
  sous:SetText(d.officier
    and "« Mon affichage » ne concerne que toi. Le reste est réservé aux officiers."
    or "Ces réglages ne concernent que toi.")
  loot:SetShown(d.officier)
  droits:SetShown(d.officier)
  synchro:SetShown(true)
  synchro:ClearAllPoints()
  synchro:SetPoint("TOPLEFT", DEMI + 14, HAUT)
  loot:ClearAllPoints()
  loot:SetPoint("TOPLEFT", synchro, "BOTTOMLEFT", 0, -14)
  droits:ClearAllPoints()
  droits:SetPoint("TOPLEFT", affichage, "BOTTOMLEFT", 0, -14)
  local avecCommandes = ns.admin and UI.Reglage("admin", false)
  commandes:SetShown(avecCommandes)
  commandes:ClearAllPoints()
  commandesJoueurs:ClearAllPoints()
  commandesJoueurs:SetPoint("TOPLEFT", d.officier and droits or affichage, "BOTTOMLEFT", 0, -14)
  commandes:SetPoint("TOPLEFT", commandesJoueurs, "BOTTOMLEFT", 0, -14)

  -- Rangs de la guilde et leurs droits.
  for _, ligne in ipairs(lignesRangs) do
    ligne:Hide()
  end
  local y = yEntete - 20
  for i, r in ipairs(UI.Rangs()) do
    lignesRangs[i] = lignesRangs[i] or NouvelleLigneRang()
    local ligne = lignesRangs[i]
    ligne:SetPoint("TOPLEFT", 14, y)
    ligne:SetPoint("TOPRIGHT", -14, y)
    ligne.nom:SetText(r.nom)
    ligne.membres:SetText(r.membres)
    ligne:Show()
    y = y - 34
  end
  if #UI.Rangs() == 0 then
    y = y - 10
  end
  -- Maître du butin désigné, sous les rangs.
  ligneButin:SetPoint("TOPLEFT", 14, y - 4)
  ligneButin:SetPoint("TOPRIGHT", -14, y - 4)
  local butin = UI.MaitreButin()
  nomButin:SetText(butin or "personne")
  nomButin:SetTextColor(ns.Api.CouleurClasse(butin and (UI.Membres()[butin] or {}).classe))
  y = y - 48
  noteDroits:SetPoint("TOPLEFT", 14, y - 8)
  droits:SetHeight(-y + 8 + noteDroits:GetStringHeight() + 14)

  local avecAddon = 0
  for _, m in pairs(UI.Membres()) do
    if #(m.metiers or {}) > 0 then
      avecAddon = avecAddon + 1
    end
  end
  indicationSynchro:SetText(avecAddon .. " joueur(s) avec l'addon")

  local gauche = affichage:GetHeight() + (d.officier and droits:GetHeight() + 14 or 0)
    + commandesJoueurs:GetHeight() + 14 + (avecCommandes and commandes:GetHeight() + 14 or 0)
  local droite = synchro:GetHeight() + (d.officier and 14 + loot:GetHeight() or 0)
  contenu:SetHeight(-HAUT + math.max(gauche, droite) + 8)
end

UI.rafraichir.reglages = Rafraichir
