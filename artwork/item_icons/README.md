# Approved item artwork sources

These are the source images, generation prompts, checksums and deterministic
recipes for the shipped 201-frame item atlas. See the runtime
`assets/item_icons/CREDITS.md` (inside the Bag component in the Suite) for
Openmon attribution and the distinction between published CC0 sources and new
AI-assisted fan artwork. No underlying Pokémon IP clearance is claimed.

Only final approved artwork is included. The runtime ZIP excludes this source
directory and needs neither a generator nor network access. `coverage.json`
records all 276 named IDs, intentional aliases and dynamic TM/HM type frames.
`main.lua` is the deterministic LÖVE image compiler; its configuration disables
window and audio modules. Its original output layout is a `payload` folder.
