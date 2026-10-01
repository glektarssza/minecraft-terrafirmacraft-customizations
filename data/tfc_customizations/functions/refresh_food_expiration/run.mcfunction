# -- Update world time storage variable
function tfc_customizations:update_world_time
# -- Execute our raycasting function
execute as @s anchored eyes run function tfc_customizations:raycast
# -- Perform action on result, if present
execute at @e[type=minecraft:interaction,sort=nearest,limit=1,tag=tfc_c_raycast_result] run data modify block ~ ~ ~ inventory.Items[].ForgeCaps.'tfc:food'.creationDate set from storage tfc_customizations:vars current_game_tick
# -- Remove any interaction markers
kill @e[type=minecraft:interaction,distance=0..5,tag=tfc_c_raycast_result]
