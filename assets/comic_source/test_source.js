// A self-contained test source: every "request" is answered from an inline
// HTML string, so the e2e probe needs no network.
class LibikoTestSource extends ComicSource {
  name = "TestSource";
  key = "libiko_test";
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

  category = {
    title: '测试分类',
    parts: [
      {
        name: '类型',
        type: 'fixed',
        categories: ['全部'],
        categoryParams: [''],
        itemType: 'category',
      },
    ],
  };

  categoryComics = {
    load: (category, param, options, page) => ({
      comics: [
        new Comic({ id: 'cat' + page + '-1', title: 'Cat ' + page + ' A' }),
        new Comic({ id: 'cat' + page + '-2', title: 'Cat ' + page + ' B' }),
        new Comic({ id: 'cat' + page + '-3', title: 'Cat ' + page + ' C' }),
      ],
      maxPage: 2,
    }),
    optionList: [],
  };

  explore = [
    {
      title: '最近更新',
      type: 'multiPageComicList',
      load: (page) => ({
        comics: Array.from(
          { length: 25 },
          (_, i) =>
            new Comic({ id: 'p' + page + '-' + i, title: 'Page ' + page + ' #' + i }),
        ),
        maxPage: 3,
      }),
    },
    {
      title: '分类',
      type: 'singlePageWithMultiPart',
      load: () => ([
        {
          title: '冒险',
          comics: [new Comic({ id: 'a1', title: 'Adventure 1' })],
          viewMore: 'category:全部@',
        },
      ]),
    },
    {
      title: '游标',
      type: 'multiPageComicList',
      loadNext: (next) => {
        const p = next ? Number(next) : 1;
        return {
          comics: Array.from(
            { length: 25 },
            (_, i) =>
              new Comic({ id: 'c' + p + '-' + i, title: 'Cursor ' + p + ' #' + i }),
          ),
          next: p < 3 ? String(p + 1) : null,
        };
      },
    },
  ];
}
