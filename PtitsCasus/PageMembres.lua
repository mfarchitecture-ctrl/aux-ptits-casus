-- Page Membres : la liste des membres à gauche, la fiche du membre choisi à droite,
-- avec son équipement façon armurerie (emplacements à gauche et à droite, armes en bas).
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local page = UI.pages.membres

local LARGEUR_LISTE = 260
local AUTOCOLLANT = "Interface\\AddOns\\PtitsCasus\\Media\\Autocollant0.tga" -- l'autocollant « +0 » façon BD

-- Recherche par nom, sous la liste.
local HAUTEUR_RECHERCHE = 36
local recherche = CreateFrame("EditBox", nil, page, "BackdropTemplate")
recherche:SetSize(LARGEUR_LISTE, HAUTEUR_RECHERCHE)
recherche:SetPoint("BOTTOMLEFT")
recherche:SetAutoFocus(false)
recherche:SetFont(UI.TEXTE, 14 * UI.ZOOM, "")
recherche:SetTextColor(Hex("e8e0cc"))
recherche:SetTextInsets(12, 12, 0, 0)
UI.Habiller(recherche, "100e0a", "6e5230")
recherche:SetScript("OnEscapePressed", recherche.ClearFocus)
UI.Noter("saisie", recherche)
recherche:SetScript("OnEnterPressed", recherche.ClearFocus)
local indice = UI.Texte(recherche, UI.TEXTE, 14, "8a826f")
indice:SetPoint("LEFT", 12, 0)
indice:SetText("Chercher…")

-- Tri de la liste, en haut : par niveau, classe, nom ou statut (petits boutons).
local Rafraichir
local boutonsTri = {}
local LARGEUR_TRI = (LARGEUR_LISTE - 3 * 4) / 4
local TRIS = { { "niveau", "Niveau" }, { "classe", "Classe" }, { "nom", "Nom" }, { "statut", "Statut" } }
for i, tri in ipairs(TRIS) do
  local bouton = UI.BoutonSombre(page, tri[2])
  bouton.texte:SetFont(UI.TEXTE, 11 * UI.ZOOM, "")
  bouton:SetSize(LARGEUR_TRI, 24)
  bouton:SetPoint("TOPLEFT", (i - 1) * (LARGEUR_TRI + 4), 0)
  bouton:SetScript("OnClick", function()
    UI.Regler("triListe", tri[1])
    if tri[1] == "statut" then
      UI.Regler("voirHorsLigne", true) -- sinon la liste ne montre que les connectés
    end
    Rafraichir()
  end)
  boutonsTri[tri[1]] = bouton
end

-- Case pour afficher aussi les membres déconnectés.
local caseHorsLigne = UI.Case(page)
caseHorsLigne:SetPoint("TOPLEFT", -4, -30)
caseHorsLigne:SetScript("OnClick", function(self)
  UI.Regler("voirHorsLigne", self:GetChecked())
  Rafraichir()
end)
local texteHorsLigne = UI.Texte(page, UI.TEXTE, 13, "c9bfa8")
texteHorsLigne:SetPoint("LEFT", caseHorsLigne, "RIGHT", 2, 0)
texteHorsLigne:SetText("Voir les déconnectés")
-- Titre de la colonne des cases +0, au-dessus de la liste (officiers seulement).
local titreZero = UI.Texte(page, UI.TITRE, 13, "ffd100")
titreZero:SetPoint("RIGHT", page, "TOPLEFT", LARGEUR_LISTE - 6, -43)
titreZero:SetText("+0")

-- Liste des membres, qui défile à la molette si elle est longue.
local HAUT_LISTE = -62
local zoneListe = CreateFrame("Frame", nil, page)
zoneListe:SetPoint("TOPLEFT", 0, HAUT_LISTE)
zoneListe:SetSize(LARGEUR_LISTE, UI.HAUTEUR + HAUT_LISTE - HAUTEUR_RECHERCHE - 10)
local liste = UI.Defilant(zoneListe, LARGEUR_LISTE)

local function NouvelleLigneMembre()
  local ligne = CreateFrame("Button", nil, liste, "BackdropTemplate")
  ligne:SetSize(LARGEUR_LISTE, 44)
  ligne:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  UI.Survol(ligne)
  -- Bulle comme dans la liste de guilde du jeu. La zone n'est affichée que pour un membre connecté.
  ligne:SetScript("OnEnter", function(self)
    local m = self.membre
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.nomMembre, ns.Api.CouleurClasse(m.classe))
    if m.rang then
      GameTooltip:AddLine(m.rang, 1, 0.82, 0)
    end
    GameTooltip:AddLine(ns.Api.NomClasse(m.classe) .. " de niveau " .. (m.niveau or "?"), 1, 1, 1)
    if m.enLigne and m.zone and m.zone ~= "" then
      GameTooltip:AddLine(m.zone, 1, 1, 1)
    end
    if m.note and m.note ~= "" then
      GameTooltip:AddLine(m.note, 1, 0.82, 0, true)
    end
    GameTooltip:Show()
  end)
  ligne:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ligne.pastille = ligne:CreateTexture(nil, "ARTWORK")
  ligne.pastille:SetSize(8, 8)
  ligne.pastille:SetPoint("LEFT", 8, 0)
  ligne.pastille:SetColorTexture(Hex("9bd35a"))
  ligne.nom = UI.Texte(ligne, UI.TEXTE, 12, "e8e0cc")
  ligne.nom:SetPoint("TOPLEFT", 24, -5)
  ligne.info = UI.Texte(ligne, UI.TEXTE, 11, "a89f8a")
  ligne.info:SetPoint("TOPLEFT", ligne.nom, "BOTTOMLEFT", 0, -2)
  -- Case « +0 » (officiers seulement) et petit autocollant +0 (visible par tous).
  ligne.zero = UI.Case(ligne)
  ligne.zero:SetPoint("RIGHT", -2, 0)
  ligne.zero:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("+0 ce soir")
    GameTooltip:AddLine("Cocher pour donner le +0 à ce joueur pour la soirée.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  ligne.zero:SetScript("OnLeave", function() GameTooltip:Hide() end)
  ligne.autocollant = ligne:CreateTexture(nil, "OVERLAY")
  ligne.autocollant:SetSize(30, 30)
  ligne.autocollant:SetTexture(AUTOCOLLANT)
  return ligne
end

-- Fiche du membre.
local fiche = UI.Carte(page, "1a140d", "6e5230")
fiche:SetPoint("TOPLEFT", LARGEUR_LISTE + 14, 0)
fiche:SetPoint("BOTTOMRIGHT")
local LARGEUR_FICHE = UI.LARGEUR - LARGEUR_LISTE - 14

local avatar = CreateFrame("Frame", nil, fiche, "BackdropTemplate")
avatar:SetSize(44, 44)
avatar:SetPoint("TOPLEFT", 14, -14)
local iconeClasse = avatar:CreateTexture(nil, "ARTWORK")
iconeClasse:SetPoint("TOPLEFT", 2, -2)
iconeClasse:SetPoint("BOTTOMRIGHT", -2, 2)

local nomFiche = UI.Texte(fiche, UI.TITRE, 22, "e8e0cc")
nomFiche:SetPoint("TOPLEFT", avatar, "TOPRIGHT", 12, 2)
local puceIlvl = UI.Puce(fiche, "", "2a2316", "e8e0cc")
puceIlvl:SetPoint("LEFT", nomFiche, "RIGHT", 8, 0)
local identite = UI.Texte(fiche, UI.TEXTE, 14, "e8e0cc")
identite:SetPoint("TOPLEFT", nomFiche, "BOTTOMLEFT", 0, -4)
local resume = UI.TexteCourt(fiche, 12, "a89f8a", 380)
resume:SetPoint("TOPLEFT", identite, "BOTTOMLEFT", 0, -3)
resume:SetPoint("RIGHT", fiche, "RIGHT", -14, 0) -- toute la largeur de la fiche
-- Date de la dernière synchro de l'équipement, en bas à droite de la fiche.
local synchro = UI.Texte(fiche, UI.TEXTE, 12, "a89f8a")
synchro:SetPoint("BOTTOMRIGHT", -14, 12)

synchro:SetJustifyH("RIGHT")

-- Autocollant « +0 » dans le coin en haut à droite de la fiche, sans déborder, quand le joueur a un +0.
local autocollant = CreateFrame("Frame", nil, fiche)
autocollant:SetSize(84, 84)
-- Placé par son centre (pour l'animation) : coin haut droit de la fiche, sans déborder.
local CENTRE_X, CENTRE_Y = -50, -48
autocollant:SetPoint("CENTER", fiche, "TOPRIGHT", CENTRE_X, CENTRE_Y)
autocollant:SetFrameLevel(fiche:GetFrameLevel() + 20)
-- Grand autocollant qui s'envole quand un officier coche le +0 d'un joueur dans la liste.
local envol = CreateFrame("Frame", nil, page)
envol:SetSize(84, 84)
envol:SetFrameStrata("DIALOG")
envol:Hide()
local imageEnvol = envol:CreateTexture(nil, "OVERLAY")
imageEnvol:SetAllPoints()
imageEnvol:SetTexture(AUTOCOLLANT)

local imageAutocollant = autocollant:CreateTexture(nil, "OVERLAY")
imageAutocollant:SetAllPoints()
imageAutocollant:SetTexture(AUTOCOLLANT)
autocollant:EnableMouse(true)
autocollant:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("+0 ce soir")
  GameTooltip:AddLine("Donné par les officiers : prioritaire sur un seul loot de la soirée.", 1, 1, 1, true)
  GameTooltip:Show()
end)
autocollant:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Emplacements d'équipement : { clé, libellé, image de l'emplacement vide dans le jeu }.
local GAUCHE = {
  { "tete", "Tête", "Head" }, { "cou", "Cou", "Neck" }, { "epaules", "Épaules", "Shoulder" },
  { "dos", "Dos", "Chest" }, { "torse", "Torse", "Chest" }, { "chemise", "Chemise", "Shirt" },
  { "tabard", "Tabard", "Tabard" }, { "poignets", "Poignets", "Wrists" },
}
local DROITE = {
  { "mains", "Mains", "Hands" }, { "taille", "Taille", "Waist" }, { "jambes", "Jambes", "Legs" },
  { "pieds", "Pieds", "Feet" }, { "doigt1", "Doigt", "Finger" }, { "doigt2", "Doigt", "Finger" },
  { "bijou1", "Bijou", "Trinket" }, { "bijou2", "Bijou", "Trinket" },
}
local ARMES = {
  { "arme", "Arme", "MainHand" }, { "mainGauche", "Main gauche", "SecondaryHand" }, { "relique", "Relique", "Relic" },
}

local ICONE = 56 -- taille d'une icône d'équipement, comme dans la fiche de personnage du jeu
local PAS = 58 -- d'une icône à la suivante
local HAUT_ICONES = -90 -- haut des colonnes d'icônes, sous l'en-tête de la fiche

-- Fond de la fiche de personnage du jeu (selon la race), en quatre morceaux, sous l'en-tête.
-- Fond sombre uni si la race du joueur n'est pas connue.
local LARGEUR_GAUCHE, HAUTEUR_HAUT = 256 / 318, 255 / 383 -- part des morceaux 1 et 3 dans l'image
local morceaux = {}
for i = 1, 4 do
  morceaux[i] = fiche:CreateTexture(nil, "BORDER")
end
morceaux[2]:SetTexCoord(0, 62 / 64, 0, 1)
morceaux[4]:SetTexCoord(0, 62 / 64, 0, 1)
local LARGEUR_FOND, HAUTEUR_FOND = LARGEUR_FICHE - 6, UI.HAUTEUR - 87
local gaucheFond, hautFond = LARGEUR_FOND * LARGEUR_GAUCHE, HAUTEUR_FOND * HAUTEUR_HAUT
morceaux[1]:SetPoint("TOPLEFT", 3, -84)
morceaux[1]:SetSize(gaucheFond, hautFond)
morceaux[2]:SetPoint("TOPRIGHT", -3, -84)
morceaux[2]:SetSize(LARGEUR_FOND - gaucheFond, hautFond)
morceaux[3]:SetPoint("BOTTOMLEFT", 3, 3)
morceaux[3]:SetSize(gaucheFond, HAUTEUR_FOND - hautFond)
morceaux[4]:SetPoint("BOTTOMRIGHT", -3, 3)
morceaux[4]:SetSize(LARGEUR_FOND - gaucheFond, HAUTEUR_FOND - hautFond)
local voile = fiche:CreateTexture(nil, "ARTWORK") -- assombrit l'image, comme dans le jeu
voile:SetPoint("TOPLEFT", 3, -84)
voile:SetPoint("BOTTOMRIGHT", -3, 3)
voile:SetColorTexture(0, 0, 0, 0.45)

local function RemplirFond(image)
  voile:SetShown(image ~= nil)
  for i = 1, 4 do
    morceaux[i]:SetShown(image ~= nil)
    morceaux[i]:SetTexture(image and image .. i or nil)
  end
end

-- Un emplacement : icône de l'objet (bordure de la couleur de sa qualité), avec son niveau
-- d'objet dans le coin. Le survol de l'icône affiche le détail.
local function NouvelEmplacement()
  local e = CreateFrame("Frame", nil, fiche, "BackdropTemplate")
  e:SetSize(ICONE, ICONE)
  e.image = e:CreateTexture(nil, "ARTWORK")
  e.image:SetPoint("TOPLEFT", 2, -2)
  e.image:SetPoint("BOTTOMRIGHT", -2, 2)
  e.ilvl = UI.Texte(e, UI.TEXTE, 12, "ffffff")
  e.ilvl:SetPoint("BOTTOMRIGHT", -4, 3)
  e:EnableMouse(true)
  e:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local o = self.objet
    if o and o.lien then -- objet réel (le mien ou celui reçu d'un membre) : la bulle du jeu
      GameTooltip:SetHyperlink(o.lien)
      GameTooltip:Show()
      return
    end
    if o then
      GameTooltip:SetText(o.nom, Hex(UI.QUALITES[o.qualite][1]))
      GameTooltip:AddLine(self.libelle, 1, 1, 1)
      GameTooltip:AddLine("Niveau d'objet " .. o.ilvl, 1, 0.82, 0)
      GameTooltip:AddLine(o.stat, 1, 1, 1, true)
      if o.enchant then
        GameTooltip:AddLine("Enchanté : " .. o.enchant, 0.12, 1, 0)
      end
    else
      GameTooltip:SetText(self.libelle)
      GameTooltip:AddLine("Vide", 0.54, 0.51, 0.44)
    end
    GameTooltip:Show()
  end)
  e:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return e
end

local function RemplirEmplacement(e, s, objet)
  e.objet, e.libelle = objet, s[2]
  if objet then
    UI.Habiller(e, "100e0a", UI.QUALITES[objet.qualite][1], 2)
    local icone = objet.icone or (objet.lien and ns.Api.IconeObjet(objet.lien))
    e.image:SetTexture(type(icone) == "number" and icone
      or "Interface\\Icons\\" .. (icone or "INV_Misc_QuestionMark"))
    e.image:SetDesaturated(false)
    e.ilvl:SetText(objet.ilvl)
  else
    UI.Habiller(e, "100e0a", "6e5230", 2)
    e.image:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. s[3])
    e.image:SetDesaturated(true)
    e.ilvl:SetText("")
  end
end

local emplacements = {} -- [clé] = { cadre, emplacement }
for i, s in ipairs(GAUCHE) do
  local e = NouvelEmplacement()
  e:SetPoint("TOPLEFT", 14, HAUT_ICONES - (i - 1) * PAS)
  emplacements[s[1]] = { e, s }
end
for i, s in ipairs(DROITE) do
  local e = NouvelEmplacement()
  e:SetPoint("TOPRIGHT", -14, HAUT_ICONES - (i - 1) * PAS)
  emplacements[s[1]] = { e, s }
end
-- Armes en bas, centrées et collées comme dans le jeu.
for i, s in ipairs(ARMES) do
  local e = NouvelEmplacement()
  e:SetPoint("TOP", fiche, "TOPLEFT", LARGEUR_FICHE / 2 + (i - 2) * (ICONE + 4), HAUT_ICONES + 4 - 8 * PAS + 8)
  emplacements[s[1]] = { e, s }
end

-- Au centre, le modèle 3D du personnage (glisser pour le tourner), quand le jeu peut l'afficher ;
-- sinon un texte à sa place.
local MARGE_CENTRE = 14 + ICONE + 8
local modele = UI.Paragraphe(fiche, 12, "a89f8a", 170, "Modèle 3D du personnage quand il est à portée d'inspection")
modele:SetJustifyH("CENTER")
modele:SetPoint("CENTER", fiche, "TOPLEFT", LARGEUR_FICHE / 2, HAUT_ICONES - 4 * PAS)
local modele3D = CreateFrame("PlayerModel", nil, fiche)
modele3D:SetPoint("TOPLEFT", MARGE_CENTRE, HAUT_ICONES)
modele3D:SetPoint("BOTTOMRIGHT", fiche, "TOPRIGHT", -MARGE_CENTRE, HAUT_ICONES - 8 * PAS + 8)
modele3D:EnableMouse(true)
modele3D:SetScript("OnMouseDown", function(self) self.x = GetCursorPosition() end)
modele3D:SetScript("OnMouseUp", function(self) self.x = nil end)
modele3D:SetScript("OnUpdate", function(self)
  if self.x then
    local x = GetCursorPosition()
    self:SetFacing(self:GetFacing() + (x - self.x) / 100)
    self.x = x
  end
end)

local lignes = {}

function Rafraichir()
  local membres = UI.Membres()
  local filtre = recherche:GetText():lower()
  indice:SetShown(filtre == "")
  local voirHorsLigne = UI.Reglage("voirHorsLigne", false)
  caseHorsLigne:SetChecked(voirHorsLigne)
  local tri = UI.Reglage("triListe", "nom")
  for cle, bouton in pairs(boutonsTri) do
    UI.Habiller(bouton, "241f17", cle == tri and UI.ACCENT or "6e5230")
    bouton.texte:SetTextColor(Hex(cle == tri and UI.ACCENT or "e8e0cc"))
  end

  local noms = {}
  for nom, m in pairs(membres) do
    if (voirHorsLigne or m.enLigne) and (filtre == "" or nom:lower():find(filtre, 1, true)) then
      table.insert(noms, nom)
    end
  end
  -- Par classe : ordre alphabétique des classes.
  -- Par statut : les connectés d'abord. Par niveau : du plus haut au plus bas.
  -- Puis par nom à égalité.
  table.sort(noms, function(a, b)
    local ma, mb = membres[a], membres[b]
    if tri == "niveau" and ma.niveau ~= mb.niveau then
      return (ma.niveau or 0) > (mb.niveau or 0)
    end
    if tri == "statut" and not ma.enLigne ~= not mb.enLigne then
      return ma.enLigne
    end
    local ca, cb = ns.Api.NomClasse(ma.classe), ns.Api.NomClasse(mb.classe)
    if tri == "classe" and ca ~= cb then
      return ca < cb
    end
    return a < b
  end)
  if not membres[UI.membreChoisi] then
    UI.membreChoisi = membres[UI.Moi()] and UI.Moi() or noms[1]
  end

  for _, ligne in ipairs(lignes) do
    ligne:Hide()
  end
  local officier = UI.Droits().officier
  titreZero:SetShown(officier)
  for i, nom in ipairs(noms) do
    lignes[i] = lignes[i] or NouvelleLigneMembre()
    local ligne, m = lignes[i], membres[nom]
    ligne.nomMembre, ligne.membre = nom, m
    ligne:SetPoint("TOPLEFT", 0, -(i - 1) * 46)
    ligne.pastille:SetShown(m.enLigne == true)
    -- À droite de la ligne : [autocollant +0] [case +0 des officiers].
    local zero = UI.AZero(nom)
    ligne.zero:SetShown(officier)
    ligne.zero:SetChecked(zero)
    ligne.zero:SetScript("OnClick", function(self)
      UI.MettreZero(nom, self:GetChecked())
      if self:GetChecked() then
        UI.AnimerAutocollant(envol, self, "CENTER", -50, 0, true)
      end
      Rafraichir()
    end)
    local droite = officier and -32 or -6
    ligne.autocollant:SetShown(zero)
    ligne.autocollant:ClearAllPoints()
    ligne.autocollant:SetPoint("RIGHT", droite, 0)
    -- Nom en couleur de classe (en gris si déconnecté), suivi du niveau en gris.
    ligne.nom:SetText(nom .. (m.niveau and (" |cffa89f8a" .. m.niveau .. "|r") or ""))
    if m.enLigne then
      ligne.nom:SetTextColor(ns.Api.CouleurClasse(m.classe))
    else
      ligne.nom:SetTextColor(Hex("8a826f"))
    end
    -- Classe et grade.
    ligne.info:SetText(ns.Api.NomClasse(m.classe) .. " · " .. (m.rang or "?"))
    local choisi = nom == UI.membreChoisi
    UI.Habiller(ligne, choisi and "2a2316" or "13110d", choisi and UI.ACCENT or "13110d")
    ligne:SetScript("OnClick", function(_, bouton)
      if bouton == "RightButton" then
        ns.Api.MenuJoueur(nom, m.guid) -- clic droit : menu du jeu
        return
      end
      UI.membreChoisi = nom
      Rafraichir()
    end)
    ligne:Show()
  end
  liste:SetHeight(#noms * 46)

  local nom = UI.membreChoisi
  local m = membres[nom]
  fiche:SetShown(m ~= nil)
  if not m then
    return
  end
  -- Autocollant +0 : animé seulement la première fois qu'on ouvre cette fiche pour ce +0.
  local zero = UI.AZero(nom)
  autocollant:SetShown(zero)
  if zero and not UI.ZeroVu(nom) then
    UI.MarquerZeroVu(nom)
    UI.AnimerAutocollant(autocollant, fiche, "TOPRIGHT", CENTRE_X, CENTRE_Y)
  end
  local couleur = UI.HexClasse(m.classe)
  UI.Habiller(avatar, "2a1c0e", couleur, 2)
  iconeClasse:SetTexture(ns.Api.IconeClasse(m.classe))
  nomFiche:SetText(nom)
  nomFiche:SetTextColor(Hex(couleur))
  puceIlvl:SetShown(m.ilvl ~= nil)
  UI.EcrirePuce(puceIlvl, "ilvl moyen " .. (m.ilvl or ""))
  identite:SetText(string.format("Niveau %s %s|cff%s%s|r · %s · %s",
    m.niveau or "?", m.race and (m.race .. " ") or "", couleur, ns.Api.NomClasse(m.classe),
    m.rang or "Hors guilde", m.enLigne and "|cff9bd35aen ligne|r" or "hors ligne"))

  local parties = {}
  for _, metier in ipairs(m.metiers or {}) do
    table.insert(parties, metier.nom .. " " .. metier.niveau)
  end
  if m.rerolls then
    table.insert(parties, "rerolls : " .. m.rerolls)
  end
  resume:SetText(#parties > 0 and table.concat(parties, " · ") or "Aucun métier reçu")
  -- Ma propre fiche se lit directement dans le jeu.
  local monEquipement = not ns.demo and nom == UI.Moi() and ns.Api.LireEquipement()
  synchro:SetText(monEquipement and "" or m.synchro and ("Équipement synchronisé " .. m.synchro) or "Équipement pas encore reçu")

  -- En démo, la fiche de « toi » (Fendrel) montre ton propre personnage.
  local unite = nom == UI.Moi() and "player" or ns.Api.UniteVisible(nom)
  modele3D:SetShown(unite ~= nil)
  modele:SetShown(unite == nil)
  RemplirFond(ns.Api.FondRace(unite))
  if unite then
    modele3D:SetUnit(unite)
  end

  local equipement = monEquipement or m.equipement or {}
  for cle, e in pairs(emplacements) do
    RemplirEmplacement(e[1], e[2], equipement[cle])
  end
end

recherche:SetScript("OnTextChanged", Rafraichir)
UI.rafraichir.membres = Rafraichir
