# -- Store current game ticks for later access
scoreboard objectives add current_game_tick minecraft.custom:play_time
execute store result storage tfc_customizations:tmp current_game_tick long 1.0 run scoreboard players get @p[limit=1] current_game_tick
# -- Go through the player inventory and update food expiration times
data modify entity @p[predicate=tfc_customizations:keep_food_fresh] Inventory[].ForgeCaps.'tfc:food'.creationDate set from storage tfc_customizations:tmp current_game_tick
# -- Reschedule ourselves
schedule function tfc_customizations:refresh_food_expiration/run 60s replace
