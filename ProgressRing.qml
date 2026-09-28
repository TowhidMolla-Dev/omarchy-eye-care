import QtQuick
import QtQuick.Shapes
import qs.Commons

// Thin circular progress ring, drawn behind a bar-widget glyph.
//
// The Compact bar mode hides the numeric timer, so the ring carries the
// same information as shape instead of text: an empty ring means the
// interval has barely started, a full sweep means it is done. That keeps
// the widget glanceable without needing the pointer, which is the whole
// point -- a timer you have to hover to read defeats the purpose of a bar.
Item {
  id: root

  // 0..1 fraction of the interval already elapsed.
  property real progress: 0
  property real thickness: Style.spaceReal(2)
  property color trackColor: Util.alpha(Color.foreground, 0.22)
  property color progressColor: Color.accent

  readonly property real radius: Math.max(1, (Math.min(width, height) - root.thickness) / 2)
  readonly property real centerX: width / 2
  readonly property real centerY: height / 2
  readonly property real sweep: 360 * Math.min(1, Math.max(0, root.progress))

  // ShapePath is not an Item, so a zero-length arc is hidden by giving it a
  // transparent stroke rather than by setting visible: a round-capped arc
  // still paints a dot at 0, which would read as "a little progress" on a
  // timer that has only just started.
  readonly property color sweepColor: root.sweep > 0.1 ? root.progressColor : "transparent"

  // A 360-degree arc closes back onto its own start point, which Qt's path
  // stroker treats as degenerate and drops. 359.9 draws the full circle.
  readonly property real trackSweep: 359.9

  Shape {
    anchors.fill: parent
    antialiasing: true

    // Unfilled track.
    ShapePath {
      strokeColor: root.trackColor
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.centerX
      startY: root.centerY - root.radius

      PathAngleArc {
        centerX: root.centerX
        centerY: root.centerY
        radiusX: root.radius
        radiusY: root.radius
        startAngle: -90
        sweepAngle: root.trackSweep
      }
    }

    // Elapsed portion. Both arcs share the 12-o'clock start, so only the
    // sweep length moves as the countdown advances.
    ShapePath {
      strokeColor: root.sweepColor
      strokeWidth: root.thickness
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.centerX
      startY: root.centerY - root.radius

      PathAngleArc {
        centerX: root.centerX
        centerY: root.centerY
        radiusX: root.radius
        radiusY: root.radius
        startAngle: -90
        sweepAngle: root.sweep
      }
    }
  }
}
