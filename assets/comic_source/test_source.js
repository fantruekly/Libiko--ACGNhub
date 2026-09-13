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

  explore = [
    {
      title: '最近更新',
      type: 'multiPageComicList',
      load: (page) => ({
        comics: [
          new Comic({ id: 'p' + page + '-1', title: 'Page ' + page + ' A' }),
          new Comic({ id: 'p' + page + '-2', title: 'Page ' + page + ' B' }),
        ],
        maxPage: 3,
      }),
    },
    {
      title: '分类',
      type: 'singlePageWithMultiPart',
      load: () => ({
        '冒险': [new Comic({ id: 'a1', title: 'Adventure 1' })],
        '日常': [new Comic({ id: 'd1', title: 'Daily 1' })],
      }),
    },
    {
      title: '游标',
      type: 'multiPageComicList',
      loadNext: (next) => {
        const p = next ? Number(next) : 1;
        return {
          comics: [new Comic({ id: 'c' + p, title: 'Cursor ' + p })],
          next: p < 3 ? String(p + 1) : null,
        };
      },
    },
  ];
}
