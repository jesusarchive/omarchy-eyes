import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import "Eyes.js" as Eyes

// Eyes in the bar: the two eyes from x.org's demo app, following the pointer
// across every monitor the way xfce4-eyes-plugin did in its panel.
//
// The proportions and the pupil math come straight from Eyes.c (see Eyes.js).
// The one thing that cannot be ported is how xeyes learns where the pointer
// is: X11 let any client ask the server, Wayland does not, so
// cursor-tracker.py asks Hyprland for `cursorpos` and streams the answer in.
BarWidget {
  id: root
  moduleName: "jesusarchive.eyes"

  function clamped(value, min, max, fallback) {
    var n = Number(value)
    if (!isFinite(n)) return fallback
    return Math.max(min, Math.min(max, n))
  }

  // Samples per second. xeyes redraws on every pointer motion event; polling
  // at 60 costs well under a millisecond of CPU per second, and an unchanged
  // position never reaches the widget at all.
  readonly property int fps: clamped(setting("fps", 60), 1, 144, 60)

  // Height of the eyes in bar pixels. 0 fits them to the bar.
  readonly property real eyeHeight: {
    var explicit = clamped(setting("size", 0), 0, 400, 0)
    return explicit > 0 ? explicit : Math.max(8, barSize - 8)
  }

  // xeyes maps its 3.8 x 1.8 bounding box onto the window with a separate
  // scale per axis (SetTransform keeps mx and my independent), so its default
  // 150x100 window is what gives the eyes their egg shape. Keeping that ratio
  // is what makes this read as xeyes instead of as two circles; "round" opts
  // out and gives the shape a square xeyes window would draw.
  readonly property bool round: String(setting("shape", "stretched")) === "round"
  readonly property real drawAspect: round ? Eyes.BBOX_W / Eyes.BBOX_H : 150.0 / 100.0
  readonly property real drawWidth: eyeHeight * drawAspect

  // One bar pixel per xeyes unit, per axis. Every length in the drawing is
  // measured in unitX and then squashed to unitY by one transform, so the
  // circles become the same ellipses xeyes fills.
  readonly property real unitX: drawWidth / Eyes.BBOX_W
  readonly property real unitY: eyeHeight / Eyes.BBOX_H
  readonly property real centreInset: (1.0 - Eyes.EYE_OFFSET) * unitX

  // xeyes' -distance: pupil travel scales with how far across the screen the
  // cursor is, so the eyes look *into* the distance rather than staring at
  // full stretch. Off in xeyes, off here.
  readonly property bool distance: {
    var value = setting("distance", "Off")
    return value === true || String(value) === "On"
  }

  readonly property string clickCommand: String(setting("onClick", ""))

  // xeyes' own defaults are the X toolkit's foreground and background: a black
  // rim, a white eye, a black pupil. "theme" takes the bar's colors instead.
  function resolveColor(name, xeyesDefault, themeColor) {
    var value = String(setting(name, ""))
    if (value === "") return xeyesDefault
    if (value === "theme") return themeColor
    return value
  }

  readonly property color outlineColor: resolveColor("outline", "black", bar ? bar.barForeground : "black")
  readonly property color centerColor: resolveColor("center", "white", bar ? bar.background : "white")
  readonly property color pupilColor: resolveColor("pupil", "black", bar ? bar.barForeground : "black")

  // Cursor position in Hyprland's layout coordinates — the same space the
  // monitors are placed in, so an eye on one screen can look at a pointer on
  // another.
  property real cursorX: 0
  property real cursorY: 0
  property bool tracking: false

  // Looked up per sample rather than bound: QsWindow is an attached property
  // that does not exist yet while the widget is being built, and a binding
  // that reads it too early would latch onto null and never look again.
  function hostWindow() {
    return root.QsWindow ? root.QsWindow.window : null
  }

  // mapToItem() is not a reactive binding, so a bar that moves or resizes
  // under a still cursor needs a nudge to recompute the stare.
  property int layoutRevision: 0
  onUnitXChanged: layoutRevision++
  onUnitYChanged: layoutRevision++
  onXChanged: layoutRevision++
  onYChanged: layoutRevision++
  Connections {
    target: root.bar
    function onPositionChanged() { root.layoutRevision++ }
  }

  // A bar panel spans its edge, so its window sits at the screen origin
  // unless it is anchored to the far edge.
  function windowOrigin(window, screen) {
    var side = bar ? bar.position : "top"
    if (side === "bottom") return { "x": 0, "y": screen.height - window.height }
    if (side === "right") return { "x": screen.width - window.width, "y": 0 }
    return { "x": 0, "y": 0 }
  }

  // Pupil offset for one eye, in the drawing's own pixels, as xeyes computes
  // it: the cursor is converted into xeyes units per axis first, which is what
  // makes a stretched eye look along the stretched geometry.
  function pupilOffset(index) {
    var revision = layoutRevision // dependency: recompute when the bar moves
    if (!tracking) return { "x": 0, "y": 0 }

    var window = hostWindow()
    var screen = window ? window.screen : null
    if (!screen) return { "x": 0, "y": 0 }

    var origin = windowOrigin(window, screen)
    var local = eyeField.mapToItem(null,
                                   centreInset + index * Eyes.SPACING * unitX,
                                   eyeField.height / 2.0)
    var eyeX = screen.x + origin.x + local.x
    var eyeY = screen.y + origin.y + local.y

    var rect = null
    if (distance) {
      rect = {
        "x": (screen.x - eyeX) / unitX,
        "y": (screen.y - eyeY) / unitY,
        "width": screen.width / unitX,
        "height": screen.height / unitY
      }
    }

    var offset = Eyes.pupilOffset((cursorX - eyeX) / unitX, (cursorY - eyeY) / unitY, rect)
    // Laid out in unitX and squashed to unitY by eyeField's transform, so the
    // y offset is carried in the same units as everything else in there.
    return { "x": offset.x * unitX, "y": offset.y * unitX }
  }

  implicitWidth: vertical ? barSize : Math.round(drawWidth)
  implicitHeight: vertical ? Math.round(drawWidth) : barSize

  Process {
    id: tracker
    running: root.visible && Hyprland.requestSocketPath !== ""
    command: [
      "/usr/bin/python3",
      String(Qt.resolvedUrl("cursor-tracker.py")).replace(/^file:\/\//, ""),
      Hyprland.requestSocketPath,
      String(1.0 / root.fps)
    ]

    stdout: SplitParser {
      onRead: function (line) {
        var parts = String(line).split(",")
        if (parts.length < 2) return
        var x = Number(parts[0])
        var y = Number(parts[1])
        if (!isFinite(x) || !isFinite(y)) return
        root.cursorX = x
        root.cursorY = y
        root.tracking = true
      }
    }
  }

  // A vertical bar turns the pair a quarter turn, so they stack instead of
  // overflowing a 28px-wide strip.
  Item {
    id: stage
    anchors.centerIn: parent
    width: Math.round(root.drawWidth)
    height: Math.round(root.eyeHeight)
    rotation: root.vertical ? 90 : 0

    // The eyes are drawn round, in unitX, and this squashes them to unitY —
    // one transform standing in for xeyes' two-axis SetTransform.
    Item {
      id: eyeField
      anchors.centerIn: parent
      width: Eyes.BBOX_W * root.unitX
      height: Eyes.BBOX_H * root.unitX

      layer.enabled: true
      layer.samples: 8
      layer.smooth: true

      transform: Scale {
        origin.x: eyeField.width / 2.0
        origin.y: eyeField.height / 2.0
        yScale: root.unitY / root.unitX
      }

      Repeater {
        model: 2

        Item {
          id: eye
          required property int index

          readonly property var offset: root.pupilOffset(index)
          readonly property real diameter: Eyes.OUTER_DIAM * root.unitX

          x: root.centreInset + index * Eyes.SPACING * root.unitX - diameter / 2.0
          y: (eyeField.height - diameter) / 2.0
          width: diameter
          height: diameter

          // The rim is the black disc showing around the white one, exactly
          // the way Eyes.c layers the two ellipses.
          Rectangle {
            anchors.fill: parent
            radius: width / 2.0
            color: root.outlineColor
            antialiasing: true

            Rectangle {
              anchors.centerIn: parent
              width: Eyes.EYE_DIAM * root.unitX
              height: width
              radius: width / 2.0
              color: root.centerColor
              antialiasing: true
            }
          }

          Rectangle {
            width: Eyes.BALL_DIAM * root.unitX
            height: width
            radius: width / 2.0
            color: root.pupilColor
            antialiasing: true
            x: (eye.width - width) / 2.0 + eye.offset.x
            y: (eye.height - height) / 2.0 + eye.offset.y

            // Samples land on frame boundaries; a short glide keeps a fast
            // flick across the screen from looking stepped.
            Behavior on x { enabled: root.tracking; NumberAnimation { duration: 45; easing.type: Easing.Linear } }
            Behavior on y { enabled: root.tracking; NumberAnimation { duration: 45; easing.type: Easing.Linear } }
          }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: root.clickCommand !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor

    onClicked: if (root.clickCommand !== "" && root.bar) root.bar.run(root.clickCommand)
    onEntered: if (root.bar) root.bar.showTooltip(root, "Eyes")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
