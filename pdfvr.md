
Absolutely. The key idea is that a good PDF viewer is **not a single image that gets scaled to fit the screen**. It is a document renderer with a viewport, a page coordinate system, a zoom transform, scrolling state, and a rendering/cache pipeline.

Below is a detailed implementation-oriented model you can give to an LLM when building or fixing your PDF viewer.

## 1. The mental model

Think of the PDF viewer as five separate systems:

```text
PDF File
   ↓
PDF Parser
   ↓
Document Model
   ↓
Page Renderer
   ↓
Viewport / Zoom / Scroll
   ↓
Screen
```

And separately:

```text
User Input
   ├── mouse wheel
   ├── pinch
   ├── Ctrl/Cmd + wheel
   ├── zoom buttons
   ├── keyboard
   ├── drag
   └── scrollbar
          ↓
   Viewport Controller
          ↓
   zoom + scroll + page position
```

The most important distinction is:

> **The PDF document has its own coordinate system. The screen has another coordinate system. The viewer maintains a transformation between them.**

That is what makes zooming, scrolling, text selection, annotations, and different page sizes possible.

---

# 2. A PDF is not normally an image

A PDF page is fundamentally a collection of drawing instructions.

Conceptually, a page might contain:

```text
Draw text:
    "Hello World"
    at (100, 200)
    using Helvetica
    size 14

Draw rectangle:
    x = 50
    y = 50
    width = 300
    height = 100

Draw image:
    x = 400
    y = 200
    width = 200
    height = 150

Draw path:
    move to ...
    line to ...
    curve to ...
    stroke ...
```

So the PDF renderer interprets these instructions and produces pixels.

This is important because:

```text
PDF page
    ↓
render at zoom = 1
    ↓
pixels
```

is fundamentally different from:

```text
PDF page
    ↓
render at zoom = 2
    ↓
pixels
```

The second rendering should generally be generated at the appropriate resolution rather than simply taking the first bitmap and stretching it.

---

# 3. The PDF document has a page model

A PDF document can contain:

```text
Document
 ├── Page 1
 ├── Page 2
 ├── Page 3
 ├── ...
 └── Page N
```

Every page can have different properties.

For example:

```text
Page 1:
    width  = 612 PDF units
    height = 792 PDF units

Page 2:
    width  = 612
    height = 792

Page 3:
    width  = 842
    height = 595
```

Therefore:

> **Do not assume every page has the same dimensions.**

A PDF viewer should be capable of displaying:

* portrait pages
* landscape pages
* A4
* Letter
* Legal
* custom page sizes
* scanned pages
* mixed-size documents
* rotated pages

---

# 4. PDF coordinates are different from screen coordinates

Suppose a PDF page is:

```text
612 × 792
```

These aren't necessarily pixels.

They are PDF coordinate units.

The viewer converts them into screen pixels.

At:

```text
zoom = 1
devicePixelRatio = 1
```

you might conceptually have:

```text
PDF:
612 × 792

Screen:
612 × 792
```

At:

```text
zoom = 2
```

you get:

```text
PDF:
612 × 792

Screen:
1224 × 1584
```

The page's **logical size has not changed**.

Only its representation on the screen has changed.

This distinction is extremely important.

---

# 5. Zoom should be treated as a transform

The easiest mental model is:

```text
screenX = documentX × zoom
screenY = documentY × zoom
```

For example:

```text
documentX = 100
documentY = 200
zoom = 2
```

becomes:

```text
screenX = 200
screenY = 400
```

If:

```text
zoom = 0.5
```

then:

```text
screenX = 50
screenY = 100
```

So zoom is essentially a scaling transformation.

But a real viewer also needs scrolling.

Therefore a more useful equation is:

```text
screenX = documentX × zoom - scrollX
screenY = documentY × zoom - scrollY
```

This is one of the core equations of a PDF viewer.

---

# 6. The viewport

The viewer has a visible area.

For example:

```text
Browser window
┌─────────────────────────────┐
│                             │
│        VIEWPORT              │
│                             │
│    ┌─────────────────┐      │
│    │                 │      │
│    │     PDF PAGE    │      │
│    │                 │      │
│    │                 │      │
│    └─────────────────┘      │
│                             │
└─────────────────────────────┘
```

The viewport might be:

```text
viewportWidth  = 1200
viewportHeight = 800
```

The document might be much larger:

```text
documentWidth  = 3000
documentHeight = 9000
```

The viewport is essentially a **window looking into the document**.

---

# 7. Do NOT confuse "page size" with "viewport size"

This causes many PDF viewer bugs.

There are three separate concepts:

### PDF page size

Example:

```text
612 × 792 PDF units
```

### Rendered page size

At zoom 1.5:

```text
918 × 1188
```

### Viewport

Maybe:

```text
1200 × 800
```

These are not interchangeable.

---

# 8. Fit-to-width is only one viewing mode

A common mistake is implementing:

```text
zoom = viewportWidth / pageWidth
```

and then continually recalculating it.

That produces:

> "Always fit the PDF to the width."

That is **not how a normal PDF viewer should behave**.

Instead, fit-to-width should be a **viewing mode/action**.

For example:

```text
zoomMode:

FIT_WIDTH
FIT_PAGE
ACTUAL_SIZE
CUSTOM
```

When the user chooses:

```text
Fit Width
```

calculate:

```text
zoom = availableWidth / pageWidth
```

But after that, if the user manually zooms:

```text
FIT_WIDTH
   ↓
user zooms in
   ↓
CUSTOM
```

The viewer should no longer force the page back to fit-width.

---

# 9. Example of the fit-width calculation

Suppose:

```text
viewport width = 1000
page width = 612
```

Then:

```text
zoom = 1000 / 612
     ≈ 1.634
```

The page becomes:

```text
width  = 612 × 1.634
       ≈ 1000
```

So it fits exactly.

But if the user clicks:

```text
Zoom In
```

you might change:

```text
zoom = 1.634
```

to:

```text
zoom = 1.8
```

Now:

```text
page width = 612 × 1.8
           = 1101.6
```

The page is wider than the viewport.

That is perfectly valid.

A horizontal scrollbar may now become necessary.

---

# 10. Fit-to-page is different

Fit-to-page means:

> Make the entire page visible inside the viewport.

Calculate two possible zoom levels:

```text
widthZoom  = viewportWidth  / pageWidth
heightZoom = viewportHeight / pageHeight
```

Then:

```text
zoom = min(widthZoom, heightZoom)
```

Example:

```text
viewport = 1200 × 800
page     = 612 × 792
```

Then:

```text
widthZoom  = 1200 / 612 ≈ 1.96
heightZoom = 800 / 792  ≈ 1.01
```

Therefore:

```text
fitPageZoom = 1.01
```

The entire page fits vertically.

---

# 11. Actual size

"Actual size" generally means rendering around the PDF's natural scale rather than adapting it to the viewport.

Conceptually:

```text
zoom = 1
```

although the exact mapping to physical screen size can involve DPI/device assumptions.

The important behavior is:

> The viewer should not continually resize the page to fill the available width.

---

# 12. Zoom levels

A viewer can use either:

### Continuous zoom

```text
100%
101%
102%
103%
...
```

or discrete zoom steps:

```text
50%
66.7%
75%
100%
125%
150%
200%
250%
300%
400%
```

Discrete steps often feel better for toolbar buttons.

You can still support continuous pinch zoom.

---

# 13. Zoom should have limits

Never allow:

```text
zoom = infinity
```

or:

```text
zoom = 0
```

Use:

```text
MIN_ZOOM
MAX_ZOOM
```

For example:

```text
MIN_ZOOM = 0.25
MAX_ZOOM = 5
```

The exact values depend on the application.

The zoom operation should effectively be:

```text
newZoom = clamp(newZoom, MIN_ZOOM, MAX_ZOOM)
```

---

# 14. The most important zoom behavior: zoom around the cursor

This is where many bad PDF viewers feel terrible.

Suppose the user places the cursor here:

```text
┌─────────────────────────────┐
│                             │
│        PDF PAGE             │
│                             │
│            X ← cursor       │
│                             │
│                             │
└─────────────────────────────┘
```

They zoom in.

A bad implementation does:

```text
zoom
↓
center page
↓
user loses what they were looking at
```

A good implementation does:

```text
zoom around cursor
```

The point underneath the cursor remains underneath the cursor.

---

# 15. How cursor-centered zoom works

Suppose:

```text
mouseX = 500
mouseY = 300

oldZoom = 1
newZoom = 2

scrollX = 0
scrollY = 0
```

The document coordinate underneath the cursor is:

```text
documentX = (mouseX + scrollX) / oldZoom
documentY = (mouseY + scrollY) / oldZoom
```

Therefore:

```text
documentX = 500
documentY = 300
```

After changing zoom to 2, that same document point should appear at:

```text
documentX × newZoom
documentY × newZoom
```

which is:

```text
1000
600
```

But we want it to appear at:

```text
500
300
```

because that's where the cursor is.

Therefore adjust scrolling:

```text
newScrollX = documentX × newZoom - mouseX
newScrollY = documentY × newZoom - mouseY
```

So:

```text
newScrollX = 1000 - 500
           = 500

newScrollY = 600 - 300
           = 300
```

Now the same document point stays under the cursor.

This produces the familiar behavior of professional document viewers.

---

# 16. General zoom transformation

For a zoom from:

```text
oldZoom
```

to:

```text
newZoom
```

around screen point:

```text
(cursorX, cursorY)
```

calculate:

```text
documentX = (cursorX + scrollX) / oldZoom
documentY = (cursorY + scrollY) / oldZoom
```

Then:

```text
scrollX = documentX × newZoom - cursorX
scrollY = documentY × newZoom - cursorY
```

Then clamp the scroll positions to valid boundaries.

---

# 17. Zoom buttons should also have an anchor

When clicking:

```text
+
```

you need to decide what the zoom center is.

Common choices:

### Cursor position

Best if the cursor is available.

### Viewport center

Best for toolbar buttons.

For center-based zoom:

```text
anchorX = viewportWidth / 2
anchorY = viewportHeight / 2
```

Then use the exact same zoom transformation.

This means:

> Clicking "+" zooms toward the center of what you're currently looking at.

---

# 18. Pinch-to-zoom

On a touchscreen, two fingers produce:

```text
finger 1 = (x1, y1)
finger 2 = (x2, y2)
```

Calculate the distance:

```text
distance = sqrt(
    (x2-x1)^2 +
    (y2-y1)^2
)
```

Store the initial distance:

```text
initialDistance
```

During movement:

```text
currentDistance
```

Then:

```text
scale = currentDistance / initialDistance
```

So:

```text
newZoom = startingZoom × scale
```

But again, you should zoom around the **midpoint between the fingers**.

```text
anchorX = (x1 + x2) / 2
anchorY = (y1 + y2) / 2
```

That makes pinch zoom feel natural.

---

# 19. Scrolling

Scrolling is independent of zoom.

You have:

```text
scrollX
scrollY
```

For vertical scrolling:

```text
scrollY += deltaY
```

Then:

```text
scrollY = clamp(
    scrollY,
    0,
    documentHeight - viewportHeight
)
```

Same for horizontal scrolling.

---

# 20. Don't recreate the document when scrolling

Scrolling should ideally only change:

```text
scrollX
scrollY
```

It should **not** cause the entire PDF to be parsed again.

Likewise, scrolling a page that's already rendered should not necessarily cause a new PDF render.

The viewer should reuse rendered content where possible.

---

# 21. The document is larger than the viewport

Suppose you have:

```text
viewport:
1200 × 800

document:
1200 × 10000
```

Only approximately:

```text
y = 0 → 800
```

is visible.

The viewer doesn't need to treat the entire 10,000px document as a visible surface.

It can determine:

```text
visibleTop
visibleBottom
```

and identify which pages intersect that region.

---

# 22. Multi-page documents

A typical vertical document layout is:

```text
Page 1
   ↓
gap
   ↓
Page 2
   ↓
gap
   ↓
Page 3
   ↓
...
```

Each page has a position:

```text
Page 1:
top = 0

Page 2:
top = page1Height + gap

Page 3:
top = page1Height
     + gap
     + page2Height
     + gap
```

The viewer maintains a page layout model.

For example:

```text
Page {
    index
    width
    height
    top
    left
    renderedWidth
    renderedHeight
}
```

---

# 23. Page layout must account for zoom

Suppose:

```text
PDF page width = 612
PDF page height = 792
zoom = 1.5
```

Then:

```text
renderedWidth = 612 × 1.5 = 918
renderedHeight = 792 × 1.5 = 1188
```

The layout system uses these dimensions.

If zoom changes to:

```text
2
```

then:

```text
renderedWidth = 1224
renderedHeight = 1584
```

The layout must be updated.

---

# 24. Mixed-size pages

Imagine:

```text
Page 1 = 612 × 792
Page 2 = 792 × 612
Page 3 = 612 × 792
```

Do not globally calculate:

```text
pageWidth = documentWidth
```

Instead:

```text
page[0].width
page[1].width
page[2].width
```

Each page should retain its own dimensions.

---

# 25. Centering pages

When a page is narrower than the viewport, it can be centered.

For example:

```text
viewportWidth = 1200
pageWidth = 800
```

Then:

```text
left = (1200 - 800) / 2
     = 200
```

So:

```text
┌─────────────────────────────────┐
│        ┌──────────────┐         │
│        │              │         │
│        │     PAGE     │         │
│        │              │         │
│        └──────────────┘         │
└─────────────────────────────────┘
          ← 200px →
```

But when:

```text
pageWidth > viewportWidth
```

you generally should **not** force the page to remain centered in a way that makes navigation awkward.

Horizontal scrolling should become available.

---

# 26. The page can extend beyond both sides

At high zoom:

```text
viewport = 1000px

page = 2000px
```

The user should be able to see:

```text
left side
   ↓
center
   ↓
right side
```

using horizontal scrolling.

Do not automatically reduce the zoom just because the page became wider than the viewport.

That's the entire purpose of zoom.

---

# 27. Zoom and scrolling are coupled

Changing zoom changes the size of the document.

For example:

```text
zoom = 1
documentHeight = 5000
```

Then:

```text
zoom = 2
documentHeight = 10000
```

Therefore the valid scroll range changes.

If:

```text
viewportHeight = 800
```

then:

```text
maxScrollY = documentHeight - viewportHeight
```

At zoom 1:

```text
maxScrollY = 4200
```

At zoom 2:

```text
maxScrollY = 9200
```

The viewer must recalculate these bounds.

---

# 28. Preserve the user's visual position during zoom

A particularly important feature is:

> Zooming should not make the user's current location jump unexpectedly.

Suppose the user is looking at:

```text
Page 8
paragraph 4
```

and zooms from:

```text
100%
→
125%
```

They should still be looking at roughly:

```text
Page 8
paragraph 4
```

rather than suddenly jumping to:

```text
Page 1
```

or the top of Page 8.

This is accomplished by preserving an **anchor point** during zoom.

---

# 29. Page-aware scrolling

For a multi-page PDF, you should know which page is visible.

Given:

```text
scrollY
viewportHeight
```

calculate:

```text
viewportTop = scrollY
viewportBottom = scrollY + viewportHeight
```

Then for every page:

```text
pageTop
pageBottom
```

determine whether:

```text
pageBottom >= viewportTop
AND
pageTop <= viewportBottom
```

If both are true, that page intersects the viewport.

---

# 30. Only render visible pages

A professional PDF viewer typically uses a concept similar to **virtualization**.

Instead of rendering:

```text
1,000 pages
```

immediately, render approximately:

```text
visible pages
+
a few pages before
+
a few pages after
```

For example:

```text
Current viewport:

Page 20  ← pre-render
Page 21  ← visible
Page 22  ← visible
Page 23  ← visible
Page 24  ← pre-render
```

Pages far away can remain unrendered.

This dramatically reduces:

* CPU usage
* memory usage
* GPU usage
* initial loading time

---

# 31. Render ahead

If the user scrolls downward, the viewer can predict:

```text
user is probably going to see Page 24 next
```

and render it before it becomes visible.

For example:

```text
Visible:
Page 20
Page 21

Render ahead:
Page 22
Page 23
```

This makes scrolling appear instantaneous.

---

# 32. Rendering should be asynchronous

PDF rendering can be expensive.

Therefore don't block the UI thread with:

```text
render page 1
render page 2
render page 3
...
```

Instead conceptually:

```text
UI thread
    ↓
request page render
    ↓
render worker
    ↓
bitmap
    ↓
UI displays bitmap
```

If your platform supports worker threads/processes, PDF rendering is a good candidate.

---

# 33. Rendering priority

Not every page has equal importance.

A useful priority system is:

```text
Priority 1:
currently visible page

Priority 2:
other visible pages

Priority 3:
pages immediately adjacent

Priority 4:
pages further ahead

Priority 5:
far-away pages
```

If the user scrolls quickly, rendering requests that are no longer relevant should be cancelled or deprioritized.

---

# 34. Render resolution

This is another extremely important concept.

Suppose the page is displayed at:

```text
1200 × 1600 CSS pixels
```

but your monitor has:

```text
devicePixelRatio = 2
```

Then rendering only:

```text
1200 × 1600
```

physical pixels can look blurry.

Instead, the backing bitmap may need approximately:

```text
2400 × 3200
```

physical pixels.

So conceptually:

```text
bitmapWidth =
    pageWidth × zoom × devicePixelRatio
```

and:

```text
bitmapHeight =
    pageHeight × zoom × devicePixelRatio
```

But you also need a practical maximum because enormous bitmaps consume huge amounts of memory.

---

# 35. Device pixel ratio

There are often two coordinate systems:

```text
CSS pixels
```

and:

```text
physical device pixels
```

For example:

```text
CSS page width = 1000
DPR = 2
```

The bitmap may be:

```text
2000 physical pixels
```

while still occupying:

```text
1000 CSS pixels
```

on the screen.

Don't accidentally multiply the UI layout dimensions by DPR twice.

---

# 36. Separate logical zoom from render scale

This is a useful architecture.

Keep:

```text
zoom = 1.5
```

as the user's document zoom.

Then separately:

```text
devicePixelRatio = 2
```

for rendering quality.

Therefore:

```text
renderScale = zoom × devicePixelRatio
```

The viewer's layout uses:

```text
zoom
```

while the raster renderer uses:

```text
renderScale
```

This separation prevents many scaling bugs.

---

# 37. Don't use the bitmap's dimensions as the document dimensions

This is another common bug.

You might render:

```text
bitmap = 1800 × 2400
```

because:

```text
zoom × DPR
```

requires that resolution.

But the logical page might still be:

```text
900 × 1200 CSS pixels
```

The bitmap resolution and displayed page dimensions are separate concepts.

---

# 38. Tile rendering

At very high zoom, rendering an entire page into one enormous bitmap can be expensive.

Instead, the viewer can divide the page into tiles:

```text
┌────┬────┬────┬────┐
│ 1  │ 2  │ 3  │ 4  │
├────┼────┼────┼────┤
│ 5  │ 6  │ 7  │ 8  │
├────┼────┼────┼────┤
│ 9  │ 10 │ 11 │ 12 │
└────┴────┴────┴────┘
```

Only render tiles that are visible.

At:

```text
400% zoom
```

the viewer might only need:

```text
tiles 5, 6, 9, 10
```

instead of the entire page.

This is especially useful for:

* huge scanned documents
* architectural drawings
* maps
* high-resolution images
* very large pages

---

# 39. Rendering cache

Rendered pages/tiles should usually be cached.

For example:

```text
cache key:
documentId
+
pageIndex
+
zoom/renderScale
+
rotation
+
render parameters
```

If the user scrolls away and then back:

```text
Page 5
```

the viewer can reuse the existing rendering.

---

# 40. But don't cache unlimited bitmaps

A 2,000-page PDF at high resolution can consume enormous memory.

Use an eviction policy such as:

```text
LRU
```

meaning:

> Least Recently Used.

If memory gets too high:

```text
remove old/far-away renderings
```

while retaining:

```text
currently visible pages
```

and perhaps:

```text
nearby pages
```

---

# 41. Zoom changes should invalidate rendering appropriately

Suppose:

```text
oldZoom = 1
newZoom = 2
```

A bitmap rendered for zoom 1 is not necessarily appropriate for zoom 2.

The viewer should either:

```text
render new high-resolution content
```

or temporarily use the old rendering as a visual placeholder while the new rendering arrives.

A polished viewer can do:

```text
zoom starts
   ↓
temporarily scale existing bitmap
   ↓
request new render
   ↓
new render finishes
   ↓
swap bitmap
```

This makes zoom feel immediate instead of freezing.

---

# 42. Progressive rendering

A good viewer can render progressively.

For example:

```text
zoom to 300%
       ↓
low/previous-resolution image appears immediately
       ↓
high-resolution render starts
       ↓
high-resolution image arrives
       ↓
replace previous image
```

The user gets immediate visual feedback.

---

# 43. Text is a separate layer

If your PDF viewer supports text selection, don't treat the PDF as only a bitmap.

A common architecture is:

```text
PDF page
 ├── rendered bitmap/canvas
 ├── text layer
 ├── annotation layer
 ├── selection layer
 └── interaction layer
```

The text layer can contain positioned text elements.

For example:

```text
Text:
"Hello"

PDF coordinate:
x = 100
y = 200

width = 80
height = 20
```

The text layer applies the same transform as the PDF page.

---

# 44. Every overlay must use the same coordinate transformation

This is critical.

Suppose the page is zoomed:

```text
zoom = 2
```

Then all of these must scale together:

```text
PDF rendering
text selection
links
annotations
highlights
comments
drawing tools
cursor positions
search results
```

If the PDF scales but your annotation doesn't, you'll get:

```text
PDF:
       highlighted text

Annotation:
              highlight somewhere else
```

That is a coordinate-system bug.

---

# 45. Use a shared transform

Conceptually:

```text
PDF coordinate
       ↓
zoom
       ↓
page position
       ↓
scroll offset
       ↓
screen coordinate
```

Every layer should use that same transformation.

Do not independently invent:

```text
text scaling
annotation scaling
PDF scaling
selection scaling
```

They should all derive from the same viewport state.

---

# 46. Rotation

PDF pages can be rotated.

For example:

```text
rotation = 0°
rotation = 90°
rotation = 180°
rotation = 270°
```

Rotation changes the effective page dimensions.

For a page:

```text
612 × 792
```

at 90°:

```text
792 × 612
```

The viewer's layout system must account for this.

---

# 47. Crop boxes and page boxes

PDFs can have several page boundaries, such as:

```text
MediaBox
CropBox
BleedBox
TrimBox
ArtBox
```

A viewer typically uses an appropriate page box—commonly the CropBox when present—for what is displayed.

This matters because the raw PDF page dimensions may not exactly equal the visible content boundary.

---

# 48. Links

PDF pages can contain links.

For example:

```text
"Go to page 20"
```

or:

```text
https://example.com
```

The PDF viewer should map the link's PDF coordinates into screen coordinates.

When the user clicks:

```text
screenX
screenY
```

the viewer can reverse-transform them:

```text
documentX = (screenX + scrollX) / zoom
documentY = (screenY + scrollY) / zoom
```

Then determine which PDF object occupies that coordinate.

---

# 49. Reverse coordinate transformation

You need both directions.

### PDF → screen

```text
screenX = documentX × zoom - scrollX
screenY = documentY × zoom - scrollY
```

### Screen → PDF

```text
documentX = (screenX + scrollX) / zoom
documentY = (screenY + scrollY) / zoom
```

The second one is required for:

* clicking
* selecting
* drawing
* annotations
* searching
* links
* text selection
* measuring
* highlighting

---

# 50. Selection

Suppose the user drags from:

```text
screen coordinate A
```

to:

```text
screen coordinate B
```

Convert both into PDF/document coordinates.

Then determine which text glyphs/words intersect that region.

The selection UI is then rendered using the same zoom transform.

---

# 51. Search

Search shouldn't require visually scanning the rendered bitmap.

Instead:

```text
PDF
 ↓
text extraction
 ↓
search index/string
 ↓
match positions
 ↓
PDF coordinates
 ↓
screen coordinates
```

When the user searches:

```text
"invoice"
```

the viewer finds matching text and can calculate:

```text
page = 17
x = 230
y = 450
width = 80
height = 20
```

Then scroll to that location.

---

# 52. "Go to page" is not the same as scrolling a fixed amount

Suppose the user enters:

```text
Page 50
```

You should find the layout position of Page 50:

```text
page50.top
```

and set:

```text
scrollY = page50.top
```

rather than doing something like:

```text
scrollY = pageNumber × arbitraryHeight
```

because pages can have different heights.

---

# 53. Current page indicator

The viewer can determine the current page from the viewport.

One strategy:

```text
Find page with the largest intersection
with the viewport.
```

For example:

```text
Page 10 = 20% visible
Page 11 = 80% visible
Page 12 = 5% visible
```

Therefore:

```text
currentPage = 11
```

Another common strategy is to use the page containing the viewport center.

---

# 54. Scrollbars

The scrollbar represents the relationship between:

```text
viewport size
```

and:

```text
document size
```

For vertical scrolling:

```text
thumbSize ≈ viewportHeight / documentHeight
```

The thumb gets smaller as the document gets larger.

Zooming increases:

```text
documentHeight
```

so the scrollbar thumb should generally become smaller.

---

# 55. Continuous document vs page snapping

A PDF viewer can support:

### Continuous scrolling

```text
Page 1
Page 2
Page 3
Page 4
```

with no forced snapping.

### Page-by-page scrolling

Scrolling ends on page boundaries.

### Hybrid

Normal wheel scrolling is continuous, while:

```text
Page Up
Page Down
```

moves between pages.

For a note-taking app, continuous scrolling is generally more natural.

---

# 56. Keyboard controls

Useful controls include:

```text
+
-
Ctrl/Cmd + +
Ctrl/Cmd + -
Ctrl/Cmd + 0
Home
End
Page Up
Page Down
Arrow keys
Space
Shift + Space
```

But keyboard zoom should use the same zoom controller as mouse/pinch zoom.

Don't create separate zoom logic.

---

# 57. Zoom controller

Architecturally, you want something like:

```text
setZoom(newZoom, anchor)
zoomIn(anchor)
zoomOut(anchor)
fitWidth()
fitPage()
actualSize()
resetZoom()
```

Every one of these eventually calls one central function:

```text
setZoom(...)
```

This prevents different controls from producing inconsistent behavior.

---

# 58. Example viewer state

A useful viewer state might look conceptually like:

```text
ViewerState {

    document

    pages[]

    zoom

    zoomMode

    scrollX
    scrollY

    viewportWidth
    viewportHeight

    devicePixelRatio

    rotation

    currentPage

    selectedText

    searchState

    renderCache

    renderingPages

}
```

You may have more state, but these are the important concepts.

---

# 59. Separate layout from rendering

This is extremely important.

You should have:

```text
Layout system
```

that answers:

```text
Where is Page 12?
What size is Page 12?
Which pages are visible?
What is the document height?
```

And:

```text
Renderer
```

that answers:

```text
How do I turn Page 12 into pixels?
```

Don't mix these responsibilities.

---

# 60. Separate rendering from interaction

Likewise:

```text
Input
 ↓
Viewport Controller
 ↓
Viewer State
 ↓
Layout
 ↓
Renderer
```

Mouse input shouldn't directly manipulate canvas dimensions all over the codebase.

Instead:

```text
mouse wheel
 ↓
zoomController / scrollController
 ↓
update state
 ↓
layout recalculates
 ↓
renderer updates
```

---

# 61. Recommended high-level architecture

A robust implementation could conceptually look like this:

```text
PDFViewer
│
├── DocumentManager
│   ├── loadDocument()
│   ├── getPage()
│   ├── getPageCount()
│   └── extractText()
│
├── PageModel
│   ├── pageSize
│   ├── rotation
│   └── coordinates
│
├── LayoutManager
│   ├── calculatePagePositions()
│   ├── getVisiblePages()
│   ├── getPageAtPosition()
│   └── calculateDocumentSize()
│
├── ViewportController
│   ├── scrollX
│   ├── scrollY
│   ├── zoom
│   ├── setZoom()
│   ├── zoomIn()
│   ├── zoomOut()
│   ├── fitWidth()
│   └── fitPage()
│
├── RenderManager
│   ├── renderPage()
│   ├── renderVisiblePages()
│   ├── renderAhead()
│   ├── cancelRender()
│   └── renderTiles()
│
├── RenderCache
│   ├── get()
│   ├── set()
│   └── evict()
│
├── TextLayer
│
├── AnnotationLayer
│
├── SelectionLayer
│
└── InteractionManager
    ├── mouse
    ├── touch
    ├── keyboard
    └── pointer
```

---

# 62. The render loop

The viewer effectively follows this process:

```text
1. User changes viewport
        ↓
2. Viewer state changes
        ↓
3. Calculate visible pages
        ↓
4. Calculate required render resolution
        ↓
5. Check render cache
        ↓
6. Render missing pages
        ↓
7. Display available renderings
        ↓
8. Update overlays
        ↓
9. Continue responding to input
```

---

# 63. When the window resizes

This is where you need to distinguish **fit modes**.

Suppose:

```text
zoomMode = FIT_WIDTH
```

and the window changes:

```text
1200px → 1500px
```

Then recalculating fit-width zoom makes sense:

```text
newZoom = newViewportWidth / pageWidth
```

But suppose:

```text
zoomMode = CUSTOM
```

and the user manually selected:

```text
150%
```

Then resizing the window should generally **not silently change 150% to some new fit-width value**.

This is one of the most important fixes for the problem you described.

---

# 64. Recommended zoom mode state machine

Think of it like this:

```text
FIT_WIDTH
FIT_PAGE
ACTUAL_SIZE
CUSTOM
```

Actions:

```text
Window resize:
    FIT_WIDTH  → recalculate
    FIT_PAGE   → recalculate
    CUSTOM     → preserve zoom
    ACTUAL     → preserve zoom

Manual zoom:
    any mode → CUSTOM

Fit Width button:
    any mode → FIT_WIDTH

Fit Page button:
    any mode → FIT_PAGE

Actual Size:
    any mode → ACTUAL_SIZE
```

This prevents the viewer from constantly fighting the user.

---

# 65. Important: don't use window resize as an excuse to reset zoom

A buggy implementation often does:

```text
onResize:
    zoom = viewportWidth / pageWidth
```

This means:

```text
user zooms to 200%
        ↓
window changes by 1 pixel
        ↓
zoom becomes 163%
```

That's extremely frustrating.

Instead:

```text
if zoomMode == FIT_WIDTH:
    recalculate zoom
else:
    preserve zoom
```

---

# 66. Double-click zoom

You can optionally implement:

```text
double click
```

as:

```text
100% → 200%
```

or:

```text
fit → 200%
```

But again, anchor it around the clicked location.

---

# 67. Mouse wheel behavior

Normal wheel:

```text
scroll
```

Ctrl/Cmd + wheel:

```text
zoom
```

This distinction is important.

For example:

```text
wheel delta = +100

if Ctrl/Cmd pressed:
    zoom
else:
    scroll
```

For macOS, use the appropriate modifier semantics for the platform.

---

# 68. Trackpad behavior

Trackpads can generate very small, high-frequency deltas.

Don't assume:

```text
one wheel event = one scroll step
```

Instead accumulate/interpret the delta naturally.

Similarly, pinch gestures can produce fractional zoom:

```text
1.00
1.01
1.015
1.02
1.035
...
```

Don't round every event to:

```text
100%
101%
102%
```

or pinch zoom can feel jerky.

---

# 69. Debouncing vs throttling

Rendering shouldn't necessarily happen for every single input event.

For example:

```text
wheel
wheel
wheel
wheel
wheel
wheel
wheel
```

can generate a lot of state changes.

You can update visual viewport state immediately but schedule expensive work efficiently.

For example:

```text
input event
    ↓
update scroll/zoom immediately
    ↓
request render/update
    ↓
browser/frame scheduler
```

The exact mechanism depends on your UI framework.

---

# 70. Don't block scrolling waiting for rendering

Suppose the user scrolls.

Bad:

```text
scroll
 ↓
render page
 ↓
wait
 ↓
update screen
```

Good:

```text
scroll
 ↓
update viewport immediately
 ↓
display existing cached rendering / placeholder
 ↓
render missing content asynchronously
 ↓
replace placeholder
```

Scrolling should remain responsive even if rendering is expensive.

---

# 71. Page placeholders

While a page is being rendered, you can display:

```text
empty page rectangle
```

or:

```text
previous lower-resolution render
```

This prevents layout jumps.

The page's **layout dimensions should be known before rendering finishes**.

That means:

```text
page dimensions
```

come from PDF metadata, not from the bitmap that happens to finish rendering.

---

# 72. A very useful invariant

Your viewer should maintain:

```text
PAGE LOGICAL SIZE
≠
PAGE BITMAP SIZE
```

and:

```text
DOCUMENT POSITION
≠
SCREEN POSITION
```

Those are separate concepts.

---

# 73. Another important invariant

At any moment, the viewer should be able to answer:

```text
What document coordinate is underneath this screen coordinate?
```

and:

```text
Where should this document coordinate appear on screen?
```

If those two operations are reliable, many features become much easier.

---

# 74. A complete conceptual zoom operation

When the user zooms:

```text
INPUT
 ↓
Determine anchor point
 ↓
Read old zoom
 ↓
Convert anchor screen coordinate → document coordinate
 ↓
Calculate new zoom
 ↓
Clamp new zoom
 ↓
Update zoom
 ↓
Calculate new scroll position
 ↓
Clamp scroll position
 ↓
Update layout
 ↓
Determine visible pages
 ↓
Request renders at new resolution
 ↓
Update text/annotation/selection layers
 ↓
Display result
```

That is essentially the whole zoom pipeline.

---

# 75. A complete conceptual scroll operation

```text
INPUT
 ↓
Read scroll delta
 ↓
Update scrollX / scrollY
 ↓
Clamp to document boundaries
 ↓
Determine visible pages
 ↓
Determine pages to pre-render
 ↓
Display cached renderings
 ↓
Request missing renderings
 ↓
Update current page
 ↓
Update overlays
```

Notice that **zoom and scrolling are related but not the same operation**.

---

# 76. A complete conceptual page navigation operation

When the user says:

```text
Go to page 37
```

do:

```text
find page 37
 ↓
read page37.top
 ↓
choose desired alignment
 ↓
set scrollY
 ↓
clamp scroll
 ↓
render page 37 if necessary
 ↓
update currentPage
```

Possible alignment:

```text
TOP
CENTER
```

For example:

```text
scrollY =
    pageTop - desiredTopMargin
```

---

# 77. A complete conceptual "Fit Width"

```text
availableWidth
    ↓
subtract viewer padding
    ↓
subtract scrollbar if necessary
    ↓
calculate page width
    ↓
zoom = availableWidth / pageWidth
    ↓
set zoomMode = FIT_WIDTH
    ↓
recalculate layout
    ↓
render pages at new scale
```

For mixed page sizes, you need to define what "fit width" means.

Usually you might fit the **current page**, or choose a document-wide policy such as fitting to the widest page.

---

# 78. What "fit width" should mean for multiple pages

There are two reasonable interpretations.

### Current-page fit

```text
zoom = viewportWidth / currentPageWidth
```

This can cause the apparent zoom to change when moving between differently sized pages.

### Document-wide fit

```text
zoom = viewportWidth / widestPageWidth
```

This keeps one consistent zoom across the document.

For a note-taking app, **consistent zoom across pages is usually preferable**, because changing zoom automatically while scrolling is surprising.

You can still offer a separate "Fit Current Page" mode if desired.

---

# 79. Recommended behavior for your note-taking app

I'd recommend:

```text
Default:
    Fit Width

After user manually zooms:
    switch to Custom

Scrolling:
    preserve zoom

Window resize:
    only change zoom if still in Fit Width/Fit Page mode

Moving between pages:
    do NOT automatically change zoom

Zoom:
    centered around cursor/finger

Zoom buttons:
    centered around viewport center

Pinch:
    centered around pinch midpoint

High zoom:
    allow horizontal scrolling

Rendering:
    virtualize pages
    cache renders
    render ahead
    render asynchronously
```

This will feel much more like a proper document viewer.

---

# 80. The most common architectural mistake

The biggest thing I'd look for in your existing PDF viewer is code resembling:

```text
onResize:
    pageWidth = containerWidth
    pageHeight = ...
    scale = containerWidth / pdfPageWidth
    render()
```

combined with:

```text
onScroll:
    render()
```

and:

```text
onZoom:
    scale = ...
    render()
```

all modifying the same dimensions.

That tends to create a viewer where everything is fighting everything else.

Instead, establish a single source of truth:

```text
viewport = {
    zoom,
    scrollX,
    scrollY,
    width,
    height
}
```

Then derive everything else from it.

---

# 81. The core data model I'd give an LLM

If you want an LLM to understand the architecture, this is the most useful abstraction:

```text
Document:
    pages[]

Page:
    index
    pdfWidth
    pdfHeight
    rotation
    layoutTop
    layoutLeft

Viewport:
    width
    height
    scrollX
    scrollY
    zoom
    zoomMode

Rendering:
    renderScale
    visiblePages[]
    cachedPages[]
    renderingPages[]

Coordinate conversion:

    screenToDocument(screenX, screenY)

    documentToScreen(documentX, documentY)

Zoom:

    setZoom(newZoom, anchorX, anchorY)

Layout:

    calculatePageLayout()

Visibility:

    calculateVisiblePages()

Rendering:

    renderPage(pageIndex, renderScale)

Cache:

    getCachedRender(pageIndex, renderScale)

Navigation:

    goToPage(pageIndex)

Modes:

    fitWidth()
    fitPage()
    actualSize()
```

---

# 82. The single most important rule

If you only take one thing from all of this, make it this:

> **Never make "fit to width" the fundamental behavior of the PDF viewer. Make it one of several zoom modes.**

Your viewer should fundamentally operate on:

```text
document
+
zoom
+
scroll position
+
viewport
```

not:

```text
viewport width
→
force page width to viewport
```

That distinction is what allows a user to say:

```text
"Show me the PDF at 175%."
```

and have the viewer respect that choice.

---

# 83. A compact specification you can give directly to an LLM

## PDF Viewer Implementation Specification

Build the PDF viewer as a document viewport system, not as an image that is continuously resized to the container width.

### 1. Core concepts

The viewer has four independent concepts:

1. PDF document coordinates
2. Logical page layout coordinates
3. Viewport coordinates
4. Physical render pixels

Do not mix these coordinate systems.

Each PDF page has its own logical dimensions:

```text
Page:
    pdfWidth
    pdfHeight
    rotation
```

The viewer maintains:

```text
Viewport:
    width
    height
    scrollX
    scrollY
    zoom
    zoomMode
```

The document layout maintains the position and displayed logical size of every page.

### 2. Coordinate transformation

Use one shared transformation for all PDF content and overlays.

Document → screen:

```text
screenX = documentX * zoom - scrollX
screenY = documentY * zoom - scrollY
```

Screen → document:

```text
documentX = (screenX + scrollX) / zoom
documentY = (screenY + scrollY) / zoom
```

All of the following must use the same coordinate transformation:

* PDF page rendering
* text layer
* text selection
* annotations
* highlights
* links
* search results
* drawing tools
* comments
* interaction hit testing

Never implement separate scaling logic for these layers.

### 3. Zoom modes

Support at least:

```text
FIT_WIDTH
FIT_PAGE
ACTUAL_SIZE
CUSTOM
```

Fit modes are modes, not permanent behavior.

When the user manually changes zoom:

```text
zoomMode = CUSTOM
```

Once in CUSTOM mode, resizing the window must not automatically change the zoom.

Only FIT_WIDTH and FIT_PAGE should automatically recalculate zoom when the viewport changes size.

### 4. Fit width

For fit width:

```text
zoom = availableViewportWidth / targetPageWidth
```

Do not continuously enforce this formula unless the viewer is actually in FIT_WIDTH mode.

Manual zoom must be allowed to exceed the viewport width.

If:

```text
pageWidth * zoom > viewportWidth
```

allow horizontal scrolling instead of reducing zoom.

### 5. Fit page

Calculate:

```text
widthZoom = viewportWidth / pageWidth
heightZoom = viewportHeight / pageHeight

zoom = min(widthZoom, heightZoom)
```

This makes the entire page visible.

### 6. Actual size

Use the PDF's natural scale:

```text
zoom ≈ 1
```

Do not automatically resize the page to fill the viewport.

### 7. Zoom limits

Always clamp zoom:

```text
zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM)
```

Choose sensible application-specific limits.

### 8. Cursor-centered zoom

When zooming around a cursor position:

```text
documentX = (cursorX + scrollX) / oldZoom
documentY = (cursorY + scrollY) / oldZoom
```

After changing zoom:

```text
scrollX = documentX * newZoom - cursorX
scrollY = documentY * newZoom - cursorY
```

Then clamp scrolling.

This keeps the document point underneath the cursor stationary during zoom.

### 9. Toolbar zoom

For toolbar +/− buttons, use the viewport center as the anchor:

```text
anchorX = viewportWidth / 2
anchorY = viewportHeight / 2
```

Then perform the same anchor-preserving zoom calculation.

Do not implement separate zoom mathematics for toolbar buttons.

### 10. Pinch zoom

For two touch points:

```text
distance = sqrt((x2-x1)^2 + (y2-y1)^2)
```

Calculate:

```text
scale = currentDistance / initialDistance
newZoom = initialZoom * scale
```

Use the midpoint of the two fingers as the zoom anchor:

```text
anchorX = (x1 + x2) / 2
anchorY = (y1 + y2) / 2
```

### 11. Scrolling

Maintain:

```text
scrollX
scrollY
```

Clamp them to the document bounds.

For vertical scrolling:

```text
scrollY = clamp(
    scrollY,
    0,
    documentHeight - viewportHeight
)
```

Scrolling must not reset zoom.

Scrolling must not cause the PDF document to be reloaded.

### 12. Multi-page layout

Each page must retain its own dimensions.

Do not assume all pages have identical sizes.

Store something equivalent to:

```text
Page {
    index
    pdfWidth
    pdfHeight
    layoutTop
    layoutLeft
    layoutWidth
    layoutHeight
}
```

Page positions should be calculated from actual page dimensions and the current zoom.

### 13. Mixed page sizes

Support:

* portrait pages
* landscape pages
* different paper sizes
* custom page sizes
* rotated pages

Do not globally assume:

```text
pageWidth = documentWidth
```

Every page has its own dimensions.

### 14. Current page

Determine the current page from its intersection with the viewport.

A reasonable strategy is to select the page with the largest visible intersection or the page containing the viewport center.

### 15. Go-to-page

For:

```text
goToPage(pageIndex)
```

find the page's calculated layout position and set the scroll position from that value.

Do not estimate page positions using:

```text
pageNumber * fixedPageHeight
```

because pages can have different heights.

### 16. Virtualized rendering

Do not render every page of a large document simultaneously.

Render:

```text
currently visible pages
+
a small number of pages before/after the viewport
```

Render nearby pages ahead of the user's scrolling direction.

Pages far outside the viewport can remain unrendered.

### 17. Asynchronous rendering

PDF rendering can be expensive.

Do not block scrolling or user interaction while rendering pages.

The preferred flow is:

```text
user interaction
    ↓
update viewport state immediately
    ↓
show cached/previous rendering if available
    ↓
request required render asynchronously
    ↓
replace temporary rendering when finished
```

### 18. Render resolution

Separate logical zoom from physical bitmap resolution.

For example:

```text
zoom = 1.5
devicePixelRatio = 2

renderScale = zoom * devicePixelRatio
```

The page's logical display size is determined by `zoom`.

The bitmap resolution is determined by `renderScale`.

Do not confuse bitmap dimensions with logical page dimensions.

### 19. Rendering cache

Cache rendered pages or tiles.

A cache key should account for relevant rendering parameters, such as:

```text
document
pageIndex
renderScale
rotation
render options
```

Use an eviction strategy such as LRU so that very large documents do not consume unlimited memory.

### 20. High zoom

At high zoom levels, a complete page bitmap may become enormous.

For very large pages/documents, support tiled rendering:

```text
page
 ├── tile 1
 ├── tile 2
 ├── tile 3
 └── ...
```

Only render tiles that are visible or likely to become visible.

### 21. Progressive rendering

When zoom changes:

```text
show existing cached rendering immediately
        ↓
request new resolution
        ↓
render asynchronously
        ↓
replace old rendering
```

Do not make the interface freeze while waiting for a high-resolution render.

### 22. Window resizing

When the viewport changes size:

```text
if zoomMode == FIT_WIDTH:
    recalculate zoom

if zoomMode == FIT_PAGE:
    recalculate zoom

if zoomMode == CUSTOM:
    preserve zoom

if zoomMode == ACTUAL_SIZE:
    preserve zoom
```

Never blindly execute:

```text
zoom = viewportWidth / pageWidth
```

on every resize.

### 23. Architecture

Separate these responsibilities:

```text
DocumentManager
    loads/parses PDF and exposes page information

LayoutManager
    calculates page positions and document dimensions

ViewportController
    owns zoom and scrolling

RenderManager
    renders pages/tiles asynchronously

RenderCache
    caches render results

TextLayer
    displays selectable/searchable text

AnnotationLayer
    displays annotations

InteractionManager
    handles mouse, touch, keyboard and pointer input
```

All state changes should flow through the viewer state rather than having individual UI controls directly manipulate canvas dimensions.

### 24. Central zoom function

Implement one central function conceptually equivalent to:

```text
setZoom(newZoom, anchorX, anchorY)
```

It should:

1. Read the old zoom.
2. Convert the anchor from screen coordinates to document coordinates.
3. Clamp the new zoom.
4. Update zoom.
5. Calculate the new scroll position so the same document point remains under the anchor.
6. Clamp scrolling.
7. Recalculate page layout.
8. Determine visible pages.
9. Request new renders.
10. Update all overlay layers.

All zoom mechanisms must ultimately use this function.

### 25. Central scrolling function

Similarly, scrolling should go through one system that:

1. Reads the scroll delta.
2. Updates scroll position.
3. Clamps scroll position.
4. Determines visible pages.
5. Determines pages to render ahead.
6. Updates current-page state.
7. Updates overlays.
8. Requests missing renderings.

### 26. Most important behavioral rule

The PDF viewer must never continuously force the document to fit the viewport width unless the viewer is explicitly in FIT_WIDTH mode.

The user must be able to:

```text
Fit Width
    ↓
manually zoom to 150%
    ↓
remain at 150%
    ↓
scroll horizontally if necessary
    ↓
resize the window
    ↓
remain at 150%
```

Manual zoom changes the mode to CUSTOM.

The viewer should respect the user's zoom choice.

### 27. Core invariant

At all times, the viewer must be able to answer:

```text
Which PDF/document coordinate is underneath this screen coordinate?
```

and:

```text
Where should this PDF/document coordinate appear on screen?
```

These two transformations are the foundation for:

* zooming
* scrolling
* text selection
* annotations
* search
* links
* drawing
* highlighting
* navigation
* cursor interaction

The PDF viewer should be designed around these transformations rather than around continuously resizing a PDF image to the viewport.

If you tell me **what stack you're using** (for example React + PDF.js, Electron, Flutter, Swift, Android, React Native, Tauri, etc.), I can turn this into a **stack-specific implementation spec**, including the exact functions/classes/state you should create and the zoom/scroll algorithms in code.
