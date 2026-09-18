import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import "Eyes.js" as Eyes

// Draw two xeyes-style eyes in the bar and point them at the cursor.
//
// Eyes.js adapts the proportions and pupil calculation from Eyes.c. X11 lets
// xeyes query the pointer directly. Wayland does not, so cursor-tracker.py
// reads Hyprland's `cursorpos` response instead.
BarWidget {
  id: root
  moduleName: "jesusarchive.eyes"

  function clamped(value, min, max, fallback) {
    var n = Number(value)
    if (!isFinite(n)) return fallback
    return Math.max(min, Math.min(max, n))
  }

  // Number of Hyprland cursor-position requests per second. The helper does
  // not send duplicate positions to the widget.
  readonly property int fps: clamped(setting("fps", 60), 1, 144, 60)

  // Height of the eyes in bar pixels. 0 fits them to the bar.
  readonly property real eyeHeight: {
    var explicit = clamped(setting("size", 0), 0, 400, 0)
    return explicit > 0 ? explicit : Math.max(8, barSize - 8)
  }

  // xeyes maps its 3.8 x 1.8 bounds onto the window with separate horizontal
  // and vertical scales. Its default 150x100 window turns the circles into
  // ellipses. The "round" setting uses the aspect ratio of the source bounds.
  readonly property bool round: String(setting("shape", "stretched")) === "round"
  readonly property real drawAspect: round ? Eyes.BBOX_W / Eyes.BBOX_H : 150.0 / 100.0
  readonly property real drawWidth: eyeHeight * drawAspect

  // unitX and unitY convert xeyes units to bar pixels. The drawing uses unitX
  // for its geometry, then a vertical scale converts it to unitY.
  readonly property real unitX: drawWidth / Eyes.BBOX_W
  readonly property real unitY: eyeHeight / Eyes.BBOX_H
  readonly property real centreInset: (1.0 - Eyes.EYE_OFFSET) * unitX

  // xeyes' -distance option scales pupil travel by the cursor's distance from
  // the eye. Both xeyes and this plugin disable it by default.
  readonly property bool distance: {
    var value = setting("distance", "Off")
    return value === true || String(value) === "On"
  }

  readonly property string clickCommand: String(setting("onClick", ""))

  // xeyes uses black for the rim and pupil, and white for the eye. The value
  // "theme" replaces those defaults with the bar colours.
  function resolveColor(name, xeyesDefault, themeColor) {
    var value = String(setting(name, ""))
    if (value === "") return xeyesDefault
    if (value === "theme") return themeColor
    return value
  }

  readonly property color outlineColor: resolveColor("outline", "black", bar ? bar.barForeground : "black")
  readonly property color centerColor: resolveColor("center", "white", bar ? bar.background : "white")
  readonly property color pupilColor: resolveColor("pupil", "black", bar ? bar.barForeground : "black")

  // Hyprland reports the cursor in global layout coordinates. Monitor
  // positions use the same coordinate system.
  property real cursorX: 0
  property real cursorY: 0
  property bool tracking: false

  // Resolve QsWindow for each sample. The attached property may not exist
  // while QML creates the widget, and an early binding can remain null.
  function hostWindow() {
    return root.QsWindow ? root.QsWindow.window : null
  }

  // mapToItem() is not reactive. Increment this value when the bar moves or
  // resizes so pupilOffset() runs again while the cursor is stationary.
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

  // Convert the cursor to xeyes units before calculating the pupil offset.
  // Separate axis units preserve the direction inside a stretched eye.
  function pupilOffset(index) {
    var revision = layoutRevision // Recompute when the bar moves.
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
    // eyeField applies the unitY scale later, so both offsets use unitX here.
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

    // Draw circles in unitX, then scale the vertical axis to unitY.
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

          // Draw the rim behind the smaller eye disc, as Eyes.c does.
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

            // Interpolate between samples to reduce visible stepping.
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
