#import "@local/gribouille:0.0.0": *
#import "@local/keisen:0.0.0" as keisen

// Prepended before every {typst} block by typst-render (see _quarto.yml), so a
// block never has to import Gribouille or Keisen itself.
// Keisen is imported as a module (`keisen.display-table(...)`), because a star
// import clashes with Gribouille: theme-minimal, format-number and
// format-percent exist in both.
//
// Nothing wraps the theme functions: Gribouille reads the light / dark values
// declared in _quarto.yml straight from the `typst-render-foreground` and
// `typst-render-background` inputs typst-render passes to `typst compile`, so
// `theme-minimal()` and friends already track the site theme toggle.

// Draws a figure at its natural height and only scales it down when the page is
// shorter, so the featured image shows the same figure as plot.svg with empty
// bands left and right. `draw` takes the width and height to draw at. Give
// `natural-height` for a plot that fills any height it gets, and leave it to
// `auto` for content that has a height of its own, such as a table.
#let fit-page(draw, natural-height: auto) = layout(size => {
  let natural = if natural-height == auto {
    measure(width: size.width, draw(size.width, auto)).height
  } else {
    natural-height
  }
  if natural <= size.height {
    draw(size.width, size.height)
  } else {
    align(center + horizon, scale(size.height / natural * 100%, reflow: true, draw(size.width, natural)))
  }
})
