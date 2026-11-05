-- Skin EllesmereUI (optionnel) : si EllesmereUI est installé et que le skin est activé
-- (/pc skin), EllesmereUI repeint le panneau et les fenêtres de loot dans son thème.
-- Tout passe par l'API qu'EllesmereUI prévoit pour les autres addons (SKINNING_API.md
-- dans son dossier). Sans EllesmereUI, ce fichier ne fait rien.
local _, ns = ...
local UI = ns.UI

-- Repeint un élément noté par UI.Noter, selon sa sorte.
function UI.Peindre(sorte, objet)
  local S = UI.skin
  if sorte == "fenetre" then
    S.Shell(objet)
    S.FadeRegions(objet.bandeau)
    S.CloseButton(objet.fermer)
    if objet.menu then
      S.FadeRegions(objet.menu)
      S.Panel(objet.menu, { inset = true, noBorder = true })
    end
  elseif sorte == "carte" then
    S.Panel(objet)
  elseif sorte == "bouton" then
    S.Button(objet)
  elseif sorte == "saisie" then
    S.EditBox(objet)
  elseif sorte == "case" then
    S.Checkbox(objet)
  elseif sorte == "texte" then
    S.Font(objet)
  end
end

if EllesmereUI and EllesmereUI.RegisterSkin then
  EllesmereUI.RegisterSkin("PtitsCasus", function(S)
    if not (PtitsCasusDB and PtitsCasusDB.reglages and PtitsCasusDB.reglages.skin) then
      return -- skin pas activé avec /pc skin
    end
    UI.skin = S
    for _, note in ipairs(UI.aSkinner) do
      UI.Peindre(note[1], note[2])
    end
    UI.aSkinner = {}
    -- Quand le joueur change son thème EllesmereUI (couleur d'accent…), on redessine nos
    -- éléments faits main ; les éléments repeints par EllesmereUI suivent tout seuls.
    S.OnLooksChanged(function()
      if UI.panneau:IsShown() then
        UI.RafraichirTout()
      end
    end)
  end)
end
