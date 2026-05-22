# TidyTuesday in Typst

My weekly [TidyTuesday](https://github.com/rfordatascience/tidytuesday) figures, drawn entirely in [Typst](https://typst.app) with [Gribouille](https://m.canouil.dev/gribouille), a grammar-of-graphics package.

Live gallery: <https://m.canouil.dev/tidytuesday>.

## Layout

Each entry sits under `tidytuesday/year/month/day` matching the dataset's date.

```text
tidytuesday/2026/05/26/
├── index.qmd     # gallery page; embeds the figure and its Typst source
├── _plot.typ     # Typst figure (the leading "_" keeps Quarto from rendering it directly)
└── data/*.csv    # the week's downloaded data
```

The figure is compiled at render time by the [`typst-render`](https://github.com/mcanouil/quarto-typst-render) Quarto extension, which turns the `{typst}` block in `index.qmd` into light and dark SVGs (`plot-light.svg`, `plot-dark.svg`) that follow the site theme.
Those SVGs are build artifacts (git-ignored), so there is no separate compile step and no committed image.

Shared assets live under `assets/`:

```text
assets/
├── brand/_brand.yml        # colour palette shared with figures
├── listings/gallery.ejs.md # custom gallery listing template (read as markdown)
└── scss/
    ├── theme.scss          # custom complete theme (default / light)
    └── theme-dark.scss     # dark overrides, layered on top
```

Fonts come from [Bunny Fonts](https://fonts.bunny.net) (GDPR-friendly), linked in the page head.

## Add a week

```sh
scripts/new-week.sh 2026-05-26   # create the folder and fetch the CSV(s)
# edit tidytuesday/2026/05/26/_plot.typ to map the real columns
quarto preview                   # browse locally; figures compile on render
```

`new-week.sh` needs [`gh`](https://cli.github.com), `jq`, and `curl`.
Typst downloads Gribouille and its CeTZ backend on first render (network required once).

## Tooling

- Typst `0.14.2`.
- Gribouille `0.1.0` (CeTZ `0.5` backend).
- Quarto `1.9.37`.

## Publishing

Pushes to `main` trigger `.github/workflows/publish.yml`, which renders the site and deploys it to GitHub Pages.
The custom domain `m.canouil.dev` is configured in the repository's Pages settings.

## Licence

[CC BY-NC-SA 4.0](LICENSE). Source datasets belong to their respective TidyTuesday curators.
