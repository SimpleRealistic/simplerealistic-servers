#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

public Plugin myinfo =
{
    name = "Fix Competitive Warmup",
    author = "Ilusion9",
    description = "Fix competitive warmup.",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

public void OnMapStart()
{
    if (FileExists("scripts/vscripts/warmup/warmup_arena.nut"))
    {
        DeleteFile("scripts/vscripts/warmup/warmup_arena.nut");
    }
    
    if (FileExists("scripts/vscripts/warmup/warmup_teleport.nut"))
    {
        DeleteFile("scripts/vscripts/warmup/warmup_teleport.nut");
    }
} 