.pragma library

// Geometry and pupil math lifted from the xeyes source (x.org app/xeyes
// 1.3.0, Eyes.c) so these are the same eyes rather than an impression of
// them. xeyes lays each eye out in a cell 2.0 units wide; every length below
// is in those units and the widget scales them to the bar height.
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

// computePupil() from Eyes.c, in eye-local units: dx/dy point from the eye
// centre to the cursor and the result is the pupil's offset from that centre.
//
// `screen` is the -distance behaviour, off in xeyes by default: instead of
// staring at full stretch all the time, the pupil's travel scales with how
// far across the screen the cursor is, so the eyes read as looking *into* the
// distance. Pass the screen rect relative to the eye centre to switch it on.
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

    // The ray reaches the first screen edge at the larger axis ratio. Using
    // both axes here also keeps the direction stable in every quadrant.
    var screenFraction = Math.max(0, Math.min(1, Math.max(xRatio, yRatio)))
    dist *= screenFraction
  }

  // Closer than the pupil can travel, the pupil sits on the cursor itself —
  // what makes xeyes go cross-eyed when you park the pointer on it.
  if (dist > Math.hypot(dx, dy)) return { x: dx, y: dy }
  return { x: dist * Math.cos(angle), y: dist * Math.sin(angle) }
}
