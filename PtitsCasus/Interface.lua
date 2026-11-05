-- Le panneau principal : cadre, bandeau, menu, outils communs aux pages,
-- bouton autour de la minimap et commandes /pc et /ig.
-- Chaque page est dans son propre fichier Page*.lua.
local _, ns = ...
local UI = {}
ns.UI = UI

UI.ACCENT = "ff7c0a" -- remplacée à l'affichage par la couleur choisie (voir UI.MajAccent)
-- Polices Expressway, copiées depuis EllesmereUI dans notre dossier Fonts.
UI.TITRE = "Interface\\AddOns\\PtitsCasus\\Fonts\\ExpresswayBold.ttf"
UI.TEXTE = "Interface\\AddOns\\PtitsCasus\\Fonts\\Expressway.ttf"
local BLANC = "Interface\\Buttons\\WHITE8x8"
UI.ZOOM = 1.25 -- grossit tous les textes du panneau
local ZOOM_TEXTE = UI.ZOOM

-- Taille de la zone des pages, à droite du menu.
UI.LARGEUR = 880 -- laisse une marge à droite, avec la barre de défilement
UI.HAUTEUR = 630
UI.RANG_OFFICIER = 1 -- position dans la guilde du rang officier (0 = maître de guilde) : suit le rang même renommé
UI.ECHELLE = 0.75 -- taille réelle de la fenêtre quand le réglage indique 100 %

-- Couleurs des objets par qualité : texte et fond de l'icône.
UI.QUALITES = {
  e = { "c27cf7", "2b1f38" }, -- épique
  r = { "3d9bff", "14243a" }, -- rare
  u = { "5fd068", "16301a" }, -- peu commun
  c = { "e8e0cc", "2a2620" }, -- commun
}

-- Couleurs des paliers de loot : titre, fond et texte de la puce. Propres aux paliers
-- (jamais une couleur de classe), vérifiées pour rester distinctes, daltoniens compris.
UI.PALIERS = {
  ["+0"] = { "e04a5f", "e04a5f", "ffffff" }, -- framboise
  ["+1"] = { "3a8fd0", "3a8fd0", "ffffff" }, -- bleu
  ["+1 DL"] = { "22a06b", "22a06b", "ffffff" }, -- vert
  ["+2"] = { "a463c8", "a463c8", "ffffff" }, -- violet
  ["PU"] = { "c4862b", "c4862b", "ffffff" }, -- ocre
}

-- Skin EllesmereUI : chaque élément est noté à sa création, puis repeint
-- par EllesmereUI à la connexion (voir Skin.lua). Une fois le skin en place, UI.skin existe
-- et les éléments créés ensuite sont repeints tout de suite.
-- Sortes : "fenetre", "carte", "bouton", "saisie", "case", "texte".
UI.aSkinner = {}

function UI.Noter(sorte, objet)
  if UI.skin then
    UI.Peindre(sorte, objet)
  else
    table.insert(UI.aSkinner, { sorte, objet })
  end
end

-- "8c6a3c" -> 0.55, 0.42, 0.24
function UI.Hex(h)
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end
local Hex = UI.Hex

-- Couleur de classe au format "ff7c0a", pour colorer un mot dans un texte avec |cff...|r.
function UI.HexClasse(classe)
  local r, g, b = ns.Api.CouleurClasse(classe)
  return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

function UI.Fond(frame, couleur)
  local t = frame:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(Hex(couleur))
  return t
end

-- Fond uni et bordure. Le frame doit être créé avec "BackdropTemplate".
function UI.Habiller(frame, fond, bord, epaisseur)
  frame:SetBackdrop({ bgFile = BLANC, edgeFile = BLANC, edgeSize = epaisseur or 1 })
  frame:SetBackdropColor(Hex(fond))
  frame:SetBackdropBorderColor(Hex(bord))
end

-- Éclaircit légèrement un bouton au survol de la souris.
function UI.Survol(bouton)
  local t = bouton:CreateTexture(nil, "HIGHLIGHT")
  t:SetAllPoints()
  t:SetColorTexture(1, 1, 1, 0.06)
end

function UI.Texte(parent, police, taille, couleur)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(police, taille * ZOOM_TEXTE, "")
  fs:SetTextColor(Hex(couleur))
  fs:SetShadowOffset(1, -1)
  fs:SetJustifyH("LEFT")
  UI.Noter("texte", fs)
  return fs
end

-- Texte sur plusieurs lignes, coupé à la largeur donnée.
function UI.Paragraphe(parent, taille, couleur, largeur, texte)
  local fs = UI.Texte(parent, UI.TEXTE, taille, couleur)
  fs:SetWidth(largeur)
  fs:SetWordWrap(true)
  fs:SetText(texte)
  return fs
end

-- Texte sur une ligne, coupé par « … » s'il dépasse la largeur donnée.
function UI.TexteCourt(parent, taille, couleur, largeur)
  local fs = UI.Texte(parent, UI.TEXTE, taille, couleur)
  fs:SetWidth(largeur)
  fs:SetWordWrap(false)
  return fs
end

-- Petite étiquette colorée (« peu d'artisans », « Officier »…).
function UI.Puce(parent, texte, fond, couleur)
  local puce = CreateFrame("Frame", nil, parent)
  puce.fond = UI.Fond(puce, fond)
  puce.texte = UI.Texte(puce, UI.TEXTE, 11, couleur)
  puce.texte:SetPoint("CENTER")
  UI.EcrirePuce(puce, texte)
  return puce
end

function UI.EcrirePuce(puce, texte)
  puce.texte:SetText(texte)
  puce:SetSize(puce.texte:GetStringWidth() + 14, 18 * ZOOM_TEXTE)
end

-- Bouton rouge bordé d'or.
function UI.BoutonRouge(parent, texte)
  local bouton = CreateFrame("Button", nil, parent, "BackdropTemplate")
  UI.Habiller(bouton, "7c140e", "c9a35a")
  UI.Survol(bouton)
  bouton.texte = UI.Texte(bouton, UI.TEXTE, 14, "ffd100")
  bouton.texte:SetPoint("CENTER")
  bouton.texte:SetText(texte)
  bouton:SetSize(bouton.texte:GetStringWidth() + 28, 34)
  UI.Noter("bouton", bouton)
  return bouton
end

-- Bouton sombre bordé de brun (choix d'une liste, « Partager »…).
function UI.BoutonSombre(parent, texte)
  local bouton = CreateFrame("Button", nil, parent, "BackdropTemplate")
  UI.Habiller(bouton, "241f17", "6e5230")
  UI.Survol(bouton)
  bouton.texte = UI.Texte(bouton, UI.TEXTE, 13, "e8e0cc")
  bouton.texte:SetPoint("CENTER")
  bouton.texte:SetText(texte)
  bouton:SetSize(bouton.texte:GetStringWidth() + 28, 34)
  UI.Noter("bouton", bouton)
  return bouton
end

-- Cadre sombre bordé, utilisé pour regrouper un bloc d'informations.
function UI.Carte(parent, fond, bord)
  local carte = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  UI.Habiller(carte, fond or "1b1711", bord or "4a3820")
  UI.Noter("carte", carte)
  return carte
end

-- Case à cocher de WoW.
function UI.Case(parent)
  local case = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  case:SetSize(26, 26)
  UI.Noter("case", case)
  return case
end

-- Zone qui défile à la molette, avec une barre de défilement quand le contenu dépasse
-- (barre à droite du parent, ou dessous si « horizontal »). La barre se tire à la souris.
-- Renvoie le cadre où placer le contenu ; lui donner sa hauteur (sa largeur si horizontal).
function UI.Defilant(parent, largeur, horizontal)
  local defil = CreateFrame("ScrollFrame", nil, parent)
  defil:SetAllPoints()
  defil:SetClipsChildren(true) -- ce qui sort de la zone est coupé
  local contenu = CreateFrame("Frame", nil, defil)
  if horizontal then
    contenu:SetSize(1, parent:GetHeight())
  else
    contenu:SetSize(largeur or UI.LARGEUR, 1)
  end
  defil:SetScrollChild(contenu)

  local barre = CreateFrame("Slider", nil, parent)
  barre:SetOrientation(horizontal and "HORIZONTAL" or "VERTICAL")
  if horizontal then
    barre:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -4)
    barre:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -4)
    barre:SetHeight(6)
  else
    barre:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, 0)
    barre:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 4, 0)
    barre:SetWidth(6)
  end
  barre:EnableMouse(true)
  UI.Fond(barre, "241f17")
  local curseur = barre:CreateTexture(nil, "OVERLAY")
  curseur:SetColorTexture(Hex("8c6a3c"))
  barre:SetThumbTexture(curseur)

  -- Longueur du curseur proportionnelle à la part visible ; barre masquée si tout tient.
  local function MettreAJour()
    local visible = horizontal and defil:GetWidth() or defil:GetHeight()
    local total = horizontal and contenu:GetWidth() or contenu:GetHeight()
    local max = total - visible
    if max < 16 then
      max = 0 -- presque tout tient : pas de barre pour quelques pixels
    end
    barre:SetShown(max > 0)
    barre:SetMinMaxValues(0, max)
    local longueur = math.max(20, (horizontal and barre:GetWidth() or barre:GetHeight()) * visible / math.max(total, 1))
    if horizontal then
      curseur:SetSize(longueur, 6)
    else
      curseur:SetSize(6, longueur)
    end
  end
  barre:SetScript("OnValueChanged", function(_, valeur)
    if horizontal then
      defil:SetHorizontalScroll(valeur)
    else
      defil:SetVerticalScroll(valeur)
    end
  end)
  defil:EnableMouseWheel(true)
  defil:SetScript("OnMouseWheel", function(_, sens) barre:SetValue(barre:GetValue() - sens * 50) end)
  contenu:SetScript("OnSizeChanged", MettreAJour)
  defil:SetScript("OnSizeChanged", MettreAJour)
  return contenu
end

-- Réglages enregistrés dans la sauvegarde de l'addon.
function UI.Reglage(cle, defaut)
  local valeur = PtitsCasusDB.reglages[cle]
  if valeur == nil then
    return defaut
  end
  return valeur
end

function UI.Regler(cle, valeur)
  PtitsCasusDB.reglages[cle] = valeur
end

-- Couleur d'accent : la couleur de classe du joueur, ou celle d'EllesmereUI avec son skin.
-- Les éléments colorés une seule fois au chargement s'inscrivent dans UI.surAccent
-- (une fonction qui les recolore).
UI.surAccent = {}

function UI.MajAccent(membres)
  local moi = membres[UI.Moi()] or {}
  UI.ACCENT = UI.HexClasse(moi.classe)
  if UI.skin then
    local r, g, b = UI.skin.GetAccentColor()
    UI.ACCENT = string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
  end
  for _, f in ipairs(UI.surAccent) do
    f()
  end
end

-- Données affichées : celles de la démo (/pc test) ou les vraies.

-- { ["Nom"] = { classe, rang, niveau, enLigne, metiers, equipement, ... }, ... }
function UI.Membres()
  if ns.demo then
    return ns.Demo.membres
  end
  local membres = {}
  for nomComplet, infos in pairs(ns.Api.LireGuilde()) do
    infos.metiers = {}
    membres[ns.Api.NomCourt(nomComplet)] = infos
  end
  for nomComplet, recu in pairs(PtitsCasusDB.membres) do
    local nom = ns.Api.NomCourt(nomComplet)
    membres[nom] = membres[nom] or { enLigne = false }
    membres[nom].metiers = recu.metiers
    membres[nom].addon = true
  end
  return membres
end

function UI.Moi()
  if ns.demo then
    return ns.Demo.moi
  end
  return ns.Api.NomCourt(ns.Api.MonNom())
end

function UI.Loot()
  return ns.demo and ns.Demo.loot or nil
end

function UI.Historique()
  return ns.demo and ns.Demo.historique or {}
end

-- +0 de la soirée, posé par les officiers sur un membre.
-- Pour l'instant gardé seulement chez celui qui le pose (le partage avec la guilde viendra plus tard).
function UI.AZero(nom)
  if ns.demo then
    return ns.Demo.zero[nom] == true
  end
  return UI.Reglage("zero:" .. nom, false) == true
end

function UI.MettreZero(nom, valeur)
  if ns.demo then
    ns.Demo.zero[nom] = valeur or nil
  else
    UI.Regler("zero:" .. nom, valeur or nil)
  end
  if not valeur then
    -- +0 retiré ou utilisé : le prochain +0 de ce joueur rejouera l'animation.
    if ns.demo then
      ns.Demo.zeroVu[nom] = nil
    else
      UI.Regler("zeroVu:" .. nom, nil)
    end
  end
end

-- L'animation de l'autocollant +0 ne se joue qu'une fois par +0 : la première fois
-- qu'on ouvre la fiche du joueur (chaque membre la voit donc une fois de son côté).
function UI.ZeroVu(nom)
  if ns.demo then
    return ns.Demo.zeroVu[nom] == true
  end
  return UI.Reglage("zeroVu:" .. nom, false) == true
end

function UI.MarquerZeroVu(nom)
  if ns.demo then
    ns.Demo.zeroVu[nom] = true
  else
    UI.Regler("zeroVu:" .. nom, true)
  end
end

-- Animation « coup de BD » d'un autocollant : il surgit avec un rebond pendant que l'image
-- tremble. Avec « envol », il monte ensuite en s'effaçant puis disparaît.
-- Le cadre est placé par son centre sur le point « point » de « parent », décalé de (ox, oy).
local ECHELLES = { { 0, 0.2 }, { 0.08, 1.3 }, { 0.16, 0.92 }, { 0.24, 1.04 }, { 0.3, 1 } }
local SECOUSSES = { { 0.08, 0, 0 }, { 0.10, -6, 3 }, { 0.12, 5, -4 }, { 0.14, -4, -2 },
  { 0.16, 4, 3 }, { 0.18, -2, 1 }, { 0.2, 0, 0 } }

-- Valeur de la colonne « i » à l'instant « t », entre les points voisins.
local function Courbe(points, t, i)
  if t <= points[1][1] then
    return points[1][i]
  end
  for k = 2, #points do
    local a, b = points[k - 1], points[k]
    if t <= b[1] then
      return a[i] + (b[i] - a[i]) * (t - a[1]) / (b[1] - a[1])
    end
  end
  return points[#points][i]
end

function UI.AnimerAutocollant(f, parent, point, ox, oy, envol)
  local debut, fin = GetTime(), envol and 1.4 or 0.3
  f:SetAlpha(1)
  f:Show()
  f:SetScript("OnUpdate", function(self)
    local t = GetTime() - debut
    local echelle = Courbe(ECHELLES, t, 2)
    local dx, dy = Courbe(SECOUSSES, t, 2), Courbe(SECOUSSES, t, 3)
    if envol and t > 0.8 then
      local p = math.min(1, (t - 0.8) / 0.6)
      dy = dy + 70 * p
      echelle = echelle * (1 + 0.05 * p)
      self:SetAlpha(1 - p)
    end
    -- Les décalages d'un cadre agrandi sont agrandis aussi : on les divise par l'échelle.
    self:SetScale(echelle)
    self:ClearAllPoints()
    self:SetPoint("CENTER", parent, point, (ox + dx) / echelle, (oy + dy) / echelle)
    if t >= fin then
      self:SetScript("OnUpdate", nil)
      if envol then
        self:Hide()
      end
    end
  end)
end

-- Journal de raid : { { date, instance, boss = { ... }, presents = { ... } }, ... }, du plus ancien au plus récent.
function UI.Raids()
  return ns.demo and ns.Demo.raids or {}
end

function UI.SansLoot()
  return ns.demo and ns.Demo.sansLoot or {}
end

function UI.Rangs()
  return ns.demo and ns.Demo.rangs or ns.Api.LireRangs()
end

-- Grades simulés par /pc maitre, /pc officier, /pc raideur et /pc recrue, pour tester.
local SIMULATIONS = {
  maitre = { rang = "Maître de guilde", maitre = true, officier = true, butin = true },
  officier = { rang = "Officier", officier = true },
  butin = { rang = "Maître du butin", officier = true, butin = true },
  raideur = { rang = "Raideur" },
  recrue = { rang = "Recrue" },
}

-- Maître du butin : un membre désigné par le maître de guilde ou un officier, une fois pour toutes. Personne par défaut.
-- Partagé avec la guilde : voir UI.RecevoirDroits.
function UI.MaitreButin()
  if ns.demo then
    return ns.Demo.maitreButin
  end
  return UI.Reglage("maitreButin", nil)
end

function UI.DesignerMaitreButin(nom)
  if ns.demo then
    ns.Demo.maitreButin = nom
  else
    UI.Regler("maitreButin", nom)
    UI.Regler("maitreButinDate", ns.Api.Heure())
    UI.EnvoyerButin()
  end
end

-- Ce que le joueur peut voir et faire : { rang, maitre, officier, butin }.
-- D'après son grade, les droits par rang des Réglages et le maître du butin désigné,
-- ou d'après le grade simulé (/pc maitre, /pc butin…).
function UI.Droits()
  if ns.simulation then
    return SIMULATIONS[ns.simulation]
  end
  local moi = UI.Membres()[UI.Moi()] or {}
  local rang = moi.rang
  local droits = { rang = rang or "Sans guilde", maitre = moi.rangIndex == 0 }
  droits.officier = droits.maitre or moi.rangIndex == UI.RANG_OFFICIER
  droits.butin = droits.maitre or UI.Moi() == UI.MaitreButin()
  if ns.admin and UI.Reglage("admin", false) then
    droits.maitre, droits.officier, droits.butin = true, true, true
  end
  return droits
end

-- Partage du maître du butin avec la guilde. Messages :
-- "B" + date ~ nom (maître de guilde ou officier) ; "D" : demande envoyée à la connexion.
-- À la réception, le grade de l'expéditeur est vérifié dans la liste de guilde du jeu.
local function PeutDesigner(nomComplet)
  local m = ns.Api.LireGuilde()[ns.Api.NomCourt(nomComplet)]
  if not m then
    return false
  end
  return m.rangIndex == 0 or m.rangIndex == UI.RANG_OFFICIER
end

function UI.EnvoyerButin()
  local date = UI.Reglage("maitreButinDate", 0)
  if not ns.demo and date > 0 then
    ns.Api.EnvoyerGuilde("B" .. date .. "~" .. UI.Reglage("maitreButin", ""))
  end
end

-- Seuls le maître de guilde et les officiers envoient le maître du butin.
local function EnvoyerSiOfficier()
  if PeutDesigner(ns.Api.MonNom()) then
    UI.EnvoyerButin()
  end
end

-- À la connexion et avec « Forcer ma synchronisation ».
function UI.SynchroDroits()
  ns.Api.EnvoyerGuilde("D")
  EnvoyerSiOfficier()
end

function UI.RecevoirDroits(texte, expediteur)
  local sorte, reste = texte:sub(1, 1), texte:sub(2)
  if ns.Api.NomCourt(expediteur) == ns.Api.NomCourt(ns.Api.MonNom()) then
    return -- le jeu nous renvoie nos propres messages de guilde
  end
  if sorte == "D" then
    EnvoyerSiOfficier()
    return
  elseif sorte == "B" and PeutDesigner(expediteur) then
    local date, nom = reste:match("^(%d+)~(.+)$") -- message abîmé : ignoré
    if not date or tonumber(date) <= UI.Reglage("maitreButinDate", 0) then
      return
    end
    UI.Regler("maitreButinDate", tonumber(date))
    UI.Regler("maitreButin", nom)
  else
    return
  end
  if UI.panneau:IsShown() then
    UI.RafraichirTout()
  end
end

-- Panneau déplaçable, se ferme avec Échap.
local panneau = CreateFrame("Frame", "PtitsCasusPanneau", UIParent, "ButtonFrameTemplate")
panneau:SetSize(1160, 720)
panneau:SetPoint("CENTER")
panneau:SetMovable(true)
panneau:SetClampedToScreen(true)
panneau:SetFrameStrata("HIGH") -- au-dessus des barres d'action et des cadres de l'interface
panneau:SetToplevel(true)
panneau:EnableMouse(true)
panneau:RegisterForDrag("LeftButton")
panneau:SetScript("OnDragStart", panneau.StartMoving)
panneau:SetScript("OnDragStop", panneau.StopMovingOrSizing)
panneau:Hide()
table.insert(UISpecialFrames, "PtitsCasusPanneau")
-- Cadre standard du jeu : bordure, barre de titre, portrait et croix de fermeture.
ButtonFrameTemplate_HideButtonBar(panneau)
panneau.Inset:Hide()
panneau:SetTitle("Aux Ptits Casus")
if panneau.SetPortraitToAsset then
  panneau:SetPortraitToAsset("Interface\\Icons\\INV_Misc_Book_09")
else
  ButtonFrameTemplate_HidePortrait(panneau)
end
UI.panneau = panneau

-- Applique le réglage de taille à toutes les fenêtres de l'addon.
UI.fenetres = { panneau }
function UI.AppliquerTaille()
  for _, f in ipairs(UI.fenetres) do
    f:SetScale(UI.Reglage("taille", 100) / 100 * UI.ECHELLE)
  end
end

-- Bandeau sous la barre de titre : sous-titre et fiche du joueur.
local bandeau = CreateFrame("Frame", nil, panneau)
bandeau:SetPoint("TOPLEFT", 6, -24)
bandeau:SetPoint("TOPRIGHT", -6, -24)
bandeau:SetHeight(38)
local ligneBandeau = bandeau:CreateTexture(nil, "ARTWORK")
ligneBandeau:SetPoint("BOTTOMLEFT")
ligneBandeau:SetPoint("BOTTOMRIGHT")
ligneBandeau:SetHeight(2)
ligneBandeau:SetColorTexture(Hex("8c6a3c"))

local sousTitre = UI.Texte(bandeau, UI.TEXTE, 13, "a89f8a")
sousTitre:SetPoint("LEFT", 58, 0) -- après le portrait
sousTitre:SetText("Gestion de guilde · WoW Forever")
local puceDemo = UI.Puce(bandeau, "DÉMO", "3a2a14", "f0c674")
puceDemo:SetPoint("LEFT", sousTitre, "RIGHT", 12, 0)


-- « Ma fiche » : icône de classe, nom, classe et niveau, niveau d'objet, rang. Clic : ma fiche membre.
local fiche = CreateFrame("Button", nil, bandeau, "BackdropTemplate")
fiche:SetHeight(36)
fiche:SetPoint("RIGHT", -10, 0)
UI.Habiller(fiche, "241f17", "6e5230")
UI.Survol(fiche)
UI.Noter("bouton", fiche)
fiche.initiale = CreateFrame("Frame", nil, fiche, "BackdropTemplate")
fiche.initiale:SetSize(28, 28)
fiche.initiale:SetPoint("LEFT", 4, 0)
fiche.icone = fiche.initiale:CreateTexture(nil, "ARTWORK")
fiche.icone:SetPoint("TOPLEFT", 2, -2)
fiche.icone:SetPoint("BOTTOMRIGHT", -2, 2)
fiche.nom = UI.Texte(fiche, UI.TEXTE, 14, "e8e0cc")
fiche.nom:SetPoint("LEFT", fiche.initiale, "RIGHT", 10, 0)
fiche.classe = UI.Texte(fiche, UI.TEXTE, 12, "c9bfa8")
fiche.classe:SetPoint("LEFT", fiche.nom, "RIGHT", 10, 0)
fiche.ilvl = UI.Puce(fiche, "", "16130e", "e8e0cc")
fiche.ilvl:SetPoint("LEFT", fiche.classe, "RIGHT", 10, 0)
fiche.rang = UI.Puce(fiche, "", "2a2316", "e6b84a")
fiche.rang:SetPoint("LEFT", fiche.ilvl, "RIGHT", 6, 0)
fiche:SetScript("OnClick", function() UI.OuvrirFiche(UI.Moi()) end)

local function RafraichirBandeau(membres)
  puceDemo:SetShown(ns.demo)
  local moi = membres[UI.Moi()] or {}
  local couleur = UI.HexClasse(moi.classe)
  local nom = UI.Moi()
  UI.Habiller(fiche.initiale, "2a1c0e", couleur, 2)
  fiche.icone:SetTexture(ns.Api.IconeClasse(moi.classe))
  fiche.nom:SetText(nom)
  fiche.nom:SetTextColor(Hex(couleur))
  fiche.classe:SetText(ns.Api.NomClasse(moi.classe) .. " " .. (moi.niveau or ""))
  UI.EcrirePuce(fiche.ilvl, "ilvl " .. (moi.ilvl or "?"))
  UI.EcrirePuce(fiche.rang, UI.Droits().rang .. (ns.simulation and " (simulé)" or ""))
  fiche:SetWidth(4 + 28 + 10 + fiche.nom:GetStringWidth() + 10 + fiche.classe:GetStringWidth()
    + 10 + fiche.ilvl:GetWidth() + 6 + fiche.rang:GetWidth() + 10)
end

-- Menu de gauche et zone des pages à droite.
local menu = CreateFrame("Frame", nil, panneau)
menu:SetPoint("TOPLEFT", bandeau, "BOTTOMLEFT")
menu:SetPoint("BOTTOMLEFT", 6, 5)
menu:SetWidth(210)
UI.Fond(menu, "0e0c09")
local bordMenu = menu:CreateTexture(nil, "ARTWORK")
bordMenu:SetPoint("TOPRIGHT")
bordMenu:SetPoint("BOTTOMRIGHT")
bordMenu:SetWidth(2)
bordMenu:SetColorTexture(Hex("6e5230"))

-- Pour le skin EllesmereUI : le panneau, son bandeau, son menu et sa croix de fermeture.
panneau.bandeau, panneau.menu, panneau.fermer = bandeau, menu, panneau.CloseButton
UI.Noter("fenetre", panneau)

local contenu = CreateFrame("Frame", nil, panneau)
contenu:SetPoint("TOPLEFT", menu, "TOPRIGHT", 20, -18)
contenu:SetSize(UI.LARGEUR, UI.HAUTEUR)

-- Pages : chaque fichier Page*.lua remplit UI.pages[id] et donne UI.rafraichir[id],
-- appelé à chaque affichage de la page.
UI.pages, UI.rafraichir = {}, {}
local boutons = {}
UI.boutons = boutons -- boutons du menu, par page (la visite guidée les entoure)
-- Page d'accueil à la première ouverture après la connexion ; ensuite, l'addon se rouvre
-- sur la dernière page vue pendant la session.
local pageActive = "stats"

local function RafraichirTout()
  local membres = UI.Membres()
  UI.MajAccent(membres)
  RafraichirBandeau(membres)
  UI.RafraichirMenu(membres)
  for cle, bouton in pairs(boutons) do
    bouton.fond:SetShown(cle == pageActive)
    bouton.texte:SetTextColor(Hex(cle == pageActive and UI.ACCENT or "c9bfa8"))
  end
  if UI.rafraichir[pageActive] then
    UI.rafraichir[pageActive]()
  end
end
UI.RafraichirTout = RafraichirTout

function UI.AfficherPage(id)
  pageActive = id
  for cle, page in pairs(UI.pages) do
    page:SetShown(cle == id)
  end
  if panneau:IsShown() then
    RafraichirTout()
  end
end

-- Ouvre la fiche d'un membre (page Membres).
function UI.OuvrirFiche(nom)
  UI.membreChoisi = nom
  UI.AfficherPage("membres")
end

panneau:HookScript("OnShow", RafraichirTout)

local y = -12 -- position du prochain élément du menu

-- Catégorie du menu : titre doré suivi d'un trait, pages en retrait dessous.
local function Section(texte)
  y = y - 8
  local fs = UI.Texte(menu, UI.TITRE, 13, "ffd100")
  fs:SetPoint("TOPLEFT", 20, y - 8)
  fs:SetText(texte)
  local trait = menu:CreateTexture(nil, "ARTWORK")
  trait:SetHeight(1)
  trait:SetPoint("LEFT", fs, "RIGHT", 8, 0)
  trait:SetPoint("RIGHT", menu, "RIGHT", -14, 0)
  trait:SetColorTexture(Hex("6e5230"))
  y = y - 36
end

-- Ajoute un bouton au menu et une page vide correspondante.
local function Page(id, libelle)
  local bouton = CreateFrame("Button", nil, menu)
  bouton:SetSize(190, 34)
  bouton:SetPoint("TOPLEFT", 10, y)
  bouton.fond = UI.Fond(bouton, "2a2316")
  UI.Survol(bouton)
  bouton.texte = UI.Texte(bouton, UI.TEXTE, 14, "c9bfa8")
  bouton.texte:SetPoint("LEFT", 26, 0)
  bouton.texte:SetText(libelle)
  bouton:SetScript("OnClick", function() UI.AfficherPage(id) end)
  boutons[id] = bouton
  y = y - 34

  local page = CreateFrame("Frame", nil, contenu)
  page:SetAllPoints()
  page:Hide()
  UI.pages[id] = page
end

Section("GUILDE")
Page("stats", "Statistiques")
Page("membres", "Membres")
Page("metiers", "Métiers")
Page("commandes", "Commandes")
Section("RAID")
Page("loot", "Loot en cours")
Page("historique", "Historique des loots")
Page("regles", "Règles du loot")
Page("reglages", "Réglages")

-- Bas du menu : Réglages (hors catégorie, sans retrait) puis le nombre de membres en ligne.
local piedMenu = CreateFrame("Frame", nil, menu)
piedMenu:SetPoint("BOTTOMLEFT", 10, 8)
piedMenu:SetPoint("BOTTOMRIGHT", -12, 8)
piedMenu:SetHeight(50)
local traitPied = piedMenu:CreateTexture(nil, "ARTWORK")
traitPied:SetPoint("TOPLEFT")
traitPied:SetPoint("TOPRIGHT")
traitPied:SetHeight(1)
traitPied:SetColorTexture(Hex("4a3820"))
local enLigne = UI.Texte(piedMenu, UI.TEXTE, 12, "a89f8a")
enLigne:SetPoint("TOPLEFT", 12, -10)
local avecAddon = UI.Texte(piedMenu, UI.TEXTE, 12, "a89f8a")
avecAddon:SetPoint("TOPLEFT", enLigne, "BOTTOMLEFT", 0, -4)

boutons.reglages:ClearAllPoints()
boutons.reglages:SetPoint("BOTTOMLEFT", piedMenu, "TOPLEFT", 0, 6)
boutons.reglages.texte:SetPoint("LEFT", 12, 0)

-- « aucun » à côté de Loot en cours quand rien n'est en jeu.
local aucunLoot = UI.Texte(boutons.loot, UI.TEXTE, 11, "a89f8a")
aucunLoot:SetPoint("RIGHT", -10, 0)
aucunLoot:SetText("aucun")

-- Nombre de nouveautés à côté de Commandes.
local nouveautes = UI.Texte(boutons.commandes, UI.TITRE, 12, "ffd100")
nouveautes:SetPoint("RIGHT", -10, 0)

function UI.RafraichirMenu(membres)
  local nbEnLigne, nbAddon = 0, 0
  for _, m in pairs(membres) do
    if m.enLigne then
      nbEnLigne = nbEnLigne + 1
      if #(m.metiers or {}) > 0 then
        nbAddon = nbAddon + 1
      end
    end
  end
  enLigne:SetText(nbEnLigne .. " en ligne")
  avecAddon:SetText(nbAddon .. " avec l'addon")
  aucunLoot:SetShown(not UI.Loot())
end

local function Basculer()
  panneau:SetShown(not panneau:IsShown())
end

-- Raccourci clavier (Bindings.xml) : se choisit dans les Réglages de l'addon, ou dans Options > Raccourcis > AddOns.
BINDING_HEADER_PTITSCASUS = "Aux Ptits Casus"
BINDING_NAME_PTITSCASUS_OUVRIR = "Ouvrir ou fermer le panneau"
PtitsCasus_Basculer = Basculer

-- Bouton rond autour de la minimap.
local bouton = CreateFrame("Button", "PtitsCasusBoutonMinimap", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
bouton:RegisterForDrag("LeftButton")
UI.boutonMinimap = bouton

local icone = bouton:CreateTexture(nil, "BACKGROUND")
icone:SetSize(20, 20)
icone:SetPoint("TOPLEFT", 7, -5)
icone:SetTexture("Interface\\Icons\\INV_Misc_Book_09")

local bord = bouton:CreateTexture(nil, "OVERLAY")
bord:SetSize(53, 53)
bord:SetPoint("TOPLEFT")
bord:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Pastille rouge sur le bouton : nombre de nouveautés dans les commandes.
local pastille = CreateFrame("Frame", nil, bouton)
pastille:SetSize(16, 16)
pastille:SetPoint("TOPRIGHT", 2, 2)
pastille:SetFrameLevel(bouton:GetFrameLevel() + 5)
UI.Fond(pastille, "c0261a")
local chiffre = UI.Texte(pastille, UI.TITRE, 9, "ffffff")
chiffre:SetPoint("CENTER")
chiffre:SetJustifyH("CENTER")
pastille:Hide()

-- Met à jour la pastille, le nombre dans le menu et la page Commandes si elle est affichée.
function UI.MajCommandes()
  local n = ns.Commandes.Donnees().nonLues
  pastille:SetShown(n > 0)
  chiffre:SetText(n)
  nouveautes:SetShown(n > 0)
  nouveautes:SetText(n)
  if panneau:IsShown() and pageActive == "commandes" then
    UI.rafraichir.commandes()
  end
end

-- Place le bouton sur le bord de la minimap, selon un angle en degrés.
local function Placer(angle)
  local rayon = Minimap:GetWidth() / 2 + 10
  bouton:ClearAllPoints()
  bouton:SetPoint("CENTER", Minimap, "CENTER", math.cos(math.rad(angle)) * rayon, math.sin(math.rad(angle)) * rayon)
end

local function SuivreSouris()
  local mx, my = Minimap:GetCenter()
  local sx, sy = GetCursorPosition()
  local echelle = Minimap:GetEffectiveScale()
  PtitsCasusDB.angleMinimap = math.deg(math.atan2(sy / echelle - my, sx / echelle - mx))
  Placer(PtitsCasusDB.angleMinimap)
end

-- Clic gauche : ouvrir ou fermer. Clic droit : Réglages.
bouton:SetScript("OnClick", function(_, clic)
  if clic == "RightButton" then
    panneau:Show()
    UI.AfficherPage("reglages")
  else
    Basculer()
  end
end)
bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreSouris) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
bouton:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("Aux Ptits Casus")
  GameTooltip:AddLine("Clic : ouvrir le panneau", 1, 1, 1)
  GameTooltip:AddLine("Clic droit : Réglages", 1, 1, 1)
  GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
  local n = ns.Commandes.Donnees().nonLues
  if n > 0 then
    GameTooltip:AddLine(n .. " nouveauté(s) dans les commandes", 1, 0.82, 0)
  end
  GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Onglet dans la fenêtre Guilde et communautés, sous le dernier de ses onglets de droite.
-- Accroché à ce dernier : il apparaît et disparaît avec lui. La fenêtre du jeu n'est pas modifiée.
local ongletGuilde
local function PlacerOngletGuilde()
  local f = CommunitiesFrame
  local dernier = f.GuildInfoTab
  for _, c in ipairs({ f:GetChildren() }) do
    if c:IsShown() and c:GetLeft() and math.abs(c:GetLeft() - f.ChatTab:GetLeft()) < 2
      and c:GetBottom() < dernier:GetBottom() then
      dernier = c
    end
  end
  ongletGuilde:SetParent(dernier)
  ongletGuilde:ClearAllPoints()
  ongletGuilde:SetPoint("TOP", dernier, "BOTTOM", 0, f.RosterTab:GetTop() - f.ChatTab:GetBottom())
end

local function AjouterOngletGuilde()
  local f = CommunitiesFrame
  if ongletGuilde or not (f and f.GuildInfoTab) then
    return
  end
  -- Modèle d'onglet des fenêtres du jeu : il gère l'enfoncement, le son et l'infobulle.
  ongletGuilde = CreateFrame("Frame", nil, f.GuildInfoTab, "LargeSideTabButtonTemplate")
  ongletGuilde.Icon:SetTexture("Interface/Icons/INV_Misc_Book_09")
  ongletGuilde:SetFillToInterior(true)
  ongletGuilde.tooltipText = "Aux Ptits Casus"
  ongletGuilde:EnableMouse(true)
  ongletGuilde:SetChecked(panneau:IsShown())
  ongletGuilde:SetCustomOnMouseUpHandler(function(_, clic, dessus)
    if clic == "LeftButton" and dessus then
      Basculer()
    end
  end)
  panneau:HookScript("OnShow", function() ongletGuilde:SetChecked(true) end)
  panneau:HookScript("OnHide", function() ongletGuilde:SetChecked(false) end)
  -- Les onglets du jeu ne sont placés qu'une fois la fenêtre ouverte.
  f:HookScript("OnShow", function() C_Timer.After(0, PlacerOngletGuilde) end)
  if f:IsShown() then
    PlacerOngletGuilde()
  end
end

-- La fenêtre Guilde et communautés n'est chargée par le jeu qu'à sa première ouverture.
local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(_, _, addon)
  if addon == "Blizzard_Communities" then
    AjouterOngletGuilde()
  end
end)

-- Appelé à la connexion, une fois PtitsCasusDB chargé.
function ns.InitInterface()
  Placer(PtitsCasusDB.angleMinimap or 225)
  bouton:SetShown(UI.Reglage("minimap", true))
  UI.AppliquerTaille()
  AjouterOngletGuilde() -- au cas où un autre addon aurait déjà chargé la fenêtre de guilde
  UI.AfficherPage(pageActive)
  UI.MajCommandes()
end

-- /pc : ouvrir ou fermer. /pc visite : visite guidée de l'addon (Visite.lua).
-- En développement seulement : /pc test (données de démo), /pc reduit (fenêtre de loot réduite, en démo),
-- /pc maitre, officier, butin, raideur, recrue (simuler ce grade, même commande : arrêter).
-- /pc loot : rouvrir la fenêtre de loot (vue officier pour le maître du butin, vue joueur sinon).
SLASH_PTITSCASUS1 = "/pc"
SLASH_PTITSCASUS2 = "/ig"
SlashCmdList.PTITSCASUS = function(argument)
  if argument == "loot" then
    UI.BasculerLoot()
  elseif ns.admin and SIMULATIONS[argument] then
    -- Même commande une deuxième fois : retour au vrai grade.
    ns.simulation = ns.simulation ~= argument and argument or nil
    print("Aux Ptits Casus : " .. (ns.simulation and ("grade simulé : " .. SIMULATIONS[argument].rang) or "retour au vrai grade") .. ".")
    panneau:Show()
    RafraichirTout()
  elseif argument == "visite" then
    UI.LancerVisite()
  elseif ns.admin and argument == "reduit" then
    ns.demo = true
    UI.membreChoisi = nil
    UI.OuvrirLootReduit()
  elseif ns.admin and argument == "test" then
    ns.demo = not ns.demo
    print("Aux Ptits Casus : démo " .. (ns.demo and "activée" or "coupée") .. ".")
    UI.membreChoisi = nil
    panneau:Show()
    RafraichirTout()
    UI.MajCommandes()
  else
    Basculer()
  end
end
