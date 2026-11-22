import assert from "node:assert/strict";
import { DuaRotation, duaGroups, duaIntervalMs } from "./dua-rotation.ts";

assert.equal(duaIntervalMs, 10000);
assert.equal(duaGroups.reduce((total, group) => total + group.texts.length, 0), 744);
assert.equal(duaGroups.filter(group => group.author).length, 24);
assert.ok(duaGroups.every(group => group.texts.length === 1));
for (let seed = 1; seed <= 50; seed++) {
  let state = seed;
  const random = () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
  const rotation = new DuaRotation(duaGroups, random);
  let previous: (typeof duaGroups)[number] | undefined;
  for (let cycle = 0; cycle < 4; cycle++) {
    const seen = new Set<(typeof duaGroups)[number]>();
    let count = 0;
    for (let block = 0; block < duaGroups.length; block++) {
      const group = rotation.group;
      assert.notEqual(group, previous);
      assert.ok(!seen.has(group));
      seen.add(group);
      for (let index = 0; index < group.texts.length; index++) {
        assert.equal(rotation.group, group);
        assert.equal(rotation.textIndex, index);
        assert.equal(
          rotation.current,
          group.author ? `قال ${group.author}: ${group.texts[index]}` : group.texts[index],
        );
        rotation.next();
        count++;
      }
      previous = group;
    }
    assert.equal(count, 744);
  }
}
console.log("PASS: all 744 individual texts, including 600 PDF hadiths and the original 144 texts, randomly mixed without omissions across 200 cycles.");
