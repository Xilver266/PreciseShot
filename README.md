# PreciseShot

## Description

Force drop weapon client on shooting him in the hands

## Requeriments

SourceMod 1.4.0+
SDK Hooks 2.1

## ConVars

* **sm_psweaponuse** - Use a specific weapon for make the drop function
* **sm_psweaponname** - Specific weapon (Dependency: sm_psweaponuse)
* **sm_damagecheck** - Damage to force drop weapon
* **sm_psdamage** - Amount of damage to force drop weapon (Dependency: sm_psdamagecheck)
* **sm_psclientmessage** - Show messages to client

## Changelog

> 2012-17-06 (v1.1)
> 
> * Fixed some bugs.
> * Native GetConVarInt() replaced by native GetConVarBool()
> 
> 2012-16-06 (v1.0)
> 
> * Initial release.

## Installation

* Place SMX in the plugins folder and you're done". A cfg file will be generated once the server has started (cfg/sourcemod/plugin.preciseshot.cfg)
