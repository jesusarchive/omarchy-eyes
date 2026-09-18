.pragma library

// Geometry and pupil calculations adapted from x.org app/xeyes 1.3.0,
// Eyes.c. xeyes gives each eye a 2.0-unit-wide cell. The widget scales these
// units to the bar height.
var EYE_OFFSET = 0.1                                     // padding between eyes
var EYE_THICK = 0.175                                    // thickness of the rim
var BALL_DIAM = 0.3                                      // the pupil
var BALL_PAD = 0.175                                     // pupil clearance inside the white
var EYE_DIAM = 2.0 - (EYE_THICK + EYE_OFFSET) * 2.0      // 1.45, the white of the eye
var OUTER_DIAM = EYE_DIAM + 2.0 * EYE_THICK              // 1.8, rim included
var BALL_DIST = (EYE_DIAM - BALL_DIAM) / 2.0 - BALL_PAD  // 0.4, how far a pupil travels

// layout_standard puts the two eye centers at x=0 and x=2, and the bounding
// box reaches half an eye minus the padding past each one.
var SPACING = 2.0
var BBOX_W = SPACING + OUTER_DIAM                        // 3.8
var BBOX_H = OUTER_DIAM                                  // 1.8

// Adapt computePupil() from Eyes.c. dx and dy point from the eye centre to the
// cursor. The result is the pupil's offset from the eye centre.
//
// Pass screen bounds relative to the eye centre to enable xeyes' -distance
// behaviour. It scales pupil travel by the cursor's distance across the
// screen. Xeyes disables this option by default.
function pupilOffset(dx, dy, screen) {
  if (dx === 0 && dy === 0) return { x: 0, y: 0 }

  var angle = Math.atan2(dy, dx)
  var dist = BALL_DIST

  if (screen) {
    var x0 = screen.x
    var y0 = screen.y
    var x1 = x0 + screen.width
    var y1 = y0 + screen.height
    var xEdge = dx < 0 ? x0 : x1
    var yEdge = dy < 0 ? y0 : y1
    var xRatio = dx === 0 || xEdge === 0 ? 0 : dx / xEdge
    var yRatio = dy === 0 || yEdge === 0 ? 0 : dy / yEdge

    // The larger axis ratio identifies the first screen edge hit by the ray.
    var screenFraction = Math.max(0, Math.min(1, Math.max(xRatio, yRatio)))
    dist *= screenFraction
  }

  // Place the pupil on a nearby cursor. This produces xeyes' cross-eyed state.
  if (dist > Math.hypot(dx, dy)) return { x: dx, y: dy }
  return { x: dist * Math.cos(angle), y: dist * Math.sin(angle) }
}
