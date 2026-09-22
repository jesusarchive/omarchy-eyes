import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import "Eyes.js" as Eyes

// Wayland does not expose the global pointer position to QML, so
// cursor-tracker.py reads Hyprland's `cursorpos` response.
BarWidget {
  id: root
  moduleName: "jesusarchive.eyes"

  readonly property real eyeHeight: Math.max(8, barSize - 8)

  // xeyes maps its 3.8 x 1.8 bounds onto its default 150x100 window with
  // separate horizontal and vertical scales. This turns the circles into
  // ellipses.
  readonly property real drawAspect: 150.0 / 100.0
  readonly property real drawWidth: eyeHeight * drawAspect

  // unitX and unitY convert xeyes units to bar pixels. The drawing uses unitX
  // for its geometry, then a vertical scale converts it to unitY.
  readonly property real unitX: drawWidth / Eyes.BBOX_W
  readonly property real unitY: eyeHeight / Eyes.BBOX_H
  readonly property real centreInset: (1.0 - Eyes.EYE_OFFSET) * unitX

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

  // A bar panel spans its edge. Top and left bars start at the screen origin;
  // bottom and right bars need an offset to reach the far edge.
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

    var offset = Eyes.pupilOffset((cursorX - eyeX) / unitX, (cursorY - eyeY) / unitY)
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
      String(1.0 / 60.0)
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

          Rectangle {
            anchors.fill: parent
            radius: width / 2.0
            color: "black"
            antialiasing: true

            Rectangle {
              anchors.centerIn: parent
              width: Eyes.EYE_DIAM * root.unitX
              height: width
              radius: width / 2.0
              color: "white"
              antialiasing: true
            }
          }

          Rectangle {
            width: Eyes.BALL_DIAM * root.unitX
            height: width
            radius: width / 2.0
            color: "black"
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
    acceptedButtons: Qt.NoButton

    onEntered: if (root.bar) root.bar.showTooltip(root, "Eyes")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
