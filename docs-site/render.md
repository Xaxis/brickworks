---
tools: render_model, render_queue, light_model, animate_model, render_motion
panels: RenderDialog#render, RenderQueue#render-queue
ai: Photo-real renders, line art and comic looks, turntables, motion animations and building videos, the model's own lights, and the render queue. An assistant renders with render_model or render_motion (both jobs: follow them with job), queues pictures with render_queue, and places the model's lights with light_model.
rules:
  - A render answers with a job number; follow it with job.
  - Path tracing runs only in the desktop app on a graphics card that traces rays; in a browser Best averages frames.
  - A model keeps at most 8 lights of its own, no more than 4 of them suns.
title: Render
nav: Render
description: A picture of the model worth keeping, a turntable, an animation of its motions or a video of it being built, in its own light.
---

Render makes a picture of the model worth keeping, a turntable, an animation of one of its motions, or a video of it being built. It is **File › Render…** ([[F9]]), or the camera on the toolbar.

## Render a picture {#render}

![The Render dialog: a draft of the car on the left with the four Render buttons under it, and on the right its Preset, Quality, Look, Size, Background, Light and Lights in the model.](/docs/img/render-dialog.webp "File › Render… (F9): the draft on the left is what Render draws.")

1. Press [[F9]]. The quick draft on the left is drawn again whenever a choice changes, so what comes out is what you see.
2. Make your choices on the right (below).
3. Press **Render picture**, or [[Enter]]. **Cancel** or [[Esc]] stops it; when it is done, it downloads.

<!-- covers
ui:photo-real render
lib:studio renderer
-->

### The choices {#choices}

| Choice | What there is |
|---|---|
| Preset | Your choices kept by a name on this device: **Save…** names them, choosing the name puts them all back on any model, **Remove** forgets one |
| Quality | **Quick**, **Good**, or **Best** (below) |
| Look | **As in the window**, **Product**, **Line art** or **Comic** (below) |
| Size | 720p, 1080p, 4K, Square, or Custom |
| Background | White, Gradient, Grey, Dark, a Colour, or None (transparent); a contact shadow if you like |
| Light | Three lights, as in the window; a photographed studio, window light or daylight; or **Dark**, only the [model's own lights](#lights). **Light from** turns it round. |
| Camera | Three-quarter like the box, the view you are looking at, front, side, back three-quarter, low looking up, from above, or a [view saved with the model](/docs/the-view#saved-views); and the **Lens**, 18 to 200 mm |
| Depth of field | Off, or f/16 to f/2, at Best |

### Best {#path-traced}

**Best** averages many frames for soft shadows, smooth edges, shading under every ledge and depth of field. **Best's frames** sets how many: **As this device does best** is 32 in a browser.

> [!NOTE]
> In the desktop app (coming soon), on a graphics card that traces rays, Best is path traced: light bounces off the floor and between the parts, and glass tints what is behind it, in 256 samples unless you set fewer. A browser cannot trace rays; the Quality note says when Best is not path traced.

<!-- covers
lib:path tracer
-->

### Product {#product-look}

**Product** draws the model as a set's box does: glossy plastic, rounded edges, clear parts you see through, a studio's light, every colour true.

<!-- covers
lib:product look
-->

### Line art and Comic {#line-art}

![The car drawn by the Line art look: black lines on white, thickest round the outline, the shading in halftone dots and its shadow on the floor in dots too.](/docs/img/render-line-art.webp "Look › Line art: the model inked, to print or colour in.")

**Line art** inks the model: black lines on white, thickest round the outline and thinnest round a stud or a print, with the shade in halftone dots. **Comic** puts the same lines and dots over each part's own colour. Both are sharp at any quality; with the background **None**, the drawing goes over anything.

<!-- covers
lib:line art and comic looks
-->

## Lights in the model {#lights}

![The Render dialog with Light set to Dark and one bulb added under Lights in the model: the draft shows the car lit by the bulb alone, and the bulb's strength, size, shadows and where it hangs are on the right.](/docs/img/render-lights.webp "Lights in the model, Add › Bulb, with Light on Dark.")

A model can keep up to eight lights of its own: a spot over a cockpit, a bulb in a lamp post, a low sun.

1. Select the parts to light, or nothing for the whole model.
2. Under **Lights in the model**, press **Add**: **Bulb**, **Spot**, **Sun** or **Light panel**. It is hung over them as a photographer first sets one.
3. Set its colour, **Strength**, a spot's **Cone**, its **Size** and **Shadows**. **From where I look** moves it to where the window's camera is, and **Over the selection** hangs it over other parts.

They are drawn in every render over the Light you chose, saved in the model's file, and shared with whoever builds it with you. With **Dark** they are all there is, with the plastics that glow: Trans Neon colours and Glow In Dark light the parts round them. Undo does not take back a light: **Remove** does.

<!-- covers
ui:lights in the model
-->

## Turntables and videos {#videos}

Further down are three more, each with its own button, at the picture's quality, size, light and lens:

- **Turntable**: the model turning round once, in 24, 36, 48 or 72 frames. **Render turntable**.
- **Animation**: one of the model's [motions](/docs/joints-and-mechanisms#motions), or all of them in order, with the camera as you see it or framed on what moves. **Render animation**.
- **Building**: the model going up step by step as the [timeline](/docs/instructions#timeline) shows it, the camera turning slowly round to end on your view; 10, 20, 30 or 60 seconds. **Render building**.

<!-- covers
ui:building video
-->

### Kept as WebP or GIF {#gif}

**Kept as** chooses the file: an animated **WebP**, small and in every colour, or a **GIF**, which plays anywhere, chats and mail included. A GIF has 256 colours, is at most 640 pixels across and is made to fit in 8 MB. The desktop app also keeps the frames, and an MP4 where ffmpeg is installed.

<!-- covers
ui:moving renders kept as a GIF
-->

## Render queue {#render-queue}

**File › Render queue…** ([[Shift+F9]]) draws pictures one after another while you go on building, each with Render's choices.

- **Add this view** queues the model as it is now, from where you look. Change the view or the model, and add another.
- **Add each saved view** queues one from each [view saved with the model](/docs/the-view#saved-views), as **View › Viewpoint › Render each saved view** does.
- **Pause** and **Go on** hold the queue; **Stop** or **Remove** on a row takes it out, and **Clear finished** clears the done ones.

Each is saved as Render saves one. The status bar's **Cancel** stops the one being drawn and pauses the rest; **Close** or [[Esc]] puts the panel away while the queue goes on.

<!-- covers
ui:render queue
-->
