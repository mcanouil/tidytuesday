#import "@local/gribouille:0.0.0": *

// Prepended before every {typst} block by typst-render (see _quarto.yml), so a
// block never has to import Gribouille itself.
//
// Nothing wraps the theme functions: Gribouille reads the light / dark values
// declared in _quarto.yml straight from the `typst-render-foreground` and
// `typst-render-background` inputs typst-render passes to `typst compile`, so
// `theme-minimal()` and friends already track the site theme toggle.
