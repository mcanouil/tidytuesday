# Vendored fonts

Typst rasterises text to paths when it compiles a figure, so the faces a figure names have to exist on the machine that renders it.
The CI runner (`ubuntu-latest`) installs no fonts, so anything not vendored here silently falls back in the published output.

These files are passed to the Typst CLI through `extensions.typst-render.font-path` in `tidytuesday/_metadata.yml`.

Every family below is licensed under the SIL Open Font License 1.1.
Each family's `OFL.txt` is kept alongside its font files, as the licence requires.
All files were taken from [`google/fonts`](https://github.com/google/fonts).

| Family | Files | Upstream | Used by |
| --- | --- | --- | --- |
| Alegreya | `Alegreya[wght].ttf`, `Alegreya-Italic[wght].ttf` | [`ofl/alegreya`](https://github.com/google/fonts/tree/main/ofl/alegreya) | 2026-07-14 |
| Alegreya Sans | `AlegreyaSans-Regular.ttf`, `AlegreyaSans-Bold.ttf` | [`ofl/alegreyasans`](https://github.com/google/fonts/tree/main/ofl/alegreyasans) | 2026-07-14 |
| Public Sans | `PublicSans[wght].ttf` | [`ofl/publicsans`](https://github.com/google/fonts/tree/main/ofl/publicsans) | 2026-07-21 |
| IBM Plex Mono | `IBMPlexMono-Regular.ttf`, `IBMPlexMono-Medium.ttf` | [`ofl/ibmplexmono`](https://github.com/google/fonts/tree/main/ofl/ibmplexmono) | 2026-07-21 |
| Archivo | `Archivo[wdth,wght].ttf` | [`ofl/archivo`](https://github.com/google/fonts/tree/main/ofl/archivo) | 2026-07-28 |
| Lato | `Lato-Regular.ttf`, `Lato-Bold.ttf` | [`ofl/lato`](https://github.com/google/fonts/tree/main/ofl/lato) | 2026-07-28 |

Files in square brackets are variable fonts.
Typst 0.15 reads their weight axis, so one file covers every weight a figure asks for.
Where a family ships only static instances upstream, the individual weights the figures use are vendored instead.

## Adding a family

Only add fonts that a figure actually uses, and only under a licence that permits redistribution.

1. Copy the font files and the family's `OFL.txt` into this directory, naming the licence `<Family>-OFL.txt`.
2. Confirm Typst sees the family and every weight it needs:

   ```sh
   typst fonts --font-path assets/fonts --ignore-system-fonts --variants
   ```

3. Add a row to the table above.

Earlier weeks name faces that are not vendored yet (`Oswald`, `Fira Sans`, `PT Serif`, `Big Caslon`), so their published figures still fall back.
The first three are redistributable and could be added here; `Big Caslon` is Apple's and cannot be.
