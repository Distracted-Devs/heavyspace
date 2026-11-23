# Player growth
**Status:** planned (Phase 2, step 2.5)

The player gets bigger as it collects mass, so it can consume mass that was
bigger than it. Agreed: the player's radius grows with its mass. Thrust
doesn't scale: only the shop changes booster strength.

## Contracts
None agreed yet. Agree each API's contract with the user at the start of its
step.

## Steps

### 2.5 Player grows with mass
- The player's radius (mesh, collider, camera distance) follows its mass.
  Thrust and torque are unchanged.
