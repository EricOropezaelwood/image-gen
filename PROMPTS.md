# Prompt Log

A running record of prompts that worked well and the reasoning behind them.

---

## Cityscapes & Landmarks

### Tokyo Tower at Night

```bash
python client/zimage.py \
  "photograph of tokyo tower at night, tack sharp, perfectly in focus, f/11 aperture, tripod shot, tokyo tower lit up orange, illuminated skyline, city lights reflecting on buildings, slight elevation angle" \
  --negative-prompt "blurry, bokeh, defocused, unfocused, soft focus, lens blur, motion blur, out of focus, depth of field, illustration, graphic, overexposed" \
  --width 1280 --height 720
```

**What worked:**

- `f/11 aperture` + `tripod shot` — photography terms that signal everything-in-focus, prevents the model from generating bokeh/shallow depth of field
- `tack sharp` + `perfectly in focus` — reinforces sharpness beyond just "sharp focus" which is too weak on its own
- `illuminated skyline` + `city lights reflecting on buildings` — keeps the background alive instead of a flat dark mass
- `slight elevation angle` — breaks the dead-center composition

**What to avoid:**

- `atmospheric`, `cinematic lighting` — both encourage bokeh and haze
- `sharp focus` alone — not strong enough for night scenes; model overrides it with blur
- Sparse prompts for night scenes — model defaults to graphic/illustrative style without enough anchoring

---

## Interiors & Still Life

### Library Window, Evening

```bash
python client/zimage.py \
  "photograph taken inside a cozy library, looking toward a large floor-to-ceiling window in the evening, lush green potted plants and trailing vines framing the window, warm amber lamp light illuminating dark wood bookshelves and leather reading chair in foreground, blue-hour evening sky visible through window glass, wooden window frame, scattered books on side table, dust motes in lamplight, tack sharp, f/8 aperture, focus on bookshelves and chair" \
  --negative-prompt "blurry, bokeh, defocused, unfocused, soft focus, lens blur, motion blur, out of focus, illustration, graphic, overexposed, modern, neon, people, figures" \
  --width 1280 --height 720
```

**What worked:**

- `warm amber lamp light` vs `blue-hour evening sky` — interior/exterior color temperature contrast grounds the scene and prevents flat, ambiguous lighting
- `dark wood bookshelves and leather reading chair` — naming materials and foreground objects prevents the model from inventing random props
- `f/8 aperture` + `focus on bookshelves and chair` — foreground stays crisp while the window view has natural softness behind it
- `dust motes in lamplight` — adds texture and reinforces the warm interior atmosphere
- `tall window` — establishes the window as a prominent visual element without making it the focal subject

**What to avoid:**

- `cinematic` or `atmospheric` — encourages haze and blur in interior shots
- Leaving foreground furniture vague — model fills empty space with random clutter
- `sharp focus` alone — not strong enough for interiors; model still blurs background elements
- `people` or `figures` in the positive prompt — model tends to add silhouetted figures at the window unprompted

---

### Coffee Shop Window, Morning

```bash
python client/zimage.py \
  "photograph taken inside a cozy coffee shop looking out the window, morning, warm golden sunlight streaming through glass, sharp coffee cup and open journal on wooden table in foreground, lively city street with pedestrians and trees outside, condensation on window, tack sharp, f/8 aperture, focus on coffee cup" \
  --negative-prompt "blurry, bokeh, defocused, unfocused, soft focus, lens blur, motion blur, out of focus, illustration, graphic, overexposed, dark, night, pens, pencils, cups, glasses, objects, tripod, camera, equipment" \
  --width 1280 --height 720
```

**What worked:**

- `sharp coffee cup` + `focus on coffee cup` — naming the subject as sharp and explicitly stating focus point keeps the model from putting the focal plane on the background
- `f/8 aperture` — slightly shallower than f/11 so the street has natural softness while the foreground stays crisp
- Specifying all foreground items (`coffee cup and open journal`) — leaving the table description open causes the model to invent random objects
- `condensation on window` — adds texture and reinforces the morning/cold feel

**What to avoid:**

- `tripod shot` in the positive prompt — model places a literal tripod in the scene; move to negatives instead
- Leaving table description vague — model fills empty space with random props (pens, glasses, etc.)
- `atmospheric` — causes haze and blur even in interior shots
