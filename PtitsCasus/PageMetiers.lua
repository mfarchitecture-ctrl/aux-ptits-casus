-- Page Métiers : en haut, la recherche « Qui peut fabriquer ? » par nom de recette ;
-- dessous, la liste des métiers de la guilde à gauche et le cadre des artisans à droite.
-- Clic sur un artisan : son artisanat (la liste de ses recettes dans ce métier).
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local page = UI.pages.metiers

local Rafraichir

-- Recherche par recette.
local libelleRecherche = UI.Texte(page, UI.TITRE, 15, "ffd100")
libelleRecherche:SetPoint("TOPLEFT", 0, -12)
libelleRecherche:SetText("Qui peut fabriquer ?")
local recherche = CreateFrame("EditBox", nil, page, "BackdropTemplate")
recherche:SetHeight(40)
recherche:SetPoint("TOPLEFT", libelleRecherche, "TOPRIGHT", 12, 12)
recherche:SetPoint("RIGHT")
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
indice:SetText("Nom d'une recette…")

-- Résultats de la recherche, sous le champ (masqués si le champ est vide).
local MAX_RESULTATS = 4
local resultats = UI.Carte(page, "1e1a13", "6e5230")
resultats:SetPoint("TOPLEFT", 0, -50)
resultats:SetPoint("TOPRIGHT", 0, -50)
local lignesResultats = {}
for i = 1, MAX_RESULTATS + 1 do
  lignesResultats[i] = UI.TexteCourt(resultats, 14, "e8e0cc", UI.LARGEUR - 24)
  lignesResultats[i]:SetPoint("TOPLEFT", 12, -10 - (i - 1) * 24)
end

-- Partie basse : métiers et artisans. Elle descend quand des résultats s'affichent.
local bas = CreateFrame("Frame", nil, page)
bas:SetPoint("BOTTOMLEFT")
bas:SetPoint("BOTTOMRIGHT")

local titreListe = UI.Texte(bas, UI.TITRE, 15, "ffd100")
titreListe:SetPoint("TOPLEFT")
titreListe:SetText("Métiers de la guilde")

local cadre = UI.Carte(bas)
cadre:SetPoint("TOPLEFT", 316, 0)
cadre:SetPoint("BOTTOMRIGHT")
local titreMetier = UI.Texte(cadre, UI.TITRE, 16, "ffd100")
titreMetier:SetPoint("TOPLEFT", 12, -12)
local detailMetier = UI.Texte(cadre, UI.TEXTE, 12, "a89f8a")
detailMetier:SetPoint("BOTTOMLEFT", titreMetier, "BOTTOMRIGHT", 10, 1)
local colonnes = CreateFrame("Frame", nil, cadre)
colonnes:SetAllPoints()
local colonneJoueur = UI.Texte(colonnes, UI.TEXTE, 11, "a89f8a")
colonneJoueur:SetPoint("TOPLEFT", 20, -44)
colonneJoueur:SetText("JOUEUR")
local colonneRecettes = UI.Texte(colonnes, UI.TEXTE, 11, "a89f8a")
colonneRecettes:SetPoint("TOPLEFT", cadre, "TOPRIGHT", -262, -44)
colonneRecettes:SetText("RECETTES")
local colonneNiveau = UI.Texte(colonnes, UI.TEXTE, 11, "a89f8a")
colonneNiveau:SetPoint("TOPLEFT", cadre, "TOPRIGHT", -142, -44)
colonneNiveau:SetText("NIVEAU")
local aide = UI.Texte(colonnes, UI.TEXTE, 12, "a89f8a")
aide:SetPoint("BOTTOMLEFT", 20, 12)
aide:SetText("Clic sur un joueur : son artisanat.")

local function NouvelleLigneMetier()
  local ligne = CreateFrame("Button", nil, bas, "BackdropTemplate")
  ligne:SetSize(300, 36)
  UI.Survol(ligne)
  ligne.nom = UI.Texte(ligne, UI.TEXTE, 14, "e8e0cc")
  ligne.nom:SetPoint("LEFT", 12, 0)
  ligne.nombre = UI.Texte(ligne, UI.TEXTE, 13, "c9bfa8")
  ligne.nombre:SetPoint("RIGHT", -12, 0)
  ligne.puce = UI.Puce(ligne, "peu d'artisans", "3a2a14", "f0c674")
  ligne.puce:SetPoint("RIGHT", -44, 0)
  return ligne
end

-- Pastille en ligne, nom couleur de classe, nombre de recettes, niveau et sa jauge.
local function NouvelleLigneArtisan()
  local ligne = CreateFrame("Button", nil, colonnes)
  ligne:SetHeight(40)
  UI.Fond(ligne, "16130e")
  UI.Survol(ligne)
  ligne.pastille = ligne:CreateTexture(nil, "ARTWORK")
  ligne.pastille:SetSize(8, 8)
  ligne.pastille:SetPoint("LEFT", 8, 0)
  ligne.nom = UI.Texte(ligne, UI.TEXTE, 14, "e8e0cc")
  ligne.nom:SetPoint("LEFT", 24, 0)
  ligne.recettes = UI.Texte(ligne, UI.TEXTE, 13, "c9bfa8")
  ligne.recettes:SetPoint("LEFT", ligne, "RIGHT", -250, 0)
  ligne.niveau = UI.Texte(ligne, UI.TEXTE, 13, "c9bfa8")
  ligne.niveau:SetPoint("TOPLEFT", ligne, "TOPRIGHT", -130, -6)
  local barre = ligne:CreateTexture(nil, "ARTWORK")
  barre:SetSize(110, 5)
  barre:SetPoint("BOTTOMLEFT", ligne, "BOTTOMRIGHT", -130, 7)
  barre:SetColorTexture(Hex("4a3820"))
  ligne.jauge = ligne:CreateTexture(nil, "OVERLAY")
  ligne.jauge:SetHeight(5)
  ligne.jauge:SetPoint("LEFT", barre)
  return ligne
end

-- Artisanat d'un joueur : remplace la liste des artisans dans le cadre de droite.
-- Sous le titre, une rangée de boutons ; clic sur une recette : la commander.
local artisanat = CreateFrame("Frame", nil, cadre)
artisanat:SetAllPoints()
artisanat:Hide()
local chuchoter = UI.BoutonSombre(artisanat, "Chuchoter")
chuchoter:SetHeight(28)
chuchoter:SetPoint("TOPLEFT", 12, -46)
local voirFiche = UI.BoutonSombre(artisanat, "Voir sa fiche")
voirFiche:SetHeight(28)
voirFiche:SetPoint("LEFT", chuchoter, "RIGHT", 8, 0)
local retour = UI.BoutonSombre(artisanat, "« Retour")
retour:SetHeight(28)
retour:SetPoint("LEFT", voirFiche, "RIGHT", 8, 0)
local aideRecettes = UI.Texte(artisanat, UI.TEXTE, 12, "a89f8a")
aideRecettes:SetPoint("BOTTOMLEFT", 20, 12)
aideRecettes:SetText("Clic sur une recette : la commander.")
local zoneRecettes = CreateFrame("Frame", nil, artisanat)
zoneRecettes:SetPoint("TOPLEFT", 12, -88)
zoneRecettes:SetPoint("BOTTOMRIGHT", -12, 36)
local LARGEUR_RECETTES = UI.LARGEUR - 316 - 24
local listeRecettes = UI.Defilant(zoneRecettes, LARGEUR_RECETTES)
local lignesRecettes = {}
local artisanChoisi -- nom du joueur dont on regarde l'artisanat

local lignesMetiers, lignesArtisans = {}, {}
local metierChoisi

-- { ["Couture"] = { { nom, niveau, max, classe, enLigne, recettes = { "Sac en étoffe runique", ... } }, ... }, ... }
local function RegrouperParMetier()
  local parMetier = {}
  for nom, membre in pairs(UI.Membres()) do
    for _, m in ipairs(membre.metiers or {}) do
      parMetier[m.nom] = parMetier[m.nom] or {}
      table.insert(parMetier[m.nom], {
        nom = nom, niveau = m.niveau, max = m.max, classe = membre.classe, enLigne = membre.enLigne == true,
        recettes = m.recettes or {},
      })
    end
  end
  return parMetier
end

-- Recettes dont le nom contient le texte cherché : { { recette, artisans = { ... } }, ... }
local function Chercher(parMetier, texte)
  local parRecette = {}
  for _, artisans in pairs(parMetier) do
    for _, a in ipairs(artisans) do
      for _, recette in ipairs(a.recettes) do
        if recette:lower():find(texte, 1, true) then
          parRecette[recette] = parRecette[recette] or {}
          table.insert(parRecette[recette], a)
        end
      end
    end
  end
  local liste = {}
  for recette, artisans in pairs(parRecette) do
    table.insert(liste, { recette = recette, artisans = artisans })
  end
  table.sort(liste, function(a, b) return a.recette < b.recette end)
  return liste
end

-- « Fendrel en ligne · Kéliane » : en ligne d'abord, noms en couleur de classe.
local function ListeArtisans(artisans)
  table.sort(artisans, function(a, b)
    if a.enLigne ~= b.enLigne then
      return a.enLigne
    end
    return a.nom < b.nom
  end)
  local parties = {}
  for _, a in ipairs(artisans) do
    table.insert(parties, "|cff" .. UI.HexClasse(a.classe) .. a.nom .. "|r" .. (a.enLigne and " |cff9bd35aen ligne|r" or ""))
  end
  return table.concat(parties, "  ·  ")
end

local videRecettes = UI.Paragraphe(listeRecettes, 14, "a89f8a", LARGEUR_RECETTES,
  "Recettes pas encore reçues. Elles arrivent quand le joueur ouvre la fenêtre de son métier.")
videRecettes:SetPoint("TOPLEFT")

local function AfficherArtisanat(a)
  titreMetier:SetText(metierChoisi .. " de " .. a.nom)
  titreMetier:SetTextColor(ns.Api.CouleurClasse(a.classe))
  detailMetier:SetText(a.niveau .. " / " .. a.max .. " · " .. #a.recettes .. " recette(s)")
  voirFiche:SetScript("OnClick", function() UI.OuvrirFiche(a.nom) end)
  -- Chuchoter : ouvre seulement « /w Nom » dans le chat ; grisé si le joueur est hors ligne.
  chuchoter:SetEnabled(a.enLigne)
  chuchoter:SetAlpha(a.enLigne and 1 or 0.4)
  chuchoter:SetScript("OnClick", function() ns.Api.OuvrirChuchotement(a.nom) end)
  chuchoter:SetScript("OnEnter", function(self)
    if not a.enLigne then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Hors ligne")
      GameTooltip:Show()
    end
  end)
  chuchoter:SetScript("OnLeave", function() GameTooltip:Hide() end)

  for _, ligne in ipairs(lignesRecettes) do
    ligne:Hide()
  end
  local recettes = {}
  for i, r in ipairs(a.recettes) do
    recettes[i] = r
  end
  table.sort(recettes)
  -- Deux colonnes de recettes, chacune cliquable pour la commander.
  local largeur = (LARGEUR_RECETTES - 12) / 2
  for i, recette in ipairs(recettes) do
    if not lignesRecettes[i] then
      local ligne = CreateFrame("Button", nil, listeRecettes)
      ligne:SetSize(largeur, 24)
      UI.Survol(ligne)
      ligne.texte = UI.TexteCourt(ligne, 14, "e8e0cc", largeur - 8)
      ligne.texte:SetPoint("LEFT", 4, 0)
      lignesRecettes[i] = ligne
    end
    local ligne = lignesRecettes[i]
    local colonne, rang = (i - 1) % 2, math.floor((i - 1) / 2)
    ligne:SetPoint("TOPLEFT", colonne * (largeur + 12), -rang * 26)
    ligne.texte:SetText("|cffffd100•|r " .. recette)
    ligne:SetScript("OnClick", function() UI.OuvrirCommande(a.nom, recette) end)
    ligne:Show()
  end
  videRecettes:SetShown(#recettes == 0)
  listeRecettes:SetHeight(math.max(30, math.ceil(#recettes / 2) * 26))
end

retour:SetScript("OnClick", function()
  artisanChoisi = nil
  Rafraichir()
end)

function Rafraichir()
  local parMetier = RegrouperParMetier()

  -- Recherche par recette.
  local texte = recherche:GetText():lower()
  indice:SetShown(texte == "")
  local hautBas = -50
  resultats:SetShown(texte ~= "")
  if texte ~= "" then
    local trouvees = Chercher(parMetier, texte)
    for _, fs in ipairs(lignesResultats) do
      fs:SetText("")
    end
    local n = math.min(#trouvees, MAX_RESULTATS)
    for i = 1, n do
      lignesResultats[i]:SetText("|cffffd100[" .. trouvees[i].recette .. "]|r  " .. ListeArtisans(trouvees[i].artisans))
    end
    if #trouvees == 0 then
      lignesResultats[1]:SetText("|cffa89f8aPersonne n'a encore partagé cette recette.|r")
      n = 1
    elseif #trouvees > MAX_RESULTATS then
      lignesResultats[n + 1]:SetText("|cffa89f8a… et " .. (#trouvees - MAX_RESULTATS) .. " autre(s) recette(s). Précise ta recherche.|r")
      n = n + 1
    end
    resultats:SetHeight(n * 24 + 14)
    hautBas = -50 - n * 24 - 14 - 12

    -- Pendant une recherche : seulement les métiers et les artisans qui ont une recette trouvée.
    local filtre = {}
    for metier, artisans in pairs(parMetier) do
      for _, a in ipairs(artisans) do
        for _, r in ipairs(a.recettes) do
          if r:lower():find(texte, 1, true) then
            filtre[metier] = filtre[metier] or {}
            table.insert(filtre[metier], a)
            break
          end
        end
      end
    end
    parMetier = filtre
  end
  bas:SetPoint("TOPLEFT", 0, hautBas)
  bas:SetPoint("TOPRIGHT", 0, hautBas)

  -- Liste des métiers.
  local noms = {}
  for nom in pairs(parMetier) do
    table.insert(noms, nom)
  end
  table.sort(noms)
  if not parMetier[metierChoisi] then
    metierChoisi = noms[1]
    artisanChoisi = nil
  end
  for _, ligne in ipairs(lignesMetiers) do
    ligne:Hide()
  end
  for i, nom in ipairs(noms) do
    lignesMetiers[i] = lignesMetiers[i] or NouvelleLigneMetier()
    local ligne = lignesMetiers[i]
    ligne:SetPoint("TOPLEFT", 0, -32 - (i - 1) * 42)
    ligne.nom:SetText(nom)
    ligne.nombre:SetText(#parMetier[nom])
    ligne.puce:SetShown(texte == "" and #parMetier[nom] <= 3)
    -- Métier choisi : fond plus clair et bordure de la couleur d'accent.
    local choisi = nom == metierChoisi
    UI.Habiller(ligne, choisi and "2a2316" or "1b1711", choisi and UI.ACCENT or "1b1711")
    ligne:SetScript("OnClick", function()
      metierChoisi = nom
      artisanChoisi = nil
      Rafraichir()
    end)
    ligne:Show()
  end

  for _, ligne in ipairs(lignesArtisans) do
    ligne:Hide()
  end
  titreMetier:SetTextColor(Hex("ffd100"))
  if not metierChoisi then
    titreMetier:SetText(texte ~= "" and "Aucun artisan pour cette recette." or "Aucun métier reçu pour l'instant.")
    detailMetier:SetText("")
    artisanat:Hide()
    colonnes:Hide()
    return
  end
  local artisans = parMetier[metierChoisi]

  -- Artisanat d'un joueur, s'il a été choisi.
  local choisi
  for _, a in ipairs(artisans) do
    if a.nom == artisanChoisi then
      choisi = a
    end
  end
  artisanat:SetShown(choisi ~= nil)
  colonnes:SetShown(choisi == nil)
  if choisi then
    AfficherArtisanat(choisi)
    return
  end

  -- Artisans du métier : en ligne d'abord, puis du plus haut niveau au plus bas.
  table.sort(artisans, function(a, b)
    if a.enLigne ~= b.enLigne then
      return a.enLigne
    end
    return a.niveau > b.niveau
  end)
  titreMetier:SetText(metierChoisi)
  detailMetier:SetText(#artisans .. " artisan(s) · en ligne d'abord")
  for i, a in ipairs(artisans) do
    lignesArtisans[i] = lignesArtisans[i] or NouvelleLigneArtisan()
    local ligne = lignesArtisans[i]
    ligne:SetPoint("TOPLEFT", 12, -66 - (i - 1) * 46)
    ligne:SetPoint("TOPRIGHT", -12, -66 - (i - 1) * 46)
    ligne.pastille:SetColorTexture(Hex(a.enLigne and "9bd35a" or "5a5244"))
    ligne.nom:SetText(a.nom)
    ligne.nom:SetTextColor(ns.Api.CouleurClasse(a.classe))
    ligne.recettes:SetText(#a.recettes)
    ligne.niveau:SetText(a.niveau .. " / " .. a.max)
    ligne.jauge:SetColorTexture(Hex(UI.ACCENT))
    ligne.jauge:SetWidth(a.max > 0 and math.max(1, 110 * a.niveau / a.max) or 1)
    ligne:SetScript("OnClick", function()
      artisanChoisi = a.nom
      Rafraichir()
    end)
    ligne:Show()
  end
end

recherche:SetScript("OnTextChanged", function() Rafraichir() end)
UI.rafraichir.metiers = Rafraichir
