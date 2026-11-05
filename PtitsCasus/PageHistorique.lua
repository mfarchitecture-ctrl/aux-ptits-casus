-- Page Historique des loots : les soirées de raid avec leurs objets attribués,
-- et à droite l'aide au +0 (soirées sans loot de chaque joueur).
-- Pour l'instant, seules les données de démo l'alimentent (/pc test).
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local page = UI.pages.historique

local LARGEUR_AIDE = 250
local LARGEUR_SOIREES = UI.LARGEUR - LARGEUR_AIDE - 16

local titre = UI.Texte(page, UI.TITRE, 16, "ffd100")
titre:SetPoint("TOPLEFT")
titre:SetText("Historique des loots")

local vide = UI.Texte(page, UI.TEXTE, 14, "a89f8a")
vide:SetPoint("TOPLEFT", 0, -40)
vide:SetText("Aucun loot enregistré pour l'instant.")

-- Soirées, qui défilent à la molette si elles sont nombreuses.
local zoneSoirees = CreateFrame("Frame", nil, page)
zoneSoirees:SetPoint("TOPLEFT", 0, -40)
zoneSoirees:SetSize(LARGEUR_SOIREES, UI.HAUTEUR - 40)
local soirees = UI.Defilant(zoneSoirees, LARGEUR_SOIREES)

-- Position (x) et largeur des colonnes d'une soirée.
local W = LARGEUR_SOIREES
local COLONNES = {
  { "BOSS", 8, 100 },
  { "OBJET", 118, W - 262 - 118 },
  { "GAGNANT", W - 252, 110 },
  { "PALIER", W - 132, 70 },
}

local function NouvelleLigne(carte)
  local ligne = CreateFrame("Frame", nil, carte)
  ligne:SetHeight(28)
  local t = ligne:CreateTexture(nil, "ARTWORK")
  t:SetPoint("TOPLEFT")
  t:SetPoint("TOPRIGHT")
  t:SetHeight(1)
  t:SetColorTexture(Hex("241f17"))
  ligne.boss = UI.TexteCourt(ligne, 13, "c9bfa8", COLONNES[1][3])
  ligne.boss:SetPoint("LEFT", COLONNES[1][2], 0)
  ligne.objet = UI.TexteCourt(ligne, 13, "e8e0cc", COLONNES[2][3])
  ligne.objet:SetPoint("LEFT", COLONNES[2][2], 0)
  ligne.nom = UI.TexteCourt(ligne, 13, "e8e0cc", COLONNES[3][3])
  ligne.nom:SetPoint("LEFT", COLONNES[3][2], 0)
  ligne.palier = UI.Puce(ligne, "", "233019", "b9e07a")
  ligne.palier:SetPoint("LEFT", COLONNES[4][2], 0)
  ligne.rand = UI.Texte(ligne, UI.TEXTE, 13, "c9bfa8")
  ligne.rand:SetPoint("RIGHT", -12, 0)
  return ligne
end

local function NouvelleCarte()
  local carte = UI.Carte(soirees)
  carte:SetWidth(LARGEUR_SOIREES)
  carte.titre = UI.Texte(carte, UI.TEXTE, 14, "e8e0cc")
  carte.titre:SetPoint("TOPLEFT", 12, -12)
  carte.sous = UI.Texte(carte, UI.TEXTE, 12, "a89f8a")
  carte.sous:SetPoint("BOTTOMLEFT", carte.titre, "BOTTOMRIGHT", 10, 0)
  for _, c in ipairs(COLONNES) do
    local fs = UI.Texte(carte, UI.TEXTE, 11, "a89f8a")
    fs:SetPoint("TOPLEFT", c[2], -42)
    fs:SetText(c[1])
  end
  local rand = UI.Texte(carte, UI.TEXTE, 11, "a89f8a")
  rand:SetPoint("TOPRIGHT", -12, -42)
  rand:SetText("RAND")
  carte.lignes = {}
  return carte
end

-- Aide au +0.
local aide = UI.Carte(page, "1e1a13", "6e5230")
aide:SetPoint("TOPRIGHT", 0, -40)
aide:SetSize(LARGEUR_AIDE, UI.HAUTEUR - 40)
local titreAide = UI.Texte(aide, UI.TITRE, 14, "ffd100")
titreAide:SetPoint("TOPLEFT", 12, -12)
titreAide:SetText("Aide au +0")
local sousAide = UI.Paragraphe(aide, 12, "a89f8a", LARGEUR_AIDE - 24, "Soirées sans loot depuis le dernier objet gagné")
sousAide:SetPoint("TOPLEFT", titreAide, "BOTTOMLEFT", 0, -6)
-- Titre de la colonne des cases +0 (officiers seulement).
local titreZero = UI.Texte(aide, UI.TITRE, 13, "ffd100")
titreZero:SetPoint("TOPRIGHT", sousAide, "BOTTOMRIGHT", -2, -6)
titreZero:SetText("+0")
local lignesAide = {}

local cartes = {}

local function Rafraichir()
  local membres = UI.Membres()
  local historique = UI.Historique()
  vide:SetShown(#historique == 0)

  local y = 0
  for _, carte in ipairs(cartes) do
    carte:Hide()
  end
  for i, s in ipairs(historique) do
    cartes[i] = cartes[i] or NouvelleCarte()
    local carte = cartes[i]
    carte:SetPoint("TOPLEFT", 0, y)
    carte.titre:SetText(s.titre)
    -- « 3 objets · 2 boss · en cours », compté à partir des lignes de la soirée.
    local boss, nbBoss = {}, 0
    for _, l in ipairs(s.lignes) do
      if not boss[l.boss] then
        boss[l.boss] = true
        nbBoss = nbBoss + 1
      end
    end
    carte.sous:SetText(#s.lignes .. " objet(s) · " .. nbBoss .. " boss" .. (s.enCours and " · en cours" or ""))
    for _, ligne in ipairs(carte.lignes) do
      ligne:Hide()
    end
    for j, l in ipairs(s.lignes) do
      carte.lignes[j] = carte.lignes[j] or NouvelleLigne(carte)
      local ligne = carte.lignes[j]
      ligne:SetPoint("TOPLEFT", 4, -64 - (j - 1) * 28)
      ligne:SetPoint("TOPRIGHT", -4, -64 - (j - 1) * 28)
      ligne.boss:SetText(l.boss)
      ligne.objet:SetText("[" .. l.objet .. "]")
      ligne.objet:SetTextColor(Hex(UI.QUALITES[l.qualite][1]))
      ligne.nom:SetText(l.nom)
      ligne.nom:SetTextColor(ns.Api.CouleurClasse((membres[l.nom] or {}).classe))
      local _, fond, texte = unpack(UI.PALIERS[l.palier])
      ligne.palier.fond:SetColorTexture(Hex(fond))
      ligne.palier.texte:SetTextColor(Hex(texte))
      UI.EcrirePuce(ligne.palier, l.palier)
      ligne.rand:SetText(l.rand)
      ligne:Show()
    end
    local hauteur = 74 + #s.lignes * 28
    carte:SetHeight(hauteur)
    carte:Show()
    y = y - hauteur - 10
  end
  soirees:SetHeight(-y)

  for _, ligne in ipairs(lignesAide) do
    ligne:Hide()
  end
  -- Les officiers peuvent donner le +0 d'ici : une case au bout de chaque ligne.
  local officier = UI.Droits().officier
  titreZero:SetShown(officier)
  for i, d in ipairs(UI.SansLoot()) do
    if not lignesAide[i] then
      local ligne = CreateFrame("Frame", nil, aide)
      ligne:SetSize(LARGEUR_AIDE - 24, 28)
      ligne.nom = UI.Texte(ligne, UI.TEXTE, 14, "e8e0cc")
      ligne.nom:SetPoint("LEFT")
      ligne.nombre = UI.Texte(ligne, UI.TEXTE, 13, "a89f8a")
      ligne.zero = UI.Case(ligne)
      ligne.zero:SetPoint("RIGHT", 4, 0)
      lignesAide[i] = ligne
    end
    local ligne = lignesAide[i]
    ligne:SetPoint("TOPLEFT", sousAide, "BOTTOMLEFT", 0, -26 - (i - 1) * 28)
    ligne.nom:SetText(d.nom)
    ligne.nom:SetTextColor(ns.Api.CouleurClasse((membres[d.nom] or {}).classe))
    local texte = d.soirees == 0 and "0" or d.soirees == 1 and "1 soirée" or (d.soirees .. " soirées")
    ligne.nombre:SetText(texte)
    ligne.nombre:SetTextColor(Hex(d.soirees >= 2 and "f0c674" or "a89f8a"))
    ligne.nombre:ClearAllPoints()
    ligne.nombre:SetPoint("RIGHT", officier and -30 or 0, 0)
    ligne.zero:SetShown(officier)
    ligne.zero:SetChecked(UI.AZero(d.nom))
    ligne.zero:SetScript("OnClick", function(self) UI.MettreZero(d.nom, self:GetChecked()) end)
    ligne:Show()
  end
end

UI.rafraichir.historique = Rafraichir
