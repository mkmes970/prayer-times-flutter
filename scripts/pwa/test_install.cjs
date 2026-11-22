'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(
  `${__dirname}/../../mobile/prayer_times/web/install-app.js`, 'utf8');

function browser({ ua = 'Android Chrome', standalone = false,
  platform = 'Linux', touch = 0 } = {}) {
  const ids = {}, handlers = {};
  let document;
  class Element {
    constructor() {
      this.hidden = false;
      this.listeners = {};
      this.children = [];
      this.isConnected = true;
    }
    appendChild(child) {
      this.children.push(child);
      if (child.id) ids[child.id] = child;
    }
    setAttribute() {}
    addEventListener(name, handler) { this.listeners[name] = handler; }
    querySelector(selector) { return ids[selector] ||= new Element(); }
    focus() { document.activeElement = this; }
    async click() { await this.listeners.click?.({ target: this }); }
  }
  document = { body: new Element(), createElement: () => new Element(),
    activeElement: null };
  const mode = { matches: standalone, addEventListener(name, fn) {
    handlers.modeChange = fn;
  } };
  vm.runInNewContext(source, {
    document, navigator: { userAgent: ua, platform, maxTouchPoints: touch },
    console: { warn() {} },
    window: {
      matchMedia: () => mode,
      addEventListener: (name, fn) => { handlers[name] = fn; },
    },
  });
  return { ids, handlers, mode, document,
    button: ids['app-install'].children[0],
    banner: ids['app-install'], help: ids['app-install-help'] };
}

test('Android shows the install action and fallback instructions', async () => {
  const b = browser();
  assert.equal(b.banner.hidden, false);
  assert.equal(b.button.textContent, 'تثبيت التطبيق');
  await b.button.click();
  assert.equal(b.help.hidden, false);
  assert.match(b.ids['#install-instructions'].innerHTML, /Chrome/);
  await b.ids['#install-close'].click();
  assert.equal(b.help.hidden, true);
});

test('iPhone and desktop-mode iPad get Safari instructions', async () => {
  for (const options of [
    { ua: 'iPhone Safari' },
    { ua: 'Safari Mac', platform: 'MacIntel', touch: 5 },
  ]) {
    const b = browser(options);
    assert.equal(b.banner.hidden, false);
    await b.button.click();
    assert.match(b.ids['#install-instructions'].innerHTML, /Safari/);
    assert.match(b.ids['#install-instructions'].innerHTML, /إضافة إلى الشاشة الرئيسية/);
  }
});

test('installed launch hides the button; normal desktop is not obstructed', () => {
  assert.equal(browser({ standalone: true }).banner.hidden, true);
  assert.equal(browser({ ua: 'Desktop Firefox' }).banner.hidden, true);
});

test('native prompt waits for a click and is consumed only once', async () => {
  const b = browser();
  let calls = 0, prevented = false;
  b.handlers.beforeinstallprompt({
    preventDefault() { prevented = true; },
    async prompt() { calls++; },
    userChoice: Promise.resolve({ outcome: 'dismissed' }),
  });
  assert.equal(prevented, true);
  assert.equal(calls, 0);
  await b.button.click();
  assert.equal(calls, 1);
  assert.equal(b.banner.hidden, false);
  await b.button.click();
  assert.equal(calls, 1);
  assert.equal(b.help.hidden, false);
});

test('acceptance or appinstalled removes the install action', async () => {
  const b = browser();
  b.handlers.beforeinstallprompt({
    preventDefault() {}, async prompt() {},
    userChoice: Promise.resolve({ outcome: 'accepted' }),
  });
  await b.button.click();
  assert.equal(b.banner.hidden, true);
  const c = browser();
  await c.button.click();
  c.handlers.appinstalled();
  assert.equal(c.banner.hidden, true);
  assert.equal(c.help.hidden, true);
});

test('native prompt errors show instructions and re-enable the button', async () => {
  const b = browser();
  b.handlers.beforeinstallprompt({
    preventDefault() {}, async prompt() { throw Error('Unavailable'); },
  });
  await b.button.click();
  assert.equal(b.button.disabled, false);
  assert.equal(b.help.hidden, false);
});

test('Escape dismisses instructions and returns keyboard focus', async () => {
  const b = browser();
  b.button.focus();
  await b.button.click();
  let prevented = false;
  b.help.listeners.keydown({ key: 'Escape', preventDefault() { prevented = true; } });
  assert.equal(prevented, true);
  assert.equal(b.help.hidden, true);
  assert.equal(b.document.activeElement, b.button);
});
