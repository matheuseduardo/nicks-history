## nicks-history
---
a nice way to get last nicks used by players (by SteamID)

### How to use
 - command: `sm_nickhistory_list <target>` on console
 - or command: `!nickhistory_list <target>` on chat
 
 ## suggestion to change in `adminmenu_custom.txt`
 ```
 "Commands"
{
	"PlayerCommands"
	{
		"admin"		"sm_kick"
		
		"Lista Nicks"
		{
			"cmd"		"sm_nickshistory_list #1"
			"execute"	"player"
			"1"
			{
				"type" 		"player"
				"title"		"Player:"
			}
		}
	}
}
```

## To-do
- Internationalization output messages
