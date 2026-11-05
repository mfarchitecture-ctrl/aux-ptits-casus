-- Commandes d'artisanat entre membres : un membre commande une recette à un artisan,
-- l'artisan l'accepte, la refuse ou la marque « Faite ». Les messages passent d'addon à addon
-- (invisibles dans le chat). Si le destinataire est hors ligne, le message attend dans la
-- « boîte » et part dès qu'il est vu en ligne.
-- Messages privés : "C~id~recette~quantité~note" (commande) et "R~id~état" (réponse).
local _, ns = ...
local Api = ns.Api
local C = {}
ns.Commandes = C

local SEP = "~"

-- Les vraies commandes, gardées dans la sauvegarde.
local function Vraies()
  PtitsCasusDB.commandes = PtitsCasusDB.commandes or { recues = {}, envoyees = {}, boite = {}, nonLues = 0 }
  return PtitsCasusDB.commandes
end

-- Celles qu'on affiche : la démo (/pc test) ou les vraies.
function C.Donnees()
  return ns.demo and ns.Demo.commandes or Vraies()
end

-- Retire les caractères qui casseraient le message.
local function Nettoyer(texte)
  return ((texte or ""):gsub(SEP, "-"):gsub("|", "/"))
end

function C.EnLigne(nom)
  local m = ns.UI.Membres()[nom]
  return m ~= nil and m.enLigne == true
end

-- Envoie tout de suite si le joueur est en ligne, sinon garde le message pour plus tard.
local function Poster(nom, texte)
  if ns.demo then
    print("Aux Ptits Casus (démo) : rien n'est envoyé.")
  elseif C.EnLigne(nom) then
    Api.EnvoyerA(nom, texte)
  else
    table.insert(Vraies().boite, { a = nom, texte = texte })
  end
end

-- Envoie les messages en attente aux joueurs revenus en ligne.
function C.ViderBoite()
  if not PtitsCasusDB then
    return
  end
  local boite = Vraies().boite
  for i = #boite, 1, -1 do
    if C.EnLigne(boite[i].a) then
      Api.EnvoyerA(boite[i].a, boite[i].texte)
      table.remove(boite, i)
    end
  end
end

function C.Commander(artisan, recette, quantite, note)
  local id = time() .. math.random(100, 999)
  table.insert(C.Donnees().envoyees, 1,
    { id = id, a = artisan, recette = recette, quantite = quantite, note = note, etat = "En attente" })
  Poster(artisan, table.concat({ "C", id, Nettoyer(recette), quantite, Nettoyer(note) }, SEP))
end

-- L'artisan répond : "Acceptée", "Refusée" ou "Faite".
function C.Repondre(commande, etat)
  commande.etat = etat
  Poster(commande.de, table.concat({ "R", commande.id, etat }, SEP))
end

-- Le demandeur annule sa commande.
function C.Annuler(commande)
  commande.etat = "Annulée"
  Poster(commande.a, table.concat({ "R", commande.id, "Annulée" }, SEP))
end

-- Retire une commande terminée de la liste.
function C.Effacer(liste, commande)
  for i, c in ipairs(liste) do
    if c == commande then
      table.remove(liste, i)
    end
  end
end

-- Commandes de guilde : visibles par tous, n'importe quel artisan peut s'en charger.
-- Message "G~id~demandeur~recette~quantité~note~état~preneur~créée~modifiée", envoyé à toute la guilde
-- avec l'état complet de la commande. "Q" : un joueur qui se connecte demande la liste ; chacun
-- renvoie alors les commandes qu'il a postées ou prises.
local function Guilde(d)
  d.guilde = d.guilde or {}
  return d.guilde
end

local function MonNom()
  return Api.NomCourt(Api.MonNom())
end

local function EnvoyerGuilde(c)
  Api.EnvoyerGuilde(table.concat({ "G", c.id, c.de, Nettoyer(c.recette), c.quantite, Nettoyer(c.note), c.etat,
    c.par or "", c.quand, c.maj }, SEP))
end

local function Diffuser(c)
  if ns.demo then
    print("Aux Ptits Casus (démo) : rien n'est envoyé.")
  else
    EnvoyerGuilde(c)
  end
end

-- Liste à afficher, la plus récente d'abord. Les commandes faites ou annulées depuis plus de
-- 3 jours, et celles ouvertes depuis plus de 7 jours, sont retirées.
function C.Guilde()
  local g = Guilde(C.Donnees())
  local maintenant = Api.Heure()
  local liste = {}
  for id, c in pairs(g) do
    local finie = c.etat == "Faite" or c.etat == "Annulée"
    if (finie and maintenant - c.maj > 3 * 86400) or (not finie and maintenant - c.quand > 7 * 86400) then
      g[id] = nil
    else
      table.insert(liste, c)
    end
  end
  table.sort(liste, function(a, b) return a.quand > b.quand end)
  return liste
end

function C.CommanderGuilde(recette, quantite, note)
  local maintenant = Api.Heure()
  local c = { id = time() .. math.random(100, 999), de = ns.UI.Moi(), recette = recette, quantite = quantite,
    note = note, etat = "Ouverte", quand = maintenant, maj = maintenant }
  Guilde(C.Donnees())[c.id] = c
  Diffuser(c)
end

-- "Prise" (je m'en charge), "Faite" ou "Annulée".
function C.ChangerGuilde(c, etat)
  c.etat = etat
  c.maj = Api.Heure()
  if etat == "Prise" then
    c.par = ns.UI.Moi()
  end
  Diffuser(c)
end

-- À la connexion : demander les commandes de guilde à ceux qui sont en ligne.
function C.DemanderGuilde()
  Api.EnvoyerGuilde("Q")
end

-- Message reçu d'un autre addon (voir PtitsCasus.lua).
function C.Recevoir(texte, expediteur)
  local de = Api.NomCourt(expediteur)
  local m = { strsplit(SEP, texte) }
  local v = Vraies()
  if m[1] == "G" then
    local g = Guilde(v)
    local c = { id = m[2], de = m[3], recette = m[4], quantite = tonumber(m[5]) or 1, note = m[6] or "",
      etat = m[7], par = m[8] ~= "" and m[8] or nil, quand = tonumber(m[9]) or 0, maj = tonumber(m[10]) or 0 }
    local ancienne = g[c.id]
    if not ancienne or c.maj > ancienne.maj then
      g[c.id] = c
      if not ancienne and c.de ~= MonNom() and c.etat == "Ouverte" then
        v.nonLues = v.nonLues + 1
        print("Aux Ptits Casus : nouvelle commande de guilde de " .. c.de .. " : " .. c.quantite .. " × [" .. c.recette .. "].")
      elseif ancienne and c.de == MonNom() and c.etat == "Prise" and ancienne.etat ~= "Prise" then
        v.nonLues = v.nonLues + 1
        print("Aux Ptits Casus : " .. c.par .. " se charge de ta commande [" .. c.recette .. "].")
      end
    end
  elseif m[1] == "Q" then
    if de ~= MonNom() then
      -- Petite attente au hasard, pour que tout le monde ne réponde pas en même temps.
      C_Timer.After(math.random(2, 6), function()
        for _, c in pairs(Guilde(v)) do
          if c.de == MonNom() or c.par == MonNom() then
            EnvoyerGuilde(c)
          end
        end
      end)
    end
  elseif m[1] == "C" then
    for _, c in ipairs(v.recues) do
      if c.id == m[2] then
        return -- déjà reçue
      end
    end
    table.insert(v.recues, 1,
      { id = m[2], de = de, recette = m[3], quantite = tonumber(m[4]) or 1, note = m[5] or "", etat = "Nouvelle" })
    v.nonLues = v.nonLues + 1
    print("Aux Ptits Casus : nouvelle commande de " .. de .. " : " .. (m[4] or 1) .. " × [" .. m[3] .. "].")
    Api.EnvoyerA(de, table.concat({ "R", m[2], "Reçue" }, SEP)) -- accusé de réception
  elseif m[1] == "R" then
    for _, liste in ipairs({ v.envoyees, v.recues }) do
      for _, c in ipairs(liste) do
        if c.id == m[2] then
          c.etat = m[3]
          if m[3] ~= "Reçue" then
            v.nonLues = v.nonLues + 1
            print("Aux Ptits Casus : commande [" .. c.recette .. "] : " .. m[3]:lower() .. " par " .. de .. ".")
          end
        end
      end
    end
  end
  ns.UI.MajCommandes()
end
