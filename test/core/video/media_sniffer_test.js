// Run with: node test/core/video/media_sniffer_test.js
// Execute the actual injected source with browser stubs, rather than mirroring
// its URL conversion in a Dart helper.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const dart = fs.readFileSync(path.join(__dirname,
  '../../../lib/core/video/headless_browser_inappwebview.dart'), 'utf8');
const source = dart.match(/const String _mediaSnifferJs = r'''([\s\S]*?)''';/)[1];
const observed = [];
const responses = new Map();
function XMLHttpRequest() {}
XMLHttpRequest.prototype.open = function () {};
XMLHttpRequest.prototype.send = function () {};
function HTMLMediaElement() {}
Object.defineProperty(HTMLMediaElement.prototype, 'src', {
  configurable: true, get() { return this._src; }, set(v) { this._src = v; },
});
const window = {
  flutter_inappwebview: { callHandler: (...args) => observed.push(args) },
  fetch: async (input) => {
    const url = typeof input === 'string' ? input : input.url;
    return { url, headers: { get: () => responses.get(url) || '' } };
  },
};
vm.runInNewContext(source, {
  window, document: { baseURI: 'https://source.test/player/episode.html' },
  URL, XMLHttpRequest, HTMLMediaElement,
});
(async () => {
  await window.fetch('../streams/master.m3u8?token=abc');
  await window.fetch('/video/episode.mp4');
  await window.fetch('//cdn.test/master.m3u8');
  await window.fetch({ url: './playlist.m3u8' });
  responses.set('/stream/opaque', 'application/vnd.apple.mpegurl');
  await window.fetch('/stream/opaque');
  responses.set('/segment/opaque', 'video/mp2t');
  await window.fetch('/segment/opaque');
  new HTMLMediaElement().src = '../media/episode.mp4';
  assert.deepEqual([...new Set(observed.map((args) => args[1]))], [
    'https://source.test/streams/master.m3u8?token=abc',
    'https://source.test/video/episode.mp4',
    'https://cdn.test/master.m3u8',
    'https://source.test/player/playlist.m3u8',
    'https://source.test/stream/opaque',
    'https://source.test/media/episode.mp4',
  ]);
  assert.ok(observed.every((args) => args[0] === 'mediaSniffer'));
  console.log('Media sniffer: relative paths, Request input, MIME and TS filtering passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
