# TEXTURES — how to dig more free packs (legal)

Agents: “scrape hard” means **CC0/public-domain APIs and pack pages**, not piracy.

## Instant wins already vendored here

| Source | Path | Count | License |
|--------|------|-------|---------|
| Kenney | `vendor/kenney/` | 40+ packs | CC0 |
| ambientCG PBR | `vendor/ambientcg/` | 40 materials @ 1K-JPG | CC0 |
| Poly Haven | `vendor/polyhaven/` | 25 textures @ 1K | CC0 |

## Dig deeper (scripts)

```powershell
# More ambientCG (next page / other queries)
pwsh ../../work/fetch-ambientcg.ps1 -Count 80

# More Poly Haven
pwsh ../../work/fetch-polyhaven.ps1 -Count 50

# More Kenney by slug
pwsh scripts/fetch-kenney.ps1 -Slug <slug>
pwsh ../../work/bulk-fetch-kenney.ps1 -Lib visual -SlugsCsv 'a,b,c'
```

## Other CC0 mines (catalog only until verified)

| Mine | Notes |
|------|-------|
| https://ambientcg.com | 2000+ materials — we mirrored a popular slice |
| https://polyhaven.com/textures | 700+ textures — slice mirrored |
| https://kenney.nl/assets | Keep fetching leftovers |
| https://quaternius.com | Often CC0 — confirm per pack before vendor |
| OpenGameArt **CC0 filter only** | Many CC-BY — **do not** vendor BY/NC blindly |
| https://opengameart.org/content/liberated-pixel-cup | Mixed — check license |

## Do not

- Steam Workshop / Unity Asset Store “free” that are NC or non-redistributable
- Scraping copyrighted itch paid packs
- Whale / nature field recordings without a clear CC0 page
