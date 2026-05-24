#import "@local/gribouille:0.0.0": *

// Prepended before every {typst} block by typst-render (see _quarto.yml).
// Wraps the Gribouille theme functions so each plot picks up the
// `_typst_render_foreground` / `_typst_render_background` colours injected
// from the light / dark values declared in _quarto.yml. Figures then track
// the site theme toggle. Because this preamble imports Gribouille, the
// {typst} blocks must NOT import it again (a re-import rebinds these themes).

#let _theme_grey = theme-grey
#let _theme_minimal = theme-minimal
#let _theme_classic = theme-classic
#let _theme_void = theme-void
#let _theme_custom = theme

#let _theme_with_document_colours(
  theme_fn,
  ink: auto,
  paper: auto,
  accent: rgb("#0f8b8d"),
  ..fields,
) = {
  let args = (accent: accent)
  if ink != auto {
    args.insert("ink", ink)
  } else if _typst_render_foreground != none {
    args.insert("ink", _typst_render_foreground)
  }
  if paper != auto {
    args.insert("paper", paper)
  } else if _typst_render_background != none {
    args.insert("paper", _typst_render_background)
  }
  theme_fn(..args, ..fields)
}

#let _wrap-theme(theme_fn) = (
  ink: auto,
  paper: auto,
  accent: rgb("#0f8b8d"),
  ..fields,
) => _theme_with_document_colours(
  theme_fn,
  ink: ink,
  paper: paper,
  accent: accent,
  ..fields,
)

#let theme-grey = _wrap-theme(_theme_grey)
#let theme-minimal = _wrap-theme(_theme_minimal)
#let theme-classic = _wrap-theme(_theme_classic)
#let theme-void = _wrap-theme(_theme_void)

#let theme(..fields) = {
  let named = fields.named()
  if (
    named.at("ink", default: none) == none and _typst_render_foreground != none
  ) {
    named.insert("ink", _typst_render_foreground)
  }
  if (
    named.at("paper", default: none) == none
      and _typst_render_background != none
  ) {
    named.insert("paper", _typst_render_background)
  }
  _theme_custom(..named)
}
