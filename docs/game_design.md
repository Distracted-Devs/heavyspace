# Overview
- This is a 3D third-person space flight game.
- The player controls a spaceship and must collect "mass" to get bigger so it can consume mass that is bigger than itself.
- The player experiences gravity from mass bigger than itself, but not from mass smaller.
- Mass objects do not experience gravity.
- The player can use both keyboard and controller.
- This is a "number goes up" game where the player starts underpowered and get stronger to create broken and satifying interactions.
- Semi-realistic physics movement is a core pillar (eg. Newton's laws of motion), but elements can be non-physical (eg. rotational drag).
- Levels are procedurally generated.

# Game Design
## Core Game Loop
- The player warps into the game and must navigate space to collect mass pickups smaller than itself, while avoiding crashing into bigger objects.
- The player collects as much as it can and if they have enough can spend that mass to warp out.
- Once the player has warped out there is a shop phase where they can upgrade various stats.

## Controls
- Booster
- Camera look
- Rotation for each of the 3 degrees of freedom
- Pause/Unpause
- Warp out

## Shop Stats
- Starting size
- Booster fuel tank size
- Booster fuel refill rate
- Booster strength
- Pickup radius

