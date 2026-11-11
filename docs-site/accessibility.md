---
ai: Using Brickworks with the keyboard alone, What's This? (Shift+F1), Find a command (Ctrl+/), the keys sheet's search, a bigger interface (85 to 150%) and reduced motion; a screen reader in the desktop app (coming soon); and how the website and these docs meet the same needs.
rules:
  - In a browser the app draws its own controls, which a screen reader cannot reach; its keys all work.
title: Accessibility
nav: Accessibility
description: Use Brickworks with the keyboard alone, a bigger interface and less motion; ask any control what it does; the website and these docs with a screen reader.
---

Brickworks can be used with the keyboard alone, at a bigger size and with less on the screen moving, and it can tell you what any control does. **Interface size** and **Reduce motion** are in **Tools › Settings…** ([[,]]); the rest is in the **Help** menu.

## The keyboard alone {#keyboard}

![The parts bin with one part's tile ringed in blue: the keyboard's focus, moved there with the arrow keys.](/docs/img/accessibility-keyboard.webp "The arrows move the keyboard's focus through the parts bin; Return takes the part.")

1. Press [[F6]]: the keys go from the model into the window's controls.
2. [[Tab]] and the arrows move through the toolbar, the parts bin, the colours and the view cube's buttons. A ring shows where you are. [[Enter]] or [[Space]] presses a button.
3. On a part's tile, [[Enter]] takes the part into your hand, aimed at the middle of the view. Move the view with its keys ([The view](/docs/the-view#camera)), then [[Enter]] puts the part down.
4. [[F6]] again gives the keys back to the model, and the next [[F6]] returns to where you were.

Every command has a place in the menus, and [[Ctrl+/]] (**Find a command…**) runs any of them by name: type *mirror* or *steps* and press [[Enter]]. The keys sheet ([[F1]]) lists every key, and its box finds one: type *hinge*. The key strip over the model shows the commonest; **View › Panels › Key strip** hides it.

<!-- covers
ui:accessibility
-->

## What's This? {#whats-this}

![What's This? over the toolbar: the Snap chooser outlined and a box beside it naming Snap and saying what it does.](/docs/img/accessibility-whats-this.webp "Help › What's This? (Shift+F1): the next click says what a control does instead of doing it.")

Press [[Shift+F1]], or choose **Help › What's This?**, then click any button, field, chip or panel. Instead of doing what it does, it says so in a box beside it, with whether it is on now and why it is greyed when it is. Over the model, it says what the tool in use does there. [[Esc]], a right click or [[Shift+F1]] again stops asking.

<!-- covers
ui:what's this
-->

## Size and motion {#size}

![The Brickworks window at Interface size 150%: the menus, the toolbar, the parts bin's tiles and the words all half as big again, the model as before.](/docs/img/accessibility-size.webp "Settings, Interface size 150%: every control and word bigger.")

- **Interface size**, 85 to 150%, makes every control and word bigger or smaller.
- **Reduce motion** stops the build animation and the shimmer, and the view moves without gliding.

## Screen readers {#screen-reader}

In a browser, the app draws its own controls, and a screen reader cannot reach them; the keys above all work. The desktop app, coming soon, names every control for a screen reader, in your language, and there [[Tab]] moves through the controls while one is running.

## On the website {#website}

Every page of brickworks.diy, these docs included, works with a keyboard and a screen reader: a **Skip to content** link first, landmarks for the header, the pages list, the page and the footer, a visible focus ring on every control, and dialogs that keep the focus and give it back. Every text colour is at least 4.5:1 on its background in both themes, and the theme is yours: System, Light or Dark, at the foot of every page.

## These docs {#docs}

- [[Ctrl+K]] or [[/]] opens search; the arrows choose a result, [[Enter]] opens it, [[Esc]] closes.
- Every heading has a link of its own, so a section can be sent to someone.
- On a phone, **Browse the docs** opens the pages list.
