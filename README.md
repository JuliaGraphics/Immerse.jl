![splash](images/splash.png)

# Immerse

[![Build Status](https://travis-ci.org/JuliaGraphics/Immerse.jl.svg?branch=master)](https://travis-ci.org/JuliaGraphics/Immerse.jl)

Immerse is a wrapper that adds graphical interactivity to Julia plots.
Currently, Immerse supports
[Gadfly](https://github.com/dcjones/Gadfly.jl).  Existing or
in-progress features include pan/zoom, hit-testing, and multi-point
selection.  Documentation is currently a work-in-progress.

# Usage

By and large, you plot just as you would in Gadfly:

```jl
using Immerse, Distributions
X = rand(MultivariateNormal([0.0, 0.0], [1.0 0.5; 0.5 1.0]), 10000)
plot(x=X[1,:], y=X[2,:], Geom.hexbin)
```
However, rather than being displayed in a browser window, you'll see your figure in a Gtk window:

![window](images/zoom_hexbin_snapshot.png)

The toolbar at the top permits zooming and panning, using the defaults set by [GtkUtilities](https://github.com/timholy/GtkUtilities.jl).  The left button allows you to rubberband-select a zoom region, and use your mouse wheel or keyboard to pan or change the zoom level.  The 1:1 button restores the full view

## Lasso selection

The next button on the toolbar allows you to select a group of points for further analysis by drawing a "lasso" around them:

![lasso](images/lasso_snapshot.png)

By default, this pops up a dialog asking you which variable in `Main` you ant to save the selected indexes to:

![lassodialog](images/lasso_dialog_snapshot.png)

You can alternatively define a custom callback function; see the help for `lasso_initialize` by typing `?lasso_initialize` at the REPL.

## Hit testing

You can add extra interactivity by setting up callbacks that run whenever the user clicks on an object. A demonstration of this capability is exhibited in the `test/hittesting.jl` test script:

![hittest](images/hittest_snapshot.png)

Here the red circles are drawn around the dots that the user clicked on; see also the console output that showed the results of clicking on the line segments between the dots.

Note that hit testing is disabled while the "zoom" button is active.

## Figure windows

Each figure is addressed by an integer; for a window displaying a
single Gadfly figure, by default this integer appears in the window
title.

There are a few simple utilities for working with figure windows:

- `figure()` opens a new figure window. This will become the default
plotting window.
- `figure(3)` raises the corresponding window and makes it the default.
- `gcf()` returns the index of the current default figure.
- `scf()` shows the current figure (raising the window to the top).
- `closefig(3)` destroys Figure 3, closing the window.
- `closeall()` closes all open figure windows.


## Issues

#### When I type `scf()`, nothing happens

Your window manager may have "focus stealing prevention" enabled. For
example, under KDE, go to the Kmenu->System Settings->Window
behavior->Window behavior (pane)->Focus (tab) and set "Focus stealing
prevent" to "None".  Alternatively, if you want to limit this change
to julia, use the "Window rules" pane and add a new setting where
"Window class (application)" is set to "Regular Expression" with value
"^julia.*".
