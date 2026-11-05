-- Page Statistiques : une seule page qui défile, faite de graphiques animés à l'ouverture
-- (les axes se tracent, les colonnes montent, les blocs s'empilent, les anneaux tournent).
-- Composition (tuiles, anneau des classes | colonnes à blocs des grades),
-- Métiers (colonnes avec l'icône du métier) | Raids (boss tués), puis Loot (tuiles, anneau des paliers). Survoler un élément affiche son détail.
-- Pas de couleur de classe ici, sauf dans l'anneau des classes : tons dorés de l'addon.
local _, ns = ...
local UI = ns.UI
local Hex = UI.Hex
local contenu = UI.Defilant(UI.pages.stats)

local L = UI.LARGEUR
local ECART = 24 -- entre deux colonnes de la page
local COLONNE = (L - ECART) / 2
local LIBELLE = 120 -- largeur des libellés devant les barres
local VALEUR = 44 -- largeur réservée à la valeur après les barres
local DUREE = 0.45 -- durée d'une animation, en secondes
local OR, OR_FONCE, AXE = "c9a35a", "8c6a3c", "6e5230"
local GRADES = { "e6b84a", "c9a35a", "a8853f", "8c6a3c", "6e5230" } -- du plus haut grade au plus bas
local TRANCHE = "Interface\\AddOns\\PtitsCasus\\Media\\Tranche.tga"
local TRANCHES = 64 -- tranches par anneau

-- Icône de chaque métier (noms français et anglais du jeu).
local ICONES_METIERS = {
  Alchimie = "Trade_Alchemy", Alchemy = "Trade_Alchemy",
  Forge = "Trade_BlackSmithing", Blacksmithing = "Trade_BlackSmithing",
  Couture = "Trade_Tailoring", Tailoring = "Trade_Tailoring",
  ["Ingénierie"] = "Trade_Engineering", Engineering = "Trade_Engineering",
  ["Travail du cuir"] = "Trade_LeatherWorking", Leatherworking = "Trade_LeatherWorking",
  Enchantement = "Trade_Engraving", Enchanting = "Trade_Engraving",
  Minage = "Trade_Mining", Mining = "Trade_Mining",
  Herboristerie = "Spell_Nature_NatureTouchGrow", Herbalism = "Spell_Nature_NatureTouchGrow",
  ["Dépeçage"] = "INV_Misc_Pelt_Wolf_01", Skinning = "INV_Misc_Pelt_Wolf_01",
  Cuisine = "INV_Misc_Food_15", Cooking = "INV_Misc_Food_15",
  Secourisme = "Spell_Holy_SealOfSacrifice", ["First Aid"] = "Spell_Holy_SealOfSacrifice",
  ["Pêche"] = "Trade_Fishing", Fishing = "Trade_Fishing",
}

-- Animations : chaque élément animé reçoit une avancée de 0 à 1 (ralentie à la fin).
local animations = {}
local animateur = CreateFrame("Frame")
animateur:Hide()
animateur:SetScript("OnUpdate", function(self)
  local maintenant, enCours = GetTime(), false
  for _, a in ipairs(animations) do
    local t = math.min(1, math.max(0, (maintenant - a.debut) / DUREE))
    a.appliquer(1 - (1 - t) ^ 3)
    enCours = enCours or t < 1
  end
  if not enCours then
    self:Hide()
  end
end)

local function Animer(delai, appliquer)
  table.insert(animations, { debut = GetTime() + delai, appliquer = appliquer })
  appliquer(0)
  animateur:Show()
end

-- Réserves d'éléments : la page est redessinée à chaque affichage en réutilisant
-- les éléments déjà créés (un jeu ne peut pas détruire ses cadres).
local reserves = {}

local function Prendre(sorte, creer)
  local r = reserves[sorte]
  if not r then
    r = { n = 0 }
    reserves[sorte] = r
  end
  r.n = r.n + 1
  r[r.n] = r[r.n] or creer()
  r[r.n]:ClearAllPoints()
  r[r.n]:SetAlpha(1)
  r[r.n]:Show()
  return r[r.n]
end

local function ToutCacher()
  for _, r in pairs(reserves) do
    for i = 1, #r do
      r[i]:Hide()
    end
    r.n = 0
  end
end

-- Texte réutilisable, avec sa police, sa taille et sa couleur.
local function Texte(police, taille, couleur, x, y, texte, largeur)
  local fs = Prendre(police .. taille, function() return UI.Texte(contenu, police, taille, "e8e0cc") end)
  fs:SetTextColor(Hex(couleur))
  fs:SetWidth(largeur or 0)
  fs:SetWordWrap(largeur ~= nil)
  fs:SetJustifyH("LEFT")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(texte)
  return fs
end

-- Texte centré sur le point (x, y) de la page.
local function TexteCentre(taille, couleur, x, y, texte)
  local fs = Texte(UI.TEXTE, taille, couleur, 0, 0, texte)
  fs:ClearAllPoints()
  fs:SetPoint("CENTER", contenu, "TOPLEFT", x, y)
  return fs
end

-- Rectangle de couleur unie.
local function Rect(couleur)
  local t = Prendre("rect", function() return contenu:CreateTexture(nil, "ARTWORK") end)
  t:SetColorTexture(Hex(couleur))
  return t
end

-- Icône du jeu (dossier Interface\Icons ou chemin complet).
local function Icone(chemin, taille, x, y)
  local t = Prendre("icone", function() return contenu:CreateTexture(nil, "ARTWORK") end)
  t:SetTexture(chemin:find("\\") and chemin or ("Interface\\Icons\\" .. chemin))
  t:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- retire le bord des icônes du jeu
  t:SetSize(taille, taille)
  t:SetPoint("CENTER", contenu, "TOPLEFT", x, y)
  return t
end

-- Zone invisible qui affiche une info-bulle au survol.
local function Survol(x, y, largeur, hauteur, titre, info)
  local f = Prendre("survol", function()
    local z = CreateFrame("Frame", nil, contenu)
    z:EnableMouse(true)
    z:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(self.titre, 1, 0.82, 0)
      GameTooltip:AddLine(self.info, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    z:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return z
  end)
  f:SetPoint("TOPLEFT", x, y)
  f:SetSize(largeur, hauteur)
  f.titre, f.info = titre, info
end

-- Axe horizontal (à la hauteur y) ou vertical (de y vers le bas) qui se trace.
local function Axe(x, y, longueur, vertical)
  local t = Rect(AXE)
  if vertical then
    t:SetWidth(1)
    t:SetPoint("BOTTOMLEFT", contenu, "TOPLEFT", x, y - longueur)
    Animer(0, function(e) t:SetHeight(math.max(0.01, longueur * e)) end)
  else
    t:SetHeight(1)
    t:SetPoint("TOPLEFT", x, y)
    Animer(0, function(e) t:SetWidth(math.max(0.01, longueur * e)) end)
  end
end

-- Titre de section : titre doré, trait jusqu'au bout de la colonne, phrase d'explication sur une ligne.
local function TitreSection(x, y, largeur, titre, sousTitre)
  local t = Texte(UI.TITRE, 18, "ffd100", x, y, titre)
  local trait = Rect(AXE)
  trait:SetHeight(1)
  trait:SetPoint("LEFT", t, "RIGHT", 12, 0)
  trait:SetWidth(math.max(1, largeur - t:GetStringWidth() - 12))
  Texte(UI.TEXTE, 12, "a89f8a", x, y - t:GetStringHeight() - 4, sousTitre)
  return y - t:GetStringHeight() - 4 - 18 - 14
end

-- Rangée de tuiles : { { valeur, libellé, détail }, ... }. Les valeurs en nombre défilent depuis 0.
local function Tuiles(x, y, largeur, tuiles)
  local l = (largeur - (#tuiles - 1) * 10) / #tuiles
  for i, t in ipairs(tuiles) do
    local tuile = Prendre("tuile", function()
      local f = UI.Carte(contenu)
      f.haut = f:CreateTexture(nil, "ARTWORK")
      f.haut:SetPoint("TOPLEFT", 1, -1)
      f.haut:SetPoint("TOPRIGHT", -1, -1)
      f.haut:SetHeight(2)
      f.haut:SetColorTexture(Hex(OR))
      f.valeur = UI.Texte(f, UI.TITRE, 22, "e8e0cc")
      f.valeur:SetPoint("TOPLEFT", 12, -10)
      f.libelle = UI.Texte(f, UI.TEXTE, 12, "c9bfa8")
      f.libelle:SetPoint("TOPLEFT", f.valeur, "BOTTOMLEFT", 0, -3)
      f.libelle:SetWordWrap(true)
      f.libelle:SetMaxLines(2)
      f.detail = UI.Texte(f, UI.TEXTE, 10, "8a826f")
      f.detail:SetPoint("TOPLEFT", f.libelle, "BOTTOMLEFT", 0, -2)
      f.detail:SetWordWrap(false)
      return f
    end)
    tuile:SetSize(l, 88)
    tuile:SetPoint("TOPLEFT", x + (i - 1) * (l + 10), y)
    tuile.libelle:SetWidth(l - 20)
    tuile.libelle:SetText(t[2])
    tuile.detail:SetWidth(l - 20)
    tuile.detail:SetText(t[3] or "")
    if type(t[1]) == "number" then
      local cible = t[1]
      Animer(0.05 * i, function(e) tuile.valeur:SetText(math.floor(cible * e + 0.5)) end)
    else
      tuile.valeur:SetText(t[1])
    end
  end
  return y - 88 - 18
end

-- Petit titre au-dessus d'un graphique.
local function SousTitre(x, y, texte)
  local fs = Texte(UI.TITRE, 14, "e8e0cc", x, y, texte)
  return y - fs:GetStringHeight() - 10
end

-- Texte gris quand un graphique n'a pas encore de données.
local function Vide(x, y, largeur, texte)
  local fs = Texte(UI.TEXTE, 13, "8a826f", x, y, texte, largeur)
  return y - fs:GetStringHeight() - 8
end

-- Anneau qui se remplit en tournant : { { valeur, couleur, icône, titre, info }, ... }.
-- Total au centre ; autour, l'icône et le nombre de chaque part (détail au survol).
local function Anneau(x, y, largeur, segments)
  local rayon = 62
  local cx, cy = x + largeur / 2, y - rayon - 30
  local total = 0
  for _, s in ipairs(segments) do
    total = total + s[1]
  end
  -- Couleur de chaque tranche, en suivant les parts dans le sens des aiguilles d'une montre.
  local tranches, cumul, k = {}, 0, 1
  for i = 1, TRANCHES do
    local milieu = (i - 0.5) / TRANCHES * total
    while k < #segments and milieu > cumul + segments[k][1] do
      cumul = cumul + segments[k][1]
      k = k + 1
    end
    local t = Prendre("tranche", function()
      local tx = contenu:CreateTexture(nil, "ARTWORK")
      tx:SetTexture(TRANCHE)
      return tx
    end)
    t:SetSize(2 * rayon, 2 * rayon)
    t:SetPoint("CENTER", contenu, "TOPLEFT", cx, cy)
    t:SetRotation(-(i - 0.5) / TRANCHES * 2 * math.pi)
    t:SetVertexColor(Hex(segments[k][2]))
    tranches[i] = t
  end
  Animer(0.1, function(e)
    for i, t in ipairs(tranches) do
      t:SetShown(i <= e * TRANCHES + 0.01)
    end
  end)
  local centre = TexteCentre(20, "e8e0cc", cx, cy, total)
  Animer(0.1, function(e) centre:SetText(math.floor(total * e + 0.5)) end)
  -- Icône et nombre de chaque part, posés à l'extérieur de l'anneau, au milieu de la part.
  cumul = 0
  for i, s in ipairs(segments) do
    local angle = (cumul + s[1] / 2) / total * 2 * math.pi
    cumul = cumul + s[1]
    local ix, iy = cx + (rayon + 22) * math.sin(angle), cy + (rayon + 22) * math.cos(angle)
    -- Avec une icône : l'icône et le nombre dessous. Sans icône : « libellé · nombre ».
    local icone = s[3] and Icone(s[3], 18, ix, iy)
    local nombre = TexteCentre(12, "e8e0cc", ix, iy - (s[3] and 16 or 0), s[3] and s[1] or (s[4] .. " · " .. s[1]))
    Animer(0.5 + 0.04 * i, function(e)
      if icone then
        icone:SetAlpha(e)
      end
      nombre:SetAlpha(e)
    end)
    Survol(ix - 14, iy + 12, 28, 36, s[4], s[5])
  end
  return cy - rayon - 40
end

-- Colonnes à blocs : { { valeur, couleur, icône ou libellé, titre, info }, ... }.
-- Un bloc par unité (ou par paquet si les valeurs sont grandes), qui s'empilent un à un.
local function Blocs(x, y, largeur, colonnes)
  local hauteur, BLOC, PAS_BLOC = 150, 10, 13
  local base = y - hauteur
  Axe(x, base, largeur)
  local max = 0
  for _, c in ipairs(colonnes) do
    max = math.max(max, c[1])
  end
  local unite = math.max(1, math.ceil(max / 10))
  local pas = largeur / math.max(#colonnes, 1)
  local l = math.min(30, pas * 0.6)
  for i, c in ipairs(colonnes) do
    local px = x + (i - 1) * pas + (pas - l) / 2
    local nb = math.ceil(c[1] / unite)
    for b = 1, nb do
      local bloc = Rect(c[2])
      bloc:SetSize(l, BLOC)
      bloc:SetPoint("BOTTOMLEFT", contenu, "TOPLEFT", px, base + 3 + (b - 1) * PAS_BLOC)
      Animer(0.2 + 0.08 * i + 0.04 * b, function(e) bloc:SetAlpha(e > 0 and 1 or 0) end)
    end
    local nombre = TexteCentre(12, "e8e0cc", px + l / 2, base + 12 + nb * PAS_BLOC, c[1])
    Animer(0.3 + 0.08 * i + 0.04 * nb, function(e) nombre:SetAlpha(e) end)
    if c[3] and c[3]:find("\\") then
      Icone(c[3], 20, px + l / 2, base - 16)
    else
      TexteCentre(11, "c9bfa8", px + l / 2, base - 12, c[3] or "")
    end
    Survol(px - 4, base + 6 + nb * PAS_BLOC, l + 8, nb * PAS_BLOC + 40, c[4], c[5])
  end
  return base - 36
end

-- Colonnes qui montent, avec l'icône sous chacune. { { valeur, icône, titre, info }, ... }
local function Colonnes(x, y, largeur, colonnes)
  local hauteur = 150
  local base = y - hauteur
  Axe(x, y, hauteur, true)
  Axe(x, base, largeur)
  local max = 0
  for _, c in ipairs(colonnes) do
    max = math.max(max, c[1])
  end
  local pas = (largeur - 10) / math.max(#colonnes, 1)
  local l = math.min(28, pas * 0.6)
  for i, c in ipairs(colonnes) do
    local px = x + 10 + (i - 1) * pas + (pas - l) / 2
    local h = max > 0 and (hauteur - 40) * c[1] / max or 0
    local col = Rect(i % 2 == 1 and OR or OR_FONCE)
    col:SetWidth(l)
    col:SetPoint("BOTTOMLEFT", contenu, "TOPLEFT", px, base)
    Animer(0.25 + 0.06 * i, function(e) col:SetHeight(math.max(0.01, h * e)) end)
    local nombre = TexteCentre(11, "e8e0cc", px + l / 2, base + h + 9, c[1])
    Animer(0.5 + 0.06 * i, function(e) nombre:SetAlpha(e) end)
    Icone(c[2], 20, px + l / 2, base - 16)
    Survol(px - 4, base + h + 18, l + 8, h + 48, c[3], c[4])
  end
  return base - 36
end

-- Barres horizontales qui glissent : { { libellé, valeur, couleur, info-bulle }, ... }.
local function Barres(x, y, largeur, barres)
  local max = 0
  for _, b in ipairs(barres) do
    max = math.max(max, b[2])
  end
  local piste = largeur - LIBELLE - VALEUR
  Axe(x + LIBELLE, y + 2, #barres * 26, true)
  for i, b in ipairs(barres) do
    Texte(UI.TEXTE, 12, "c9bfa8", x, y - 4, b[1], LIBELLE - 8):SetWordWrap(false)
    local barre = Rect(b[3])
    barre:SetHeight(14)
    barre:SetPoint("TOPLEFT", x + LIBELLE + 1, y - 4)
    local cible = max > 0 and math.max(2, piste * b[2] / max) or 2
    Animer(0.2 + 0.05 * i, function(e) barre:SetWidth(math.max(0.01, cible * e)) end)
    local valeur = Texte(UI.TEXTE, 12, "e8e0cc", 0, 0, b[2])
    valeur:ClearAllPoints()
    valeur:SetPoint("LEFT", barre, "RIGHT", 6, 0)
    Survol(x, y, largeur, 24, b[1], b[4])
    y = y - 26
  end
  return y - 6
end

-- Pourcentage arrondi ("18 %").
local function Pct(n, total)
  return total > 0 and (math.floor(n * 100 / total + 0.5) .. " %") or "0 %"
end

-- Compte par clé, puis liste triée du plus grand au plus petit : { { clé, nombre }, ... }.
local function Trier(comptes)
  local liste = {}
  for cle, n in pairs(comptes) do
    table.insert(liste, { cle, n })
  end
  table.sort(liste, function(a, b)
    if a[2] ~= b[2] then
      return a[2] > b[2]
    end
    return a[1] < b[1]
  end)
  return liste
end

-- Composition : tuiles, puis l'anneau des classes et les colonnes à blocs des grades.
local function Composition(y, membres)
  y = TitreSection(0, y, L, "Composition", "Qui est dans la guilde, par classe et par grade, et son niveau d'objet.")
  local total, enLigne, n60, addon = 0, 0, 0, 0
  local somme, connus = 0, 0
  local parClasse, parGrade, ordreGrade = {}, {}, {}
  for nom, m in pairs(membres) do
    total = total + 1
    if m.enLigne then enLigne = enLigne + 1 end
    if (m.niveau or 0) >= 60 then n60 = n60 + 1 end
    if #(m.metiers or {}) > 0 then addon = addon + 1 end
    if m.classe then parClasse[m.classe] = (parClasse[m.classe] or 0) + 1 end
    local grade = m.rang or "Sans grade"
    parGrade[grade] = (parGrade[grade] or 0) + 1
    ordreGrade[grade] = m.rangIndex or 99
    if m.ilvl then
      connus = connus + 1
      somme = somme + m.ilvl
    end
  end
  y = Tuiles(0, y, L, {
    { total, "Membres" },
    { enLigne, "En ligne", Pct(enLigne, total) },
    { n60, "Niveau 60", Pct(n60, total) },
    { addon, "Avec l'addon", Pct(addon, total) },
    { connus > 0 and math.floor(somme / connus + 0.5) or "—", "ilvl moyen", connus .. " équipement(s) connu(s)" },
  })

  -- Anneau des classes : la seule place de la page où les couleurs de classe ont un sens.
  local segments = {}
  for _, c in ipairs(Trier(parClasse)) do
    local nom = ns.Api.NomClasse(c[1])
    table.insert(segments, { c[2], UI.HexClasse(c[1]), ns.Api.IconeClasse(c[1]), nom,
      c[2] .. " membre(s), " .. Pct(c[2], total) .. " de la guilde" })
  end
  local yg = SousTitre(0, y, "Classes")
  yg = #segments > 0 and Anneau(0, yg, COLONNE, segments) or Vide(0, yg, COLONNE, "Aucun membre.")

  local grades = {}
  for grade, n in pairs(parGrade) do
    table.insert(grades, { grade, n })
  end
  table.sort(grades, function(a, b) return ordreGrade[a[1]] < ordreGrade[b[1]] end)
  local colonnes = {}
  for i, g in ipairs(grades) do
    table.insert(colonnes, { g[2], GRADES[math.min(i, #GRADES)], g[1], g[1],
      g[2] .. " membre(s), " .. Pct(g[2], total) .. " de la guilde" })
  end
  local x2 = COLONNE + ECART
  local yd = Blocs(x2, SousTitre(x2, y, "Grades"), COLONNE, colonnes)
  return math.min(yg, yd)
end

-- Métiers : une colonne par métier (nombre d'artisans), son icône dessous.
local function Metiers(x, y, largeur, membres)
  y = TitreSection(x, y, largeur, "Métiers", "Artisans et meilleur niveau, métier par métier.")
  local artisans, meilleur, auMax, recettes, nbRecettes = {}, {}, 0, {}, 0
  for _, m in pairs(membres) do
    for _, metier in ipairs(m.metiers or {}) do
      artisans[metier.nom] = (artisans[metier.nom] or 0) + 1
      meilleur[metier.nom] = math.max(meilleur[metier.nom] or 0, metier.niveau)
      if metier.niveau >= 300 then auMax = auMax + 1 end
      for _, r in ipairs(metier.recettes or {}) do
        if not recettes[r] then
          recettes[r] = true
          nbRecettes = nbRecettes + 1
        end
      end
    end
  end
  local nbMetiers = 0
  for _ in pairs(artisans) do nbMetiers = nbMetiers + 1 end
  y = Tuiles(x, y, largeur, {
    { nbMetiers, "Métiers" },
    { auMax, "Artisans au 300" },
    { nbRecettes, "Recettes connues" },
  })
  local colonnes = {}
  for _, a in ipairs(Trier(artisans)) do
    table.insert(colonnes, { a[2], ICONES_METIERS[a[1]] or "INV_Misc_QuestionMark", a[1],
      a[2] .. " artisan(s), meilleur niveau " .. meilleur[a[1]] })
  end
  return #colonnes > 0 and Colonnes(x, y, largeur, colonnes) or Vide(x, y, largeur, "Aucun métier reçu pour l'instant.")
end

-- Raids : soirées et boss tués (nombre de kills par boss, premier kill au survol).
local function Raids(x, y, largeur)
  y = TitreSection(x, y, largeur, "Raids", "Les soirées de raid et les boss tombés.")
  local raids = UI.Raids()
  local kills, premier, nbBoss, parBoss = 0, {}, 0, {}
  for _, r in ipairs(raids) do
    for _, boss in ipairs(r.boss) do
      kills = kills + 1
      if not parBoss[boss] then
        nbBoss = nbBoss + 1
        premier[boss] = r.date
      end
      parBoss[boss] = (parBoss[boss] or 0) + 1
    end
  end
  y = Tuiles(x, y, largeur, {
    { #raids, "Soirées" },
    { kills, "Boss tués", nbBoss .. " boss différents" },
  })
  if #raids == 0 then
    return Vide(x, y, largeur, "Le journal de raid n'a encore rien enregistré. Il se remplira pendant les soirées.")
  end
  local barres = {}
  for i, b in ipairs(Trier(parBoss)) do
    table.insert(barres, { b[1], b[2], i % 2 == 1 and OR or OR_FONCE,
      b[2] .. " kill(s), le premier le " .. premier[b[1]] })
  end
  return Barres(x, SousTitre(x, y, "Boss tués"), largeur, barres)
end

-- Loot : tuiles, puis l'anneau des paliers.
local function Loot(y)
  y = TitreSection(0, y, L, "Loot", "Les objets distribués, par palier et par joueur.")
  local historique = UI.Historique()
  local total, epiques, pu = 0, 0, 0
  local parPalier = {}
  for _, soiree in ipairs(historique) do
    for _, l in ipairs(soiree.lignes) do
      total = total + 1
      if l.qualite == "e" then epiques = epiques + 1 end
      if l.palier == "PU" then pu = pu + 1 end
      parPalier[l.palier] = (parPalier[l.palier] or 0) + 1
    end
  end
  y = Tuiles(0, y, L, {
    { total, "Objets distribués" },
    { epiques, "Épiques", Pct(epiques, total) .. " des objets" },
    { pu, "Pour des PU", Pct(pu, total) .. " des objets" },
    { #historique > 0 and string.format("%.1f", total / #historique) or "—", "Par soirée", "en moyenne" },
  })
  if total == 0 then
    return Vide(0, y, L, "Aucun loot enregistré pour l'instant.")
  end

  local segments = {}
  for _, p in ipairs({ "+0", "+1", "+1 DL", "+2", "PU" }) do
    local n = parPalier[p] or 0
    if n > 0 then
      table.insert(segments, { n, UI.PALIERS[p][1], nil, p, n .. " objet(s), " .. Pct(n, total) })
    end
  end
  return Anneau(0, SousTitre(0, y, "Par palier"), L, segments)
end

local function Rafraichir()
  ToutCacher()
  wipe(animations)
  local membres = UI.Membres()
  local titre = Texte(UI.TITRE, 22, "ffd100", 0, 0, "Aux Ptits Casus · Statistiques")
  local sous = Texte(UI.TEXTE, 13, "a89f8a", 0, -titre:GetStringHeight() - 6,
    "Les chiffres de la guilde. Survole un graphique pour son détail.", L)
  local y = -titre:GetStringHeight() - 6 - sous:GetStringHeight() - 24
  y = Composition(y, membres) - 30
  -- Métiers et Raids côte à côte, puis Loot sous la plus longue des deux.
  y = math.min(Metiers(0, y, COLONNE, membres), Raids(COLONNE + ECART, y, COLONNE)) - 30
  y = Loot(y) - 20
  contenu:SetHeight(-y)
end

UI.rafraichir.stats = Rafraichir
