# -- Run our update routine
function tfc_customizations:update
# -- Reschedule our main function in 20 ticks (1 second)
schedule function tfc_customizations:main 20t replace
