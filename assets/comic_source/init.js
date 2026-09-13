// ACGNhub comic-source JS API. Re-implements the Venera API shape on top of the
// Dart `sendMessage` bridge.
(function () {
  const call = (obj) => sendMessage(obj);

  const _log = (args) =>
    call({ method: 'log', message: Array.prototype.map.call(args, String).join(' ') });
  globalThis.console = {
    log: function () { _log(arguments); },
    info: function () { _log(arguments); },
    debug: function () { _log(arguments); },
    warn: function () { _log(arguments); },
    error: function () { _log(arguments); },
  };

  class Comic {
    constructor(o = {}) {
      this.id = ''; this.title = '';
      this.subtitle = null; this.cover = null;
      this.tags = []; this.description = null;
      Object.assign(this, o);
      if (this.id == null) this.id = '';
      if (this.title == null) this.title = '';
      if (this.tags == null) this.tags = [];
    }
  }

  class ComicDetails {
    constructor(o = {}) {
      this.id = ''; this.title = '';
      this.subtitle = null; this.cover = null;
      this.tags = []; this.description = null;
      this.chapters = {}; this.thumbnails = [];
      this.recommend = []; this.stars = null;
      Object.assign(this, o);
      if (this.id == null) this.id = '';
      if (this.title == null) this.title = '';
      if (this.tags == null) this.tags = [];
      if (this.chapters == null) this.chapters = {};
      if (this.thumbnails == null) this.thumbnails = [];
      if (this.recommend == null) this.recommend = [];
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
    static post(url, headers, data) {
      return Network.sendRequest('POST', url, headers, data);
    }
    static put(url, headers, data) {
      return Network.sendRequest('PUT', url, headers, data);
    }
    static delete(url, headers, data) {
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
    static deleteCookies(url) {
      return call({ method: 'cookie', op: 'set', url: url, cookies: null });
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
    static decodeBase64(s) { return call({ method: 'convert', type: 'base64Decode', data: s }); }
    static encodeBase64(s) { return call({ method: 'convert', type: 'base64Encode', data: s }); }
    static decodeUtf8(bytes) { return call({ method: 'convert', type: 'utf8', data: bytes }); }
    static encodeUtf8(s) { return call({ method: 'convert', type: 'utf8Encode', data: s }); }
    static hmacString(key, data, algorithm) {
      return call({ method: 'convert', type: 'hmac', key: key, data: data, algo: algorithm });
    }
    static decryptAesEcb(data, key) {
      return call({ method: 'convert', type: 'aesEcbDecrypt', data: data, key: key });
    }
  }

  class Cookie {
    constructor({ name, value, domain, path } = {}) {
      this.name = name || '';
      this.value = value || '';
      this.domain = domain || '';
      this.path = path || '/';
    }
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
    get innerHTML() { return this.innerHtml; }
    get html() { return this.innerHtml; }
    get outerHtml() { return call({ method: 'html', op: 'outerHtml', handle: this._h }); }
    get outerHTML() { return this.outerHtml; }
    get attributes() { return call({ method: 'html', op: 'attributes', handle: this._h }); }
    get children() { return (call({ method: 'html', op: 'children', handle: this._h }) || []).map(wrap); }
    attr(name) { return call({ method: 'html', op: 'attr', handle: this._h, name: name }); }
    dispose() { call({ method: 'html', op: 'free', handle: this._h }); }
  }

  class HtmlDocument extends HtmlNode {
    constructor(html) { super(call({ method: 'html', op: 'parse', html: html })); }
  }

  class ComicSource {
    constructor() {
      this.name = ''; this.key = ''; this.version = ''; this.url = '';
    }
    loadSetting(key) {
      const v = call({ method: 'setting', op: 'get', key: 'source_setting.' + this.key + '.' + key });
      if (v !== null && v !== undefined && v !== '') return v;
      const decl = this.settings ? this.settings[key] : null;
      if (decl === null || decl === undefined) return null;
      if (typeof decl === 'object') {
        return Object.prototype.hasOwnProperty.call(decl, 'default')
          ? decl.default
          : null;
      }
      return decl;
    }
    saveSetting(key, value) { return call({ method: 'setting', op: 'set', key: 'source_setting.' + this.key + '.' + key, value: value }); }
    get isLogged() {
      const keys = ['token', 'account', 'uid'];
      for (const k of keys) {
        const v = this.loadData(k);
        if (v !== null && v !== undefined && v !== '') return true;
      }
      return false;
    }
    loadData(name) {
      const v = call({ method: 'setting', op: 'get', key: 'source_data.' + this.key + '.' + name });
      if (v === null || v === undefined || v === '') return null;
      try { return JSON.parse(v); } catch (_) { return v; }
    }
    saveData(name, value) {
      return call({ method: 'setting', op: 'set', key: 'source_data.' + this.key + '.' + name, value: JSON.stringify(value) });
    }
    deleteData(name) {
      return call({ method: 'setting', op: 'set', key: 'source_data.' + this.key + '.' + name, value: '' });
    }
  }

  globalThis.randomInt = function (min, max) {
    if (max === undefined) { max = min; min = 0; }
    return Math.floor(Math.random() * (max - min + 1)) + min;
  };

  globalThis.fetch = async function (url, options) {
    options = options || {};
    const method = (options.method || 'GET').toUpperCase();
    const r = await Network.sendRequest(method, url, options.headers || {}, options.body, null, false);
    return {
      status: r.status,
      ok: r.status >= 200 && r.status < 300,
      headers: r.headers || {},
      url: url,
      text: async () => r.body,
      json: async () => JSON.parse(r.body),
      arrayBuffer: async () => Convert.encodeUtf8(r.body),
    };
  };

  class Comment {
    constructor(o = {}) { Object.assign(this, o); }
  }

  globalThis.createUuid = function () {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  };

  globalThis.APP = {
    version: '1.5.0',
    locale: 'zh_CN',
  };

  globalThis.Cookie = Cookie;
  globalThis.Comment = Comment;
  globalThis.ComicSource = ComicSource;
  globalThis.Comic = Comic;
  globalThis.ComicDetails = ComicDetails;
  globalThis.Network = Network;
  globalThis.Convert = Convert;
  globalThis.HtmlDocument = HtmlDocument;
  globalThis.HtmlNode = HtmlNode;
  globalThis.comicSourceBridgeReady = true;
})();
