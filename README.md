# game-texture-assets

**Go-big** house vault of **CC0** PBR / environment textures for JimmyTheHat games.

> Not sprites (see `game-visual-assets`) and not 3D mesh kits (see `game-3d-assets`).
> Brand media stays in private Meniscus / Ilerioluwa vaults.

## Inventory (2026-07-13 haul)

| Vendor | Path | Count | Res | License |
|--------|------|--------------|-----|---------|
| ambientCG | `vendor/ambientcg/` | **1940** materials (near-full catalog) | 1K-JPG maps | [CC0](https://ambientcg.com/license) |
| Poly Haven | `vendor/polyhaven/` | **780** textures (full catalog) | 1K JPG maps | [CC0](https://polyhaven.com/license) |

Each ambientCG folder typically includes Color / Normal / Roughness / AO (and extras).
Each Poly Haven folder typically includes Diffuse, nor_gl, Rough, AO.

## Fetch / expand further

```powershell
# Need more ambientCG (site has 2000+):
pwsh scripts/fetch-ambientcg-parallel.ps1 -Count 2000 -Parallel 12

# Poly Haven is already complete at 1K; re-run is resume-safe:
pwsh scripts/fetch-polyhaven-parallel.ps1 -Parallel 12
```

Scripts also live under `C:\Users\hrmread\work\fetch-*-parallel.ps1`.

## Use

Copy only the materials you need into a game’s `assets/textures/` — do **not**
npm-link this whole repo into a web bundle (multi‑GB).

## Attribution

See `ATTRIBUTION.md`. Credit is optional under CC0; we keep the ledger.

## First-session tip

Before wiring textures into a game, skim `## Use` above: copy only the materials you need into that game's `assets/textures/`. Never npm-link or bundle this whole vault (multi-GB). Sprites live in `game-visual-assets`; mesh kits in `game-3d-assets`.

