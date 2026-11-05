-- Page Règles du loot : la règle du council, épinglée sur le Discord, lisible par tous.
-- La page défile à la molette.
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local contenu = UI.Defilant(UI.pages.regles)

local L = UI.LARGEUR

-- Mises en valeur dans les textes : mot important en blanc, touche ou annonce en or.
local function B(texte) return "|cffffffff" .. texte .. "|r" end
local function K(texte) return "|cffffd100" .. texte .. "|r" end

local y = 0 -- position du prochain bloc

local titre = UI.Texte(contenu, UI.TITRE, 22, "ffd100")
titre:SetPoint("TOPLEFT", 0, y)
titre:SetText("Règles du loot")
y = y - titre:GetStringHeight() - 6
local sous = UI.Paragraphe(contenu, 13, "a89f8a", L,
  "Règle du council, épinglée sur le Discord le 21/10/2026. Visible par tous.")
sous:SetPoint("TOPLEFT", 0, y)
y = y - sous:GetStringHeight() - 18

-- Carte avec un titre et des paragraphes. Renvoie la carte et la hauteur occupée par son contenu.
local function CarteTexte(x, largeur, titreCarte, couleurTitre, paragraphes, bord)
  local carte = UI.Carte(contenu, "1b1711", bord or "4a3820")
  carte:SetPoint("TOPLEFT", x, y)
  carte:SetWidth(largeur)
  local h = 14
  if titreCarte then
    carte.titre = UI.Texte(carte, UI.TITRE, 15, couleurTitre or "e8e0cc")
    carte.titre:SetPoint("TOPLEFT", 14, -h)
    carte.titre:SetText(titreCarte)
    h = h + carte.titre:GetStringHeight() + 10
  end
  for _, p in ipairs(paragraphes) do
    local texte, couleur = p, "d8cfb8"
    if type(p) == "table" then
      texte, couleur = p[1], p[2]
    end
    local fs = UI.Paragraphe(carte, 13, couleur, largeur - 28, texte)
    fs:SetPoint("TOPLEFT", 14, -h)
    h = h + fs:GetStringHeight() + 8
  end
  return carte, h + 6
end

-- 1. L'ordre de priorité : quatre cartes côte à côte.
local h3 = UI.Texte(contenu, UI.TITRE, 15, "e8e0cc")
h3:SetPoint("TOPLEFT", 0, y)
h3:SetText("1. L'ordre de priorité")
y = y - h3:GetStringHeight() - 10

local PRIORITES = {
  { "+0", "Priorité 1", "Désigné par les officiers",
    "Prioritaire sur tout le monde. Deux +0 sur le même objet : /rand entre eux. Un seul loot dans la soirée." },
  { "+1", "Priorité 2", "Spé principale", "L'objet améliore ta spé principale et tu n'as rien looté ce soir." },
  { "+1 DL", "Priorité 3", "Déjà looté ce soir",
    "Spé principale, mais tu as déjà gagné un objet ce soir." },
  { "+2", "Priorité 4", "2e spé",
    "L'objet sert ta deuxième spé, par exemple ton équipement de soin si tu joues DPS." },
}
local largeurPalier = (L - 3 * 10) / 4
local cartes, hauteurMax = {}, 0
for i, p in ipairs(PRIORITES) do
  local couleur = UI.PALIERS[p[1]][1]
  local carte = UI.Carte(contenu)
  carte:SetPoint("TOPLEFT", (i - 1) * (largeurPalier + 10), y)
  carte:SetWidth(largeurPalier)
  local haut = carte:CreateTexture(nil, "ARTWORK")
  haut:SetPoint("TOPLEFT")
  haut:SetPoint("TOPRIGHT")
  haut:SetHeight(3)
  haut:SetColorTexture(Hex(couleur))
  local palier = UI.Texte(carte, UI.TITRE, 24, couleur)
  palier:SetPoint("TOPLEFT", 14, -14)
  palier:SetText(p[1])
  local rang = UI.Texte(carte, UI.TEXTE, 12, "a89f8a")
  rang:SetPoint("TOPRIGHT", -14, -20)
  rang:SetText(p[2])
  local h = 14 + palier:GetStringHeight() + 6
  local nom = UI.Texte(carte, UI.TEXTE, 14, "e8e0cc")
  nom:SetPoint("TOPLEFT", 14, -h)
  nom:SetText(p[3])
  h = h + nom:GetStringHeight() + 6
  local texte = UI.Paragraphe(carte, 13, "d8cfb8", largeurPalier - 28, p[4])
  texte:SetPoint("TOPLEFT", 14, -h)
  h = h + texte:GetStringHeight() + 14
  cartes[i] = carte
  hauteurMax = math.max(hauteurMax, h)
end
for _, carte in ipairs(cartes) do
  carte:SetHeight(hauteurMax)
end
y = y - hauteurMax - 14

-- 2 à 5 : deux rangées de deux cartes.
local demi = (L - 12) / 2

local c2, h2 = CarteTexte(0, demi, "2. Comment annoncer", nil, {
  "Quand le maître du butin annonce un objet en avertissement de raid, écris ton palier dans le " .. B("chat de raid") .. " : "
    .. K("+1") .. "   " .. K("+1 DL") .. "   " .. K("+2"),
  { "Si tu as déjà looté ce soir, ton +1 compte comme un +1 DL.", "a89f8a" },
  "Fenêtre de loot fermée par erreur ? " .. K("/pc loot") .. " la rouvre.",
})
local c3, h3b = CarteTexte(demi + 12, demi, "3. En cas d'égalité", nil, {
  "Si plusieurs joueurs sont sur le même palier, le maître du butin leur demande un " .. K("/rand")
    .. ". Le plus grand score gagne.",
  "Seuls les /rand des joueurs concernés comptent, et seul le premier /rand de chacun est retenu.",
  { "Un +0 seul gagne directement. Si deux +0 annoncent sur le même objet, ils font /rand entre eux ; le perdant garde son +0.", "a89f8a" },
})
local hRangee = math.max(h2, h3b)
c2:SetHeight(hRangee)
c3:SetHeight(hRangee)
y = y - hRangee - 12

local c4, h4 = CarteTexte(0, demi, "4. Le +0", UI.PALIERS["+0"][1], {
  "Le RNG te boude ? " .. B("Deux soirées sans rien voir tomber") .. " ? Le +0 est fait pour toi.",
  "Ce sont " .. B("les officiers qui le donnent") .. ", avant le raid, en cochant le joueur. "
    .. "On ne peut pas se mettre +0 soi-même : sans case cochée, un « +0 » tapé dans le chat ne compte pas.",
  "Il vaut pour " .. B("un seul loot") .. ", pendant la soirée. Une fois l'objet gagné, le joueur repasse en +1 DL.",
}, UI.PALIERS["+0"][1])
local c5, h5 = CarteTexte(demi + 12, demi, "5. Quand un PU est présent", "f0c674", {
  "Si un joueur " .. B("hors guilde (PU)") .. " annonce sur un objet, le +0 " .. B("ne s'applique pas")
    .. " sur cet objet. Tout le monde reste en +1, +1 DL ou +2, le joueur +0 compris.",
  "Le joueur +0 garde son +0 pour un autre objet de la soirée.",
})
-- Encadré « À confirmer » en bas de la carte 5.
local encadre = UI.Carte(c5, "3a2a14", "8a6424")
encadre:SetPoint("TOPLEFT", 14, -h5 + 4)
encadre:SetPoint("TOPRIGHT", -14, -h5 + 4)
local aConfirmer = UI.Puce(encadre, "À confirmer", "f0c674", "16130e")
aConfirmer:SetPoint("TOPLEFT", 10, -8)
local question = UI.Paragraphe(encadre, 13, "f3d9a4", demi - 28 - 20 - aConfirmer:GetWidth() - 8,
  "S'il gagne quand même cet objet en +1, perd-il son +0 ? Réglable dans Réglages.")
question:SetPoint("TOPLEFT", aConfirmer, "TOPRIGHT", 8, -2)
local hEncadre = math.max(aConfirmer:GetHeight(), question:GetStringHeight()) + 16
encadre:SetHeight(hEncadre)
h5 = h5 + hEncadre + 10
hRangee = math.max(h4, h5)
c4:SetHeight(hRangee)
c5:SetHeight(hRangee)
y = y - hRangee - 12

-- Exemples : trois cas côte à côte.
local EXEMPLES = {
  { "Égalité en +1", "Brakkor et Thalyn tapent +1, Mirlinda tape +2. Brakkor fait 74 au /rand, Thalyn 41.",
    "Brakkor gagne. Il passe en +1 DL." },
  { "Un +0 dans le raid", "Kéliane est cochée +0. Elle tape +1 sur un objet, comme Brakkor.",
    "Kéliane gagne sans /rand. Son +0 est utilisé." },
  { "Un PU annonce", "Kéliane (+0), Brakkor et le PU Zorgdu tapent +1. Le +0 ne compte pas ici.",
    "/rand entre les trois. Kéliane garde son +0." },
}
local exemples = UI.Carte(contenu)
exemples:SetPoint("TOPLEFT", 0, y)
exemples:SetWidth(L)
local titreExemples = UI.Texte(exemples, UI.TITRE, 15, "e8e0cc")
titreExemples:SetPoint("TOPLEFT", 14, -14)
titreExemples:SetText("Exemples")
local haut = 14 + titreExemples:GetStringHeight() + 10
local largeurCas = (L - 28 - 2 * 12) / 3
local cas, hCas = {}, 0
for i, e in ipairs(EXEMPLES) do
  local bloc = CreateFrame("Frame", nil, exemples)
  bloc:SetPoint("TOPLEFT", 14 + (i - 1) * (largeurCas + 12), -haut)
  bloc:SetWidth(largeurCas)
  UI.Fond(bloc, "16130e")
  local t = UI.Texte(bloc, UI.TEXTE, 13, "c9bfa8")
  t:SetPoint("TOPLEFT", 10, -10)
  t:SetText(e[1])
  local h = 10 + t:GetStringHeight() + 6
  local texte = UI.Paragraphe(bloc, 13, "d8cfb8", largeurCas - 20, e[2])
  texte:SetPoint("TOPLEFT", 10, -h)
  h = h + texte:GetStringHeight() + 6
  local resultat = UI.Paragraphe(bloc, 13, UI.ACCENT, largeurCas - 20, "» " .. e[3])
  resultat:SetPoint("TOPLEFT", 10, -h)
  table.insert(UI.surAccent, function() resultat:SetTextColor(Hex(UI.ACCENT)) end)
  h = h + resultat:GetStringHeight() + 10
  cas[i] = bloc
  hCas = math.max(hCas, h)
end
for _, bloc in ipairs(cas) do
  bloc:SetHeight(hCas)
end
exemples:SetHeight(haut + hCas + 14)
y = y - haut - hCas - 14

contenu:SetHeight(-y + 10)
