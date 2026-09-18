import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs
  .readFileSync(new URL("../Eyes.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\s*$/m, "");
const eyes = { Math };
vm.createContext(eyes);
vm.runInContext(source, eyes);

const closeTo = (actual, expected, epsilon = 1e-12) =>
  assert.ok(Math.abs(actual - expected) <= epsilon, `${actual} != ${expected}`);

test("constants retain the xeyes proportions", () => {
  closeTo(eyes.EYE_DIAM, 1.45);
  closeTo(eyes.OUTER_DIAM, 1.8);
  closeTo(eyes.BALL_DIST, 0.4);
  closeTo(eyes.BBOX_W, 3.8);
  closeTo(eyes.BBOX_H, 1.8);
});

test("a pupil at the cursor stays centered", () => {
  const result = eyes.pupilOffset(0, 0);
  closeTo(result.x, 0);
  closeTo(result.y, 0);
});

test("a nearby cursor places the pupil on the cursor", () => {
  const result = eyes.pupilOffset(0.1, -0.2);
  closeTo(result.x, 0.1);
  closeTo(result.y, -0.2);
});

test("a distant cursor clamps pupil travel in each direction", () => {
  const cases = [
    [10, 0, eyes.BALL_DIST, 0],
    [-10, 0, -eyes.BALL_DIST, 0],
    [0, 10, 0, eyes.BALL_DIST],
    [0, -10, 0, -eyes.BALL_DIST],
  ];
  for (const [dx, dy, expectedX, expectedY] of cases) {
    const result = eyes.pupilOffset(dx, dy);
    closeTo(result.x, expectedX);
    closeTo(result.y, expectedY);
  }
});
