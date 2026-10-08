# STRIDE — Visual design

The interface follows the app icon: a diagonal gradient from light orange (top right)
to crimson (bottom left), a thick white rounded route, and white ring endpoints with a
crimson dot. This page records where each color comes from and the contrast rules the
screens obey, so a change to the icon or the palette has a checklist.

Code: `STRIDE/Design/BrandPalette.swift` (colors) and `STRIDE/Design/BrandStyle.swift`
(backgrounds, cards, buttons, route markers). Tests: `STRIDETests/BrandPaletteTests.swift`.

## Palette

The three base colors are sampled from `AppIcon.appiconset/icon-1024.png`. A test reads
the icon file and fails if the palette stops matching it.

| Name | Hex | Source / use |
|------|-----|--------------|
| `orange` | `#FE8726` | Icon, top-right corner. Start of the gradient. |
| `coral` | `#F66534` | Icon, middle of the diagonal. |
| `crimson` | `#E82A4D` | Icon, bottom-left corner, and the dot inside the route endpoints. |
| `ink` | `#D01F47` | Derived. A deeper crimson for text and fills on white. |
| `inkOnDark` | `#FF7A90` | Derived. Accent for text and icons on dark surfaces. |

`ink` exists because `crimson` on white is 4.3:1, below the 4.5:1 that WCAG asks for
body text; `ink` reaches 5.3:1.

## Contrast rules

Contrast ratios are computed with the WCAG formula (`BrandColor.contrast(with:)`) and
asserted in the tests.

- **Large text may sit directly on the gradient.** The timer is large text (3:1 needed).
  White on the gradient measures 2.4:1 over `orange`, 3.1:1 over `coral` and 4.3:1 over
  `crimson`, so over the lightest corner it is below the 3:1 mark. The timer has a soft
  dark shadow to help, which was judged by eye on the simulator, not measured.
- **Small or secondary text goes on an opaque card** (`brandCard`), which uses the system
  background and so keeps the system's contrast in light and dark mode.
- **Secondary buttons** are a black layer at 30 % under white text: 4.7:1 over `orange`,
  the lightest part of the gradient, and more elsewhere.
- **Primary buttons** are white capsules with `ink` text (5.3:1).
- **Dark mode** puts a 30 % black layer over the gradient. The same layer over `orange`
  gives white text 4.7:1, and the other stops are darker. `inkOnDark` against the dark card color (`#1C1C1E`)
  is 6.8:1.
- **Tab bar.** It floats over the gradient on a glass pill that is light in light mode
  and dark in dark mode, so its selected tint is a deep crimson (`#7A0F2B`) in light mode
  and `inkOnDark` in dark mode. This one was judged on the simulator, not computed: the
  glass is rendered by the system and its color depends on what is behind it.

## Components

| Component | What it is |
|-----------|-----------|
| `BrandBackground` / `.brandScreen()` | The gradient behind a screen, dimmed in dark mode. |
| `.brandCard()` | Opaque rounded card with a soft shadow, like the shadow under the icon's route. |
| `.brandMapFrame()` | Rounded map with a 3 pt white edge and a soft shadow. |
| `.brandPrimary` / `.brandSecondary` / `.brandFilled` | Full-width capsule buttons: white on the gradient, dark translucent on the gradient, accent fill inside a card. |
| `RouteEndpointMarker` | White ring with a crimson dot, the icon's route ends. |
| `BrandBadge` | Rounded gradient square with a white SF Symbol, used in the history list. |

On maps (`RouteMapView`) the route is a crimson line (6 pt) over a white casing (10 pt),
which reads on both the light and the dark map styles and echoes the icon's white route.

## Not verified

- Dynamic Type at the largest accessibility sizes was not checked. Only the timer scales
  with `@ScaledMetric` (and shrinks to half its size before truncating).
- Contrast was computed for the colors above, not measured on a physical screen under
  sunlight, which is where a running app is used.
