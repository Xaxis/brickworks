---
ai: Using Brickworks with the keyboard alone, a screen reader (the desktop app from 0.8.0), a bigger interface (85 to 150%) and reduced motion, and how the website and these docs meet the same needs.
rules:
  - In a browser the app draws its own controls, which a screen reader cannot reach; its keys all work.
title: Accessibility
nav: Accessibility
description: Using Brickworks with a keyboard alone, a screen reader, a bigger interface and less motion.
---

## In the desktop app {#desktop}

From 0.8.0, the desktop app can be used with a screen reader and with the keyboard alone.

- **Every control says its name**: each button, part, colour and field (*Select, V*; *Brick 2 x 4, 3001*), and what the status line says is read out.
- **The keyboard reaches everything.** [[F6]] (or [[Tab]], with a screen reader running) goes from the model into the toolbar, the parts and the colours, and back. [[Enter]] takes a part, and [[Enter]] again puts it down at the middle of the view.
- **Settings** has **Interface size**, 85 to 150%, and **Reduce motion**.

<!-- covers
ui:accessibility
-->

In a browser, the app draws its controls itself, where a screen reader cannot reach them; its keys all work there too.

## On the website {#website}

Every page of brickworks.diy, these docs included, works with a keyboard and a screen reader: a **Skip to content** link first, landmarks for the header, the pages list, the page and the footer, a visible focus ring on every control, and dialogs that keep the focus and give it back. Every text colour is at least 4.5:1 on its background in both themes, and the theme is yours: System, Light or Dark, at the foot of every page.

## These docs {#docs}

- [[Ctrl+K]] or [[/]] opens search; the arrows choose a result, [[Enter]] opens it, [[Esc]] closes.
- Every heading has a link of its own, so a section can be sent to someone.
- On a phone, **Browse the docs** opens the pages list.
