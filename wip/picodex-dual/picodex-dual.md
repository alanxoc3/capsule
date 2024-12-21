# The Making of Picodex Dual
[Picodex]() was my hobby project from January to April 2023. It is a complete battle simulator for the Red/Blue/Yellow (RBY) Pokemon games, squeezed into a single 32kb PICO-8 cartridge. I thought I had pushed PICO-8 to its limits when I published that game and I was able to continue life without any plans to start another big PICO-8 project. That is, until mid-September when I wrote something very dangerous in my journal:

> I've been casually drawing Johto Pokemon in PICO-8. I think it will be cool to do something with that. Maybe a just-Pokedex Picodex. Or convert all Pokemon to black/white and try to create a full Johto battle-sim. Not sure if the latter is possible, but it's a fun idea.

Thus I spent the next 14 months of my free time proving myself wrong! And now I'm proud to present my 32kb sequel called [Picodex Dual](). This is a complete battle simulator for the next generation of Pokemon games, Gold/Silver/Crystal (GSC).

While it may not seem like it at first glance, this was a much more ambitious project than the previous game. It has roughly double the content, but packed into the same amount of space. There are new Pokemon, new types, new moves, more edge cases, and many new mechanics. My goal with this article is to explain some of the interesting challenges I encountered as I made one of the most data packed PICO-8 game on the BBS.

## Dual Colored Sprites
From the start I knew I needed to minimize sprite space in order to fit all the extra data and code. Compressed sprites took up 1.5 sprite sheets and ~500 code tokens in the original Picodex. Picodex Dual however has over 100 new sprites, only fills up 1 sprite sheet, and needs 0 tokens for decompression!

Sprites are drawn at 16x16 pixels with only 1 bit per pixel. Outlines are faked by drawing the sprite multiple times, shifted 1 pixel in all directions. Dark colored Pokemon such as Unown and Houndoom are faked by abusing the outlining algorithm. Sprites are packed such that each pixel contains part of 4 different sprites. Clever pal & palt logic can be used to draw sprites without any sprite unpacking code on startup. Try loading the game with `LOAD #PICODEX_DUAL` and replacing all the game's code with this snippet:

```
function spr_pkmn(num,x,y,c)
  for i=1,15 do
    palt(i,2^(3-num\64)&i==0)
    pal(i,c)
  end
  spr(num%8*2+num%64\8*32,x,y,2,2)
end

function _draw()
  cls()
  for i=0,63 do
    spr_pkmn(i+t()\1%4*64,i%8*16,i\8*16,i%14+2)
  end
end
```

[The result of the above snippet](./sprite_unpack.gif)
[What sprites look like without above snippet](./unpacked_sprites.png)

I made a custom sprite editor on my playdate so I could sprite on the go! Here is an example of how dark outlines are faked with the playdate simulator.

![playdatething]()

## Learnset Packing
A learnset is all the possible moves a Pokemon can learn from leveling, breeding, evolving, tutoring, TMs, HMs, RBY import, glitches, and events.

11927 is the number of bytes it takes to store all learnsets without compression, but I needed this smaller to fit all the extra data!

The size can be reduced to ~7300 by removing duplicate moves that evolved Pokemon share with their pre-evolutions. Eg: Jolteon learns all the moves Eevee learns, but with some extras.

It can be reduced even further if the move id `255` is reserved to mean a range. For example, Magikarp can learn 6 moves: splash, tackle, flail, bubble, dragon rage, and reversal. Assume splash is 1, tackle is 2, etc, and reversal is 6. Instead of Magikarp's learnset taking up 6 bytes, it could be represented like `1 255 6` in just 3 bytes. Smeargle can learn every move in the game, so that learnset compresses down from 252 bytes down to just 3 bytes no matter what the move ids represent.

But generally, the amount of space this technique can save depends on how move ids are assigned. Since determining the optimal assignment is one of those NP problems, I created a python program that combines manual tweaks with brute force and an evolutionary algorithm that ran on my 16-core laptop for almost a week to find a good move id assignment. This took the total byte count down to just 4110, a 35% compression ratio from the original size! Without this extra saving, I don't think I would have been able to fit the remaining data to be packed.

## More Data Packing
My general data packing strategy for the remaining data was to make every bit count. About 90% of all Pokemon base stats are multiples of 5 and rounding the non-conforming 10% lets each stat be stored in 6 bits rather than 8 bits which saves 378 bytes. Genders use 2 bits, text uses 5 bits per letter, types use 5 bits, and so on. Since peek/poke only work on 8 bit boundaries, I made a function that I call on startup to unpack variable bit length values in order:

```
g_peek_loc, g_peek_off = 0x2000, 0
function bitpeek_inc(bitjump)
  bitjump = bitjump or 8
  local val = (((peek(g_peek_loc) << 8) | (peek(g_peek_loc+1))) >> 16 << (g_peek_off+bitjump)) & (2^(bitjump)-1)
  g_peek_loc += (g_peek_off+bitjump)\8
  g_peek_off = (g_peek_off+bitjump)%8
  return val
end
```

This game fills up 99.5% of the cartridge's data section with sprites and data. Unfortunately leaving no space for Pokemon cries. But wait!!! With some obfuscated poke logic, you can apply a filter to the packed data, resulting in 252 unique cries with 1 sfx reserved for UI beeps. Again, try replacing all the code from `LOAD #PICODEX_DUAL` with this snippet to test it out:

```
for iloc=0x3200, 0x4278, 68 do
  -- remove loops
  -- set speed to 7
  -- set filters to max
  poke4(iloc+64, 0x.07d7)

  for loc=iloc, iloc+63, 2 do
    -- only triangle/saw/tilted/square waves
    -- set volume to 6
    -- remove high pitch notes
    poke2(loc, %loc & 0x70df | 0x0a00)
  end
end

-- play bulbasaur's cry with an empty game loop
sfx(0,0,8,8) function _update() end
```

## And the code
Ah yes. The code... I'll stick with There is way too much that I could cover , the code. I won't go into the general design, but The true secret to getting 

The code for this game had gone over the limits many times throughout development, and each time required refactoring to fit more moves and battle logic.


and each time reucharacter, token, and compression limits multiple times throughout development. [Shrinko8]() was again a huge help to bring down the compression and character limits.

Scope creep management. Removed features. All UI uses same grid based system. zobj data function. heavy use of _env, _ENV changes for some code paths.

This was easily overcome by using [shrinko8]() with minification enabled. The compression limit was also a challenge at times, for example near the end of development I had to move all Pokemon names to the data section, but keep item/move names in the code section to help lower code compression even after minification. But PICO-8's token limit was the real problem.

And there are 
I designed the entire UI to reuse the same grid based system. This helps free up token space for the battle system.

I reused my data unpacking function called `zobj`, which costs 160 tokens up fr.9uThere is a data unpacking function called `zobj` that costs 160 tokens up front, but easily helps save thousands of tokens. It is used everywhere possible in the code base.
I designed the entire Ui 
I have a data unpacking function called `zobj` that costs 160 tokens up front,

I 

I had to make some tradeoffs, like near the end devof the storing Pokemon names in the data section, but keeping all other names in the code section.

all the code limits multiple times. both the compression, character, and 
his game is very close to the limits of AI.


Getting all the code to fit was a long coding and design nightmare. 
development,  o parPicodex Dual has been For the last maPicodex Dual really Picodex Dual challenges both the compression limits


They are just a filter over all the 

cries are 

And finally, Pokemon cries are just a filter over all the previously mentioned data that resides in the sfx section of the cartridge.

 unless the foe is digging, thunder can hit a flying though2 , but misses when the foe uses dig, but

it now has a 30% chance to paralyze the foe (with the same type restrictions), thunder now always hits when the weather is rainy, but misses when the opponent uses dig, 

pow was changed t, if the paralyzed.

oves gets 

existing Pokemon keep all their original moves plus many new moves to add to their from RBYPokemon learn a lot more moves in GSC.
Not only is there lots of new Pokemon, but existing Pokemon new data, but existing Pokemon now learn more moves than before.

but the existing , but a lot of the existing stuff

Not to mention all 151 existing Pokemon have a new stat (

41 hold items.

100 new pokemon.

Don't forget all Pokemon

Gen-2 has 86 new moves. That doesn't seem like too much compared to the 165 existing moves from Gen-1 games, however many of the gen-1 moves share the same logic. That is hardly the case with all the moves added in gen-2.

Before digging into the game itself, I'll first explain why gen-2 

TODO: describe how thunder changed from relatively simple, to pretty complex: https://bulbapedia.bulbagarden.net/wiki/Thunder_(move)


and how its and its more, I'll explain why GSC a bit how  gen-2 games are differences why gen-2 en2 ihere are  I'd like to explain  into 
Why this is a challenge. chal
1. 
- GSC has 86 new moves, most of them having a completely original behavior.

- GSC complicated behavior for many existing moves. For example 
- GSC has 41 hold items that had battle-related effects. RBY had 0 hold items.
- GSC intro
- There are many changes to existing moves.

rthan that, but items in the game, but they didn't 

 that hade that holding items. There are 41 items Pokemon could hold that actually had any battle-related effect.

Which translates to reserving as many code tokens as I can to battle logic.
  - For example, 
  - Furthermore, many existing 

 and code space. And further made many of the existing moves more complex. More move behaviour 
- Gen-2 introduced items with many of othe

However most of these moves have unique behavior which means lots of code space for edge cases.

most of these moves  And further complicated many 

prThis was a much more ambition It may sound

the next generato


It Proving  wrong is probably my I shouldn't have written that. Proving myself wrong is the biggest motivation.

, because proving myself wrong is 

One of the most motivating things 
If there is anything I hate more, it would be my past self telling my future self that something isn't possible.




I was safe from starting any more big side projects, until I Until I found myself 

I was safe from starting any more I was content It was . I was a quiet Saturday morning in September, I 

That is until I found myself doing something dangerous on a Saturday morning.

Until I had a dangerous thought . Oh how I oh how I was ... Until I started doing something very dangerous on a quiet

until a quiet Saturday morning in September later that year I found myself 

But on a quiet Saturday morning a weekend in SBut on a quiet Saturday morning in September I , I dangerously

But on a  But on a quiet Saturday morning in September 2023 something was telling me that I didn't go far enough.

a lonely SaturAt that I thought I had pushed pico-8 its limit,

 to the limit and


, and I thought I had done it all, until quiet I thought was pretty happy with that project, but doubts

If you asked me to make a game twice as big, but 

When I published [picodex]() in April of 2023, I thought I had done it all. This was 
After squeezing the entire 

I published [picodex](), a battle simulation game for Pokemon Red/Blue/Yellow, in April of 2023.

for  for Pokemon 32kba pico-8 game for  for 32kb Pico-8 cartridge for the Pokemon battle srecreated the battle spublished a 32kb Pokemon battle simulator for the games Red/Blue/Yellow.

okemon Gen 1 Picodex is a recreation of the entire Pokemon Gen 1 battle system in a single Pico-8 cartridge last year.


game I made April 2024 was when I released was when I Last year I recreated the battle system for Pokemon Red/Blue/Yellow.

Pokemon battlereated a Pokemon Gen1 battle simulation.

 published a Pokemon Gen1 Battle Simulation This was a very fun project and made me flex my pico skills.

1 created a Pokemon Gen1 battle simulation  [picodex](), a recreation of 

