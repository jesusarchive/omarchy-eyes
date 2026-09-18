# Eyes for Omarchy

Eyes puts a pair of [xeyes](https://gitlab.freedesktop.org/xorg/app/xeyes) in the [Omarchy](https://omarchy.org) bar. The pupils follow the pointer across every monitor.

Plugin ID: `jesusarchive.eyes`

![Eyes in the Omarchy bar](assets/screenshot.png)

## What it does

- Tracks the pointer across the full Hyprland monitor layout, not only while it is over the bar.
- Reproduces the dimensions and pupil movement from X.Org's `Eyes.c`.
- Goes cross-eyed when the pointer moves closer than the pupil's maximum travel.
- Rotates the pair on a vertical bar while keeping the pupils aimed at the pointer.
- Skips duplicate position updates, so a stationary pointer does not trigger QML redraws.

The eye shape matches the original xeyes window. Xeyes maps a 3.8 by 1.8 drawing onto a 150 by 100 window with separate horizontal and vertical scales. This stretches the circles into the familiar egg shape.

## Requirements

- Omarchy Quattro with the Omarchy Shell plugin system.
- Hyprland.
- `/usr/bin/python3`.

The plugin does not install packages, modify system files, or require elevated privileges.

## Install

Install and enable the plugin from GitHub:

```bash
omarchy plugin add https://github.com/jesusarchive/omarchy-eyes.git --enable
```

Omarchy places the widget in its default `left` section. Move it with:

```bash
omarchy bar move jesusarchive.eyes --section right
```

Valid sections are `left`, `center`, and `right`.

### Install from a local checkout

```bash
omarchy plugin validate .
mkdir -p ~/.config/omarchy/plugins/jesusarchive.eyes
rsync -a --delete --exclude .git ./ ~/.config/omarchy/plugins/jesusarchive.eyes/
omarchy plugin enable jesusarchive.eyes left
```

## Disable or remove

Remove the widget from the bar without deleting its files:

```bash
omarchy plugin disable jesusarchive.eyes
```

Delete the installed plugin:

```bash
omarchy plugin remove jesusarchive.eyes
```

## How cursor tracking works

Wayland clients receive pointer events only while the pointer is over one of their surfaces. That prevents the QML widget from tracking the pointer across the desktop by itself.

`cursor-tracker.py` polls Hyprland's `cursorpos` request through its Unix socket. It sends a new position to the widget only when the coordinates change. The default rate is 60 samples per second. The helper uses Python's standard library and does not call `hyprctl` for each sample.

The shell reloads plugin files after changes. If an existing widget instance does not update, restart the shell:

```bash
omarchy restart shell
```

## xeyes geometry

The drawing uses the constants and pupil calculation from X.Org's `Eyes.c`:

| Constant | Value | Meaning |
|---|---|---|
| `EYE_THICK` | `0.175` | Rim thickness. |
| `EYE_DIAM` | `1.45` | Diameter of the white area. |
| `BALL_DIAM` | `0.3` | Pupil diameter. |
| `BALL_DIST` | `0.4` | Maximum pupil travel from the centre. |
| `EYE_OFFSET` | `0.1` | Padding between the eyes. |

## Inspiration

[X.Org xeyes](https://gitlab.freedesktop.org/xorg/app/xeyes) is the source of the eye geometry and pupil movement used here.

## License and credit

The plugin is released under the MIT license in [`LICENSE`](LICENSE). Code
adapted from xeyes retains its upstream notice in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

The eye geometry and pupil calculation in `Eyes.js` are adapted from X.Org's [`Eyes.c`](https://gitlab.freedesktop.org/xorg/app/xeyes/-/blob/master/Eyes.c), copyright X Consortium and q3k. Xeyes was written by Keith Packard and Jim Gettys.
