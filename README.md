# noval · 墨町

[![release](https://github.com/knowei/noval-koko/actions/workflows/release.yml/badge.svg)](https://github.com/knowei/noval-koko/actions/workflows/release.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](#免责)

> 自己用的、**规则驱动**的小说 + 漫画阅读器。
>
> 程序本身不带任何内容，也不内置任何站点规则；所有书源（站点怎么搜、怎么解析目录和正文）
> 都由你导入的 JSON 规则决定。规则格式与 [Legado（阅读 3.0）书源](https://github.com/gedoor/legado)
> 基本一致，可以直接把现成的书源 JSON 丢进来。

技术栈：Flutter（Windows 桌面 + Android）/ Dart 3 / QuickJS（flutter_js）/ sqflite / provider。

> **名字与图标**：中文名「墨町」，拉丁名 Moting（`Moting reader`），
> 内部代号 `noval`（包名 `com.noval.noval`、可执行文件 `noval.exe`）。
> 图标由 `python tool/make_icon.py` 生成 —— 墨绿底 + 米白翻书 + 沙色书签，
> 一次产出 Android 全密度 mipmap / 自适应图标前景 / Windows `app_icon.ico`。

```bash
git clone https://github.com/knowei/noval-koko.git
cd noval-koko
flutter pub get
flutter run -d windows
```

---

## 现在能做什么

| 能力 | 状态 |
| --- | --- |
| 导入书源 JSON（粘贴、剪贴板、文件、URL） | ✅ |
| 导入本地书：TXT（UTF-8/GBK 自动识别）、EPUB | ✅ |
| 书源开关 / 删除 / 查看原始 JSON | ✅ |
| 多源并行搜索、按源显示失败原因 | ✅ |
| 书籍详情（封面、简介、目录预览） | ✅ |
| 目录拉取与缓存、换源字段（tocUrl） | ✅ |
| 小说正文：分页阅读、字号/行距/背景、进度记忆 | ✅ |
| 漫画阅读：纵向长图滚动、进度条、上下章 | ✅ |
| 书架（增删、最近阅读、继续阅读、下拉刷新书目信息） | ✅ |
| 「我的」页：书源管理、主题切换、数据统计 | ✅ |
| 阅读器双模式：上下滚动 / 左右翻页，两种都支持横向滑章 | ✅ |
| 动效：列表错峰入场、转场淡入、切章交叉淡入、点击回弹 | ✅ |
| 主题：墨町 / 青瓷 / 暖沙，切换有过渡动画 | ✅ |
| 规则引擎：CSS / XPath / JsonPath / jsoup 风格 / 正则替换 / JS | ✅ |
| JS 规则里的 `java.ajax` 同步取数（异步桥接） | ✅ |
| Cookie 持久化（`cf_clearance`、登录态跨启动复用） | ✅ |
| 网络诊断：按域名探 DNS/TCP/HTTP，一眼分清「墙」还是「规则错」 | ✅ |
| 镜像回退：主域被墙/被墙时自动换同站镜像域名 | ✅ |
| 书源订阅：一个 URL 拉整套源，点一下同步 | ✅ |
| 本地假站点 + 示例书源，一条命令自测 | ✅ |
| 正文净化、分章缓存、离线读 | 部分 |
| 换源、朗读、书签、离线整本下载 | ❌ 未做 |

---

## 跑起来

```bash
flutter pub get

# Windows 桌面（开发时最方便）
flutter run -d windows

# Android
flutter run -d <device-id>
```

### 打 Android 包（国内网络下的坑）

```powershell
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'   # 官方制品走国内镜像
flutter precache --android
flutter build apk --debug        # 产物 build\app\outputs\flutter-apk\app-debug.apk
```

已经在本仓库里处理掉的问题（换机器重装时可对照）：

- `android/gradle/wrapper/gradle-wrapper.properties` 用 `gradle-9.3.1-bin.zip`
  （`-all` 包在当前网络下下不动）。
- `android/gradle.properties` 加了 `kotlin.incremental=false`，避免第三方插件
  「Could not close incremental caches」。
- `android/build.gradle.kts` 里把 Kotlin 任务 jvmTarget 对齐到各模块 Java target，
  否则 Gradle 9 对 `flutter_js`（Kotlin 1.8 / Java 11）直接报
  `Inconsistent JVM Target Compatibility`。

### 签名是固定的（应用内更新必须）

`android/key.properties` + `android/app/noval-release.jks` 这两份**故意提交在仓库里**：
release 构建（本地和 GitHub Actions）都用同一把钥匙签名，APK 才能覆盖安装。
v0.4.0 及更早的包用的是 GitHub runner 上**每次重新生成的 debug key**，
所以每个版本的签名都不一样，升级时会报「已安装了签名冲突的应用」——
那些版本之间只能卸载重装。从 v0.5.0 起签名固定，应用内更新可以直接覆盖。

代价是这把私钥进了仓库：仓库只给自己用就别外传；要公开前先把这两个文件移出去、
再重新生成密钥（换钥匙又意味着现有装机要卸载重装一次）。

### 自动发版：打 tag 就出 APK 到 Release

`.github/workflows/release.yml`：推一个 `v*` tag（或在 Actions 页面手动 `Run workflow`）
就会在 GitHub 的 runner 上构建 release 产物，并自动挂到对应的 Release 里。

```bash
git tag v0.2.0
git push origin v0.2.0        # 触发构建，产物出现在 Releases 页面
```

工作流做四件事：

1. `subosito/flutter-action` 装 Flutter（stable，带 pub 缓存）；
2. `dart run tool/gen_version.dart` 把 `pubspec.yaml` 的版本号同步到
   `lib/src/core/version.dart`（App 内更新靠它比对 tag）；
3. `flutter build apk --release --split-per-abi` —— 按 ABI 拆分，
   **单包 20~25MB**（通用包 60MB+，split 后小一半以上）；
   再补一个 `flutter build apk --release` 出的通用包当兜底；
   Windows 任务另外打一个 `noval-<ver>-windows-x64.zip`；
4. `softprops/action-gh-release` 上传全部产物并写 Release notes。

产物命名（App 内更新就是照这个名字挑包的）：

```
noval-v0.3.0-arm64-v8a.apk       ← 手机装这个（99% 的安卓机都是 arm64）
noval-v0.3.0-armeabi-v7a.apk     ← 只给很老的 32 位设备
noval-v0.3.0-x86_64.apk          ← 只给模拟器，手机上装不上
noval-v0.3.0-universal.apk       ← 不确定装哪个时用这个，一定装得上
noval-v0.3.0-windows-x64.zip     ← Windows 桌面版
noval-latest-arm64-v8a.apk       ← 永远指向最新那版 arm64
```

> **装不上先看这里**：手机上装 `x86_64` 那份会报「应用未安装」——
> 那是 PC 模拟器的架构，手机是 arm64。装 `arm64-v8a` 或 `universal`。

不需要额外密钥：`GITHUB_TOKEN` 由 Actions 自动注入。**唯一的仓库设置**是
`Settings → Actions → General → Workflow permissions` 选
「Read and write permissions」，否则上传 Release 会被拒。

### 应用内更新

「我的 → 检查更新」会打 `api.github.com/repos/knowei/noval-koko/releases/latest`，
比对 `lib/src/core/version.dart` 里的版本号：

- 有新版本 → 弹窗给出体积与 Release notes →「下载并安装」；
- 下载走 `UpdateService.download`，落地到 `<应用支持目录>/updates/`，带进度条；
- Android 用 `MethodChannel('noval/update')` → `FileProvider` + `ACTION_VIEW`
  拉起系统安装器（首次会要求授予「安装未知应用」权限）；
- Windows / macOS / Linux 直接打开 Release 页面手动下载。

签名用的是 runner 临时 debug key；换成自己的 keystore 才需要配 Secrets（见工作流注释）。

### 源大面积失效时，按这个顺序排

书源失效有三种完全不同的原因，用错力气就是白改规则：

**1）域名到不了（墙 / 站点挂了）→ 先跑网络诊断**

「我的 → 网络诊断」会把所有书源里出现的域名逐个探一遍：DNS → TCP → HTTP。

- 全红：这个网络根本到不了站点，改规则没用，要换网络/代理/镜像；
- 能通但 403 / `Just a moment...`：站点侧反爬（Cloudflare），见下一条；
- 通了但解析空：这才是规则问题。

**2）Cloudflare 验证 → Cookie 存一次，之后自动复用**

命中验证页时报错会直接说明「站点要求人机验证（Cloudflare），不是规则的问题」。
在浏览器里过掉验证，把 `cf_clearance=...` 写进书源 JSON 的 `header`：

```json
{ "bookSourceName": "某站", "header": "{\"Cookie\":\"cf_clearance=...\"}" }
```

之后墨町会把它连同其它 `Set-Cookie` 一起存到 `<应用支持目录>/cookies.json`，
下次启动自动灌回去，直到它自己过期。

⚠️ `cf_clearance` 绑定 IP + UA：换个网络就得重新过一遍；如果整个IP段都不通，
存 Cookie 也救不回来（那种情况只能走代理或换镜像）。

**3）主域被墙但镜像还活着 → 引擎自动换**

书源可以声明镜像组（我们自己的扩展字段，Legado 导出里没有）：

```json
{ "bookSourceUrl": "https://baozimh.org", "mirrors": ["https://bzmh.org"] }
```

引擎请求失败（超时/连接重置/验证页）时会按顺序换下一个地址重试，
成功后记住这个镜像，整轮操作都用它；规则本身一个字都不用改。
内置了几组已知对照（`baozimh.org ↔ bzmh.org`），没写 `mirrors` 也会自动用。

### 书源订阅（一个 URL 拉整套源）

「书源管理 → 右上角 RSS 图标」：

- 填一个返回书源 JSON 的地址（GitHub raw / gist / jsDelivr 都行），
  支持两种格式：裸数组 `[{...}]`，或 Legado 分享格式 `{"bookSources":[...]}`；
- 拉下来按 `bookSourceUrl` 合并：同地址覆盖规则，**保留你自己改的启用/停用状态**；
- 每行显示「多少个源 · 上次更新时间」，点一下就同步；删订阅不会删已导入的源。

### 用自带的假站点自测（不联网也能验证全链路）

```bash
# 终端 1：起一个本地假小说/漫画站，监听 8787
dart run tool/mock_site.dart

# 然后在 App 里：书源 → 导入 → 粘贴 docs/mock_source.json → 搜索「仙侠」
```

### 用真实网站验证（联网）

`sample_sources/standardebooks.json` 是一个**跑得通的真实书源**，指向
[Standard Ebooks](https://standardebooks.org)（公版英文书站，服务端渲染、无反爬、结构稳定：

```bash
flutter test integration_test/real_source_test.dart -d windows
```

它会真的联网走一遍 搜索「pride」→ 7 条结果 → 书目 → 67 章目录 → 正文（约 2500 字符），
并断言每一环都有数据。想自己试：App → 书源 → 导入 → 粘贴该文件内容 → 搜索 `pride`
→ 打开《Indian Fairy Tales》→ 阅读。

> 国内中文公开源里约 97% 已报废（详见下文「从公开源里批量筛活源」的实测数据）。
> 想直接读，把 `docs/live_sources.json` 导入即可（**13 个** 2026-10 实测可用的源，小说/漫画/轻小说/日轻/名著/出版物都有）；
> 引擎侧的兼容性由本地假站点用例保证。

### 导入本地书（TXT / EPUB，不需要任何书源）

书架右上角 **+** → 选文件。导入时文件会被**复制**进应用目录
（`<appSupport>/local_books/`），所以原文件挪走/删掉也不影响阅读。

- **TXT**：自动识别 UTF-8 / GBK（国内 TXT 大量是 GBK），按
  `第N章` / `第N节` / `第N回` / `卷N` / `Chapter N` / `1.` 这些行切章，切不出来就整本一章。
- **EPUB**：读 `container.xml` → OPF 的 manifest/spine 顺序出目录，标题取
  `<h1>/<h2>/<title>`，正文用和书源一样的 HTML→纯文本净化（封面页、版权页这种空页会被跳过）。

验证：

```bash
flutter test integration_test/local_book_test.dart -d windows
```

用例会现造一个 **GBK 编码的 TXT** 和一个**手工拼的最小 EPUB**，走完「导入 → 上书架 →
切章 → 取正文」，并把结果写进 `tool/local_test_report.txt`。

### 自动化测试

```bash
flutter analyze                            # 静态检查
flutter test                               # 单元 + 端到端（自带假站点）
flutter test integration_test -d windows    # 需要桌面/真机：JS 引擎 + UI 用例
```

`test/` 里的用例会自己拉起假站点跑「搜索 → 详情 → 目录 → 正文」和漫画图片解析；
`integration_test/` 里的用例验证 QuickJS 真能跑（`java.ajax`、`base64`、`md5`、JS 规则）
以及真实站点上的活源回归（`live_source_test.dart`）；`scan_test.dart` / `pick_live_test.dart`
是批量体检公开源的工具，见下文。

两个「整机」用例值得单独说：

- `app_flow_test.dart`：不走 UI，直接压 `AppState` + SQLite + 引擎，验证导入→搜索→入架→
  目录→正文/图片→存进度→重开仍在。
- `ui_flow_test.dart`：**真的把界面点一遍**——起 App、切到搜索、输入关键词、点搜索、
  点结果进详情、点「开始阅读」、断言阅读器上出现成段正文；再把漫画阅读器拉起来断言图片
  卡片渲染。这条用例抓到过一个真 bug：正文还没到时就把「0 页」缓存了，导致正文回来后
  首屏一片空白（`_paginate` 的缓存 key 现在带上了正文本身）。

写法上有个坑：这类用例**不能用 `pumpAndSettle`**（详情页/阅读器里有一直转的进度圈，
永远等不到静止，默认 10 分钟才超时），只能用「反复 `pump` + 轮询 finder」的辅助函数。

---

## 书源 JSON 长什么样

最小可用例子（`docs/mock_source.json` 是完整可跑版）：

```json
[
  {
    "bookSourceUrl": "https://example.com",
    "bookSourceName": "示例源",
    "bookSourceType": 0,
    "searchUrl": "/search?key={{key}}",
    "ruleSearch": {
      "bookList": "class.result",
      "name": "class.name@text",
      "author": "class.author@text",
      "bookUrl": "class.name@href"
    },
    "ruleBookInfo": { "name": "class.bookname@text", "tocUrl": "class.toc@href" },
    "ruleToc": { "chapterList": "id.list@a", "chapterName": "text", "chapterUrl": "href" },
    "ruleContent": { "content": "id.content@html" }
  }
]
```

- `bookSourceType`：`0` 文本；漫画源用 `1`/`2`，其 `ruleContent.content` 取图片地址，多个用 `&&` 拼接。
- URL 里 `{{key}}` 替换成搜索词，`{{page}}` 是页码。
- 相对地址会按当前页面 / 书源地址自动补全。

## 规则语法支持

一条规则 = **选择器链 + 取值器**，或者一段 `@js:` 脚本：

| 写法 | 含义 |
| --- | --- |
| `class.book-list@tag.li@text` | jsoup 风格：`@` 逐级下钻，末尾是取值器 |
| `@css:.list > li@href` | 显式 CSS 选择器 |
| `//div[@id=list]//a/@href` | XPath（内置子集，够用但不完整） |
| `id.list@a` | `id` / `class` / `tag` / `text` 简写 |
| `@Json:$.data.list[*].name` | JSONPath（接口型站点） |
| `@js:java.ajax(baseUrl + '/api')` | JavaScript，`result` 是当前节点文本 |
| `<js>org.jsoup.Jsoup.parse(result).select('a').text()</js>` | JS 的另一种写法，可用 jsoup 垫片 |
| `.book_other span!0:3@text` | `!start:end` 索引切片（end 不含，负数从末尾算） |
| `.list li!-1@text` | 单个索引切片（负数=倒数） |
| `:detail"[\s\S]*?href="([^"]*)"` | `:` 开头=正则规则，`$1..$9` 取分组 |
| `coverUrl: "$4"` + `ruleBookInfo.init` | init 先用正则抓分组，字段里 `$N` 引用分组 |

取值器：`text`（纯文本）、`html`（内部 HTML）、`href` / `src` / `attr.xxx`（属性）、`ownText`。
多条规则用 `&&`（依次拼接）或 `||`（取第一个有结果的）组合。

### jsoup 垫片（纯 JS 实现，不走网络）

真实书源里大量出现 `org.jsoup.Jsoup.parse(result)...`。它解析的是**已在内存里的字符串**，
所以本项目在 JS 预置脚本里塞了一个迷你 DOM，支持：

```
Jsoup.parse(html) / Jsoup.parseBodyFragment(html) / Jsoup.clean(html)
.select(css) 元素选择器：tag / .class / #id / [attr] / [attr=v] / [^=] [ $= ] [*=] / :first :last :eq(n) :contains(s) :not(s)
            组合：空格（后代）、>（子元素）、逗号（并集）
.text() / .ownText() / .html() / .outerHtml() / .attr(k) / .attr('abs:href') / .hasAttr(k)
.size() / .get(i) / .first() / .last() / .eq(i) / .eachText() / .texts() / .each(fn) / .forEach(fn)
.children() / .child(i) / .parent() / .parents() / .next() / .prev() / .siblings()
```

注意：`attr('href')` 与 jsoup 一致返回原始值（不自动补全），需要绝对地址用 `attr('abs:href')`
或交给引擎的 URL 取值器处理。


### JS 里的 `java.*`（Legado 兼容子集）

```
java.ajax(url) / java.get(url) / java.post(url, body)   // 同步返回响应文本
java.base64Encode(s) / java.base64Decode(s)
java.md5Encode(s) / java.md5Encode16(s)
java.urlEncode(s) / java.timeFormat(t) / java.log(msg)
source.bookSourceUrl / source.bookSourceName / result / baseUrl
```

实现方式：JS 调用 `java.ajax` 时先抛出一个内部「需要取数」异常，Dart 侧真正发请求、
把结果写回 JS 上下文后**重放同一段脚本**。因此 **规则里不要用 `try/catch` 包住 `java.ajax`**，
否则那一轮会被当成正常返回、拿不到数据。

---

## 目录结构

```
lib/
  main.dart                     入口
  app.dart                      主题 + 底部三页（书架 / 搜索 / 我的）
  app_state.dart                全局状态：书源、书架、搜索、章节/正文加载、阅读偏好、主题
  src/
    core/      charset_util（GBK 等解码）、text_util（清洗 / URL 补全 / 图片请求头）、
               html_text（HTML→纯文本）、rule_exception、
               update_service（查 GitHub Release / 下 APK / 拉起安装）、version（版本号，脚本生成）
    db/        database（sqflite，桌面走 ffi）、shelf_repo、source_repo
    model/     book_source（规则模型）、book_info（BookInfo / BookChapter / BookContent）、
               search_book、shelf_book
    local/     local_book_store（本地 TXT / EPUB：导入、切章、取正文）
    net/       http_service（超时、UA / Referer、编码探测）、rate_limiter（concurrentRate）
    rule/      rule_parser（选择器链 + 取值器）、xpath_engine（XPath 子集）、
               js_engine（QuickJS + 异步桥 + atob/TextDecoder 垫片）、jsoup_shim、rule_context
    source/    source_engine（搜索 / 详情 / 目录 / 正文全流程）
    ui/        home_page、search_page、book_detail_page、mine_page、source_page、
               chapter_list_page、widgets、motion（动效件）、nav_bar、update_entry（检查更新）、
               theme/{app_theme, theme_sheet}、reader/{text_reader, comic_reader, read_theme}
tool/
  mock_site.dart / mock_site_server.dart   本地假站点（小说 + 漫画）
  fetch_sources.ps1            从 GitHub 批量抓公开书源集合（结果放 tool/scan_raw/，不入库）
  gen_version.dart             从 pubspec.yaml 生成 lib/src/core/version.dart
  make_mh_mirrors.py           按包子系模板生成镜像源（bzmh.org）
  add_sources_generic.py       把 sample_sources/*.json 并入 docs/live_sources.json
  sync_db.py                   把 docs/live_sources.json 同步进本机 App 的 SQLite
  scan_report.txt / pick_log.txt           体检与筛选的实测输出
sample_sources/
  standardebooks.json           真实书源（联网可用，端到端验证用）
  yijie_bookSource.json / bilinovel.json   公开书源集合（多数已失效，仅作兼容性素材）
docs/
  live_sources.json             体检筛出来的活源（可直接导入 App，有回归用例守着）
  mock_source.json              配套示例书源（小说 + 漫画各一条）
  调研-小说漫画App.md            市场调研
  设计-规则驱动阅读器.md          架构设计
```

## 真实书源适配现状与体检

引擎按 Legado 书源格式实现，已经覆盖真实源里最常见的写法：`@css:` / `@json:` / `@xpath:`
前缀、`<js>` 与 `@js:`、`org.jsoup.Jsoup` 垫片、`!0:3` 索引切片、`##正则##替换###`、
`ruleBookInfo.init` 正则分组 + `$1` 模板、`searchUrl` 的 `,{json}` 选项（`method` / `body` /
`charset` / `headers`）、GBK 站点按声明字符集往返编解码、`concurrentRate` 限速。

本机实测过两份公开书源集合（`sample_sources/yijie_bookSource.json` 30 个源、
`sample_sources/bilinovel.json` 2 个源）：绝大多数源已失效——域名停放、301 到广告页、
403/404/504、或返回「Redirecting… / 请开启 JavaScript」的反爬挑战页；少数能连通的返回的是
站点首页而不是搜索结果。**因此那批中文公开源不能作为回归依据**，引擎正确性由本地假站点用例
（`test/sample_source_test.dart`、`integration_test/*`）保证。

### 从公开源里批量筛活源（实测数据）

单个集合过时没关系，仓库里带了一条完整的「抓取 → 体检 → 筛选 → 回归」流水线：

```powershell
# 1) 从 GitHub 抓 50+ 个书源仓库里的 JSON 集合（原始字节存到 tool/scan_raw/）
.\tool\fetch_sources.ps1
# 2) 逐源体检：先按域名粗筛（死域名一次都不探），再逐源跑搜索，最后对搜到书的源验详情/目录/正文
flutter test integration_test/scan_test.dart -d windows      # 产出 tool/scan_report.txt
# 3) 把真的能读的源挑出来落盘成 docs/live_sources.json
flutter test integration_test/pick_live_test.dart -d windows  # 产出 tool/pick_log.txt
# 4) 活源回归（改引擎后必须仍然全绿）
flutter test integration_test/live_source_test.dart -d windows
```

2026-10 实测结果（关键词「剑来」）：154 个 JSON 文件 → **1508 个去重源 / 1247 个域名**，
活域名 474 个，能搜到书的 42 个，**全文链路真正跑通的 3 个**：

| 源 | 类型 | 搜索 | 目录 | 正文 |
| --- | --- | --- | --- | --- |
| 连载书 `m.lianzaisu.com` | 小说 | 2 条 | 5 章 | 23221 字 |
| 河豚小说 `m.hetunxs.com` | 小说 | 1 条 | 20 章 | 3620 字 |
| 看漫画 `m.kanman.com` | 漫画 | 2 条 | 60 章 | 单章 17 张图，首图 445 KB 可下载 |

失败原因分布：域名不通 912 个、域名活着但搜索 0 条 327 个（站点改版/规则过期）、
请求报错 227 个（403/404/400、超时、JS 规则失效）。结论很直接：**公开中文源的报废率
约 97%**，好在这条流水线随时能重跑一遍，把新冒出来的活源捡回来。

这 3 个源里有两个是 `searchUrl` 带 `,{json}` 选项（GBK + POST 表单）的，等于顺带证明了
选项解析、GBK 往返回编解码在真实站点上是有效的。

漫画那个源（看漫画）的 `ruleContent.content` 是 JS 现拼一段 `<img src="...">` 的 HTML
返回，`evalImageList` 因此会先按 `<img>` 标签抽 `src`/`data-src`，抽不到才退回按空白切分，
实测一章能出 17 张图（首图 445 KB 确实能下下来）——这条是 App 级用例
`integration_test/app_flow_test.dart` 里断言过的。

作为「真实网络跑得通」的补充证据，仓库里还带了 `sample_sources/standardebooks.json`：
Standard Ebooks 的结构稳定、无反爬，`flutter test integration_test/real_source_test.dart -d windows`
实测 搜索 7 条 / 目录 67 章 / 正文 2581 字全部通过。你要验证自己的中文源时，也是同一个流程。

### 精选书源清单（`docs/live_sources.json`，2026-10-26 实测）

回归命令（改引擎后必须仍然全绿，结果同时写进 `tool/curated_sources_report.txt`）：

```powershell
flutter test integration_test/curated_sources_test.dart -d windows
```

| 分组 | 书源 | 类型 | 搜索（关键词） | 目录 | 正文 |
| --- | --- | --- | --- | --- | --- |
| 🧩漫画 | 看漫画 `m.kanman.com` | 漫画 | 2 条（剑来） | 60 章 | 单章 17 张图 |
| 📖中文小说 | 河豚小说 `m.hetunxs.com` | 小说 | 1 条（剑来） | 20 章 | 3620 字 |
| 📖中文小说 | 连载书 `m.lianzaisu.com` | 小说 | 2 条（剑来） | 5 章 | 23221 字 |
| 📗中文轻小说 | 轻之文库 `www.linovel.net` | 小说 | 15 条（史莱姆） | 86 章 | 9452 字 |
| 📗中文轻小说 | 哔哩轻小说 `www.linovelib.com` | 小说 | 11 条（史莱姆） | 595 章 | 2 万字级长章自动分页 |
| 📗中文轻小说 | SF轻小说 `book.sfacg.com` | 小说 | 24 条（史莱姆） | 587 章 | 2764 字 |
| 🏛名著 | 漢典古籍 `gj.zdic.net` | 小说 | 1 条（西游记） | 101 章 | 7816 字（繁体） |
| 🏛名著 | Standard Ebooks | 小说 | 7 条（pride） | 67 章 | 英文原文 |
| 🗾日文轻小说 | カクヨム `kakuyomu.jp` | 小说 | 6 条（スライム） | 5~1000+ 章 | 3493 字（日文原文） |
| 🧩漫画 | 包子漫画 `baozimh.org` | 漫画 | 9 条（斗罗大陆） | 605 章 | 单章 36 张图 |
| 🧩漫画 | 包子漫画·镜像 `bzmh.org` | 漫画 | 9 条（斗罗大陆） | 605 章 | 单章 36 张图（同款解密器） |
| 📚出版物 | 可阅文学网 `www.kepub.net` | 小说 | 1 条（山雨） | 29 章 | 2 万字级（`<br>` 分段） |
| 📚出版物 | 麦归文学 `www.maiguiread.com` | 小说 | 1 条（解忧杂货店） | 5 章 | 28512 字 |
| 🧩漫画 | MangaDex `api.mangadex.org` | 漫画（日漫） | 8 条（チェンソー） | 6 章 | 单章 34 张图（@Home 节点） |

几个踩过的坑，改源前值得看一眼：

- **Gutenberg 没进清单**：`pride and prejudice` 单页全文 73 万字，阅读器分页会卡死；
  Standard Ebooks 有真正的分章节页面，体验更好。
- **目录分页**：`nextTocUrl` 里 `text.下一页@href` 的 `text.` 前缀必须用于「按文本过滤候选链接」，
  否则只能拿到第一页（20 章封顶）。
- **`###` 结尾**：Legado 里表示「正则替换全部」，引擎会先吃掉这个尾巴，避免替换串多出一个 `#`。
- **搜索页可能是排序页**：看漫画的 `searchUrl` 其实是「全部漫画」列表页，关键词根本没参与查询，
  引擎对这类源会做一次客户端相关性过滤（命中不到就标注「站点模糊匹配」）。
- **封面 403**：部分站点校验 Referer，`header` 里带上站点自身 Referer + 浏览器 UA 即可。
- **图片地址被加密（包子漫画）**：`v2.apikk.top/api/v2/chapter/getinfo` 返回的 `info.images.images`
  是整包 base64 密文，要加载站点自己的 `chapter-decoder.js`（挂 `window.__cimg.r(payload)`）解出图片路径，
  再按 `x.c` 映射拼成 `https://c-nd2-1.6wm.top` 等域名。解密器是异步的（返回 Promise），
  引擎为此补了 `atob` / `TextDecoder` / `window` / `location` 垫片，并把 `evaluate` 里的 Promise 手动抽干
  （QuickJS 插件不 await）。规则写法见 `sample_sources/baozimh.json` 的 `ruleContent.content`。
- **镜像站同构**：`bzmh.org` 与 `baozimh.org` 是同一套前端（同一份 21016 字节解密器），
  改 `bookSourceUrl` 就能复制一份兜底源（`tool/make_mh_mirrors.py`）。但 `godamh.com`（G站）
  虽然同构、目录与图片接口都能用，**搜索是纯前端渲染**（`/s?q=` SSR 里没有结果），
  所以没有收进来。

自己验证某个源时，用这个排障用例（会把「请求」和「解析」拆开看到底卡在哪一步）：

```powershell
$env:PROBE_SOURCE_FILE='sample_sources/yijie_bookSource.json'
$env:PROBE_INDICES='7,8,15'    # 要看的源下标
$env:PROBE_DETAIL='7'          # 可选：对某个源额外跑一遍引擎完整流程
flutter test integration_test/debug_source_test.dart -d windows
```

全量体检（搜索→详情→目录→正文逐源跑）：

```powershell
$env:PROBE_SOURCE_FILE='你的书源.json'; $env:PROBE_LIMIT='30'
flutter test integration_test/real_source_probe_test.dart -d windows
```

适配新写法改哪里：语法 → `lib/src/rule/rule_parser.dart`；请求/字典替换/流程 →
`lib/src/source/source_engine.dart`；JS 预置脚本（`java.*`、jsoup 垫片）→
`lib/src/rule/js_engine.dart` 与 `lib/src/rule/jsoup_shim.dart`。

## 已知限制

- XPath 是自研子集（不支持全部函数与轴），复杂表达式会返回空，优先用 CSS 选择器。
- jsoup 垫片是子集：没有 `Jsoup.connect`、`Parser`、`formData`、`absUrl` 链式用法。
- 书源里的 `jsLib`（公共 JS 库）、`loginUrl`、`enabledCookieJar` 尚未加载/处理，
  Cookie 只在同一次运行内由 CookieJar 自动维持。
- 不支持验证码 / JS 挑战 / WebView 交互类站点（这类站点在桌面端也无法直连取数）。
- 分页正文合并、换源、书架导入导出、订阅源尚未实现。
- 本地导入只支持 **TXT 文本 / EPUB 文本**；本地漫画（CBZ、图片文件夹）还没做，EPUB 里的
  插图目前也不会显示（正文按纯文本处理）。
- 中文编码依赖响应头探测 + `charset` 包，非常规编码的站点可能乱码。


## 免责

仅供个人学习与自用。请只导入你有权访问的站点规则，遵守目标站点条款与当地法律，
不要用于抓取或传播侵权内容。
