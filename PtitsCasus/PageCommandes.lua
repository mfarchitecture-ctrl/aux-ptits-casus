-- Page Commandes, qui défile à la molette :
-- - en haut, les commandes privées (visibles seulement par toi et l'autre joueur) :
--   reçues à gauche (tu es l'artisan), envoyées à droite ;
-- - en dessous, les commandes de guilde, visibles par tous : n'importe quel artisan peut s'en charger.
-- Et la petite fenêtre « Commander », ouverte depuis l'artisanat d'un joueur (page Métiers)
-- ou par le bouton « Nouvelle commande de guilde ». Les échanges sont dans Commandes.lua.
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local C = ns.Commandes
local contenu = UI.Defilant(UI.pages.commandes)

local L = UI.LARGEUR
local COLONNE = (L - 24) / 2
local HAUTEUR_CARTE = 108

-- Couleurs des états : fond et texte de la puce.
local ETATS = {
  ["Nouvelle"] = { "3a2a14", "f0c674" },
  ["Ouverte"] = { "3a2a14", "f0c674" },
  ["En attente"] = { "241f17", "a89f8a" },
  ["Reçue"] = { "16303a", "8fd3ea" },
  ["Acceptée"] = { "233019", "b9e07a" },
  ["Prise"] = { "233019", "b9e07a" },
  ["Faite"] = { "2a2316", "ffd100" },
  ["Refusée"] = { "2a1715", "f29a8e" },
  ["Annulée"] = { "2a1715", "f29a8e" },
}

local titre = UI.Texte(contenu, UI.TITRE, 22, "ffd100")
titre:SetPoint("TOPLEFT")
titre:SetText("Commandes")
local sous = UI.Paragraphe(contenu, 13, "a89f8a", L,
  "Tes commandes privées, visibles seulement par toi et l'autre joueur. Pour en passer une : page Métiers, "
    .. "recettes d'un artisan, clic sur une recette.")
sous:SetPoint("TOPLEFT", 0, -titre:GetStringHeight() - 6)
local HAUT = -titre:GetStringHeight() - 6 - sous:GetStringHeight() - 18

local entetes = {}
for i, libelle in ipairs({ "Reçues", "Envoyées" }) do
  entetes[i] = UI.Texte(contenu, UI.TITRE, 16, "e8e0cc")
  entetes[i]:SetPoint("TOPLEFT", (i - 1) * (COLONNE + 24), HAUT)
  entetes[i]:SetText(libelle)
end
local vides = {}
for i, libelle in ipairs({ "Aucune commande reçue.", "Aucune commande envoyée." }) do
  vides[i] = UI.Texte(contenu, UI.TEXTE, 13, "8a826f")
  vides[i]:SetPoint("TOPLEFT", (i - 1) * (COLONNE + 24), HAUT - 30)
  vides[i]:SetText(libelle)
end

-- Section des commandes de guilde : titre, explication et bouton (placés à chaque affichage).
local titreGuilde = UI.Texte(contenu, UI.TITRE, 18, "ffd100")
titreGuilde:SetText("Commandes de guilde")
local sousGuilde = UI.Texte(contenu, UI.TEXTE, 12, "a89f8a")
sousGuilde:SetText("Visibles par toute la guilde. N'importe quel artisan peut s'en charger.")
local nouvelle = UI.BoutonRouge(contenu, "Nouvelle commande de guilde")
nouvelle:SetHeight(30)
nouvelle:SetScript("OnClick", function() UI.OuvrirCommande(nil, nil) end)
local videGuilde = UI.Texte(contenu, UI.TEXTE, 13, "8a826f")
videGuilde:SetText("Aucune commande de guilde en cours.")

local cartes = {}

-- Une carte de commande : recette et quantité, joueurs, état, note, puis jusqu'à trois boutons.
local function NouvelleCarte()
  local carte = UI.Carte(contenu)
  carte:SetSize(COLONNE, HAUTEUR_CARTE)
  carte.recette = UI.TexteCourt(carte, 14, "ffd100", COLONNE - 140)
  carte.recette:SetPoint("TOPLEFT", 12, -10)
  carte.etat = UI.Puce(carte, "", "241f17", "a89f8a")
  carte.etat:SetPoint("TOPRIGHT", -10, -8)
  carte.joueur = UI.TexteCourt(carte, 13, "c9bfa8", COLONNE - 24)
  carte.joueur:SetPoint("TOPLEFT", carte.recette, "BOTTOMLEFT", 0, -4)
  carte.note = UI.TexteCourt(carte, 12, "8a826f", COLONNE - 24)
  carte.note:SetPoint("TOPLEFT", carte.joueur, "BOTTOMLEFT", 0, -3)
  carte.boutons = {}
  for j = 1, 3 do
    local b = UI.BoutonSombre(carte, "")
    b:SetSize(120, 26)
    b:SetPoint("BOTTOMLEFT", 12 + (j - 1) * 126, 10)
    carte.boutons[j] = b
  end
  return carte
end

-- Nom en couleur de classe.
local function Nom(membres, nom)
  return "|cff" .. UI.HexClasse((membres[nom] or {}).classe) .. nom .. "|r"
end

-- Bouton « Chuchoter » vers ce joueur, grisé s'il est hors ligne.
local function Chuchoter(nom)
  return { "Chuchoter", function() ns.Api.OuvrirChuchotement(nom) end, not C.EnLigne(nom) }
end

-- Remplit une carte : texte des joueurs, libellé d'état et boutons { libellé, action, grisé }.
local function Remplir(carte, commande, joueurs, etat, actions)
  carte.recette:SetText(commande.quantite .. " × [" .. commande.recette .. "]")
  carte.joueur:SetText(joueurs)
  carte.note:SetText(commande.note ~= "" and ("« " .. commande.note .. " »") or "")
  local couleurs = ETATS[commande.etat] or ETATS["En attente"]
  carte.etat.fond:SetColorTexture(Hex(couleurs[1]))
  carte.etat.texte:SetTextColor(Hex(couleurs[2]))
  UI.EcrirePuce(carte.etat, etat)
  for j, b in ipairs(carte.boutons) do
    local a = actions[j]
    b:SetShown(a ~= nil)
    if a then
      b.texte:SetText(a[1])
      b:SetEnabled(not a[3])
      b:SetAlpha(a[3] and 0.4 or 1)
      b:SetScript("OnClick", function()
        a[2]()
        UI.MajCommandes()
      end)
    end
  end
end

-- Boutons d'une commande privée selon son état.
local function ActionsPrivees(commande, recue, liste, autre)
  local etat = commande.etat
  local actions
  if etat == "Faite" or etat == "Refusée" or etat == "Annulée" then
    actions = { { "Effacer", function() C.Effacer(liste, commande) end } }
  elseif recue and etat == "Nouvelle" then
    actions = { { "Accepter", function() C.Repondre(commande, "Acceptée") end },
      { "Refuser", function() C.Repondre(commande, "Refusée") end } }
  elseif recue then
    actions = { { "Faite", function() C.Repondre(commande, "Faite") end } }
  else
    actions = { { "Annuler", function() C.Annuler(commande) end } }
  end
  table.insert(actions, Chuchoter(autre))
  return actions
end

-- Boutons d'une commande de guilde selon son état et ton rôle (demandeur, preneur, autre).
local function ActionsGuilde(c, moi)
  local actions = {}
  if c.etat == "Ouverte" and c.de == moi then
    table.insert(actions, { "Annuler", function() C.ChangerGuilde(c, "Annulée") end })
  elseif c.etat == "Ouverte" then
    table.insert(actions, { "Je m'en charge", function() C.ChangerGuilde(c, "Prise") end })
  elseif c.etat == "Prise" and (c.de == moi or c.par == moi) then
    table.insert(actions, { "Faite", function() C.ChangerGuilde(c, "Faite") end })
    if c.de == moi then
      table.insert(actions, { "Annuler", function() C.ChangerGuilde(c, "Annulée") end })
    end
  end
  if c.etat ~= "Faite" and c.etat ~= "Annulée" then
    local autre = c.de == moi and c.par or c.de
    if autre and autre ~= moi then
      table.insert(actions, Chuchoter(autre))
    end
  end
  return actions
end

local function Rafraichir()
  local d = C.Donnees()
  local membres = UI.Membres()
  local moi = UI.Moi()
  local n = 0
  local function Carte()
    n = n + 1
    cartes[n] = cartes[n] or NouvelleCarte()
    cartes[n]:ClearAllPoints()
    cartes[n]:Show()
    return cartes[n]
  end
  local PAS = HAUTEUR_CARTE + 10

  -- Commandes privées, sur deux colonnes.
  local y = HAUT - 30
  local bas = y
  for i, info in ipairs({ { d.recues, true }, { d.envoyees, false } }) do
    local liste, recue = info[1], info[2]
    vides[i]:SetShown(#liste == 0)
    for k, commande in ipairs(liste) do
      local carte = Carte()
      carte:SetPoint("TOPLEFT", (i - 1) * (COLONNE + 24), y - (k - 1) * PAS)
      local autre = recue and commande.de or commande.a
      local etat = commande.etat == "En attente" and "En attente (hors ligne)" or commande.etat
      Remplir(carte, commande, (recue and "De " or "Pour ") .. Nom(membres, autre), etat,
        ActionsPrivees(commande, recue, liste, autre))
    end
    bas = math.min(bas, y - math.max(#liste * PAS, 24))
  end

  -- Commandes de guilde, sur deux colonnes aussi.
  y = bas - 26
  titreGuilde:SetPoint("TOPLEFT", 0, y)
  nouvelle:SetPoint("TOPRIGHT", contenu, "TOPLEFT", L, y + 4)
  sousGuilde:SetPoint("TOPLEFT", 0, y - titreGuilde:GetStringHeight() - 4)
  y = y - titreGuilde:GetStringHeight() - 4 - sousGuilde:GetStringHeight() - 14
  local guilde = C.Guilde()
  videGuilde:SetPoint("TOPLEFT", 0, y)
  videGuilde:SetShown(#guilde == 0)
  for k, c in ipairs(guilde) do
    local carte = Carte()
    carte:SetPoint("TOPLEFT", ((k - 1) % 2) * (COLONNE + 24), y - math.floor((k - 1) / 2) * PAS)
    local joueurs = "De " .. Nom(membres, c.de) .. (c.par and (" · prise par " .. Nom(membres, c.par)) or "")
    local etat = c.etat == "Prise" and "En cours" or c.etat
    Remplir(carte, c, joueurs, etat, ActionsGuilde(c, moi))
  end
  y = y - math.max(math.ceil(#guilde / 2) * PAS, 24)

  for k = n + 1, #cartes do
    cartes[k]:Hide()
  end
  contenu:SetHeight(-y + 10)

  -- La page est ouverte : les nouveautés sont vues.
  if d.nonLues > 0 then
    d.nonLues = 0
    UI.MajCommandes()
  end
end

UI.rafraichir.commandes = Rafraichir

------------------------------------------------------------------------
-- Fenêtre « Commander » : à un artisan (recette connue) ou à la guilde (recette à écrire).
------------------------------------------------------------------------
local fenetre = CreateFrame("Frame", "PtitsCasusCommander", UIParent, "ButtonFrameTemplate")
fenetre:SetSize(420, 280)
fenetre:SetPoint("CENTER")
fenetre:SetFrameStrata("DIALOG")
fenetre:EnableMouse(true)
fenetre:Hide()
table.insert(UISpecialFrames, "PtitsCasusCommander")
ButtonFrameTemplate_HidePortrait(fenetre)
ButtonFrameTemplate_HideButtonBar(fenetre)
fenetre.Inset:Hide()

local titreFenetre = CreateFrame("Frame", nil, fenetre) -- repère sous la barre de titre
titreFenetre:SetSize(1, 14)
titreFenetre:SetPoint("TOPLEFT", 16, -26)

-- Champ de saisie sombre bordé de brun.
local function Champ(largeur)
  local champ = CreateFrame("EditBox", nil, fenetre, "BackdropTemplate")
  champ:SetSize(largeur, 32)
  champ:SetAutoFocus(false)
  champ:SetFont(UI.TEXTE, 14 * UI.ZOOM, "")
  champ:SetTextColor(Hex("e8e0cc"))
  champ:SetTextInsets(10, 10, 0, 0)
  UI.Habiller(champ, "100e0a", "6e5230")
  champ:SetScript("OnEscapePressed", champ.ClearFocus)
  UI.Noter("saisie", champ)
  return champ
end

-- La recette : affichée (commande à un artisan) ou à écrire (commande de guilde).
local recetteFenetre = UI.TexteCourt(fenetre, 14, "e8e0cc", 388)
recetteFenetre:SetPoint("TOPLEFT", titreFenetre, "BOTTOMLEFT", 0, -10)
local recetteChamp = Champ(388)
recetteChamp:SetMaxLetters(80)
recetteChamp:SetPoint("TOPLEFT", titreFenetre, "BOTTOMLEFT", 0, -8)

local libelleQuantite = UI.Texte(fenetre, UI.TEXTE, 13, "c9bfa8")
libelleQuantite:SetPoint("TOPLEFT", recetteChamp, "BOTTOMLEFT", 0, -12)
libelleQuantite:SetText("Quantité")
local quantite = Champ(70)
quantite:SetNumeric(true)
quantite:SetMaxLetters(3)
quantite:SetPoint("TOPLEFT", libelleQuantite, "BOTTOMLEFT", 0, -4)

local libelleNote = UI.Texte(fenetre, UI.TEXTE, 13, "c9bfa8")
libelleNote:SetPoint("TOPLEFT", libelleQuantite, "TOPLEFT", 90, 0)
libelleNote:SetText("Note (facultative)")
local note = Champ(298)
note:SetMaxLetters(100)
note:SetPoint("TOPLEFT", libelleNote, "BOTTOMLEFT", 0, -4)

local envoyer = UI.BoutonRouge(fenetre, "Envoyer")
envoyer:SetPoint("BOTTOMRIGHT", -16, 14)
local annuler = UI.BoutonSombre(fenetre, "Annuler")
annuler:SetPoint("RIGHT", envoyer, "LEFT", -8, 0)
annuler:SetScript("OnClick", function() fenetre:Hide() end)
local info = UI.Paragraphe(fenetre, 12, "a89f8a", 388, "")
info:SetPoint("BOTTOMLEFT", 16, 58)

-- Sans artisan : commande de guilde, visible par tous.
function UI.OuvrirCommande(artisan, recette)
  fenetre:SetTitle(artisan and ("Commander à " .. artisan) or "Commande de guilde")
  recetteFenetre:SetShown(artisan ~= nil)
  recetteChamp:SetShown(artisan == nil)
  recetteFenetre:SetText(recette and ("[" .. recette .. "]") or "")
  recetteChamp:SetText("")
  quantite:SetText("1")
  note:SetText("")
  if artisan then
    info:SetText(C.EnLigne(artisan) and "" or (artisan .. " est hors ligne : il recevra la commande à sa prochaine connexion."))
  else
    info:SetText("Écris le nom de la recette. La commande sera visible par toute la guilde.")
  end
  envoyer:SetScript("OnClick", function()
    local n = math.max(1, tonumber(quantite:GetText()) or 1)
    if artisan then
      C.Commander(artisan, recette, n, note:GetText())
      print("Aux Ptits Casus : commande pour " .. artisan .. " enregistrée.")
    else
      local nom = recetteChamp:GetText():gsub("^%s+", ""):gsub("%s+$", "")
      if nom == "" then
        info:SetText("|cfff29a8eÉcris d'abord le nom de la recette.|r")
        return
      end
      C.CommanderGuilde(nom, n, note:GetText())
      print("Aux Ptits Casus : commande de guilde publiée.")
    end
    fenetre:Hide()
    UI.MajCommandes()
  end)
  fenetre:Show()
end
