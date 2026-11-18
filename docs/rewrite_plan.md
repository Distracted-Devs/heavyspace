# Phase 0
- Strip the project back to only the player movement by removing mass collectables and have a test planet in a test level with the player
- Fix any issues in the code.
- Ensure current code matches design paradigms.

# Phase 1: Core flight 
- Add all controls with controller support
- Ensure gravity and mass works as intended
- Add the lose condition

# Phase 2: Procedural generation
- Add mass pickups and a procedural generation manager
- Make sure mass pickups spawn around ("in orbit") of bigger masses
    - There is a hierarchy of orbits for the procedural generation (moons upon moons upon moons)
- Game must be 60fps

# Phase 3: Game Loop
- Ensure the player can collect mass, once enough has been collected then they can warp out
- Can spend that mass in the shop to upgrade for the next run.

# Phase 4: HUD and art
- Add a HUD and minimap
- Integrate the art in dev-ayla

# Phase 5: Game Feel and Juice
- Add controller shake, camera shake, camera movement, VFX, etc
