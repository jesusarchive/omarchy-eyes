# Eyes for Omarchy

Based on X.Org's [xeyes](https://gitlab.freedesktop.org/xorg/app/xeyes), Eyes adds a pair of animated eyes to the [Omarchy](https://omarchy.org) bar. The pupils follow the pointer across every monitor, and the widget adapts to horizontal and vertical bars.

![Eyes in the Omarchy bar](preview.png)

## Requirements

- Omarchy Quattro with the Omarchy Shell plugin system.
- Hyprland.
- Python 3.

The plugin does not install dependencies or require elevated privileges.

## Installation

Install and enable the plugin from GitHub:

```bash
omarchy plugin add https://github.com/jesusarchive/omarchy-eyes.git --enable
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

## License and attribution

The plugin is licensed under the [MIT License](LICENSE). Its eye geometry and pupil movement are adapted from X.Org's [`Eyes.c`](https://gitlab.freedesktop.org/xorg/app/xeyes/-/blob/master/Eyes.c). See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the upstream license and copyright notices.
