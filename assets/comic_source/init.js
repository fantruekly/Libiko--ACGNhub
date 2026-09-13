// ACGNhub comic-source JS API. Re-implements the Venera API shape on top of the
// Dart `sendMessage` bridge.
(function () {
  const call = (obj) => sendMessage(obj);

  class Comic {
    constructor({ id, title, subtitle, cover, tags, description } = {}) {
      this.id = id || ''; this.title = title || '';
      this.subtitle = subtitle; this.cover = cover;
      this.tags = tags || []; this.description = description;
    }
  }

  class ComicDetails {
    constructor(o = {}) {
      this.id = o.id || ''; this.title = o.title || '';
      this.subtitle = o.subtitle; this.cover = o.cover;
      this.tags = o.tags || []; this.description = o.description;
      this.chapters = o.chapters || {}; this.thumbnails = o.thumbnails || [];
      this.recommend = o.recommend || []; this.stars = o.stars;
    }
  }

  class Network {
    static sendRequest(method, url, headers, data, extra, bytes) {
      const r = call({ method: 'http', method2: method, url: url,
        headers: headers || {}, data: data, extra: extra, bytes: !!bytes });
      if (r.error) throw new Error(r.error);
      return r;
    }
    static get(url, headers) { return Network.sendRequest('GET', url, headers); }
    static post(url, data, headers) {
      return Network.sendRequest('POST', url, headers, data);
    }
    static put(url, data, headers) {
      return Network.sendRequest('PUT', url, headers, data);
    }
    static delete(url, data, headers) {
      return Network.sendRequest('DELETE', url, headers, data);
    }
    static fetchBytes(method, url, headers, data) {
      return Network.sendRequest(method, url, headers, data, null, true).body;
    }
    static setCookies(url, cookies) {
      return call({ method: 'cookie', op: 'set', url: url, cookies: cookies });
    }
    static getCookies(url) {
      return call({ method: 'cookie', op: 'get', url: url });
    }
  }

  class Convert {
    static utf8(bytes) { return call({ method: 'convert', type: 'utf8', data: bytes }); }
    static utf8Encode(s) { return call({ method: 'convert', type: 'utf8Encode', data: s }); }
    static gbk(bytes) { return call({ method: 'convert', type: 'gbk', data: bytes }); }
    static base64Encode(s) { return call({ method: 'convert', type: 'base64Encode', data: s }); }
    static base64Decode(s) { return call({ method: 'convert', type: 'base64Decode', data: s }); }
    static hexEncode(s) { return call({ method: 'convert', type: 'hexEncode', data: s }); }
    static hexDecode(s) { return call({ method: 'convert', type: 'hexDecode', data: s }); }
    static md5(s) { return call({ method: 'convert', type: 'md5', data: s }); }
    static sha1(s) { return call({ method: 'convert', type: 'sha1', data: s }); }
    static sha256(s) { return call({ method: 'convert', type: 'sha256', data: s }); }
    static hmac(data, key) { return call({ method: 'convert', type: 'hmac', data: data, key: key }); }
  }

  function wrap(handle) {
    return handle === null || handle === undefined ? null : new HtmlNode(handle);
  }

  class HtmlNode {
    constructor(handle) { this._h = handle; }
    querySelector(sel) { return wrap(call({ method: 'html', op: 'querySelector', handle: this._h, selector: sel })); }
    querySelectorAll(sel) { return (call({ method: 'html', op: 'querySelectorAll', handle: this._h, selector: sel }) || []).map(wrap); }
    getElementById(id) { return wrap(call({ method: 'html', op: 'getElementById', handle: this._h, id: id })); }
    get text() { return call({ method: 'html', op: 'text', handle: this._h }); }
    get innerHtml() { return call({ method: 'html', op: 'innerHtml', handle: this._h }); }
    get html() { return this.innerHtml; }
    get outerHtml() { return call({ method: 'html', op: 'outerHtml', handle: this._h }); }
    get attributes() { return call({ method: 'html', op: 'attributes', handle: this._h }); }
    attr(name) { return call({ method: 'html', op: 'attr', handle: this._h, name: name }); }
  }

  class HtmlDocument extends HtmlNode {
    constructor(html) { super(call({ method: 'html', op: 'parse', html: html })); }
  }

  class ComicSource {
    constructor() {
      this.name = ''; this.key = ''; this.version = ''; this.url = '';
    }
    loadSetting(key) {
      const v = call({ method: 'setting', op: 'get', key: this.key + '.' + key });
      if (v !== null && v !== undefined && v !== '') return v;
      const decl = this.settings ? this.settings[key] : null;
      if (decl && Object.prototype.hasOwnProperty.call(decl, 'default')) {
        return decl.default;
      }
      return null;
    }
    saveSetting(key, value) { return call({ method: 'setting', op: 'set', key: this.key + '.' + key, value: value }); }
  }

  globalThis.ComicSource = ComicSource;
  globalThis.Comic = Comic;
  globalThis.ComicDetails = ComicDetails;
  globalThis.Network = Network;
  globalThis.Convert = Convert;
  globalThis.HtmlDocument = HtmlDocument;
  globalThis.HtmlNode = HtmlNode;
  globalThis.comicSourceBridgeReady = true;
})();
