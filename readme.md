# Mandragora Mania Bot

This is for automating the Mandragora Mania mini game. This only reads packets and does not inject them, and uses input commands to simulate the client actually playing the game normally. But still, use at your own risk!

# How to Use

1. Talk to Chacharoon
2. Make sure you go first in the settings (because I couldn't be bothered to find out how to figure this out from packets)
3. Go to the player selection sub menu (I couldn't find an incoming or outgoing packet when I went between the main menu and player selection sub menu)
4. //mmbot start <number>
5. Select player (Only tested logic against Green Thumb Moogle Pattern D. Quite possible there are infinite loop situations and/or bugs). You can select other players at first but the automation will always selected Green Thumb Moogle.

# Commands

use //mmbot to send commands

## mmbot start <number_of_jingly_to_get>: 

> mmbot start 0

Starts automating until you get the amount of jingly specified. 300 is default. Set to 0 automate until you tell it to stop.

## mmbot stop

Will stop the automation.

## mmbot setdelay (keypress / keydownup / ack / waitforack) (number)

Configures the delay for the various events

keypress is the delay between a key down and up event and the next key down and up event.

keydownup is the delay between a key down and key up event.

ack is the delay between sending out an ack packet and the bot trying to take a turn

waitforack is the delay the bot will wait if no ack packet is sent (usually when a turn doesn't update the score)

## mmbot debug 

Toggles between printing debug messages to console or not. Default is off.

# Version History
1.1.4:
- Reset state on zone change since logout doesn't trigger when kicked out to character select

1.1.3:
- Added Navigation Helper from mmmbot so that mmbot is faster

1.1.2:
- Start command now accepts 2nd argument again. Use 0 to go back to automate until you drop.

1.1.1:
- Update npc ids for the permanent mandy mania patch
- Changed start functionality to play until you get 300 jingly
- Removed the buyitem function

1.1.0:
- add buyitem function
- fix game logic so that it doesn't try to block opponent multiple turn when area 2 has 2 and area 4 has 3.
	
1.0.7:
- fix setdelay function

1.0.6:
- Should probably clear everything if logout

1.0.5:
- Need to handle repeated outgoing packets, as they will mess up the game state
- Fix another infinite loop situation
	
1.0.4:
- Will retry an action if for some reason a wrong action is performed (clicking empty area)
- Can change the various delays. See setdelay command
- Fix more state problems

1.0.3:
- Fix issue with state not resetting properly when it's the last time.

1.0.2:
- Made it work with Sandoria and Windurst NPCs.

1.0.1:
- Fix some logic where tried to play area 4 when only mandy left is in area 2.
- Less debug spam.

1.0.0: 
- First version.
