---
tools: move_part, pose_model, lay_flex, simulate_mechanism, search_gear_ratio, weakest_joints, list_motions, define_motion, play_motion, colour_hidden_parts
panels: SimulatePanel#simulate, PosePanel#motions, HiddenColoursPanel#hidden-colours
ai: Parts move on their real joints (hinges, clips, turntables, pins, axles, balls, gears, racks), hoses and chains are laid between connectors, stability is weighed, mechanisms are simulated, and a model keeps named motions. An assistant moves parts with move_part, lays hoses with lay_flex, and names motions with define_motion.
rules:
  - Gears mesh at their real ratios; a worm drives its gear and holds it.
  - simulate_mechanism reads the model and changes nothing.
  - Motions are saved in the model's file and play for anyone who opens it.
  - colour_hidden_parts shows a preview before it changes anything, and recolours a real set's own parts only when the person agreed.
title: Joints and mechanisms
nav: Joints and mechanisms
description: Move parts on their real joints, turn gear trains, lay hoses and chains, check a model stands, and give it motions of its own.
---

Brickworks knows how parts are joined: studs, Technic pins and axles, hinges, clips, ball joints, turntables and gears. So a model moves as the real one would, and the app can tell you whether it would stand. Joints are worked with the **Hinge** tool, a drag, the **Make** menu's hoses and chains, and **Tools › Check stability** and **Simulate mechanism…**.

## Swing on a hinge {#hinge}

![The moon rover's solar panel, hinge and all, selected and swung up beside the other lying flat, and Properties beside it saying the ten parts and their Hinge angle, -40.](/docs/img/joints-hinge.webp "Swing on its hinge (J): the panel, swung 15° a press; Properties says its angle.")

1. Choose the **Hinge** tool ([[Shift+I]], or **Tools › Hinge tool**).
2. Click a part that hangs on a hinge, a clip or a turntable. Each click swings it 15°; [[Shift]]-click swings it back.

What swings is what is selected. To swing a lid and what is built on it, select them all (or make them a sub-assembly), then press [[J]] with any tool ([[Shift+J]] back), or right-click and choose **Swing on its hinge**. For an exact angle, type it in the **Hinge** field of [Properties](/docs/panels-and-settings#properties). A swing that would run into another part is not made.

## Meet on hinges {#meet}

Select a part and the part it should meet across a chain of hinges, clips or turntables, then press **Meet** in Properties. Every joint between them swings, as little as it can, so a free end of one takes the other: a hinge's finger into its fork, a clip onto a bar. A click hinge stops on its clicks. It is one step to undo; when no swing makes them meet, nothing moves and the status bar says what is in the way.

<!-- covers
ui:meet on hinges
-->

## Grab and move on a joint {#grab}

With the **Select** tool, drag a part that hangs on a hinge, a clip, a turntable, a pin, an axle or a ball: it moves about its joint, and what is built on it comes too. [[Esc]] puts it back. To move a hand or a hook by its whole arm, hold the pointer still on it a moment, then drag.

The rest of the model answers as the real one would. A steering arm drags its tie rod and the other wheel. Gears and racks turn at their real ratios, and a worm holds its gear. Actuators slide. A beam on a free pin swings and settles; a flung wheel coasts to a stop. A hose bends with what it is fitted to. With no floor, a model pushed past its edge tips over.

<!-- covers
ui:grab and move on a joint
lib:moving a body on its joint
lib:moving a chain of joints
lib:closed loops of joints
lib:racks and their pinions
lib:worms hold their gears
lib:linear actuators
lib:swinging on a free joint
lib:coasting when flung
lib:hoses follow a grab
lib:a model that tips falls
lib:rigid bodies and joints
lib:axles and gears on a line
-->

![A Technic boom raised by hand on its joints.](/img/grab-720.webp "Drag a part and it moves about its real joint.")

## Hoses, tubes and chains {#flex}

![The Hose, tube or chain panel: buttons for a pneumatic tube, a ribbed hose, a Flex-system hose, a flexible axle, a string, a Technic chain, a tread, a rubber band and a spring or shock, with the length to use.](/docs/img/joints-flex.webp "Make › Hose, tube or chain… lays a flexible part between two connectors.")

1. **Make › Hose, tube or chain…**, and choose what to lay and its length (or the shortest that fits).
2. Click the pin hole or connector it starts on, then the one it ends on. For a chain or a tread, click the sprockets it goes round.
3. Drag the bend points to shape it; **Add a bend** gives another, **Straighten** takes them out. **Done**.

It is laid at the real part's length and saved as parts any LDraw program reads. **Make › Reshape the hose or chain** opens a laid one again. For track, see [Lay train track](/docs/placing-parts#tracks).

<!-- covers
ui:hoses and chains by hand
lib:flexible parts along a path
-->

## Rubber bands and springs {#bands}

For a band, choose **Rubber band** in the same panel (or a belt in the parts bin) and click the pulleys, wheels or axles it goes round, in order; it says how far it is stretched. For a spring, choose **Spring or shock** (or a shock absorber in the bin) and click the two pins it goes between. Move a part either is on and it follows, in the same undo step.

<!-- covers
ui:bands and springs by hand
-->

## Check stability {#stability}

**Tools › Check stability** ([[Alt+K]]) weighs the model: where its centre of mass is against its footprint, whether it stands, and which joints carry more than they hold. Those parts are selected. [View › Stress](/docs/the-view#stress) shows the same on every part as you build, and with the assistant on, a weak part's right-click menu has **Ask Claude to brace this…**.

<!-- covers
lib:stability
lib:balance
ui:balance readout
-->

![An arm reaching far past a small base: its footprint drawn in red, the centre of mass marked beyond its edge.](/img/stability-720.webp "Check stability on a model that would tip.")

## Simulate a mechanism {#simulate}

![Simulate mechanism on a kart driven from its steering wheel: the panel down the left saying what turns and how fast, where the steering stops and whether the kart stands, and the kart with its footprint drawn on the floor.](/docs/img/joints-steering.webp "Simulate mechanism turns the train from the part you choose, and finds where it stops.")

1. Select the part to drive (a crank, a steering wheel, a motor's axle), or none.
2. **Tools › Simulate mechanism…** ([[Alt+U]]). The train turns from it; click another axle or crank to drive that instead.
3. **Play**, or drag the slider through the cycle.

The panel says how fast each part turns, what locks the train, and whether the model stays standing as it turns. It finds where the motion stops: the first two parts that meet, tinted red, a linkage's range, or where a motor stalls under its load. Play stops there, and **Go to the stop** shows it. Nothing in the model changes. An assistant can find gears for a ratio you need (`search_gear_ratio`).

<!-- covers
ui:simulate mechanism
lib:mechanisms
lib:gear ratio search
-->

## Motions {#motions}

![The Motions panel for a kart: no motions yet, two suggested from what moves (Steer left and right, Turn the gears), each with Keep, and New motion.](/docs/img/joints-motions.webp "Build › Motions… suggests motions from what moves in the model.")

A model can keep named movements in its file: *Open the doors*, *Steer left and right*. **Build › Motions…** ([[Alt+O]]) lists them, and suggests more from what moves.

1. **Keep** a suggestion, or press **New motion** and name it.
2. Press **Record** and drag the parts in the view, or set a joint's slider to put a key.
3. **Play** or **Play backwards**. **Play all** runs them in turn.

Anyone who opens your shared model can play them.

A model on wheels can drive. Its suggestion *Drive and turn left* takes it 32 studs straight, then a quarter turn to the left. Under **Where it drives**, add a leg and pick **Straight**, **Left** or **Right**, with its length or its angle and radius in studs. As it drives, each wheel turns once for each round of its tyre, and the steering turns into the corners. **Play** leaves the model where the drive ends, as one undo step: the whole model moved, its wheels and steering at rest as they were, and a file from another program keeps every line but those that place its parts and sub-models. **Play backwards** drives it back the same way.

<!-- covers
ui:motions panel
lib:motions
lib:playing motions
lib:driving along a path
lib:posing joints
lib:keyframed animation
-->

## Hidden colours {#hidden-colours}

**Tools › Colour the hidden parts…** gives the parts nobody sees in the finished model a colour for each section or side, as big sets do, so a builder finds their place. It knows what shows through a gap or a window, and shows a preview first.

<!-- covers
ui:colour the hidden parts
lib:parts seen from outside
-->
