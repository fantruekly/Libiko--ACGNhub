// A self-contained test source: every "request" is answered from an inline
// HTML string, so the e2e probe needs no network.
class AcgnhubTestSource extends ComicSource {
  name = "TestSource";
  key = "acgnhub_test";
  version = "1.0.0";

  search = {
    load: (keyword, options, page) => {
      const doc = new HtmlDocument(
        '<ul><li><a href="/c/1" title="' + keyword + ' One">' + keyword + ' One</a></li>' +
        '<li><a href="/c/2" title="' + keyword + ' Two">' + keyword + ' Two</a></li></ul>');
      const comics = doc.querySelectorAll('a').map(
        (a) => new Comic({ id: a.attr('href'), title: a.text }));
      return { comics: comics, maxPage: 1 };
    },
  };

  comic = {
    loadInfo: (id) => new ComicDetails({
      id: id,
      title: 'Test ' + id,
      chapters: { 'ep1': '第1话', 'ep2': '第2话' },
    }),
    loadEp: (comicId, epId) => ({ images: ['http://img/1.jpg', 'http://img/2.jpg'] }),
    onImageLoad: (url) => ({ url: url, headers: { 'referer': 'http://test/' } }),
  };
}
