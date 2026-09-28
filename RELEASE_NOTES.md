# 0.1.34

- Restore G9 portraits in the party Stats and Moves screens, including Starly
  and other National Dex species, in both Gen 1 and Gen 2.
- Preserve G9 animation, shiny/female variants and summary settings. Use the
  dedicated summary renderer in current G9 versions and retain older support.
- Restore translation lookups for additional menu labels and individual
  summary types. Fix Japanese nickname truncation with Gender Mod and preserve
  translated stat labels at compact sizes.

Use the suite's BATTLE ART or DEFAULT menu-sprite source, enable G9's master
switch and SUMMARY SPRITES, and install the provider's artwork separately.
An explicit CRYSTAL selection continues to use that provider. DEX SPRITES can
be disabled independently of summary portraits.

Translation assets remain supplied by the installed translation mod. Custom
labels without a catalog entry continue to use their English fallback.

Validated on game 0.3.29 with G9 Battle Sprites 2.0.1 and 3.6.2, National Dex,
Gen9Dex, and the Translation Mod Generator's current integration with Fusion
Pixel Japanese. Automated test windows stayed muted and nonactivating.
