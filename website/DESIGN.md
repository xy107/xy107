# Design direction

An archival collection for the community behind XY107. The visual emphasis is the Chinese character 义, tying the collection's Hero/Songjiang vocabulary to solidarity, alongside the actual 107 + 1 structure. Placeholder records remain explicit; the website invents no hero identities or final artwork.

Design variance 6, motion intensity 3, visual density 4. The design skills inform the public-facing composition; transaction controls use Radix primitives for accessible behavior.

## Tokens

- Paper `#f3f5f8`: consistent light page surface.
- Ink `#21314a`: text.
- Blue `#294d86`: actions and availability.
- Secondary `#59677a`: supporting text.
- Surface `#e6ebf2`: placeholders and grouped information.
- Line `#d6dce5`: structural separation.

Public Sans supports reading and controls; DM Sans gives headlines, the header wordmark, and token numbers a coherent voice. Project image logos live in `../assets/logo`. A system Chinese serif renders the single heritage character. The page uses one light theme, with no inverted sections or theme toggle. Controls use 5–6px radii; collection surfaces use 8px; dialogs 10px. Error red is semantic only.

## Layout plan and review

```
Brand | Minting / Token sale | project links | wallet
Network
Statement                     | 义 / 107 + 1
Four live metrics
Collection heading
Filters                       | Search
Hero | Hero | Hero | Hero
Reserved-token explanation
Footer
```

A generic NFT storefront would feature invented art, floor prices and urgency. This direction instead derives its central character and numbering from the repository and uses honest on-chain mint/metadata information. The collection grid is required by the brief; uncommitted artwork is never represented by speculative images.

The sale page retains the same surfaces and navigation, placing contribution rules next to the form; the form comes first on mobile. No countdown is shown because the contract has no sale deadline.

## Interaction and preflight

- Available cards reveal the mint action on hover/focus, and keep it visible on touch layouts.
- Card hover movement is limited to 3px, disabled under reduced motion.
- Radix dialogs contain focus, support Escape, and present visible titles and descriptions.
- Disconnected card clicks open wallet selection; connected eligible clicks open transaction review. Reserved/finalized cards open details for connected wallets.
- Pending, committed, unknown, available and burned states carry text labels; color is never the sole signal.
- Errors offer retry or actionable feedback. No stats are fabricated while loading or unconfigured.
- One theme and one accent; no decorative status dots except the actual selected network indicator.
