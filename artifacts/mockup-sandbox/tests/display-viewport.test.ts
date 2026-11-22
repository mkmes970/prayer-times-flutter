import assert from "node:assert/strict";
import { landscapeDisplaySize, enterPrayerFullscreen } from "../src/components/mockups/prayer-themes/display-viewport.ts";

for (const [width, height] of [[402, 874], [465, 1024], [1024, 465], [1920, 1080], [2560, 1080], [1024, 768]]) {
  const display = landscapeDisplaySize(width, height);
  assert.ok(display.width >= display.height);
  assert.equal(display.width * display.height, width * height);
  assert.equal(display.rotation, height > width ? 90 : 0);
  assert.equal(display.rotation === 90 ? display.height : display.width, width);
  assert.equal(display.rotation === 90 ? display.width : display.height, height);
}

let requested = 0;
let locked = 0;
let rejectLock = false;
const fakeDocument = { fullscreenElement: null as null | HTMLElement, fullscreenEnabled: true };
Object.defineProperty(globalThis, "document", { value: fakeDocument, configurable: true });
Object.defineProperty(globalThis, "screen", {
  value: { orientation: { async lock(value: string) {
    assert.equal(value, "landscape");
    locked++;
    if (rejectLock) throw new Error("Browser refuses orientation locking");
  } } }, configurable: true,
});
const element = { async requestFullscreen() { requested++; } } as HTMLElement;
assert.equal(await enterPrayerFullscreen(element), null);
assert.equal(requested, 1);
assert.equal(locked, 1);
rejectLock = true;
assert.equal(await enterPrayerFullscreen(element), null);
fakeDocument.fullscreenElement = element;
assert.equal(await enterPrayerFullscreen(element), null);
assert.equal(requested, 2);
fakeDocument.fullscreenElement = null;
fakeDocument.fullscreenEnabled = false;
assert.match((await enterPrayerFullscreen(element))!, /لا يسمح/);
fakeDocument.fullscreenEnabled = true;
assert.match((await enterPrayerFullscreen({
  async requestFullscreen() { throw new Error("Fullscreen denied"); },
} as HTMLElement))!, /لم يسمح/);
console.log("PASS: edge-to-edge landscape dimensions, fullscreen activation, orientation lock, and browser-denied fallback.");
