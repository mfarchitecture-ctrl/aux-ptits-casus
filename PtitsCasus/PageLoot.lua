-- Page Loot en cours (vue complète du maître du butin) : file des objets du boss,
-- objet en cours, annonces lues dans le chat par palier, chat de raid, +0 de la soirée,
-- loots de la soirée et boutons d'attribution.
-- Pour l'instant, seules les données de démo l'alimentent (/pc test).
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local page = UI.pages.loot

local L = UI.LARGEUR
local LARGEUR_COTE = 300
local LARGEUR_ANNONCES = L - LARGEUR_COTE - 16
local PAR_RANGEE = 5 -- objets par rangée de la file (deux rangées : 10 objets visibles)
local LARGEUR_CASE = (L - (PAR_RANGEE - 1) * 8) / PAR_RANGEE
local HAUT_ZONE = -190 -- haut des annonces et de la colonne de droite
local HAUTEUR_BARRE = 46 -- barre des boutons, en bas
local HAUTEUR_ZONE = UI.HAUTEUR + HAUT_ZONE - 12 - HAUTEUR_BARRE - 12

local vide = UI.Texte(page, UI.TEXTE, 14, "a89f8a")
vide:SetPoint("TOPLEFT")
vide:SetText("Aucun loot en cours. La page se remplira quand un boss sera looté.")

local zone = CreateFrame("Frame", nil, page)
zone:SetAllPoints()

-- En haut : le boss, puis la file de ses objets sur deux rangées. Clic sur un objet : on l'affiche.
local titreBoss = UI.Texte(zone, UI.TITRE, 15, "ffd100")
titreBoss:SetPoint("TOPLEFT")
local casesFile = {}
local objetChoisi -- numéro de l'objet affiché (par défaut, celui en cours)
local Rafraichir

local function NouvelleCaseFile()
  local case = CreateFrame("Button", nil, zone, "BackdropTemplate")
  case:SetSize(LARGEUR_CASE, 36)
  UI.Survol(case)
  case.icone = CreateFrame("Frame", nil, case, "BackdropTemplate")
  case.icone:SetSize(20, 20)
  case.icone:SetPoint("LEFT", 8, 0)
  case.nom = UI.TexteCourt(case, 12, "e8e0cc", LARGEUR_CASE - 44)
  case.nom:SetPoint("TOPLEFT", case.icone, "TOPRIGHT", 7, 3)
  case.etat = UI.Texte(case, UI.TEXTE, 10, "a89f8a")
  case.etat:SetPoint("TOPLEFT", case.nom, "BOTTOMLEFT", 0, -1)
  return case
end

-- Bandeau de l'objet affiché.
local enCours = UI.Carte(zone, "1e1a13", "6e5230")
enCours:SetPoint("TOPLEFT", 0, -114)
enCours:SetPoint("TOPRIGHT", 0, -114)
enCours:SetHeight(64)
local grandeIcone = CreateFrame("Frame", nil, enCours, "BackdropTemplate")
grandeIcone:SetSize(44, 44)
grandeIcone:SetPoint("LEFT", 12, 0)
local grandeLettre = UI.Texte(grandeIcone, UI.TITRE, 20, "e8e0cc")
grandeLettre:SetPoint("CENTER")
local nomObjet = UI.Texte(enCours, UI.TEXTE, 17, "e8e0cc")
nomObjet:SetPoint("TOPLEFT", grandeIcone, "TOPRIGHT", 14, -2)
local infoObjet = UI.Texte(enCours, UI.TEXTE, 13, "a89f8a")
infoObjet:SetPoint("TOPLEFT", nomObjet, "BOTTOMLEFT", 0, -4)
local puceEtat = UI.Puce(enCours, "", "2f3a1c", "b9e07a")
puceEtat:SetPoint("TOPRIGHT", -12, -8)
-- Petite fenêtre de loot (FenetresLoot.lua) : celle du maître du butin pour les officiers,
-- celle du joueur pour les autres.
local fenetreReduite = UI.BoutonSombre(enCours, "Fenêtre réduite")
fenetreReduite:SetHeight(24)
fenetreReduite:SetPoint("BOTTOMRIGHT", -12, 8)
fenetreReduite:SetScript("OnClick", function() UI.BasculerLoot() end)
local pasAnnonce = UI.Texte(zone, UI.TEXTE, 14, "a89f8a")
pasAnnonce:SetPoint("TOPLEFT", 0, HAUT_ZONE - 34)
pasAnnonce:SetText("Pas encore annoncé : aucune annonce lue pour cet objet.")

-- Annonces lues dans le chat, rangées par palier.
local titreAnnonces = UI.Texte(zone, UI.TITRE, 16, "ffd100")
titreAnnonces:SetPoint("TOPLEFT", 0, HAUT_ZONE)
titreAnnonces:SetText("Annonces lues dans le chat")
local ordre = UI.Texte(zone, UI.TEXTE, 12, "a89f8a")
ordre:SetPoint("BOTTOMLEFT", titreAnnonces, "BOTTOMRIGHT", 10, 1)
ordre:SetText("Ordre : +0, +1, +1 DL, +2 · égalité au /rand")

local cartesPaliers = {}

local function NouvelleLigneAnnonce(carte)
  local ligne = CreateFrame("Frame", nil, carte, "BackdropTemplate")
  ligne:SetHeight(28)
  ligne.nom = UI.Texte(ligne, UI.TEXTE, 15, "e8e0cc")
  ligne.nom:SetPoint("LEFT", 8, 0)
  ligne.classe = UI.Texte(ligne, UI.TEXTE, 12, "a89f8a")
  ligne.classe:SetPoint("LEFT", 124, 0)
  ligne.pu = UI.Puce(ligne, "PU", "3a2a14", "f0c674")
  ligne.pu:SetPoint("LEFT", 210, 0)
  ligne.note = UI.Texte(ligne, UI.TEXTE, 13, "c9bfa8")
  ligne.rand = UI.Texte(ligne, UI.TEXTE, 14, "e8e0cc")
  ligne.rand:SetPoint("RIGHT", -8, 0)
  ligne.gagnant = UI.Puce(ligne, "Gagnant", "ffd100", "1a1209")
  ligne.gagnant:SetPoint("RIGHT", -56, 0)
  return ligne
end

local function NouvelleCartePalier()
  local carte = UI.Carte(zone)
  carte:SetWidth(LARGEUR_ANNONCES)
  carte.palier = UI.Texte(carte, UI.TITRE, 15, "e8e0cc")
  carte.palier:SetPoint("TOPLEFT", 12, -8)
  carte.sous = UI.Texte(carte, UI.TEXTE, 12, "a89f8a")
  carte.sous:SetPoint("TOPLEFT", 80, -10)
  carte.lignes = {}
  return carte
end

-- Colonne de droite : chat de raid, +0 de la soirée, loots de la soirée.
local function TitreCarte(carte, texte)
  local fs = UI.Texte(carte, UI.TITRE, 14, "ffd100")
  fs:SetPoint("TOPLEFT", 12, -12)
  fs:SetText(texte)
  return fs
end

-- Les hauteurs des trois cartes s'ajustent à chaque affichage : les +0 et les loots de la
-- soirée prennent la place dont ils ont besoin, le chat prend le reste.
local chat = UI.Carte(zone, "100e0a", "4a3820")
chat:SetPoint("TOPRIGHT", 0, HAUT_ZONE)
chat:SetWidth(LARGEUR_COTE)
chat:SetClipsChildren(true)
TitreCarte(chat, "Chat de raid")
local lignesChat = {}

local zero = UI.Carte(zone)
zero:SetPoint("TOPRIGHT", chat, "BOTTOMRIGHT", 0, -12)
zero:SetWidth(LARGEUR_COTE)
TitreCarte(zero, "+0 de la soirée")
local reserve = UI.Texte(zero, UI.TEXTE, 11, "a89f8a")
reserve:SetPoint("TOPRIGHT", -12, -14)
reserve:SetText("Officiers")
-- Les noms des joueurs qui ont un +0, à la suite ; ils se posent et s'enlèvent sur la page Membres.
local nomsZero = UI.Paragraphe(zero, 13, "e8e0cc", LARGEUR_COTE - 24, "")
nomsZero:SetPoint("TOPLEFT", 12, -38)
local noteZero = UI.Paragraphe(zero, 12, "a89f8a", LARGEUR_COTE - 24, "")
noteZero:SetPoint("TOPLEFT", nomsZero, "BOTTOMLEFT", 0, -6)

local soiree = UI.Carte(zone)
soiree:SetPoint("TOPRIGHT", zero, "BOTTOMRIGHT", 0, -12)
soiree:SetWidth(LARGEUR_COTE)
TitreCarte(soiree, "Loots de la soirée")
local lignesSoiree = {}

-- Barre du bas : boutons du maître du butin et explication du résultat.
local trait = zone:CreateTexture(nil, "ARTWORK")
trait:SetPoint("BOTTOMLEFT", 0, HAUTEUR_BARRE)
trait:SetPoint("BOTTOMRIGHT", 0, HAUTEUR_BARRE)
trait:SetHeight(1)
trait:SetColorTexture(Hex("4a3820"))
local attribuer = UI.BoutonRouge(zone, "Attribuer à ...")
attribuer:SetPoint("BOTTOMLEFT", 0, 0)
local relancer = UI.BoutonRouge(zone, "Relancer les /rand")
relancer:SetPoint("LEFT", attribuer, "RIGHT", 10, 0)
local clore = UI.BoutonRouge(zone, "Clore sans attribuer")
clore:SetPoint("LEFT", relancer, "RIGHT", 10, 0)
local suivant = UI.BoutonRouge(zone, "Objet suivant »")
suivant:SetPoint("LEFT", clore, "RIGHT", 10, 0)
local raison = UI.Texte(zone, UI.TEXTE, 13, "a89f8a")
raison:SetPoint("BOTTOMRIGHT", 0, 0)
raison:SetPoint("TOPLEFT", suivant, "TOPRIGHT", 14, 0)
raison:SetJustifyH("RIGHT")
raison:SetWordWrap(true)

-- Texte coloré en couleur de classe, à partir du nom d'un membre.
local function NomColore(membres, nom)
  local m = membres[nom] or {}
  return "|cff" .. UI.HexClasse(m.classe) .. nom .. "|r"
end

function Rafraichir()
  local loot = UI.Loot()
  vide:SetShown(not loot)
  zone:SetShown(loot ~= nil)
  if not loot then
    return
  end
  local membres = UI.Membres()

  -- Ce qui dépend du grade : la carte des +0 (officiers) et les boutons d'attribution
  -- (maître du butin).
  local droits = UI.Droits()
  zero:SetShown(droits.officier)
  soiree:ClearAllPoints()
  soiree:SetPoint("TOPRIGHT", droits.officier and zero or chat, "BOTTOMRIGHT", 0, -12)

  -- File des objets, sur deux rangées.
  titreBoss:SetText(loot.boss .. " · " .. #loot.file .. " objets")
  for i, objet in ipairs(loot.file) do
    if objet.enCours and not loot.file[objetChoisi or 0] then
      objetChoisi = i
    end
  end
  for _, case in ipairs(casesFile) do
    case:Hide()
  end
  for i, objet in ipairs(loot.file) do
    if i > 2 * PAR_RANGEE then
      break -- au-delà de 10 objets, les suivants n'ont pas de place
    end
    casesFile[i] = casesFile[i] or NouvelleCaseFile()
    local case = casesFile[i]
    local couleur, fond = unpack(UI.QUALITES[objet.qualite])
    local colonne, rangee = (i - 1) % PAR_RANGEE, math.floor((i - 1) / PAR_RANGEE)
    case:SetPoint("TOPLEFT", colonne * (LARGEUR_CASE + 8), -28 - rangee * 42)
    local choisi = i == objetChoisi
    UI.Habiller(case, choisi and "2a2316" or "1b1711", choisi and UI.ACCENT or "4a3820")
    case:SetAlpha(objet.fini and 0.7 or 1)
    UI.Habiller(case.icone, fond, couleur, 2)
    case.nom:SetText(objet.nom)
    case.nom:SetTextColor(Hex(couleur))
    case.etat:SetText(objet.etat)
    case.etat:SetTextColor(Hex(objet.enCours and "b9e07a" or "a89f8a"))
    case:SetScript("OnClick", function()
      objetChoisi = i
      Rafraichir()
    end)
    case:Show()
  end

  -- Objet affiché : son bandeau et son état.
  local objet = loot.file[objetChoisi]
  local couleur, fond = unpack(UI.QUALITES[objet.qualite])
  UI.Habiller(grandeIcone, fond, couleur, 2)
  grandeLettre:SetText(objet.nom:sub(1, 1))
  grandeLettre:SetTextColor(Hex(couleur))
  nomObjet:SetText("[" .. objet.nom .. "]")
  nomObjet:SetTextColor(Hex(couleur))
  infoObjet:SetText(string.format("Objet %d sur %d · %s · %s · %s",
    objetChoisi, #loot.file, loot.instance, loot.boss, objet.emplacement or ""))
  if objet.enCours then
    puceEtat.fond:SetColorTexture(Hex("2f3a1c"))
    puceEtat.texte:SetTextColor(Hex("b9e07a"))
    UI.EcrirePuce(puceEtat, "Annonces ouvertes")
  else
    puceEtat.fond:SetColorTexture(Hex("241f17"))
    puceEtat.texte:SetTextColor(Hex("c9bfa8"))
    UI.EcrirePuce(puceEtat, objet.etat)
  end

  -- Boutons d'attribution : pour le maître du butin, sur l'objet en cours.
  for _, bouton in ipairs({ attribuer, relancer, clore, suivant }) do
    bouton:SetShown(droits.butin and objet.enCours == true)
  end
  raison:SetShown(objet.enCours == true or objet.raison ~= nil)

  -- Paliers et annonces de l'objet affiché.
  local paliers = objet.enCours and loot.paliers or objet.paliers or {}
  pasAnnonce:SetShown(#paliers == 0)
  local y = HAUT_ZONE - 30
  for _, carte in ipairs(cartesPaliers) do
    carte:Hide()
  end
  for i, p in ipairs(paliers) do
    cartesPaliers[i] = cartesPaliers[i] or NouvelleCartePalier()
    local carte = cartesPaliers[i]
    carte:SetPoint("TOPLEFT", 0, y)
    carte.palier:SetText(p.palier)
    carte.palier:SetTextColor(Hex(UI.PALIERS[p.palier][1]))
    carte.sous:SetText(p.sous)
    for _, ligne in ipairs(carte.lignes) do
      ligne:Hide()
    end
    for j, a in ipairs(p.lignes) do
      carte.lignes[j] = carte.lignes[j] or NouvelleLigneAnnonce(carte)
      local ligne, m = carte.lignes[j], membres[a.nom] or {}
      ligne:SetPoint("TOPLEFT", 8, -32 - (j - 1) * 30)
      ligne:SetPoint("TOPRIGHT", -8, -32 - (j - 1) * 30)
      if a.gagnant then
        UI.Habiller(ligne, "2a2316", UI.ACCENT)
      else
        UI.Habiller(ligne, "1b1711", "1b1711")
      end
      ligne.nom:SetText(a.nom)
      ligne.nom:SetTextColor(ns.Api.CouleurClasse(m.classe))
      ligne.classe:SetText(ns.Api.NomClasse(m.classe))
      ligne.pu:SetShown(a.pu == true)
      ligne.note:SetPoint("LEFT", a.pu and 250 or 210, 0)
      ligne.note:SetText(a.note or "")
      ligne.note:SetTextColor(Hex(a.alerte and "f0b44a" or "c9bfa8"))
      ligne.gagnant:SetShown(a.gagnant == true)
      ligne.rand:SetText(a.rand or "")
      ligne:Show()
    end
    local hauteur = 36 + #p.lignes * 30
    carte:SetHeight(hauteur)
    carte:Show()
    y = y - hauteur - 8
  end

  -- Colonne de droite. D'abord les +0 de la soirée : les noms à la suite, posés sur la page Membres.
  local nomsAvecZero, avecZero = {}, {}
  for nom in pairs(membres) do
    if UI.AZero(nom) then
      table.insert(nomsAvecZero, nom)
    end
  end
  table.sort(nomsAvecZero)
  for _, nom in ipairs(nomsAvecZero) do
    local etat = (loot.etatsZero or {})[nom]
    table.insert(avecZero, NomColore(membres, nom) .. (etat and (" |cffa89f8a(" .. etat .. ")|r") or ""))
  end
  nomsZero:SetText(#avecZero > 0 and table.concat(avecZero, ", ") or "|cffa89f8aAucun +0 ce soir.|r")
  noteZero:SetText(#avecZero > 0 and "1 seul loot par joueur. Ils se posent sur la page Membres."
    or "Les +0 se posent sur la page Membres.")
  local hauteurZero = 38 + nomsZero:GetStringHeight() + 6 + noteZero:GetStringHeight() + 12
  zero:SetHeight(hauteurZero)

  -- Puis les loots de la soirée.
  for _, fs in ipairs(lignesSoiree) do
    fs:Hide()
  end
  for i, s in ipairs(loot.soiree) do
    lignesSoiree[i] = lignesSoiree[i] or UI.TexteCourt(soiree, 13, "e8e0cc", LARGEUR_COTE - 24)
    local fs = lignesSoiree[i]
    fs:SetPoint("TOPLEFT", 12, -40 - (i - 1) * 22)
    fs:SetText(string.format("|cff%s[%s]|r » %s |cffa89f8a%s|r",
      UI.QUALITES[s.qualite][1], s.objet, NomColore(membres, s.nom), s.palier))
    fs:Show()
  end
  soiree:SetHeight(40 + #loot.soiree * 22 + 6)

  -- Le chat de raid prend la place qui reste au-dessus.
  local place = HAUTEUR_ZONE - soiree:GetHeight() - 12 - (droits.officier and (hauteurZero + 12) or 0)
  chat:SetHeight(math.max(60, place))

  -- Chat de raid de l'objet affiché : ses derniers messages, du bas vers le haut.
  local messages = objet.enCours and loot.chat or objet.chat or {}
  for _, fs in ipairs(lignesChat) do
    fs:Hide()
  end
  local bas = 10
  for i = #messages, 1, -1 do
    local c = messages[i]
    lignesChat[i] = lignesChat[i] or UI.Paragraphe(chat, 13, "e8e0cc", LARGEUR_COTE - 24, "")
    local fs = lignesChat[i]
    local couleurTexte = c.style == "systeme" and "e6b84a" or c.style == "gris" and "a89f8a" or "e8e0cc"
    local qui = ""
    if c.qui then
      qui = c.style and ("|cffe6b84a" .. c.qui .. "|r") or NomColore(membres, c.qui)
      qui = qui .. " "
    end
    fs:SetText("|cff8a826f" .. c.heure .. "|r " .. qui .. "|cff" .. couleurTexte .. c.texte .. "|r")
    if bas + fs:GetStringHeight() > chat:GetHeight() - 36 then
      break -- plus de place sous le titre
    end
    fs:SetPoint("BOTTOMLEFT", 12, bas)
    bas = bas + fs:GetStringHeight() + 3
    fs:Show()
  end

  -- Barre du bas : l'explication du résultat de l'objet affiché.
  attribuer.texte:SetText("Attribuer à " .. loot.gagnant)
  attribuer:SetWidth(attribuer.texte:GetStringWidth() + 28)
  raison:SetText(objet.enCours and loot.raison or objet.raison or "")
end

UI.rafraichir.loot = Rafraichir
