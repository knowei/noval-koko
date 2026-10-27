# Cimoc 源站可达性体检（2026-10-27）

原始 JSON：`sourceBaseUrl.json`（133 个条目）

- **A 类：可达且看起来是真站 —— 32 个域名（38 个 key）**
- B 类：可达但像占位页/纯 API —— 15 个 key
- C 类：不可达 —— 80 个 key

## A 类：可达的真站（按域名去重）

| 域名 | key | 标题 | 大小 | 耗时 | 跳转后 |
|---|---|---|---|---|---|
| ac.qq.com | TENCENT | ËÖæËÆØÂä®Êº´ÂÆòÁΩë_Êº´Áî | 479KB | 1126ms | https://ac.qq.com/ |
| bbboy.cc | BOLEMH | 啵乐 - 腐味满满 | 110KB | 1543ms |  |
| dumanwu1.com | DUMANWU | 读漫屋 - 好看的热门漫画_最新最全漫画_免费观 | 15KB | 681ms |  |
| godamh.com | HaoManEight | 首頁-G站漫畫 | 81KB | 980ms |  |
| m.ac.qq.com | TENCENTM | ËÖæËÆØÂä®Êº´ÂÆòÁΩë_Êº´Áî | 479KB | 2002ms | https://ac.qq.com/ |
| m.baozimh.one | BAOZIV2/HaoManSix | 首頁-Bun漫畫 | 65KB | 1050ms |  |
| m.dm5.com | DM5/DongManWu | 动漫屋_在线漫画_为看漫画的人而生 | 109KB | 839ms |  |
| m.g-mh.org | GODAMH | 首頁-G社漫畫 | 81KB | 660ms |  |
| m.kanman.com | MANHUATAIPIC | 穿越西元3000后漫画 斗罗大陆漫画 斗破苍穹漫 | 38KB | 130ms |  |
| m.ykmh.net | YKMH/YouKuManHua | 漫画堆,漫画呗,漫画袋,日本漫画大全,日本漫画, | 23KB | 1502ms |  |
| m.ymgjmh.com | GUILUOLIMANHUA | 鬼丫头漫画|北疆群仙传|道诡异仙|白夜灵官|山神 | 33KB | 3508ms |  |
| rumanhua2.com | RUMANHUA | 如漫画 - 好看的热门漫画_最新最全漫画_免费观 | 19KB | 2088ms |  |
| www.36mh.org | QIMIAO | 36漫画 - 下拉式漫画网 | 52KB | 1261ms |  |
| www.bilimanga.net | BILIMANHUA | 嗶哩漫畫_線上看漫畫 | 138KB | 2147ms |  |
| www.colamanga.com | CoCoManHua | COLAMANGA 为您提供优质的漫画阅读体验 | 29KB | 9260ms | https://www.yoyomanga.com/ |
| www.dashumanhua.com | DASHUMANHUA | 大树漫画-优质人气漫画站-看下拉式漫画就在大树漫 | 171KB | 1700ms |  |
| www.dongmanmanhua.cn | WEBTOONDONGMANMANHUA | 咚漫漫画官网|咚咚手指 看看漫画 | 226KB | 1392ms |  |
| www.dumanwu.org | DUMANWUORG | 读漫屋 - 好看的热门漫画_最新最全漫画_免费观 | 49KB | 845ms |  |
| www.gmanhua.com | SHOUJIMH/ShouJiManHua | 手机漫画 - 手机用户最喜爱的在线漫画网 | 59KB | 733ms | https://www.gmanhua.com/ |
| www.haoduoman.com | HAODUOMAN | 好多漫 - 免费漫画在线观看平台 | 76KB | 494ms |  |
| www.kanman.com | MANHUATAI/ManHuaTai | 穿越西元3000后漫画 斗罗大陆漫画 斗破苍穹漫 | 150KB | 124ms |  |
| www.laimanhua88.com | LAIMH | 来漫画手机版-斗破苍穹漫画,斗罗大陆漫画,咒术回 | 20KB | 1950ms | https://m.laimanhua88.com/ |
| www.liumanhua.com | BMG | 六漫画 - 好看的热门漫画_最新最全漫画_免费观 | 49KB | 1395ms |  |
| www.manben.com | HAOMAN6 | 漫本_原创漫画发行平台_漫画_在线漫画 | 115KB | 1061ms |  |
| www.manhua666.cc | MANHUADB | 漫画牛_漫画666_下拉式漫画免费阅读！ | 35KB | 700ms |  |
| www.manhuayu88.com | MANHUAYU | 漫画鱼 - 在线免费看漫画 | 66KB | 257ms |  |
| www.manmanapp.com | MANMANMANHUA | 漫漫漫画 | 57KB | 699ms | https://www.manmanapp.com/ |
| www.mh160mh.com | MH160CC/MH160 | 漫画160 - 斗破苍穹漫画,斗罗大陆漫画,咒术 | 62KB | 1445ms |  |
| www.mhua5.com | MANHUAWU | 漫画屋-漫画大全-免费漫画在线看-最好看的漫画 | 88KB | 2084ms |  |
| www.umh5.com | YOUMANHUAWU | 漫画屋-漫画大全-免费漫画在线看-最好看的漫画 | 88KB | 1313ms |  |
| www.vomicmh.com | VOMIC2 | 首頁-vomic漫 - vomic漫画官网 | 18KB | 1108ms | https://www.vomicmh.com/ |
| www.wmh1234.com | DMZJFIX | 快看漫画_三生三世十里桃花漫画_扶摇皇后_兽王的 | 14KB | 1166ms |  |

## B 类：可达但疑似占位 / 纯接口（不建议直接对接）

| key | 域名 | 现象 |
|---|---|---|
| BUKA | https://www.bukamh.org | 200 / 11874B / welcome |
| BaiManGu | https://cn.zhuzhumh.com | 200 / 1920B / Welcome to nginx! |
| CARTOONMAD | https://www.cartoonmad.com | 200 / 114B / (无标题) |
| HAOMAN8 | https://m.zaimanhua.com | 200 / 4410B / 再漫画 |
| KUMANWU | http://www.kumwu2.com | 200 / 2459B / (无标题) |
| KUMANXIONGV2 | http://www.ziyuanxue.cn/Cimoc/hmx/api/queryHmx | 200 / 66B / (无标题) |
| MKZHAN | https://comic.mkzhan.com | 200 / 51B / (无标题) |
| QIMANWU | https://cn.zhuzhumh.com | 200 / 1920B / Welcome to nginx! |
| QIXIMH | http://qiximh4.com | 200 / 1662B / (无标题) |
| SUMANKU | http://www.sumanku.com | 200 / 5575B / Redirecting... |
| TUHAO | https://www.kawazhuyy.com | 200 / 11874B / welcome |
| TUHAOMHV2 | https://www.tuho123.com | 200 / 11874B / welcome |
| WEBTOON | https://m.webtoons.com | 200 / 2758B / Unsupported Language |
| YEMANMH | https://m.mhkami.com | 200 / 17143B / 百度一下，你就知道 |
| YKMH_SERVER | http://js.haotuyk.top | 200 / 1352B / 恭喜，站点创建成功！ |

## C 类：不可达

| key | 域名 | 原因 |
|---|---|---|
| ANIMX2 | https://www.2animx.com | HTTP 403 |
| BAINIAN | https://m.bnman.net | ConnectionError: ('Connection aborted.', ConnectionReset |
| BAINIANMH | https://m.bnman.net | ConnectionError: ('Connection aborted.', ConnectionReset |
| BAOZIMH | https://cn.baozimhcn.com | HTTP 403 |
| BASEURLHLV2 | PyhLDL/o0X0uZzEBUQQsjNDF3D+J6d33YRxE1rMnpuw= | MissingSchema: Invalid URL 'PyhLDL/o0X0uZzEBUQQsjNDF3D+J |
| BASEURLJMV2 | DbW/7c+yB4mmImuQQX9dq4cDxS8H1GrpzUc7FeY2ET0= | MissingSchema: Invalid URL 'DbW/7c+yB4mmImuQQX9dq4cDxS8H |
| BIQUGE | https://www.biqu8.xyz | ReadTimeout: 连接失败 www.biqu8.xyz |
| BODONGMH | https://ymcdnyfqdapp.ikmmh.com | HTTP 404 |
| BOLEFU | http://www.mxqf.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| BaoziManHua | https://cn.baozimhcn.com | HTTP 403 |
| BoLeFu | http://www.mxqf.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| CCMH | http://m.ccmh16.com | ConnectionError: 连接失败 m.ccmh16.com |
| CCTUKU | http://m.tuku.cc | ConnectionError: 连接失败 m.tuku.cc |
| CHUIXUE | http://www.chuixue.net | ConnectTimeout: 连接失败 www.chuixue.net |
| CHUIXUEMH | http://www.chuixue.net | ConnectTimeout: 连接失败 www.chuixue.net |
| CHUIXUESERVER | https://chuixue2.xiluweb.com/ | ConnectionError: 连接失败 chuixue2.xiluweb.com |
| CHUIYAO | http://m.chuiyao.com | HTTP 530 |
| COPYMH | https://www.2025copy.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| COPYMHSERVER | https://www.2025copy.com/api/kb/web/searchbg | ConnectionError: ('Connection aborted.', ConnectionReset |
| CopyManHua | https://www.2026copy.com | ConnectTimeout: 连接失败 www.2026copy.com |
| DMZJ | http://m.dmzj.com | HTTP 404 |
| DMZJFIXPICTURE | https://images.dmzj.com/ | ConnectionError: 连接失败 images.dmzj.com |
| DMZJFIXSERVER | http://api.dmzj.com | HTTP 404 |
| DMZJPICTURE | http://images.dmzj.com/ | ConnectionError: 连接失败 images.dmzj.com |
| DMZJSEARCH | http://s.acg.dmzj.com | HTTP 404 |
| DMZJSERVER | http://v3api.dmzj.com | HTTP 404 |
| DMZJV2 | https://m.dmzj.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| DMZJV2PICTURE | https://images.dmzj.com/ | ConnectionError: 连接失败 images.dmzj.com |
| DMZJV2SERVER | https://v3api.idmzj.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| DUMH | https://m.7stary.com | ConnectTimeout: 连接失败 m.7stary.com |
| DongManZhiJia | https://m.dmzj.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| DuManHua | https://m.7stary.com | ConnectTimeout: 连接失败 m.7stary.com |
| FEIXUEMH | https://www.feixuemh.com | ConnectionError: ('Connection aborted.', RemoteDisconnec |
| GUFENG | https://m.gufengmh.com | ConnectionError: 连接失败 m.gufengmh.com |
| GUFENGSERVER | https://res.xiaoqinre.com/ | ConnectionError: 连接失败 res.xiaoqinre.com |
| GUOGUOMH | https://d9zfb53b.lstool.xyz | ReadTimeout: 连接失败 d9zfb53b.lstool.xyz |
| GoDaMH | https://cn.godamanga.art | ConnectionError: ('Connection aborted.', ConnectionReset |
| GuFengManHua | https://m.gufengmh.com | ConnectionError: 连接失败 m.gufengmh.com |
| GuFengWang | https://m.gufengmanhua.com | ConnectionError: 连接失败 m.gufengmanhua.com |
| IKANMAN | https://www.manhuagui.com | ConnectTimeout: 连接失败 www.manhuagui.com |
| IKANMANSERVER | https://i.hamreus.com | ConnectTimeout: 连接失败 i.hamreus.com |
| IKANMANTW | https://tw.manhuagui.com | ConnectTimeout: 连接失败 tw.manhuagui.com |
| IQIYI | https://bud.iqiyi.com | HTTP 404 |
| KOMIIC | https://komiic.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| KUAIKANMANHUASERVER | https://api.kkmh.com | HTTP 404 |
| MANGABZ | https://www.mangabz.com | ConnectTimeout: 连接失败 www.mangabz.com |
| MANHUA90 | https://www.90mh.org | ConnectionError: ('Connection aborted.', ConnectionReset |
| MH160SERVER1 | https://mhpic5.kingwar.cn | ConnectionError: 连接失败 mhpic5.kingwar.cn |
| MH160SERVER2 | https://mhpic6.kingwar.cn | ConnectionError: 连接失败 mhpic6.kingwar.cn |
| MH160SERVER3 | https://mhpic5.kingwar.cn | ConnectionError: 连接失败 mhpic5.kingwar.cn |
| MH360 | https://m.100fanwo.com | ConnectionError: 连接失败 m.100fanwo.com |
| MH50 | https://www.maofly.com | SSLError: 连接失败 www.maofly.com |
| MH517 | http://m.517mh.net | ConnectionError: 连接失败 m.517mh.net |
| MH57 | http://m.wuqimh.net/ | ConnectionError: ('Connection aborted.', ConnectionReset |
| MH57SERVER | http://imagesold.502215.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| MIGU | http://www.migudm.cn | ConnectTimeout: 连接失败 www.migudm.cn |
| MITUI | https://www.imitui.com | ConnectTimeout: 连接失败 www.imitui.com |
| MYCOMIC | https://mycomic.com | HTTP 403 |
| ManHuaCat | https://www.maofly.com | SSLError: 连接失败 www.maofly.com |
| MangaBZManHua | http://www.mangabz.com | ConnectTimeout: 连接失败 www.mangabz.com |
| PUFEI | http://m.pufei.cc | ConnectTimeout: 连接失败 m.pufei.cc |
| PUFEIMH | http://m.pufei.cc | ConnectTimeout: 连接失败 m.pufei.cc |
| PUFEISERVER | http://res.img.shengda0769.com/ | ConnectionError: ('Connection aborted.', ConnectionReset |
| PuFeiManHua | http://m.pufei.cc | ConnectTimeout: 连接失败 m.pufei.cc |
| QIMANHUA | https://www.qimanwu.org | ConnectionError: ('Connection aborted.', ConnectionReset |
| QIMIAOMH | https://www.qimiaomh.com | SSLError: 连接失败 www.qimiaomh.com |
| SIXMH | http://www.jsj66.com | ConnectionError: 连接失败 www.jsj66.com |
| TTKANMANHUA | https://www.ttkmh.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| U17 | http://www.u17.com | ReadTimeout: 连接失败 www.u17.com |
| U17_SO | http://so.u17.com | ConnectionError: 连接失败 so.u17.com |
| XINXINMH | https://so.77mh.nl | SSLError: 连接失败 so.77mh.nl |
| XMANHUA | https://xmanhua.com | ConnectTimeout: 连接失败 xmanhua.com |
| XinXinManHua | https://so.77mh.nl | SSLError: 连接失败 so.77mh.nl |
| YIMMH | https://m.yimmh.com | ConnectionError: 连接失败 m.yimmh.com |
| YOUDM | https://www.udm123.com | SSLError: 连接失败 www.udm123.com |
| YYMANHUA | https://www.yymanhua.com | ConnectionError: ('Connection aborted.', ConnectionReset |
| YiManHua | https://m.yimmh.com | ConnectionError: 连接失败 m.yimmh.com |
| ZERO | https://www.zerobywdlss.com | SSLError: 连接失败 www.zerobywdlss.com |
| backup_update | https://haleytesla.top/cimoc/sourceBaseUrl.j | HTTP 530 |
| update_backup_my | https://raw.githubusercontent.com/haleydu-te | ConnectionError: ('Connection aborted.', ConnectionReset |
