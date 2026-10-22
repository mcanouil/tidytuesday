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
