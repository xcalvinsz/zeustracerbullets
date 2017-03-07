# CS:GO Zeus Tracer Bullets

[![IMAGE ALT TEXT HERE](http://img.youtube.com/vi/AyNLrRxBMaw/0.jpg)](http://www.youtube.com/watch?v=AyNLrRxBMaw)

## Description
This plugin will create a zeus tracer effect on bullets fired

## Requirements
```
Plugin for Counter-Strike: Global Offensive
Requires Sourcemod 1.8+ and Metamod 1.10+
```

## Convar settings
```
sm_zeustracers_enabled - [1/0] - Enables/Disables plugin
```

## Commands
```
sm_zeustracers <client> <1:ON | 0:OFF> - Turns on/off zeus tracers, this will make ALL weapons have zeus tracers regardless if it is disabled in configuration
```

## Installation
```
1. Place zeustracers.smx to addons/sourcemod/plugins/
2. Place zeustracers_guns.cfg to addons/sourcemod/configs/
3. Place zeustracers.cfg to cfg/sourcemod/ and edit your convars to fit your needs
```

##Configuration Setup
* Open addons/sourcemod/configs/zeustracers_guns.cfg
```
"weapon_ak47"					//Classname of weapon
{
	"Enable"			"1"		//Enable or disable for this weapon (0 to disable, 1 to enable) (sm_zeustracers can override this setting if it is set to disable)
	"Impact Glow"		"1"		//Creates a particle glow at bullet impact (0 to disable, 1 to enable)
	"Impact Sound"		"0.5"	//Sound volume of taser impact sound (Set to 0.0 to disable)
	"Muzzle Sound"		"0.3"	//Sound volume of taser shot when shooting (Set to 0.0 to disable)
	"Flag"				"b"		//Only players with this flag can have zeus tracers for this weapon (sm_zeustracers will override this), check https://wiki.alliedmods.net/Adding_Admins_(SourceMod)#Levels for more flags
}
```
There are more weapons listed that you can individually modify