# -- Set all scores to 0 (disabled)
execute as @p[predicate=tfc_customizations:keep_food_fresh] run function tfc_customizations:refresh_food_expiration/remove_player
