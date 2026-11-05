-- Les deux petites fenêtres de loot, à côté de la page complète « Loot en cours » :
-- - la fenêtre du joueur (« Loot · Garr ») : chaque membre choisit son palier ou passe, objet par objet ;
-- - la vue réduite du maître du butin : annonces reçues par objet, attribuer, annoncer.
-- Pour l'instant, seules les données de démo les alimentent (/pc test, puis /pc loot ou les boutons
-- de la page Loot en cours). Les boutons du maître du butin n'envoient encore rien.
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex

local LARGEUR = 368
local INTERIEUR = LARGEUR - 26 -- largeur d'une ligne d'objet

-- Petite fenêtre déplaçable : bandeau avec titre, texte à droite et bouton de fermeture, texte en pied.
local function PetiteFenetre(nom)
  local f = CreateFrame("Frame", nom, UIParent, "ButtonFrameTemplate")
  f:SetWidth(LARGEUR)
  f:SetPoint("CENTER", 300, 0)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()
  table.insert(UISpecialFrames, nom)
  table.insert(UI.fenetres, f)
  -- Cadre standard du jeu, sans portrait.
  ButtonFrameTemplate_HidePortrait(f)
  ButtonFrameTemplate_HideButtonBar(f)
  f.Inset:Hide()

  f.bandeau = CreateFrame("Frame", nil, f)
  f.bandeau:SetPoint("TOPLEFT", 3, -3)
  f.bandeau:SetPoint("TOPRIGHT", -3, -3)
  f.bandeau:SetHeight(40)
  f.fermer = f.CloseButton
  f.droite = UI.Texte(f.bandeau, UI.TEXTE, 12, "a89f8a")
  f.droite:SetPoint("RIGHT", f.fermer, "LEFT", -10, 0)

  f.pied = UI.Paragraphe(f, 11, "a89f8a", LARGEUR - 30, "")
  f.lignes = {}
  UI.Noter("fenetre", f)
  return f
end

-- Ligne d'objet : icône, nom et état ; la zone « detail » dessous s'affiche quand la ligne est ouverte.
local function LigneObjet(f, hauteur, tailleIcone, avecLettre, largeurNom)
  local ligne = CreateFrame("Frame", nil, f, "BackdropTemplate")
  ligne:SetWidth(INTERIEUR)
  ligne.hauteur = hauteur
  ligne.bouton = CreateFrame("Button", nil, ligne)
  ligne.bouton:SetPoint("TOPLEFT")
  ligne.bouton:SetPoint("TOPRIGHT")
  ligne.bouton:SetHeight(hauteur)
  UI.Survol(ligne.bouton)
  ligne.icone = CreateFrame("Frame", nil, ligne.bouton, "BackdropTemplate")
  ligne.icone:SetSize(tailleIcone, tailleIcone)
  ligne.icone:SetPoint("LEFT", 8, 0)
  if avecLettre then
    ligne.lettre = UI.Texte(ligne.icone, UI.TITRE, 15, "e8e0cc")
    ligne.lettre:SetPoint("CENTER")
  end
  ligne.nom = UI.TexteCourt(ligne.bouton, 13, "e8e0cc", largeurNom)
  ligne.nom:SetPoint("TOPLEFT", ligne.icone, "TOPRIGHT", 8, 1)
  ligne.etat = UI.Texte(ligne.bouton, UI.TEXTE, 11, "a89f8a")
  ligne.etat:SetPoint("TOPLEFT", ligne.nom, "BOTTOMLEFT", 0, -2)
  ligne.detail = CreateFrame("Frame", nil, ligne)
  ligne.detail:SetPoint("TOPLEFT", 0, -hauteur)
  ligne.detail:SetPoint("TOPRIGHT", 0, -hauteur)
  return ligne
end

-- Couleurs de l'icône et du nom selon la qualité ; icône pâlie si l'objet est terminé ou inutilisable.
local function Colorer(ligne, objet, pali)
  local couleur, fond = unpack(UI.QUALITES[objet.qualite])
  UI.Habiller(ligne.icone, fond, couleur, 2)
  ligne.icone:SetAlpha(pali and 0.55 or 1)
  if ligne.lettre then
    ligne.lettre:SetText(objet.nom:sub(1, 1))
    ligne.lettre:SetTextColor(Hex(couleur))
  end
  ligne.nom:SetText(objet.nom)
  ligne.nom:SetTextColor(Hex(couleur))
end

-- Info-bulle façon jeu au survol d'un objet.
local function InfoBulle(ligne, objet)
  ligne.bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(objet.nom, Hex(UI.QUALITES[objet.qualite][1]))
    GameTooltip:AddLine("Lié quand ramassé", 1, 1, 1)
    GameTooltip:AddDoubleLine(objet.emplacement, objet.type, 1, 1, 1, Hex(objet.typeRouge and "ff2020" or "ffffff"))
    for _, l in ipairs(objet.infobulle or {}) do
      GameTooltip:AddLine(l[1], Hex(l[2] or "ffffff"))
    end
    GameTooltip:Show()
  end)
  ligne.bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Place les lignes les unes sous les autres, puis le pied, et ajuste la hauteur de la fenêtre.
local function Disposer(f, ouverte)
  local y = (f.onglets and f.onglets:IsShown()) and -83 or -49 -- sous les onglets s'ils sont là
  for i, ligne in ipairs(f.lignes) do
    local estOuverte = i == ouverte
    local h = ligne.hauteur + (estOuverte and ligne.detail:GetHeight() or 0)
    ligne.detail:SetShown(estOuverte)
    ligne:SetHeight(h)
    ligne:SetPoint("TOPLEFT", 13, y)
    UI.Habiller(ligne, estOuverte and "1e1a13" or "1b1711", estOuverte and UI.ACCENT or "4a3820")
    y = y - h - 4
  end
  f.pied:SetPoint("TOPLEFT", 15, y - 4)
  f:SetHeight(-y + 4 + f.pied:GetStringHeight() + 14)
end

local function PasEnvoye()
  print("Aux Ptits Casus (démo) : rien n'est envoyé.")
end

-- Annonces par palier dans le détail d'un objet : « +1  Brakkor 74 · Thalyn 41 »,
-- puis « Gagnant : Brakkor » dessous. Renvoie la nouvelle position y.
local function Annonces(d, y, annonces, membres)
  for _, a in ipairs(annonces or {}) do
    local palier = UI.Texte(d, UI.TITRE, 13, UI.PALIERS[a.palier][1])
    palier:SetPoint("TOPLEFT", 10, y)
    palier:SetText(a.palier)
    local noms = {}
    for _, q in ipairs(a.qui) do
      table.insert(noms, "|cff" .. UI.HexClasse((membres[q[1]] or {}).classe) .. q[1] .. "|r"
        .. (q[2] and (" |cffc9bfa8" .. q[2] .. "|r") or ""))
    end
    local texte = UI.TexteCourt(d, 13, "e8e0cc", INTERIEUR - 66 - 10)
    texte:SetPoint("TOPLEFT", 66, y)
    texte:SetText(table.concat(noms, " · "))
    y = y - 24
    if a.gagnant then
      local gagnant = UI.Puce(d, "Gagnant : " .. a.gagnant, "ffd100", "1a1209")
      gagnant:SetPoint("TOPLEFT", 66, y + 2)
      y = y - 28
    end
  end
  return y
end

------------------------------------------------------------------------
-- Fenêtre du joueur.
------------------------------------------------------------------------
local joueur = PetiteFenetre("PtitsCasusLootJoueur")
joueur.pied:SetText("Ton choix est transmis au maître du butin. Tu peux aussi taper +1, +1 DL ou +2 dans le chat de raid.")
-- « Ton palier : +1 DL », avec le palier en plus gros et dans sa couleur.
local monPalier = UI.Texte(joueur.bandeau, UI.TITRE, 17, "e8e0cc")
monPalier:SetPoint("RIGHT", joueur.fermer, "LEFT", -10, 0)
joueur.droite:ClearAllPoints()
joueur.droite:SetPoint("RIGHT", monPalier, "LEFT", -6, 0)
joueur.droite:SetText("Ton palier :")
local choix = {} -- choix du joueur, par numéro d'objet
local ouverteJoueur = 2
local joueurConstruit = false
local RafraichirJoueur

-- Couleurs des choix : celles des paliers (UI.PALIERS), gris pour Passer.
local COULEUR_CHOIX = { ["+1"] = UI.PALIERS["+1"][1], ["+1 DL"] = UI.PALIERS["+1 DL"][1], ["+2"] = UI.PALIERS["+2"][1], ["Passer"] = "8a826f" }

local function ConstruireJoueur(loot)
  local largeurBouton = (INTERIEUR - 16 - 12) / 3
  for i, objet in ipairs(loot.file) do
    local ligne = LigneObjet(joueur, 50, 34, true, INTERIEUR - 34 - 120)
    ligne.puce = UI.Puce(ligne.bouton, "", "16130e", "a89f8a")
    ligne.puce:SetPoint("RIGHT", -8, 0)
    InfoBulle(ligne, objet)
    ligne.bouton:SetScript("OnClick", function()
      ouverteJoueur = ouverteJoueur ~= i and i or nil
      RafraichirJoueur()
    end)
    if objet.fini then
      -- Objet terminé : qui a annoncé, les /rand et le gagnant.
      ligne.detail:SetHeight(-Annonces(ligne.detail, -2, objet.annonces, UI.Membres()) + 6)
    elseif objet.utilisable then
      -- Trois boutons : ton palier (+1 ou +1 DL), +2, Passer. Nouveau clic : annule le choix.
      ligne.choix = {}
      for j, option in ipairs({ loot.monPalier, "+2", "Passer" }) do
        local b = CreateFrame("Button", nil, ligne.detail, "BackdropTemplate")
        b:SetSize(largeurBouton, 34)
        b:SetPoint("TOPLEFT", 8 + (j - 1) * (largeurBouton + 6), 0)
        UI.Survol(b)
        b.texte = UI.Texte(b, j < 3 and UI.TITRE or UI.TEXTE, 15, "e8e0cc")
        b.texte:SetPoint("CENTER")
        b.texte:SetText(option)
        b.option = option
        b:SetScript("OnClick", function()
          choix[i] = choix[i] ~= option and option or nil
          RafraichirJoueur()
        end)
        ligne.choix[j] = b
      end
    else
      local refus = UI.Carte(ligne.detail, "2a1715", "6b2e28")
      refus:SetPoint("TOPLEFT", 8, 0)
      refus:SetPoint("TOPRIGHT", -8, 0)
      refus:SetHeight(34)
      local texte = UI.Texte(refus, UI.TEXTE, 13, "f29a8e")
      texte:SetPoint("LEFT", 10, 0)
      texte:SetText("Pas utilisable par ta classe")
    end
    if not objet.fini then
      ligne.detail:SetHeight(42)
    end
    joueur.lignes[i] = ligne
  end
  for i, c in pairs(loot.mesChoix or {}) do
    choix[i] = c
  end
end

function RafraichirJoueur()
  local loot = UI.Loot()
  if not loot then
    joueur:Hide()
    return
  end
  UI.MajAccent(UI.Membres())
  if not joueurConstruit then
    ConstruireJoueur(loot)
    joueurConstruit = true
  end
  joueur:SetTitle("Loot · " .. loot.boss)
  monPalier:SetText(loot.monPalier)
  monPalier:SetTextColor(Hex(COULEUR_CHOIX[loot.monPalier]))

  for i, objet in ipairs(loot.file) do
    local ligne = joueur.lignes[i]
    Colorer(ligne, objet, objet.fini or not objet.utilisable)
    ligne.etat:SetText(objet.etatJoueur)
    ligne.etat:SetTextColor(Hex(objet.enCours and "b9e07a" or "a89f8a"))
    -- Puce de droite : Terminé, Inutilisable, ton choix (en négatif, couleur du palier), ou À choisir.
    local texte, fond, couleur = "À choisir", "16130e", "a89f8a"
    if objet.fini then
      texte, fond, couleur = "Terminé", "16130e", "8a826f"
    elseif not objet.utilisable then
      texte, fond, couleur = "Inutilisable", "2a1715", "f29a8e"
    elseif choix[i] then
      texte, fond, couleur = choix[i], COULEUR_CHOIX[choix[i]], "ffffff"
    end
    ligne.puce.fond:SetColorTexture(Hex(fond))
    ligne.puce.texte:SetTextColor(Hex(couleur))
    UI.EcrirePuce(ligne.puce, texte)
    -- Bouton choisi : fond de la couleur du palier (violet pour +2…) et texte sombre.
    for _, b in ipairs(ligne.choix or {}) do
      local actif = choix[i] == b.option
      local c = COULEUR_CHOIX[b.option]
      UI.Habiller(b, actif and c or "241f17", actif and c or "6e5230")
      b.texte:SetTextColor(Hex(actif and "ffffff" or c))
    end
  end
  local droits = UI.Droits()
  joueur.onglets:SetShown(droits.officier or droits.butin)
  Disposer(joueur, ouverteJoueur)
end

joueur:SetScript("OnShow", RafraichirJoueur)

------------------------------------------------------------------------
-- Vue réduite du maître du butin.
------------------------------------------------------------------------
local mini = PetiteFenetre("PtitsCasusLootMini")
mini:SetPoint("CENTER", -300, 0)
mini.pied:SetText("Clic sur un objet pour voir ses annonces · fenêtre déplaçable")
local agrandir = UI.BoutonSombre(mini.bandeau, "Agrandir") -- ouvre la page complète Loot en cours
agrandir:SetHeight(24)
agrandir:SetPoint("RIGHT", mini.fermer, "LEFT", -6, 0)
agrandir:SetScript("OnClick", function()
  UI.panneau:Show()
  UI.AfficherPage("loot")
end)
mini.droite:ClearAllPoints()
mini.droite:SetPoint("RIGHT", agrandir, "LEFT", -10, 0)
local ouverteMini = 2
local miniConstruit = false
local RafraichirMini

-- Annonces de l'objet en cours, d'après les paliers de la page complète.
local function AnnoncesEnCours(loot)
  local annonces = {}
  for _, p in ipairs(loot.paliers) do
    if #p.lignes > 0 then
      local a = { palier = p.palier, qui = {} }
      for _, l in ipairs(p.lignes) do
        table.insert(a.qui, { l.nom, l.rand })
        if l.gagnant then
          a.gagnant = l.nom
        end
      end
      table.insert(annonces, a)
    end
  end
  return annonces
end

-- Encadré « ce qui sera envoyé dans le chat ». Renvoie la nouvelle position y.
local function Apercu(parent, y, titre, lignes)
  local boite = CreateFrame("Frame", nil, parent)
  boite:SetPoint("TOPLEFT", 10, y)
  boite:SetPoint("TOPRIGHT", -10, y)
  UI.Fond(boite, "0f0d09")
  local h = 6
  local t = UI.Paragraphe(boite, 12, "a89f8a", INTERIEUR - 36, titre)
  t:SetPoint("TOPLEFT", 8, -h)
  h = h + t:GetStringHeight() + 2
  for _, l in ipairs(lignes) do
    local fs = UI.Paragraphe(boite, 12, l[2], INTERIEUR - 36, l[1])
    fs:SetPoint("TOPLEFT", 8, -h)
    h = h + fs:GetStringHeight() + 2
  end
  boite:SetHeight(h + 6)
  return y - h - 6
end

local function ConstruireMini(loot)
  local membres = UI.Membres()
  for i, objet in ipairs(loot.file) do
    local ligne = LigneObjet(mini, 44, 26, false, INTERIEUR - 26 - 30)
    InfoBulle(ligne, objet)
    ligne.bouton:SetScript("OnClick", function()
      ouverteMini = ouverteMini ~= i and i or nil
      RafraichirMini()
    end)
    local d = ligne.detail
    local y = Annonces(d, -2, objet.enCours and AnnoncesEnCours(loot) or objet.annonces, membres)
    ligne.boutonsButin = {} -- boutons réservés au maître du butin
    if objet.enCours then
      local attribuer = UI.BoutonRouge(d, "Attribuer à " .. loot.gagnant)
      attribuer:SetPoint("TOPLEFT", 10, y - 6)
      attribuer:SetScript("OnClick", PasEnvoye)
      local passer = UI.BoutonRouge(d, "Passer l'objet")
      passer:SetPoint("LEFT", attribuer, "RIGHT", 6, 0)
      passer:SetScript("OnClick", PasEnvoye)
      ligne.boutonsButin = { attribuer, passer }
      y = Apercu(d, y - 46, "À l'attribution, envoie :",
        { { "[Raid] [APC] " .. loot.gagnant .. " remporte [" .. objet.nom .. "]", "ff7f00" } })
    elseif not objet.fini then
      local annoncer = UI.BoutonRouge(d, "Annoncer")
      annoncer:SetPoint("TOPLEFT", 10, y - 4)
      annoncer:SetScript("OnClick", PasEnvoye)
      ligne.boutonsButin = { annoncer }
      y = Apercu(d, y - 44, "Envoie :", {
        { "[Avertissement raid] [" .. objet.nom .. "] : +1, +1 DL ou +2", "ff4800" },
        { "[Raid] [APC] [" .. objet.nom .. "] : +1, +1 DL ou +2", "ff7f00" },
      })
    end
    d:SetHeight(-y + 8)
    mini.lignes[i] = ligne
  end
end

function RafraichirMini()
  local loot = UI.Loot()
  if not loot then
    mini:Hide()
    return
  end
  UI.MajAccent(UI.Membres())
  if not miniConstruit then
    ConstruireMini(loot)
    miniConstruit = true
  end
  mini:SetTitle("Loot · " .. loot.boss)
  local droits = UI.Droits()
  mini.onglets:SetShown(droits.officier or droits.butin)
  local attribues = 0
  for i, objet in ipairs(loot.file) do
    local ligne = mini.lignes[i]
    for _, b in ipairs(ligne.boutonsButin) do
      b:SetShown(droits.butin)
    end
    Colorer(ligne, objet, objet.fini)
    ligne.etat:SetText(objet.etatMini)
    ligne.etat:SetTextColor(Hex(objet.enCours and "b9e07a" or "a89f8a"))
    if objet.fini then
      attribues = attribues + 1
    end
  end
  mini.droite:SetText(attribues .. "/" .. #loot.file .. " attribué")
  Disposer(mini, ouverteMini)
end

mini:SetScript("OnShow", RafraichirMini)

------------------------------------------------------------------------
-- Onglets Joueur / Officier, pour les officiers et le maître du butin : ils annoncent aussi
-- leur palier comme tout le monde (onglet Joueur) et suivent les annonces (onglet Officier).
------------------------------------------------------------------------
-- Passe d'une fenêtre à l'autre, au même endroit de l'écran.
local function Changer(depuis, vers)
  local gauche, haut = depuis:GetLeft(), depuis:GetTop()
  depuis:Hide()
  if gauche then
    vers:ClearAllPoints()
    vers:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", gauche, haut)
  end
  vers:Show()
end

for _, f in ipairs({ joueur, mini }) do
  f.onglets = CreateFrame("Frame", nil, f)
  f.onglets:SetPoint("TOPLEFT", 13, -47)
  f.onglets:SetPoint("TOPRIGHT", -13, -47)
  f.onglets:SetHeight(30)
  f.onglets:Hide()
  local largeur = (INTERIEUR - 6) / 2
  local ongletJoueur = UI.BoutonSombre(f.onglets, "Joueur")
  ongletJoueur:SetSize(largeur, 28)
  ongletJoueur:SetPoint("LEFT")
  local ongletOfficier = UI.BoutonSombre(f.onglets, "Officier")
  ongletOfficier:SetSize(largeur, 28)
  ongletOfficier:SetPoint("RIGHT")
  -- L'onglet de la fenêtre affichée est en doré.
  local actif = f == joueur and ongletJoueur or ongletOfficier
  UI.Habiller(actif, "2a2316", "ffd100")
  actif.texte:SetTextColor(Hex("ffd100"))
  ongletJoueur:SetScript("OnClick", function()
    if f == mini then
      Changer(mini, joueur)
    end
  end)
  ongletOfficier:SetScript("OnClick", function()
    if f == joueur then
      Changer(joueur, mini)
    end
  end)
end

-- Ouvrir ou fermer la petite fenêtre de loot (page Loot en cours, commande /pc loot) :
-- le maître du butin arrive sur l'onglet Officier, tous les autres (officiers compris) sur l'onglet Joueur.
function UI.BasculerLoot()
  if not UI.Loot() then
    print("Aux Ptits Casus : aucun loot en cours.")
    return
  end
  if joueur:IsShown() or mini:IsShown() then
    joueur:Hide()
    mini:Hide()
    return
  end
  if UI.Droits().butin then
    mini:Show()
  else
    joueur:Show()
  end
end

-- Ouvre la vue réduite du maître du butin, quel que soit le grade (test).
function UI.OuvrirLootReduit()
  joueur:Hide()
  mini:Show()
end
