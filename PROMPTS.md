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
