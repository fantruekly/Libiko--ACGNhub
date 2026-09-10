/* ACGNhub interactive prototype — data, router, views, interactions */
(function () {
  'use strict';

  /* ============================= data ============================= */
  const anime = [
    { id: 1, title: '葬送的芙莉莲', source: 'Bangumi', year: 2023, rating: 9.4, eps: 28, tags: ['奇幻', '冒险', '治愈'], summary: '勇者一行打倒魔王之后，精灵魔法使芙莉莲踏上重走旅途的漫长时光。她开始理解人类短暂一生的分量，也在告别与重逢中学会珍惜当下。' },
    { id: 2, title: '孤独摇滚！', source: 'Bangumi', year: 2022, rating: 9.1, eps: 12, tags: ['音乐', '日常', '喜剧'], summary: '极度怕生的少女后藤一里抱着吉他独自练习，被拉进“结束乐队”后，第一次把心里的声音弹给别人听。' },
    { id: 3, title: '我推的孩子', source: 'Bangumi', year: 2023, rating: 8.6, eps: 11, tags: ['偶像', '悬疑', '剧情'], summary: '医生转生为偶像之子，带着前世的记忆踏入演艺圈，在光鲜舞台背后追查母亲之死的真相。' },
    { id: 4, title: '咒术回战 第二季', source: 'AGE动漫', year: 2023, rating: 8.7, eps: 23, tags: ['热血', '战斗', '奇幻'], summary: '怀玉·玉折篇与涩谷事变接连展开，五条悟的过去与咒术界最惨烈的一夜被完整揭开。' },
    { id: 5, title: '进击的巨人 最终季', source: 'libvio', year: 2023, rating: 9.3, eps: 28, tags: ['热血', '战争', '悬疑'], summary: '墙内外的真相层层揭开，艾伦与被卷入战争的人们一同走向无法回头的终局。' },
    { id: 6, title: '药屋少女的呢喃', source: 'Mikan', year: 2023, rating: 8.5, eps: 24, tags: ['推理', '宫廷', '日常'], summary: '精通药理的少女猫猫被卖入后宫，凭一双善于观察的眼睛卷入宫廷中一桩桩离奇事件。' },
    { id: 7, title: '排球少年!!', source: '樱花动漫', year: 2014, rating: 9.2, eps: 25, tags: ['运动', '热血'], summary: '身高不足的日向翔阳与天才二传影山飞雄组成“怪人快攻”，带着乌野高中排球队重返全国赛场。' },
    { id: 8, title: '灵能百分百 III', source: 'Bangumi', year: 2022, rating: 9.0, eps: 12, tags: ['超能力', '搞笑', '成长'], summary: '拥有强大超能力却渴望普通的影山茂夫，继续在成长中学习与自己的“爆发值”相处。' },
    { id: 9, title: '辉夜大小姐想让我告白', source: 'AGE动漫', year: 2022, rating: 8.9, eps: 13, tags: ['恋爱', '喜剧'], summary: '天才们的恋爱头脑战持续升级，学生会室里每一次看似平静的对话都暗藏攻防。' },
    { id: 10, title: '少女终末旅行', source: 'libvio', year: 2017, rating: 8.6, eps: 12, tags: ['科幻', '冒险', '治愈'], summary: '在文明终结后的废墟世界，两位少女开着履带车一路向上，寻找食物、燃料与生活的意义。' },
    { id: 11, title: '赛博朋克：边缘行者', source: 'Mikan', year: 2022, rating: 8.8, eps: 10, tags: ['科幻', '动作'], summary: '夜之城的少年大卫在失去一切后装上军用义体，成为边缘行者，追逐注定燃烧殆尽的未来。' },
    { id: 12, title: '夏日重现', source: '樱花动漫', year: 2022, rating: 8.4, eps: 25, tags: ['悬疑', '轮回'], summary: '慎平回到故乡参加葬礼，却在七月二十二日不断轮回，必须在循环中找出操控一切的“影子”。' }
  ];

  const comic = [
    { id: 1, title: '迷宫饭', source: '拷贝漫画', year: 2021, rating: 8.9, chapters: 97, latest: '更新至第 97 话', tags: ['奇幻', '美食', '冒险'], summary: '为了救回被红龙吞下的妹妹，莱欧斯一行在迷宫里就地取材，把魔物做成料理，一路吃向深处。' },
    { id: 2, title: '电锯人', source: '动漫之家', year: 2022, rating: 8.8, chapters: 97, latest: '更新至第 97 话', tags: ['动作', '黑暗'], summary: '背负债务的少年与电锯恶魔波奇塔融合，成为公安恶魔猎人，活着、战斗、并渴望着最普通的幸福。' },
    { id: 3, title: '间谍过家家', source: '拷贝漫画', year: 2022, rating: 8.9, chapters: 92, latest: '更新至第 92 话', tags: ['喜剧', '日常'], summary: '间谍、杀手与超能力少女组成临时家庭，为了各自的目的隐藏身份，却在相处中慢慢成了真正的家人。' },
    { id: 4, title: '怪兽8号', source: '哔咔', year: 2023, rating: 8.2, chapters: 116, latest: '更新至第 116 话', tags: ['动作', '科幻'], summary: '清理怪兽尸体的中年男人意外获得怪兽化能力，仍想站上防御队前线，实现与青梅竹马的约定。' },
    { id: 5, title: '蓝色时期', source: '动漫之家', year: 2021, rating: 8.7, chapters: 120, latest: '更新至第 120 话', tags: ['艺术', '成长'], summary: '成绩优秀却内心空虚的矢口八虎被一幅画击中，从此走进美术的世界，赌上一切报考东京艺术大学。' },
    { id: 6, title: '致不灭的你', source: '拷贝漫画', year: 2021, rating: 8.8, chapters: 180, latest: '更新至第 180 话', tags: ['奇幻', '治愈'], summary: '一颗被投入人间的“球”不断变换形态、体验生死，在漫长的旅程中逐渐理解何为人。' },
    { id: 7, title: '咒术回战', source: '快看', year: 2018, rating: 8.9, chapters: 258, latest: '更新至第 258 话', tags: ['热血', '战斗'], summary: '吞下诅咒之王手指的虎杖悠仁进入咒术高专，与同伴一同对抗由人类负面情绪诞生的咒灵。' },
    { id: 8, title: '怪兽之眼', source: '哔咔', year: 2022, rating: 8.1, chapters: 74, latest: '更新至第 74 话', tags: ['悬疑', '科幻'], summary: '少年在三年前的事故中失去记忆，却获得了能看到他人死亡倒计时的眼睛。' },
    { id: 9, title: '白金终局', source: '动漫之家', year: 2021, rating: 8.0, chapters: 74, latest: '更新至第 74 话', tags: ['悬疑', '奇幻'], summary: '获救的少年被赋予天使与神候补的资格，与十二位候选者展开一场关乎人间的角逐。' },
    { id: 10, title: '我的英雄学院', source: '快看', year: 2019, rating: 8.4, chapters: 410, latest: '更新至第 410 话', tags: ['热血', '校园'], summary: '无个性的少年绿谷出久继承最强英雄之力，目标成为能守护所有人的象征。' },
    { id: 11, title: '别对映像研出手！', source: '拷贝漫画', year: 2020, rating: 8.6, chapters: 60, latest: '更新至第 60 话', tags: ['校园', '创作'], summary: '三位少女为了构建“最强的世界”，在有限的预算与时间里，把脑内的设定做成动画。' },
    { id: 12, title: '天穗之咲稻姬', source: '动漫之家', year: 2021, rating: 8.3, chapters: 45, latest: '更新至第 45 话', tags: ['奇幻', '日常'], summary: '被逐出天界的丰穰之神佐久名，在鬼岛一边讨伐鬼怪，一边亲自耕作稻田。' }
  ];

  const novels = [
    { id: 1, title: '无职转生～到了异世界就拿出真本事～', author: '理不尽な孫の手', words: '12.4万字', status: '连载中', tags: ['奇幻', '异世界', '成长'], volCount: 5, summary: '一名在现实中处处碰壁的男人转生到剑与魔法的世界，从婴儿开始重新学习如何认真生活，并守住重要的人。' },
    { id: 2, title: '关于我转生变成史莱姆这档事', author: '伏濑', words: '8.9万字', status: '连载中', tags: ['异世界', '冒险'], volCount: 4, summary: '被刺杀的上班族转生成史莱姆，凭借“捕食者”与“大贤者”的能力，结盟魔物、建设理想之国。' },
    { id: 3, title: 'Re:从零开始的异世界生活', author: '长月达平', words: '15.2万字', status: '连载中', tags: ['奇幻', '悬疑'], volCount: 5, summary: '被召唤到异世界的少年只有“死亡回归”这一个能力，为了拯救重要的人，他一次次回到绝望的起点。' },
    { id: 4, title: '欢迎来到实力至上主义教室', author: '衣笠彰梧', words: '9.6万字', status: '连载中', tags: ['校园', '悬疑'], volCount: 4, summary: '在完全以实力评判学生的学校里，被分到最底层班级的绫小路清隆隐藏实力，静观班级间的博弈。' },
    { id: 5, title: '果然我的青春恋爱喜剧搞错了', author: '渡航', words: '7.8万字', status: '已完结', tags: ['校园', '恋爱'], volCount: 3, summary: '性格别扭的八幡被强制加入侍奉部，与雪之下、由比滨一同面对校园中那些无法用常理解决的人际难题。' },
    { id: 6, title: '贤者之孙', author: '吉冈刚', words: '6.7万字', status: '已完结', tags: ['异世界', '喜剧'], volCount: 3, summary: '被贤者救下并抚养长大的少年，拥有远超常识的魔法实力，却在常识层面屡屡闹出笑话。' },
    { id: 7, title: '盾之勇者成名录', author: 'アネコユサギ', words: '13.3万字', status: '连载中', tags: ['异世界', '冒险'], volCount: 5, summary: '被召为盾之勇者的尚文在陷害与背叛中成长，用守护的力量向整个世界证明自己的价值。' },
    { id: 8, title: '魔法科高中的劣等生', author: '佐岛勤', words: '18.5万字', status: '连载中', tags: ['科幻', '校园'], volCount: 5, summary: '在魔法被技术化的世界里，被视为“劣等生”的达也拥有超乎常规的破坏力，与妹妹一同卷入纷争。' },
    { id: 9, title: '86-不存在的战区-', author: '安里朝都', words: '6.2万字', status: '连载中', tags: ['科幻', '战争'], volCount: 3, summary: '被共和国当作“无人兵器”的少年少女，在战场前线拼命战斗，而指挥部另一端的少女从未停止呼唤他们。' },
    { id: 10, title: '文学少女', author: '野村美月', words: '5.9万字', status: '已完结', tags: ['校园', '文艺'], volCount: 3, summary: '把书页当作点心的文学少女天野远子，与搭档一起解开被经典文学映照出的青春谜题。' },
    { id: 11, title: '终将成为你', author: '仲谷鳰', words: '4.8万字', status: '已完结', tags: ['校园', '恋爱'], volCount: 3, summary: '在学生会相遇的两位少女，一人无法去爱，一人不敢被爱，彼此的距离在犹豫中逐渐靠近。' },
    { id: 12, title: '转生贵族的异世界冒险录', author: '某かんざき', words: '11.1万字', status: '连载中', tags: ['异世界', '冒险'], volCount: 4, summary: '转生为边境贵族次子的少年，凭前世的知识与天生的才能，走上一条自由而强韧的冒险之路。' }
  ];

  const game = [
    { id: 1, title: '命运石之门', brand: '5pb.', date: '2009-10-15', tags: ['科幻', '悬疑', '恋爱'], summary: '自称疯狂科学家的冈部伦太郎偶然造出能向过去发送信息的“电话烤箱”，一次小小的改动，却让世界线不断偏离。', staff: { 原画: 'huke', 剧本: '林直孝', 音乐: '阿保刚', CV: '宫野真守、今井麻美、花泽香菜' } },
    { id: 2, title: 'CLANNAD', brand: 'Key', date: '2004-04-28', tags: ['校园', '恋爱', '催泪'], summary: '在停滞不前的坡道上，朋也遇见了少女古河渚。从校园到家庭，这段关于相遇与羁绊的故事走向了最温柔的答案。', staff: { 原画: '樋上至', 剧本: '麻枝准', 音乐: '折户伸治', CV: '中原麻衣、中村悠一、桑岛法子' } },
    { id: 3, title: '白色相簿2', brand: 'Leaf', date: '2010-03-26', tags: ['校园', '恋爱', '剧情'], summary: '三个人的青春在轻音乐同好会的舞台上交错，明明只是想让喜欢的人回头，却在冬天里越走越远。', staff: { 原画: 'なかむらたけし', 剧本: '丸户史明', 音乐: '下川直哉', CV: '米泽圆、生天目仁美、水岛大宙' } },
    { id: 4, title: 'ATRI -My Dear Moments-', brand: 'ANIPLEX.EXE', date: '2020-06-19', tags: ['科幻', '治愈', '恋爱'], summary: '海面上升、城市沉没的未来，失去一条腿的少年与机器人少女阿托莉相遇，一起打捞着名为“心”的东西。', staff: { 原画: 'ゆさの', 剧本: '绀野アスタ', 音乐: '松本文纪', CV: '赤尾光、小野贤章' } },
    { id: 5, title: '千恋＊万花', brand: 'ゆずソフト', date: '2016-07-29', tags: ['和风', '恋爱', '喜剧'], summary: '被神刀选中的少年搬到温泉小镇，在刀与缘交织的日常里，与几位少女一同守护着古老的传说。', staff: { 原画: 'むりりん、こぶいち', 剧本: '天宮リツ', 音乐: 'Famishin', CV: '遥そら、小鸟居夕花' } },
    { id: 6, title: '魔女的夜宴', brand: 'ゆずソフト', date: '2015-05-29', tags: ['校园', '奇幻', '恋爱'], summary: '拥有读心能力的少年与只在夜里活动的魔女相遇，秘密与孤独在四人同行的日常中慢慢融化。', staff: { 原画: 'こぶいち、むりりん', 剧本: '天宮リツ', 音乐: 'Famishin', CV: '藤原鞠菜、海原エレナ' } },
    { id: 7, title: '素晴日 -美好的每一天-', brand: 'ケロQ', date: '2010-03-26', tags: ['悬疑', '哲学', '剧情'], summary: '由多个“视点”拼合而成的日常逐渐崩塌，在反复的夏日里，真相与幻觉的边界变得模糊。', staff: { 原画: '狗神煌', 剧本: 'すかぢ', 音乐: 'ピクセルビー', CV: '桐谷华、北见六花' } },
    { id: 8, title: '樱花之诗', brand: 'minori', date: '2015-02-27', tags: ['校园', '恋爱', '剧情'], summary: '社团、樱花与广播里的旋律，一段关于青春、告别和重新出发的群像恋爱故事。', staff: { 原画: '庄名泉石', 剧本: '御影', 音乐: '天门', CV: '有栖川みや、樱井浩美' } },
    { id: 9, title: '想要传达给你的爱恋', brand: "tone work's", date: '2014-03-28', tags: ['校园', '恋爱', '催泪'], summary: '转学生与青梅竹马，两条漫长而细腻的感情线，在毕业前夕终于要说出口。', staff: { 原画: '秋月こお', 剧本: '丘野塔也', 音乐: "tone work's", CV: '小仓结衣、遥空' } },
    { id: 10, title: '告别回忆 ～无垢少女～', brand: '5pb.', date: '2018-03-29', tags: ['恋爱', '悬疑', '剧情'], summary: '湘南的海风与神社的石阶之间，少年与少女们的故事在时间之外反复上演。', staff: { 原画: '森井しづき', 剧本: '下倉バイオ', 音乐: '阿保刚', CV: '白石晴香、近藤唯' } }
  ];

  const DATA = { anime, comic, novel: novels, game };
  game.forEach((g, i) => { g.source = i % 2 ? 'galgamezywz.org' : 'nekogal.com'; });

  const MODULES = {
    anime: { name: '动漫', tint: '#5856D6', watchPill: '继续观看', emptyWatch: '还没有观看记录，去发现好番吧', placeholder: '搜索动漫…', idleMsg: '输入关键词搜索动漫', noResult: (k) => '未找到「' + k + '」相关动漫，换个关键词试试' },
    comic: { name: '漫画', tint: '#FF9500', watchPill: '继续阅读', emptyWatch: '还没有阅读记录，去发现好漫画吧', placeholder: '搜索漫画…', idleMsg: '输入关键词搜索漫画', noResult: (k) => '未找到「' + k + '」相关漫画，换个关键词试试' },
    novel: { name: '轻小说', tint: '#34C759', watchPill: '热门排行', emptyWatch: '暂无排行数据', placeholder: '搜索轻小说…', idleMsg: '输入关键词搜索轻小说', noResult: (k) => '未找到「' + k + '」相关轻小说，换个关键词试试' },
    game: { name: '游戏', tint: '#AF52DE', watchPill: '最新发布', emptyWatch: '暂无游戏数据', placeholder: '搜索游戏…', idleMsg: '输入关键词搜索游戏', noResult: (k) => '未找到「' + k + '」相关游戏，换个关键词试试' }
  };

  const PILLS = {
    anime: ['继续观看', '热门推荐', '最近更新'],
    comic: ['继续阅读', '热门推荐', '最近更新'],
    novel: ['热门排行', '最新入库', '完本精选'],
    game: ['最新发布', '高分推荐', '品牌索引']
  };

  /* ============================= helpers ============================= */
  const GRADS = [
    ['#334155', '#64748b'], ['#7c2d12', '#ea580c'], ['#065f46', '#10b981'],
    ['#7f1d1d', '#ef4444'], ['#1e3a8a', '#3b82f6'], ['#713f12', '#eab308'],
    ['#4c1d95', '#8b5cf6'], ['#831843', '#ec4899'], ['#134e4a', '#14b8a6'],
    ['#3f3f46', '#71717a'], ['#1e3a8a', '#0ea5e9'], ['#5b21b6', '#a855f7']
  ];
  function seedOf(str) { let h = 0; for (const c of String(str)) h = (h * 31 + c.charCodeAt(0)) >>> 0; return h; }
  function gradOf(str) { return GRADS[seedOf(str) % GRADS.length]; }
  function bgOf(str) { const g = gradOf(str); return 'linear-gradient(150deg, ' + g[0] + ', ' + g[1] + ')'; }
  function firstChar(str) { return Array.from(String(str))[0] || '?'; }
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.prototype.slice.call((r || document).querySelectorAll(s));

  const SVG = {
    search: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.2-3.2"/></svg>',
    close: '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    back: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>',
    play: '<svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.5v13l11-6.5z"/></svg>',
    pause: '<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><rect x="7" y="5" width="3.6" height="14" rx="1.2"/><rect x="13.4" y="5" width="3.6" height="14" rx="1.2"/></svg>',
    heart: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"><path d="M12 20s-7-4.5-7-9.5A4 4 0 0 1 12 8a4 4 0 0 1 7 2.5c0 5-7 9.5-7 9.5Z"/></svg>',
    heartFill: '<svg width="20" height="20" viewBox="0 0 24 24" fill="#ff3b30" stroke="#ff3b30" stroke-width="1.4" stroke-linejoin="round"><path d="M12 20s-7-4.5-7-9.5A4 4 0 0 1 12 8a4 4 0 0 1 7 2.5c0 5-7 9.5-7 9.5Z"/></svg>',
    share: '<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3m0 0L8 7m4-4 4 4"/><path d="M5 12v7a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-7"/></svg>',
    gear: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M4.5 7l2 1.2M17.5 15.8l2 1.2M4.5 17l2-1.2M17.5 8.2l2-1.2"/></svg>',
    list: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 6h16M4 12h16M4 18h16"/></svg>',
    text: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6V4h11v2M9.5 4v16M7 20h5"/><path d="M16 20l3-9 3 9M16.8 17h4.4"/></svg>',
    ext: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 4h6v6M20 4l-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/></svg>',
    chev: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg>',
    cloud: '<svg width="52" height="52" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18a4 4 0 0 1-.5-7.97A5.5 5.5 0 0 1 17.4 9.2 3.5 3.5 0 0 1 17 18z"/><path d="M3 3l18 18"/></svg>',
    empty: '<svg width="52" height="52" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.2-3.2"/></svg>',
    playCircle: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="9"/><path d="M10 8.8v6.4l5-3.2z" fill="currentColor" stroke="none"/></svg>',
    back10: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9l5 4"/><path d="M6 9h7a5 5 0 0 1 0 10"/><text x="9" y="15.5" font-size="7" fill="currentColor" stroke="none">10</text></svg>',
    fwd10: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="m13 5 5 4-5 4"/><path d="M18 9h-7a5 5 0 0 0 0 10"/><text x="9" y="15.5" font-size="7" fill="currentColor" stroke="none">10</text></svg>',
    full: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg>'
  };

  /* ============================= state ============================= */
  const S = {
    pills: { anime: '热门推荐', comic: '热门推荐', novel: '热门排行', game: '高分推荐' },
    homeIndex: {},
    fav: {},
    brand: null,
    heroIdx: 0,
    searchSource: {},
    searchFired: false,
    reader: { size: 17, line: '1.8', theme: 'day', dir: 'vertical', zoom: 'width', bg: 'white' },
    novelChapter: 0,
    comicChapter: 1,
    playerEp: 0,
    playerTime: 0,
    playerPlaying: false,
    playerSpeed: 1,
    playerRes: '1080P'
  };
  try { const saved = JSON.parse(localStorage.getItem('acgnhub.state') || 'null'); if (saved) Object.assign(S, saved); } catch (e) { }
  function persist() { try { localStorage.setItem('acgnhub.state', JSON.stringify({ pills: S.pills, fav: S.fav })); } catch (e) { } }

  let timers = [];
  function clearTimers() { timers.forEach((t) => clearInterval(t)); timers = []; }

  function toast(msg) {
    const el = $('#toast'); el.textContent = msg; el.classList.add('on');
    clearTimeout(el._t); el._t = setTimeout(() => el.classList.remove('on'), 1800);
  }

  function findItem(mod, id) { return (DATA[mod] || []).find((x) => String(x.id) === String(id)); }

  /* ============================= router ============================= */
  function parse() {
    const raw = (location.hash || '').replace(/^#\/?/, '');
    const p = raw.split('/').filter(Boolean);
    if (p[0] === 'settings') return { module: 'anime', page: 'settings', id: null };
    return { module: p[0] || 'anime', page: p[1] || 'home', id: p[2] || null };
  }
  function go(hash) { if (location.hash === hash) mount(); else location.hash = hash; }
  function setSidebar(collapsed) {
    document.body.classList.toggle('collapsed', collapsed);
    document.querySelectorAll('[data-action="toggle-collapse"]').forEach(function (sw) { sw.classList.toggle('on', collapsed); });
    document.querySelectorAll('[data-action="sidebar-toggle"]').forEach(function (btn) {
      btn.setAttribute('aria-expanded', String(!collapsed));
      const label = collapsed ? '展开侧边栏' : '收起侧边栏';
      btn.setAttribute('title', label);
      btn.setAttribute('aria-label', label);
    });
    try { localStorage.setItem('acgnhub.sidebar', collapsed ? 'collapsed' : 'expanded'); } catch (e) { }
    syncHeroSize();
  }

  /* Hero 等比缩放：展开态保持 spec 基准高度，侧栏收起后主栏变宽，
     高度按同一比例增大，保证横幅宽高比不变（#shell 宽度在动画期间稳定）。 */
  function syncHeroSize() {
    const hero = document.getElementById('hero');
    if (!hero) return;
    const shell = document.getElementById('shell');
    const sbBody = document.querySelector('.sb-body');
    const sbW = sbBody ? sbBody.offsetWidth : 0;
    const margins = 32; /* .hero 左右各 16px */
    const shellW = shell ? shell.clientWidth : (window.innerWidth - sbW);
    const expandedW = Math.max(1, shellW - sbW - margins);
    const narrow = window.innerWidth <= 760;
    const baseH = hero.classList.contains('short') ? (narrow ? 150 : 168) : (narrow ? 200 : 240);
    const collapsed = document.body.classList.contains('collapsed');
    const curW = collapsed ? expandedW + sbW : expandedW;
    const h = Math.max(132, Math.round(baseH * (curW / expandedW)));
    hero.style.setProperty('--hero-h', h + 'px');
  }

  /* ============================= cards & shared ============================= */
  function coverRatio(mod) { return mod === 'comic' ? 'ratio-comic' : 'ratio-novel'; }

  function workCard(item, mod) {
    const badge = mod === 'comic' && item.latest ? '<span class="badge">' + item.latest + '</span>' : '';
    const sub = mod === 'novel' ? item.author + ' · ' + item.words : mod === 'game' ? item.brand : (item.source || '');
    return '<article class="card" data-action="open" data-mod="' + mod + '" data-id="' + item.id + '" data-od-id="work-card-' + mod + '-' + item.id + '">' +
      '<div class="cover ' + coverRatio(mod) + '" style="background:' + bgOf(item.title) + '"><span class="monogram">' + firstChar(item.title) + '</span>' + badge + '</div>' +
      '<div class="card-title">' + item.title + '</div>' +
      (sub ? '<div class="card-sub">' + sub + '</div>' : '') +
      '</article>';
  }

  function skeleton(n) {
    let out = '';
    for (let i = 0; i < (n || 10); i++) out += '<div class="skel"><div class="cover"></div><div class="l1"></div><div class="l2"></div></div>';
    return '<div class="skel-grid">' + out + '</div>';
  }

  function emptyState(icon, msg, actionLabel, action) {
    return '<div class="empty"><span class="ico">' + icon + '</span><div class="msg">' + msg + '</div>' +
      (actionLabel ? '<button class="btn btn-text" data-action="' + action + '">' + actionLabel + '</button>' : '') + '</div>';
  }

  function pillRow(mod) {
    return '<div class="pill-row">' + PILLS[mod].map((p) =>
      '<button class="pill' + (S.pills[mod] === p ? ' active' : '') + '" data-action="pill" data-mod="' + mod + '" data-pill="' + p + '">' + p + '</button>'
    ).join('') + '</div>';
  }

  /* ============================= home ============================= */
  function listFor(mod) {
    const all = DATA[mod].slice();
    const p = S.pills[mod];
    if (mod === 'anime' || mod === 'comic') {
      if (p === '继续观看' || p === '继续阅读') return [];
      if (p === '最近更新') return all.slice().reverse();
      return all;
    }
    if (mod === 'novel') {
      if (p === '最新入库') return all.slice().reverse();
      if (p === '完本精选') return all.filter((x) => x.status === '已完结');
      return all.slice().sort((a, b) => b.rating - a.rating);
    }
    if (mod === 'game') {
      if (p === '最新发布') return all.slice().sort((a, b) => (a.date < b.date ? 1 : -1));
      if (p === '高分推荐') return all;
      return all;
    }
    return all;
  }

  function heroHTML(mod) {
    return '<div class="hero' + (mod === 'novel' ? ' short' : '') + '" id="hero" data-od-id="hero-' + mod + '">' +
      '<div class="hero-bg" id="hero-bg"></div>' +
      '<div class="hero-scrim" id="hero-scrim"></div>' +
      '<div class="hero-body" id="hero-body"></div>' +
      '<button class="hero-nav prev" data-action="hero-prev" aria-label="上一张"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg></button>' +
      '<button class="hero-nav next" data-action="hero-next" aria-label="下一张"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg></button>' +
      '<div class="hero-dots" id="hero-dots"></div></div>';
  }

  function paintHero() {
    const hero = $('#hero'); if (!hero) return;
    const mod = S.ctx.module;
    const feat = DATA[mod].slice(0, 3);
    const i = (S.heroIdx || 0) % feat.length;
    const item = feat[i];
    const m = MODULES[mod];
    $('#hero-bg').style.cssText = 'background:' + bgOf(item.title);
    $('#hero-bg').innerHTML = '<span class="monogram">' + firstChar(item.title) + '</span>';
    $('#hero-scrim').style.background = 'linear-gradient(to bottom, rgba(0,0,0,.15) 0%, rgba(0,0,0,.28) 42%, rgba(0,0,0,.74) 100%), linear-gradient(115deg, ' + m.tint + '40, transparent 55%)';
    const sub = mod === 'novel' ? item.author + ' · ' + item.words + ' · ' + item.status
      : mod === 'game' ? item.brand + ' · ' + item.date
        : item.source + ' · ' + item.year + ' · ★ ' + item.rating;
    $('#hero-body').innerHTML =
      '<div class="hero-kicker">' + MODULES[mod].name + ' · 精选</div>' +
      '<div class="hero-title">' + item.title + '</div>' +
      '<div class="hero-meta">' + sub + '</div>' +
      (mod === 'game'
        ? '<button class="btn btn-primary" data-action="open" data-mod="' + mod + '" data-id="' + item.id + '">查看详情</button>'
        : mod === 'novel'
          ? '<button class="btn btn-primary" data-action="open" data-mod="' + mod + '" data-id="' + item.id + '">开始阅读</button>'
          : '<button class="btn btn-primary" data-action="open" data-mod="' + mod + '" data-id="' + item.id + '">' + (mod === 'comic' ? '开始阅读' : '立即观看') + '</button>');
    const dots = $('#hero-dots');
    if (dots) dots.innerHTML = feat.map((_, k) => '<i class="' + (k === i ? 'on' : '') + '"></i>').join('');
  }

  function startHeroTimer() {
    clearInterval(S._heroT);
    S._heroT = setInterval(() => { S.heroIdx = (S.heroIdx + 1) % 3; paintHero(); }, 8000);
  }

  function renderHome(mod) {
    if (mod === 'game') return renderGameHome();
    const list = listFor(mod);
    const m = MODULES[mod];
    const title = mod === 'anime' ? '热门推荐' : mod === 'comic' ? '热门推荐' : '热门排行';
    let body;
    if ((S.pills[mod] === '继续观看' || S.pills[mod] === '继续阅读') && list.length === 0) {
      body = emptyState(SVG.playCircle, m.emptyWatch, '去搜索', 'goto-search');
    } else {
      body = '<div class="grid" data-od-id="grid-' + mod + '">' + list.map((x) => workCard(x, mod)).join('') + '</div>';
    }
    return '<div class="home view-anim">' + heroHTML(mod) + pillRow(mod) +
      '<div class="section-head"><h2 class="section-title">' + (S.pills[mod]) + '</h2>' +
      (mod === 'novel' ? '<span class="link" data-action="pill" data-mod="novel" data-pill="' + (S.pills[mod] === '完本精选' ? '热门排行' : '完本精选') + '">' + (S.pills[mod] === '完本精选' ? '全部' : '完本精选') + '</span>' : '') +
      '</div>' + body + '</div>';
  }

  /* ---------- game home with brand index ---------- */
  function brandOf(item) { return item.brand; }

  function renderGameHome() {
    const p = S.pills.game;
    if (p === '品牌索引') {
      if (S.brand) {
        const items = DATA.game.filter((g) => g.brand === S.brand);
        return '<div class="home view-anim">' + pillRow('game') +
          '<div class="section-head"><button class="link" data-action="brand-back" style="display:inline-flex;align-items:center;gap:4px">' + SVG.chev.replace('width="16" height="16"', 'width="14" height="14" style="transform:rotate(180deg)"') + ' 全部品牌</button>' +
          '<span class="link" style="color:var(--muted)">' + items.length + ' 部作品</span></div>' +
          '<div class="grid">' + items.map((x) => workCard(x, 'game')).join('') + '</div></div>';
      }
      const map = {};
      DATA.game.forEach((g) => { map[g.brand] = (map[g.brand] || 0) + 1; });
      const brands = Object.keys(map);
      return '<div class="home view-anim">' + pillRow('game') +
        '<div class="section-head"><h2 class="section-title">品牌索引</h2></div>' +
        '<div class="brand-list">' + brands.map((b) => {
          const g = DATA.game.find((x) => x.brand === b);
          return '<div class="brand-row" data-action="brand-open" data-brand="' + b + '">' +
            '<div class="badge" style="background:' + bgOf(b) + '">' + firstChar(b).toUpperCase() + '</div>' +
            '<div><div class="bt">' + b + '</div><div class="bs">' + map[b] + ' 部作品</div></div>' +
            '<span class="chev">' + SVG.chev + '</span></div>';
        }).join('') + '</div></div>';
    }
    const list = listFor('game');
    return '<div class="home view-anim">' + heroHTML('game') + pillRow('game') +
      '<div class="section-head"><h2 class="section-title">' + p + '</h2></div>' +
      '<div class="grid">' + list.map((x) => workCard(x, 'game')).join('') + '</div></div>';
  }

  /* ============================= search ============================= */
  function renderSearch(mod) {
    const m = MODULES[mod];
    const sources = mod === 'anime' ? ['全部源', 'Bangumi', 'AGE动漫', 'libvio', 'Mikan', '樱花动漫']
      : mod === 'comic' ? ['全部源', '拷贝漫画', '动漫之家', '哔咔', '快看']
        : mod === 'novel' ? ['全部源', 'Wenku8']
          : ['全部源', 'nekogal.com', 'galgamezywz.org'];
    const src = S.searchSource[mod] || '全部源';
    return '<div class="view-anim">' +
      '<div class="searchbar">' +
      '<button class="tb-back" data-action="back" aria-label="返回">' + SVG.back + '</button>' +
      '<div class="field">' + SVG.search +
      '<input id="search-input" type="text" placeholder="' + m.placeholder + '" value="' + (S.searchKeyword[mod] || '') + '" aria-label="搜索" />' +
      '<button class="clear-btn" data-action="clear-search" aria-label="清除"' + ((S.searchKeyword[mod] || '') ? '' : ' style="display:none"') + '>' + SVG.close + '</button></div>' +
      '<button class="btn btn-text" data-action="do-search">搜索</button></div>' +
      '<div class="chip-row" id="source-chips">' + sources.map((s) => '<button class="chip' + (s === src ? ' active' : '') + '" data-action="source" data-mod="' + mod + '" data-source="' + s + '">' + s + '</button>').join('') + '</div>' +
      '<div id="search-results">' + searchResultsHTML(mod) + '</div></div>';
  }

  function searchResultsHTML(mod) {
    const kw = (S.searchKeyword[mod] || '').trim();
    if (!kw) return emptyState(SVG.empty, MODULES[mod].idleMsg);
    if (S.searchLoading) return skeleton(12);
    if (S.searchError) return emptyState(SVG.cloud, '网络请求失败，请检查连接后重试', '重试', 'do-search');
    const src = S.searchSource[mod] || '全部源';
    const res = DATA[mod].filter((x) => x.title.indexOf(kw) >= 0 && (src === '全部源' || x.source === src));
    if (!res.length) return emptyState(SVG.empty, MODULES[mod].noResult(kw));
    return '<div class="grid" data-od-id="search-grid-' + mod + '">' + res.map((x) => workCard(x, mod)).join('') + '</div>';
  }

  function runSearch(mod) {
    const input = $('#search-input'); if (!input) return;
    S.searchKeyword[mod] = input.value; S.searchFired = true;
    const out = $('#search-results'); if (!out) return;
    if (!input.value.trim()) { S.searchLoading = false; S.searchError = false; out.innerHTML = searchResultsHTML(mod); return; }
    S.searchLoading = true; S.searchError = false; out.innerHTML = skeleton(12);
    clearTimeout(S._sT);
    S._sT = setTimeout(() => {
      S.searchLoading = false;
      S.searchError = (typeof navigator !== 'undefined' && navigator.onLine === false);
      out.innerHTML = searchResultsHTML(mod);
    }, 480);
  }

  /* ============================= detail ============================= */
  function episodesOf(item) {
    const n = item.eps || 12;
    if (n <= 1) return [{ no: '★', name: '正片' }];
    return Array.from({ length: n }, (_, i) => ({ no: String(i + 1), name: '第 ' + (i + 1) + ' 话' }));
  }

  function detailHero(mod, item, h) {
    const m = MODULES[mod];
    return '<div class="detail-hero" style="height:' + (h || 260) + 'px;background:' + bgOf(item.title) + '">' +
      '<span class="monogram">' + firstChar(item.title) + '</span>' +
      '<div class="scrim" style="background:linear-gradient(to bottom, rgba(0,0,0,.12) 0%, rgba(0,0,0,.30) 48%, var(--bg) 100%), linear-gradient(115deg, ' + m.tint + '66, transparent 62%)"></div></div>';
  }

  function tagsHTML(tags) { return '<div class="tag-wrap">' + tags.map((t) => '<span class="tag">' + t + '</span>').join('') + '</div>'; }

  function renderDetail(mod, id) {
    const item = findItem(mod, id);
    if (!item) return emptyState(SVG.empty, '未找到该内容', '返回', 'back');
    if (mod === 'anime') return renderAnimeDetail(item);
    if (mod === 'comic') return renderComicDetail(item);
    if (mod === 'novel') return renderNovelDetail(item);
    return renderGameDetail(item);
  }

  function renderAnimeDetail(item) {
    const eps = episodesOf(item);
    const sorted = S._epsSort === 'desc' ? eps.slice().reverse() : eps;
    const playing = 0;
    return '<div class="detail view-anim" data-od-id="anime-detail">' +
      detailHero('anime', item) +
      '<div class="detail-inner">' +
      '<div class="detail-head"><div class="poster" style="background:' + bgOf(item.title) + '"><span class="monogram">' + firstChar(item.title) + '</span></div>' +
      '<div class="info"><h1 class="detail-title">' + item.title + '</h1>' +
      '<div class="detail-meta">' + item.source + ' · ' + item.year + ' · <span class="star">★ ' + item.rating + '</span><br>' + item.tags.join(' / ') + ' · 全 ' + item.eps + ' 话</div>' + tagsHTML(item.tags) + '</div></div>' +
      '<div class="block block-pad"><div class="block-title">简介</div><p class="summary clamp" id="summary">' + item.summary + '</p>' +
      '<button class="expand-btn" data-action="expand" data-target="summary">展开</button></div>' +
      '<div class="block episodes"><div class="block-pad" style="display:flex;justify-content:space-between;align-items:center;border-bottom:0.5px solid var(--border)">' +
      '<span class="block-title">剧集列表</span><button class="sort-toggle" data-action="sort">' + (S._epsSort === 'desc' ? '倒序' : '正序') + ' <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 16 6 9h12z"/></svg></button></div>' +
      '<div id="ep-list">' + sorted.map((e, i) => '<div class="ep' + (i === 0 && S._epsSort !== 'desc' ? ' playing' : '') + '" data-action="play" data-mod="anime" data-id="' + item.id + '" data-ep="' + e.no + '" title="' + e.name + '" aria-label="' + e.name + '">' +
        '<span class="ep-no">' + e.no + '</span></div>').join('') + '</div></div>' +
      '<div class="source-card"><div class="t">本内容来自「<b>' + item.source + '</b>」，无需登录即可播放。</div></div>' +
      '</div>' +
      '<div class="detail-actions"><button class="btn btn-primary" data-action="play" data-mod="anime" data-id="' + item.id + '" data-od-id="anime-primary-cta">播放最新</button></div></div>';
  }

  function renderComicDetail(item) {
    const chs = Array.from({ length: Math.min(item.chapters, 60) }, (_, i) => i + 1);
    const needLogin = item.needLogin;
    return '<div class="detail view-anim" data-od-id="comic-detail">' +
      detailHero('comic', item) +
      '<div class="detail-inner">' +
      '<div class="detail-head"><div class="poster" style="background:' + bgOf(item.title) + '"><span class="monogram">' + firstChar(item.title) + '</span></div>' +
      '<div class="info"><h1 class="detail-title">' + item.title + '</h1>' +
      '<div class="detail-meta">' + item.source + ' · ' + item.year + ' · <span class="star">★ ' + item.rating + '</span><br>' + item.latest + '</div>' + tagsHTML(item.tags) + '</div></div>' +
      '<div class="block block-pad"><div class="block-title">简介</div><p class="summary clamp" id="summary">' + item.summary + '</p>' +
      '<button class="expand-btn" data-action="expand" data-target="summary">展开</button></div>' +
      '<div class="block episodes"><div class="block-pad" style="display:flex;justify-content:space-between;align-items:center;border-bottom:0.5px solid var(--border)">' +
      '<span class="block-title">话数列表</span><button class="sort-toggle" data-action="sort">' + (S._epsSort === 'desc' ? '倒序' : '正序') + ' <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 16 6 9h12z"/></svg></button></div>' +
      '<div id="ep-list">' + (S._epsSort === 'desc' ? chs.slice().reverse() : chs).map((n, i) => '<div class="ep' + (i === 0 && S._epsSort !== 'desc' ? ' playing' : '') + '" data-action="read-comic" data-id="' + item.id + '" data-ep="' + n + '" title="第 ' + n + ' 话" aria-label="第 ' + n + ' 话">' +
        '<span class="ep-no">' + n + '</span></div>').join('') + '</div></div>' +
      '<div class="source-card"><div class="t">' + (needLogin ? '本内容来自「<b>' + item.source + '</b>」，需要登录后阅读。' : '本内容来自「<b>' + item.source + '</b>」，可直接阅读。') + '</div>' +
      (needLogin ? '<button class="btn btn-text" data-action="login">前往登录</button>' : '') + '</div>' +
      '</div>' +
      '<div class="detail-actions">' +
      '<button class="btn btn-primary" data-action="read-comic" data-id="' + item.id + '" data-ep="1" data-od-id="comic-primary-cta">从第 1 话开始阅读</button>' +
      '<button class="btn btn-secondary" data-action="read-comic" data-id="' + item.id + '" data-ep="' + Math.min(item.chapters, 12) + '">继续阅读第 ' + Math.min(item.chapters, 12) + ' 话</button>' +
      '</div></div>';
  }

  function novelVolumes(item) {
    const names = ['第一卷 起始之章', '第二卷 风起云涌', '第三卷 迷雾之城', '第四卷 命运的岔路', '第五卷 黎明之前'];
    const n = item.volCount || 3;
    const out = [];
    for (let i = 0; i < n; i++) {
      const chapters = [];
      for (let j = 0; j < 8; j++) chapters.push('第 ' + (i * 8 + j + 1) + ' 章');
      out.push({ name: names[i] || '第 ' + (i + 1) + ' 卷', chapters: chapters });
    }
    return out;
  }

  function renderNovelDetail(item) {
    const vols = novelVolumes(item);
    return '<div class="view-anim" data-od-id="novel-detail" style="padding-bottom:80px">' +
      '<div class="novel-head"><div class="poster" style="background:' + bgOf(item.title) + '"><span class="monogram" style="position:absolute;inset:0;display:grid;place-items:center;font-size:44px;color:rgba(255,255,255,.9)">' + firstChar(item.title) + '</span></div>' +
      '<div class="info"><h1 class="title">' + item.title + '</h1>' +
      '<div class="by">' + item.author + ' · ' + item.words + ' · ' + item.status + '</div>' + tagsHTML(item.tags) + '</div></div>' +
      '<div class="pad" style="padding-top:0"><div class="block block-pad" style="margin-top:0"><div class="block-title">简介</div><p class="summary" style="margin-top:8px">' + item.summary + '</p></div></div>' +
      '<div class="pad" style="padding-top:0"><div class="block catalog" data-od-id="novel-catalog">' +
      '<div class="block-pad" style="border-bottom:0.5px solid var(--border)"><span class="block-title">目录</span></div>' +
      vols.map((v, vi) => '<div class="volume' + (vi === 0 ? ' open' : '') + '">' +
        '<button data-action="volume"><span class="caret">' + SVG.chev + '</span>' + v.name + '<span class="count">' + v.chapters.length + ' 章</span></button>' +
        '<div class="chapter-list">' + v.chapters.map((c, ci) => '<div class="chapter" data-action="read-novel" data-id="' + item.id + '" data-ch="' + (vi * 8 + ci) + '"><span class="c-name">' + c + '</span><span class="go">' + SVG.chev + '</span></div>').join('') + '</div></div>').join('') +
      '</div></div></div>' +
      '<div class="detail-actions"><button class="btn btn-primary" data-action="read-novel" data-id="' + item.id + '" data-ch="0" data-od-id="novel-primary-cta">开始阅读</button></div>';
  }

  function renderGameDetail(item) {
    const shots = 4;
    return '<div class="view-anim" data-od-id="game-detail" style="padding-bottom:8px">' +
      '<div class="shots" id="shots" style="background:' + bgOf(item.title + '0') + '">' +
      Array.from({ length: shots }, (_, i) => '<div class="slide' + (i === 0 ? ' on' : '') + '" style="background:' + bgOf(item.title + i) + '">' + (i + 1) + ' / ' + shots + '</div>').join('') +
      '<button class="hero-nav prev" data-action="shot-prev" aria-label="上一张" style="z-index:3"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg></button>' +
      '<button class="hero-nav next" data-action="shot-next" aria-label="下一张" style="z-index:3"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg></button>' +
      '<div class="dots" id="shot-dots">' + Array.from({ length: shots }, (_, i) => '<i class="' + (i === 0 ? 'on' : '') + '"></i>').join('') + '</div></div>' +
      '<div class="game-titlebar"><h1 class="title">' + item.title + '</h1><div class="sub">' + item.brand + ' · 发售日 ' + item.date + '</div>' + tagsHTML(item.tags) + '</div>' +
      '<div class="pad"><div class="block block-pad" style="margin-top:0"><div class="block-title" style="margin-bottom:6px">详细信息</div>' +
      Object.keys(item.staff).map((k) => '<div class="staff-row"><span class="k">' + k + '</span><span class="v">' + item.staff[k] + '</span></div>').join('') +
      '<div class="staff-row"><span class="k">标签</span><span class="v">' + item.tags.join('、') + '</span></div>' +
      '</div></div>' +
      '<div class="pad" style="padding-top:0"><p class="summary">' + item.summary + '</p></div>' +
      '<div class="footnote">数据来源 nekogal.com · galgamezywz.org · 本模块为纯信息展示，不提供下载或播放。</div></div>';
  }

  /* ============================= player ============================= */
  function fmt(t) { const s = Math.max(0, Math.floor(t)); const m = Math.floor(s / 60); return m + ':' + String(s % 60).padStart(2, '0'); }

  function renderPlayer(id) {
    const item = findItem('anime', id) || DATA.anime[0];
    const eps = episodesOf(item);
    const epn = S.playerEp;
    return '<div id="player">' +
      '<div class="video"><div class="frame" style="background:' + bgOf(item.title + epn) + '">' +
      '<span class="monogram">' + firstChar(item.title) + '</span></div>' +
      '<div class="center-play"><button id="playToggle" data-action="toggle-play" aria-label="播放">' + SVG.play + '</button></div></div>' +
      '<div class="chrome p-top"><button class="p-btn" data-action="back" aria-label="返回">' + SVG.back + '</button><span class="t">' + item.title + ' · 第 ' + (epn + 1) + ' 话</span></div>' +
      '<div class="chrome p-bottom">' +
      '<div class="p-progress" id="progress"><div class="track"><div class="buffered"></div><div class="played" id="played"></div><div class="knob" id="knob"></div></div></div>' +
      '<div class="p-controls">' +
      '<span class="time" id="t-cur">0:00</span><span class="time">/</span><span class="time" id="t-dur">' + item.eps + ':00</span>' +
      '<span class="grow"></span>' +
      '<button class="p-btn" data-action="seek" data-delta="-10" aria-label="后退10秒">' + SVG.back10 + '</button>' +
      '<button class="p-btn big" id="bottomPlay" data-action="toggle-play" aria-label="播放/暂停">' + SVG.play + '</button>' +
      '<button class="p-btn" data-action="seek" data-delta="10" aria-label="前进10秒">' + SVG.fwd10 + '</button>' +
      '<span class="grow"></span>' +
      '<span class="p-menu"><button class="p-btn" data-action="pop" data-pop="speed" style="width:auto;padding:0 12px;font-size:13px" id="speedLabel">倍速 ' + S.playerSpeed + '×</button>' +
      '<div class="p-pop" id="pop-speed">' + [0.5, 0.75, 1, 1.25, 1.5, 2].map((s) => '<div class="opt' + (s === S.playerSpeed ? ' on' : '') + '" data-action="speed" data-v="' + s + '">' + s + '×' + (s === S.playerSpeed ? '<span>✓</span>' : '') + '</div>').join('') + '</div></span>' +
      '<span class="p-menu"><button class="p-btn" data-action="pop" data-pop="res" style="width:auto;padding:0 12px;font-size:13px" id="resLabel">' + S.playerRes + '</button>' +
      '<div class="p-pop" id="pop-res">' + ['1080P', '720P', '480P', '自动'].map((r) => '<div class="opt' + (r === S.playerRes ? ' on' : '') + '" data-action="res" data-v="' + r + '">' + r + (r === S.playerRes ? '<span>✓</span>' : '') + '</div>').join('') + '</div></span>' +
      '<button class="p-btn" data-action="fullscreen" aria-label="全屏">' + SVG.full + '</button>' +
      '</div>' +
      '<div class="ep-strip">' + eps.slice(0, 24).map((e, i) => '<div class="ep-thumb' + (i === epn ? ' on' : '') + '" data-action="set-ep" data-ep="' + i + '">' +
        '<div class="thumb" style="background:' + bgOf(item.title + i) + '">' + e.no + '</div><div class="cap">' + e.name + '</div></div>').join('') + '</div>' +
      '</div></div>';
  }

  function playerTick() {
    const played = $('#played'); if (!played) return;
    const item = findItem('anime', S.ctx.id) || DATA.anime[0];
    const total = (item.eps || 12) * 60;
    S.playerTime = Math.min(total, S.playerTime + S.playerSpeed);
    const pct = (S.playerTime / total) * 100;
    played.style.width = pct + '%';
    $('#knob').style.left = pct + '%';
    $('#t-cur').textContent = fmt(S.playerTime);
    $('#t-dur').textContent = fmt(total);
    if (S.playerTime >= total) { S.playerPlaying = false; paintPlayBtn(); }
  }
  function paintPlayBtn() {
    const b = $('#bottomPlay'), c = $('#playToggle');
    if (b) b.innerHTML = S.playerPlaying ? SVG.pause : SVG.play;
    if (c) c.innerHTML = S.playerPlaying ? SVG.pause : SVG.play;
  }

  /* ============================= comic reader ============================= */
  function renderComicReader(id) {
    const item = findItem('comic', id) || DATA.comic[0];
    const pages = 10;
    const ch = S.comicChapter || 1;
    const dirCls = S.reader.dir === 'vertical' ? '' : ' horizontal' + (S.reader.dir === 'rtl' ? ' rtl' : '');
    const zoomCls = S.reader.zoom === 'height' ? ' zoom-height' : S.reader.zoom === 'original' ? ' zoom-original' : '';
    return '<div class="view-anim">' +
      '<div class="reader-top"><button class="tool" data-action="back" aria-label="返回">' + SVG.back + '</button>' +
      '<span class="rt-title">' + item.title + ' · 第 ' + ch + ' 话</span>' +
      '<button class="tool" data-action="read-comic" data-id="' + item.id + '" data-ep="' + (ch + 1) + '" title="下一话">' + SVG.chev + '</button>' +
      '<button class="tool" data-action="comic-settings" aria-label="阅读设置">' + SVG.gear + '</button></div>' +
      '<div class="comic-pages' + dirCls + '" id="comic-pages" data-od-id="comic-pages">' +
      Array.from({ length: pages }, (_, i) => '<div class="comic-page' + zoomCls + '" style="background:' + bgOf(item.title + 'c' + ch + 'p' + i) + '">第 ' + (i + 1) + ' 页<span class="pnum">' + (i + 1) + ' / ' + pages + '</span></div>').join('') +
      '</div>' +
      '<div class="reader-footer"><button class="pill-btn">第 ' + ch + ' 话 · 共 ' + pages + ' 页</button></div></div>';
  }

  function comicSettingsHTML() {
    const d = S.reader.dir, z = S.reader.zoom, bg = S.reader.bg;
    return '<div class="s-row"><span class="s-label">阅读方向</span><span class="seg">' +
      '<button class="' + (d === 'vertical' ? 'on' : '') + '" data-action="comic-dir" data-v="vertical">竖向滚动</button>' +
      '<button class="' + (d === 'ltr' ? 'on' : '') + '" data-action="comic-dir" data-v="ltr">横向左→右</button>' +
      '<button class="' + (d === 'rtl' ? 'on' : '') + '" data-action="comic-dir" data-v="rtl">横向右→左</button></span></div>' +
      '<div class="s-row"><span class="s-label">缩放模式</span><span class="seg">' +
      '<button class="' + (z === 'width' ? 'on' : '') + '" data-action="comic-zoom" data-v="width">适应宽度</button>' +
      '<button class="' + (z === 'height' ? 'on' : '') + '" data-action="comic-zoom" data-v="height">适应高度</button>' +
      '<button class="' + (z === 'original' ? 'on' : '') + '" data-action="comic-zoom" data-v="original">原始</button></span></div>' +
      '<div class="s-row"><span class="s-label">背景色</span><span class="swatches">' +
      '<button class="swatch' + (bg === 'white' ? ' on' : '') + '" style="background:#fff" data-action="comic-bg" data-v="white" aria-label="白"></button>' +
      '<button class="swatch' + (bg === 'gray' ? ' on' : '') + '" style="background:#d8d8dd" data-action="comic-bg" data-v="gray" aria-label="灰"></button>' +
      '<button class="swatch' + (bg === 'black' ? ' on' : '') + '" style="background:#111" data-action="comic-bg" data-v="black" aria-label="黑"></button></span></div>';
  }

  function applyComicPrefs() {
    document.body.classList.toggle('reader-bg-gray', S.reader.bg === 'gray');
    document.body.classList.toggle('reader-bg-black', S.reader.bg === 'black');
    const pages = $('#comic-pages'); if (!pages) return;
    pages.className = 'comic-pages' + (S.reader.dir === 'vertical' ? '' : ' horizontal' + (S.reader.dir === 'rtl' ? ' rtl' : ''));
    $$('.comic-page', pages).forEach((p) => { p.classList.remove('zoom-height', 'zoom-original'); if (S.reader.zoom !== 'width') p.classList.add('zoom-' + S.reader.zoom); });
  }

  /* ============================= novel reader ============================= */
  const NOVEL_PARAS = [
    '风从窗棂的缝隙里钻进来，带着雨后泥土的气味，把桌上的书页吹得哗啦作响。她把手指按在纸面上，像是要把那些字按住，让它们不要逃跑。',
    '“你又在发呆。”身后的人这样说，语气里没有责备，只有一种被时间磨得发亮的熟悉。她没有回头，只是把肩膀往那声音的方向偏了偏。',
    '院子里的老树又抽出了新芽。每年这个时候，他都会想起第一次见到她的样子——那时她还不会笑，眼睛却亮得能装下整片夜空。',
    '有些约定是在没有说出口的时候就已经成立的。就像此刻的沉默，谁也没有打破，因为谁都知道，一旦开口，某些东西就会永远地改变。',
    '“如果我们走散了，要怎么办？”她终于问。他想了想，认真地回答：“那就原地等我。我一定会找到你，不管要多久。”',
    '夜色一点一点地漫上来，把远山染成了深蓝色。灯火在窗前次第亮起，像是大地写给天空的一封信，字迹温柔而缓慢。',
    '后来的很多年，她时常会梦见这个黄昏。梦里的风、梦里的树、梦里那句没有说完的话，都停在原地，等着她回去把它们讲完。'
  ];
  function novelChapterTitle() { return '第 ' + (S.novelChapter + 1) + ' 章　风起之日'; }

  function renderNovelReader(id) {
    const item = findItem('novel', id) || DATA.novel[0];
    const size = S.reader.size, line = S.reader.line, theme = S.reader.theme;
    document.body.classList.toggle('reader-theme-eye', theme === 'eye');
    document.body.classList.toggle('reader-theme-night', theme === 'night');
    const paras = [];
    for (let i = 0; i < 6; i++) paras.push(NOVEL_PARAS[(S.novelChapter + i) % NOVEL_PARAS.length]);
    return '<div class="view-anim">' +
      '<div class="reader-top"><button class="tool" data-action="back" aria-label="返回">' + SVG.back + '</button>' +
      '<span class="rt-title">' + novelChapterTitle() + '</span>' +
      '<button class="tool" data-action="catalog" aria-label="目录">' + SVG.list + '</button>' +
      '<button class="tool" data-action="font-settings" aria-label="字号设置">' + SVG.text + '</button></div>' +
      '<article class="novel-reader" id="novel-body" style="font-size:' + size + 'px;line-height:' + line + '">' +
      '<h2>' + novelChapterTitle() + '</h2>' + paras.map((p) => '<p>' + p + '</p>').join('') + '</article>' +
      '<div class="gov-bar"><button class="btn btn-secondary" data-action="prev-ch">上一章</button><button class="btn btn-secondary" data-action="next-ch">下一章</button></div>' +
      '</div>';
  }

  function novelCatalogHTML(id) {
    const item = findItem('novel', id) || DATA.novel[0];
    return novelVolumes(item).map((v, vi) => '<div class="volume' + (vi === 0 ? ' open' : '') + '">' +
      '<button data-action="volume"><span class="caret">' + SVG.chev + '</span>' + v.name + '<span class="count">' + v.chapters.length + ' 章</span></button>' +
      '<div class="chapter-list">' + v.chapters.map((c, ci) => '<div class="chapter' + ((vi === 0 && ci === S.novelChapter) ? ' current' : '') + '" data-action="jump-ch" data-ch="' + (vi * 8 + ci) + '"><span class="c-name">' + c + '</span></div>').join('') + '</div></div>').join('');
  }

  function fontSettingsHTML() {
    const t = S.reader.theme, l = S.reader.line;
    return '<div class="s-row"><span class="s-label">字号</span><span style="display:flex;align-items:center;gap:10px">' +
      '<span class="muted" style="font-size:12px">12</span>' +
      '<input type="range" id="font-range" min="12" max="24" value="' + S.reader.size + '" data-action="font-size" />' +
      '<span class="muted" style="font-size:12px">24</span>' +
      '<b id="font-val" style="width:34px;text-align:right">' + S.reader.size + 'px</b></span></div>' +
      '<div class="s-row"><span class="s-label">行距</span><span class="seg">' +
      '<button class="' + (l === '1.5' ? 'on' : '') + '" data-action="line" data-v="1.5">紧凑</button>' +
      '<button class="' + (l === '1.8' ? 'on' : '') + '" data-action="line" data-v="1.8">标准</button>' +
      '<button class="' + (l === '2.2' ? 'on' : '') + '" data-action="line" data-v="2.2">宽松</button></span></div>' +
      '<div class="s-row"><span class="s-label">主题</span><span class="seg">' +
      '<button class="' + (t === 'day' ? 'on' : '') + '" data-action="theme" data-v="day">日间</button>' +
      '<button class="' + (t === 'eye' ? 'on' : '') + '" data-action="theme" data-v="eye">护眼</button>' +
      '<button class="' + (t === 'night' ? 'on' : '') + '" data-action="theme" data-v="night">夜间</button></span></div>';
  }

  /* ============================= settings ============================= */
  function renderSettings() {
    const collapsed = document.body.classList.contains('collapsed');
    return '<div class="settings view-anim" data-od-id="settings">' +
      '<div class="set-block"><div class="h">外观</div>' +
      '<div class="set-row"><div>侧边栏自动收起<div class="desc">启动时默认收起，点击顶栏左侧按钮展开</div></div><div class="switch' + (collapsed ? ' on' : '') + '" data-action="toggle-collapse" role="switch"></div></div>' +
      '<div class="set-row"><div>主题<div class="desc">当前仅提供浅色主题</div></div><span class="muted" style="font-size:13px">浅色</span></div>' +
      '</div>' +
      '<div class="set-block"><div class="h">内容源</div>' +
      '<div class="set-row"><div>动漫源<div class="desc">Bangumi · AGE动漫 · libvio · Mikan · 樱花动漫</div></div><span class="muted" style="font-size:13px">5</span></div>' +
      '<div class="set-row"><div>漫画源<div class="desc">拷贝漫画 · 动漫之家 · 哔咔 · 快看</div></div><span class="muted" style="font-size:13px">4</span></div>' +
      '<div class="set-row"><div>轻小说源<div class="desc">Wenku8 固定源</div></div><span class="muted" style="font-size:13px">1</span></div>' +
      '</div>' +
      '<div class="set-block"><div class="h">阅读与播放</div>' +
      '<div class="set-row"><div>默认阅读方向</div><span class="muted" style="font-size:13px">竖向滚动</span></div>' +
      '<div class="set-row"><div>播放器记忆进度<div class="desc">自动保存到本地历史</div></div><div class="switch on" role="switch"></div></div>' +
      '</div>' +
      '<p class="footnote" style="padding-left:0">ACGNhub · 视觉重设计交互原型 · 数据均为演示用示例内容。</p>' +
      '</div>';
  }

  /* ============================= chrome + mount ============================= */
  function detailActions(mod, item) {
    if (mod === 'anime') return '<button class="icon-btn' + (S.fav[mod + item.id] ? ' active' : '') + '" data-action="fav" data-mod="' + mod + '" data-id="' + item.id + '" aria-label="收藏">' + (S.fav[mod + item.id] ? SVG.heartFill : SVG.heart) + '</button><button class="icon-btn" data-action="share" aria-label="分享">' + SVG.share + '</button>';
    if (mod === 'comic') return '<button class="icon-btn' + (S.fav[mod + item.id] ? ' active' : '') + '" data-action="fav" data-mod="' + mod + '" data-id="' + item.id + '" aria-label="收藏">' + (S.fav[mod + item.id] ? SVG.heartFill : SVG.heart) + '</button><button class="icon-btn" data-action="share" aria-label="分享">' + SVG.share + '</button>';
    if (mod === 'novel') return '<button class="icon-btn' + (S.fav[mod + item.id] ? ' active' : '') + '" data-action="fav" data-mod="' + mod + '" data-id="' + item.id + '" aria-label="收藏">' + (S.fav[mod + item.id] ? SVG.heartFill : SVG.heart) + '</button>';
    if (mod === 'game') return '<button class="btn btn-text" data-action="external" style="height:36px">' + SVG.ext + ' 官网</button>';
    return '';
  }

  function setChrome(ctx) {
    const title = $('#tb-title'), back = $('.tb-back'), act = $('#tb-actions');
    const searchBtn = $('[data-action="open-search"]'), avatar = $('.avatar');
    act.innerHTML = ''; back.hidden = true; title.classList.remove('sub');
    searchBtn.style.display = ''; avatar.style.display = '';
    if (ctx.page === 'home') { title.textContent = MODULES[ctx.module].name; }
    else if (ctx.page === 'settings') { title.textContent = '设置'; searchBtn.style.display = 'none'; }
    else if (ctx.page === 'detail') {
      back.hidden = false; searchBtn.style.display = 'none'; avatar.style.display = 'none';
      const item = findItem(ctx.module, ctx.id);
      title.textContent = item ? item.title : ''; title.classList.add('sub');
      if (item) act.innerHTML = detailActions(ctx.module, item);
    }
  }

  function renderRoute(ctx) {
    switch (ctx.page) {
      case 'home': return renderHome(ctx.module);
      case 'search': return renderSearch(ctx.module);
      case 'detail': return renderDetail(ctx.module, ctx.id);
      case 'read': return ctx.module === 'novel' ? renderNovelReader(ctx.id) : renderComicReader(ctx.id);
      case 'play': return renderPlayer(ctx.id);
      case 'settings': return renderSettings();
      default: return renderHome(ctx.module);
    }
  }

  function mount() {
    clearTimers();
    closeOverlays();
    const ctx = parse();
    S.ctx = ctx;
    document.body.classList.toggle('immersive', ctx.page === 'play');
    document.body.classList.toggle('no-topbar', ['search', 'read', 'play'].includes(ctx.page));
    document.body.classList.remove('searching');
    if (!['read'].includes(ctx.page)) {
      document.body.classList.remove('reader-theme-night', 'reader-theme-eye', 'reader-bg-gray', 'reader-bg-black');
    }
    if (ctx.page !== 'search') { S.searchLoading = false; S.searchError = false; }
    const view = $('#view');
    view.innerHTML = renderRoute(ctx);
    view.scrollTop = 0;
    $$('.sb-item').forEach((el) => el.classList.toggle('active', el.dataset.module === ctx.module && ctx.page === 'home'));
    if (ctx.page === 'settings') $$('.sb-item').forEach((el) => el.classList.toggle('active', el.dataset.module === 'settings'));
    setChrome(ctx);
    afterMount(ctx);
    try { localStorage.setItem('acgnhub.route', '#' + [ctx.module, ctx.page, ctx.id].filter((x) => x != null).join('/')); } catch (e) { }
  }

  function afterMount(ctx) {
    if (ctx.page === 'home' && ctx.module !== 'game') { paintHero(); startHeroTimer(); }
    if (ctx.page === 'home' && ctx.module === 'game') { paintHero(); startHeroTimer(); }
    if (ctx.page === 'home') syncHeroSize();
    if (ctx.page === 'search') { const inp = $('#search-input'); if (inp) { inp.focus(); inp.setSelectionRange(inp.value.length, inp.value.length); } }
    if (ctx.page === 'read') {
      if (ctx.module === 'comic') applyComicPrefs();
    }
    if (ctx.page === 'play') {
      S.playerTime = 0; S.playerPlaying = false; paintPlayBtn();
      const p = $('#player');
      let hideT;
      const reset = () => { if (!p) return; p.classList.remove('hide-ui'); clearTimeout(hideT); hideT = setTimeout(() => { if (S.playerPlaying) p.classList.add('hide-ui'); }, 3000); };
      p.addEventListener('mousemove', reset); reset();
      document.onkeydown = (e) => {
        if (e.code === 'Space') { e.preventDefault(); togglePlay(); }
        else if (e.key === 'ArrowLeft') seekBy(-5);
        else if (e.key === 'ArrowRight') seekBy(5);
        else if (e.key === 'f' || e.key === 'F') toggleFullscreen();
        else if (e.key === 'Escape') { if (!document.fullscreenElement) go('#/anime/detail/' + ctx.id); }
      };
    } else { document.onkeydown = null; }
    if (ctx.page === 'read' && ctx.module === 'novel') { /* reader ready */ }
  }

  /* ============================= overlays ============================= */
  function openDrawer(head, body) {
    $('#drawer-head').textContent = head; $('#drawer-body').innerHTML = body;
    $('#scrim').classList.add('on'); $('#drawer').classList.add('on'); $('#drawer').setAttribute('aria-hidden', 'false');
  }
  function openSheet(body) {
    $('#sheet-body').innerHTML = body;
    $('#scrim').classList.add('on'); $('#sheet').classList.add('on'); $('#sheet').setAttribute('aria-hidden', 'false');
  }
  function closeOverlays() {
    $('#scrim').classList.remove('on');
    $('#drawer').classList.remove('on'); $('#drawer').setAttribute('aria-hidden', 'true');
    $('#sheet').classList.remove('on'); $('#sheet').setAttribute('aria-hidden', 'true');
  }

  /* ============================= player ops ============================= */
  function togglePlay() {
    S.playerPlaying = !S.playerPlaying; paintPlayBtn();
    clearInterval(S._playT);
    if (S.playerPlaying) { S._playT = setInterval(playerTick, 1000); $('#player') && $('#player').classList.remove('hide-ui'); }
    else if ($('#player')) { $('#player').classList.remove('hide-ui'); }
  }
  function seekBy(d) {
    const item = findItem('anime', S.ctx.id) || DATA.anime[0];
    const total = (item.eps || 12) * 60;
    S.playerTime = Math.max(0, Math.min(total, S.playerTime + d)); playerTick();
  }
  function toggleFullscreen() {
    const p = $('#player');
    if (!document.fullscreenElement) p.requestFullscreen && p.requestFullscreen();
    else document.exitFullscreen && document.exitFullscreen();
  }

  /* ============================= interactions ============================= */
  document.addEventListener('click', function (e) {
    const routeEl = e.target.closest('[data-route]');
    if (routeEl) { go(routeEl.dataset.route); return; }
    const el = e.target.closest('[data-action]');
    if (!el) return;
    const a = el.dataset.action;

    switch (a) {
      case 'sidebar-toggle': setSidebar(!document.body.classList.contains('collapsed')); break;
      case 'toggle-collapse': setSidebar(!document.body.classList.contains('collapsed')); el.classList.toggle('on', document.body.classList.contains('collapsed')); break;
      case 'open-search': {
        document.body.classList.add('searching');
        const inp = $('#tb-input'); inp.placeholder = MODULES[S.ctx.module].name + '搜索…';
        setTimeout(() => inp.focus(), 60); break;
      }
      case 'close-search': document.body.classList.remove('searching'); break;
      case 'back': history.length > 1 ? history.back() : go('#/anime'); break;
      case 'goto-search': go('#/' + S.ctx.module + '/search'); break;
      case 'pill': S.pills[el.dataset.mod] = el.dataset.pill; S.brand = null; persist(); mount(); break;
      case 'brand-open': S.brand = el.dataset.brand; mount(); break;
      case 'brand-back': S.brand = null; mount(); break;
      case 'hero-prev': S.heroIdx = (S.heroIdx + 2) % 3; paintHero(); startHeroTimer(); break;
      case 'hero-next': S.heroIdx = (S.heroIdx + 1) % 3; paintHero(); startHeroTimer(); break;
      case 'open': go('#/' + el.dataset.mod + '/detail/' + el.dataset.id); break;

      /* search */
      case 'source': S.searchSource[S.ctx.module] = el.dataset.source; $$('#source-chips .chip').forEach((c) => c.classList.toggle('active', c === el)); $('#search-results').innerHTML = searchResultsHTML(S.ctx.module); break;
      case 'do-search': runSearch(S.ctx.module); break;
      case 'clear-search': { const inp = $('#search-input'); inp.value = ''; inp.focus(); S.searchKeyword[S.ctx.module] = ''; const cb = document.querySelector('.clear-btn'); if (cb) cb.style.display = 'none'; $('#search-results').innerHTML = searchResultsHTML(S.ctx.module); break; }

      /* detail */
      case 'expand': {
        const t = $('#' + el.dataset.target);
        const clamped = t.classList.toggle('clamp');
        el.textContent = clamped ? '展开' : '收起';
        break;
      }
      case 'sort': { S._epsSort = S._epsSort === 'desc' ? 'asc' : 'desc'; mount(); break; }
      case 'fav': {
        const k = el.dataset.mod + el.dataset.id; S.fav[k] = !S.fav[k]; persist();
        el.classList.toggle('active', S.fav[k]); el.innerHTML = S.fav[k] ? SVG.heartFill : SVG.heart;
        toast(S.fav[k] ? '已加入收藏' : '已取消收藏'); break;
      }
      case 'share': toast('分享链接已复制到剪贴板'); break;
      case 'login': toast('正在打开登录页…'); break;
      case 'external': toast('已在浏览器中打开官网'); break;
      case 'volume': el.parentElement.classList.toggle('open'); break;

      /* read entry */
      case 'read-novel': S.novelChapter = parseInt(el.dataset.ch, 10) || 0; go('#/novel/read/' + el.dataset.id); break;
      case 'read-comic': S.comicChapter = parseInt(el.dataset.ep, 10) || 1; go('#/comic/read/' + el.dataset.id); break;

      /* novel reader */
      case 'catalog': openDrawer('目录', novelCatalogHTML(S.ctx.id)); break;
      case 'font-settings': openSheet(fontSettingsHTML()); break;
      case 'theme': S.reader.theme = el.dataset.v; applyNovelTheme(); $$('[data-action="theme"]').forEach((b) => b.classList.toggle('on', b.dataset.v === S.reader.theme)); break;
      case 'line': S.reader.line = el.dataset.v; applyNovelStyle(); $$('[data-action="line"]').forEach((b) => b.classList.toggle('on', b.dataset.v === S.reader.line)); break;
      case 'jump-ch': S.novelChapter = parseInt(el.dataset.ch, 10); closeOverlays(); refreshNovelReader(S.ctx.id); break;
      case 'prev-ch': S.novelChapter = Math.max(0, S.novelChapter - 1); refreshNovelReader(S.ctx.id); break;
      case 'next-ch': S.novelChapter += 1; refreshNovelReader(S.ctx.id); break;

      /* comic reader */
      case 'comic-settings': openSheet(comicSettingsHTML()); break;
      case 'comic-dir': S.reader.dir = el.dataset.v; applyComicPrefs(); $$('[data-action="comic-dir"]').forEach((b) => b.classList.toggle('on', b.dataset.v === S.reader.dir)); break;
      case 'comic-zoom': S.reader.zoom = el.dataset.v; applyComicPrefs(); $$('[data-action="comic-zoom"]').forEach((b) => b.classList.toggle('on', b.dataset.v === S.reader.zoom)); break;
      case 'comic-bg': S.reader.bg = el.dataset.v; applyComicPrefs(); $$('[data-action="comic-bg"]').forEach((b) => b.classList.toggle('on', b.dataset.v === S.reader.bg)); break;

      /* player */
      case 'toggle-play': togglePlay(); break;
      case 'seek': seekBy(parseInt(el.dataset.delta, 10)); break;
      case 'pop': { const id = 'pop-' + el.dataset.pop; const pop = $('#' + id); const was = pop.classList.contains('open'); $$('.p-pop').forEach((p) => p.classList.remove('open')); if (!was) pop.classList.add('open'); break; }
      case 'speed': { S.playerSpeed = parseFloat(el.dataset.v); $('#speedLabel').textContent = '倍速 ' + S.playerSpeed + '×'; $$('#pop-speed .opt').forEach((o) => o.classList.toggle('on', parseFloat(o.dataset.v) === S.playerSpeed)); $('#pop-speed').classList.remove('open'); break; }
      case 'res': { S.playerRes = el.dataset.v; $('#resLabel').textContent = S.playerRes; $$('#pop-res .opt').forEach((o) => o.classList.toggle('on', o.dataset.v === S.playerRes)); $('#pop-res').classList.remove('open'); toast('已切换至 ' + S.playerRes); break; }
      case 'fullscreen': toggleFullscreen(); break;
      case 'set-ep': S.playerEp = parseInt(el.dataset.ep, 10); S.playerTime = 0; mount(); break;
      case 'shot-prev': shotMove(-1); break;
      case 'shot-next': shotMove(1); break;

      case 'close-overlay': closeOverlays(); break;
      case 'play': {
        S.playerEp = 0; S.playerTime = 0;
        go('#/anime/play/' + el.dataset.id); break;
      }
    }
  });

  function shotMove(d) {
    const shots = $$('#shots .slide'); if (!shots.length) return;
    let cur = shots.findIndex((s) => s.classList.contains('on'));
    cur = (cur + d + shots.length) % shots.length;
    shots.forEach((s, i) => s.classList.toggle('on', i === cur));
    const dots = $$('#shot-dots i'); dots.forEach((x, i) => x.classList.toggle('on', i === cur));
  }

  function applyNovelTheme() {
    document.body.classList.toggle('reader-theme-eye', S.reader.theme === 'eye');
    document.body.classList.toggle('reader-theme-night', S.reader.theme === 'night');
  }
  function applyNovelStyle() {
    const b = $('#novel-body'); if (!b) return;
    b.style.fontSize = S.reader.size + 'px'; b.style.lineHeight = S.reader.line;
  }
  function refreshNovelReader(id) {
    const view = $('#view');
    view.innerHTML = renderNovelReader(id);
    view.scrollTop = 0;
  }

  document.addEventListener('input', function (e) {
    const t = e.target;
    if (t.id === 'search-input') { S.searchKeyword[S.ctx.module] = t.value; const cb = document.querySelector('.clear-btn'); if (cb) cb.style.display = t.value ? '' : 'none'; runSearch(S.ctx.module); }
    if (t.id === 'tb-input') { /* typeahead hint only */ }
    if (t.type === 'range' && t.dataset.action === 'font-size') {
      S.reader.size = parseInt(t.value, 10); const v = $('#font-val'); if (v) v.textContent = S.reader.size + 'px';
      applyNovelStyle();
    }
  });
  document.addEventListener('keydown', function (e) {
    if (e.target && e.target.id === 'tb-input' && e.key === 'Enter') {
      S.searchKeyword[S.ctx.module] = e.target.value;
      document.body.classList.remove('searching');
      go('#/' + S.ctx.module + '/search');
    }
    if (e.target && e.target.id === 'search-input' && e.key === 'Enter') { runSearch(S.ctx.module); }
  });

  window.addEventListener('hashchange', mount);
  window.addEventListener('resize', syncHeroSize);

  /* ============================= boot ============================= */
  try {
    if (localStorage.getItem('acgnhub.sidebar') === 'collapsed') document.body.classList.add('collapsed');
  } catch (e) { }
  const last = (function () { try { return localStorage.getItem('acgnhub.route'); } catch (e) { return null; } })();
  if (!location.hash) location.hash = last || '#/anime';
  mount();
})();
