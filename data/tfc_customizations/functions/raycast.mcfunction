execute unless score @s tfc_c_raycast_step matches -1 run scoreboard players add @s tfc_c_raycast_step 1
execute if score @s tfc_c_raycast_step matches -1 run scoreboard players set @s tfc_c_raycast_step 0
execute unless block ~ ~ ~ minecraft:air run summon minecraft:interaction ~ ~ ~ {Tags:["tfc_c_raycast_result"],width:0.25,height:0.25}
execute if score @s tfc_c_raycast_step matches ..40 if block ~ ~ ~ minecraft:air run function tfc_customizations:raycast_step
execute if score @s tfc_c_raycast_step matches 41.. run scoreboard players set @s tfc_c_raycast_step -1
