# BiliClean

为哔哩哔哩 iOS 客户端提供赞助片段跳过、广告过滤、完整视频下载和界面整理的插件。

## 安装

从本仓库 **Releases → Assets** 下载 `BiliClean_版本号.dylib`，使用 IPA 注入工具将它加入哔哩哔哩安装包，完成签名后安装。注入环境需要提供 MobileSubstrate 兼容支持。

安装后，打开 **哔哩哔哩 → 我的 → 设置 → 右上角 BiliClean**，即可调整功能开关。

- 构建包含 `arm64`、`arm64e` 两种架构，最低部署版本为 iOS 14。
- 已测试版本：哔哩哔哩 **8.76.0**；**9.12.0** 的 CDN 测速及首页/会员购过滤已获真机正常反馈。

## 功能

| 功能 | 使用体验 |
| --- | --- |
| 赞助片段跳过 | 根据小电视空降助手的社区标注自动跳过赞助片段，可调整跳过提前量、设置不重复跳过 |
| 完整视频下载 | 下载当前正在播放的完整视频，自动选择账号可获取的最高画质，音视频无损合并后保存到照片 |
| 广告过滤 | 移除开屏、信息流和播放器广告，按需过滤带货内容、相关推荐广告及片尾推荐 |
| 关键词屏蔽 | 按普通关键词或正则表达式过滤内容，每条规则可分别用于推荐、动态和评论 |
| 播放速度 | 设置默认倍速，在常见倍速列表中增加 3 倍速 |
| CDN 加速 | 测试播放节点速度，自动选择较快节点，也可手动选择和调整优先顺序 |
| TAB 管理 | 自由选择首页频道、顶部与底部导航项目，单独控制底部发布入口 |
| 界面整理 | 按需隐藏首页直播、图文推荐、竖屏模式、推荐理由、互动弹幕及“我的”页不常用服务 |

## 使用

### 下载完整视频

1. 在视频播放页打开分享面板。
2. 点击第三个位置的 **下载分享** 或 **下载视频** 按钮
3. 顶部显示下载、合并和保存进度。可以返回列表或切换其他视频

暂不支持 HDR 或杜比视界
需有相册写入权限

### 跳过赞助与调整播放

在 **BiliClean → 播放** 中开启赞助跳过，可设置跳过提前量。片段数据来自 [小电视空降助手](https://bsbsb.top/) 的社区标注。

进入 **CDN 加速** 页面运行测速，选择节点或拖动调整顺序。这里的节点设置用于播放；完整视频下载使用接口返回的原始主备地址。

内置 31 个经点播媒体请求验证的候选节点，另会加入最近播放接口发现的节点。列表综合 BiliRoamingX 和录播姬香港 Equinix 清单去重，保留当前网络实测通过的节点；验证时间、方法、加入和排除名单见 [CDN_VALIDATION.md](CDN_VALIDATION.md)。节点可用性会随时间、地区及网络变化。

测速覆盖全部候选 CDN，按实际媒体下载速度排序。优先用该节点原生地址；没有原生地址时，将主备样本的域名替换为该候选节点，保留完整路径和签名。每个节点最多尝试 3 个样本，每个样本先用 App 下载请求头，403/404 时再试网页请求头。失败不计为速度 0，也不代表节点必然较慢；跨 CDN 跳转不计入原节点速度。播放时仍优先排列接口提供的原始地址，保留原始回退地址。请先播放一个普通视频，再进入 CDN 加速测速；关闭 CDN 替换时也能采集测速地址。地址只保留在内存中，最长使用 5 分钟，并提前排除已过期的签名地址。没有可用地址时才请求备用 BV 号的匿名接口；若此时出现 HTTP 412，表示获取测速样本被 B 站风控拒绝，请重新播放视频后再试。

### 过滤内容与整理界面

在 **屏蔽** 分组中选择要移除的广告类型，并添加关键词规则。在 **首页**、**界面** 分组中调整推荐内容、TAB 和服务入口。不同过滤功能可单独开关，也可通过总开关统一控制。

六个默认开启的开关（开启表示隐藏/移除）：

| 设置位置 | 开关 | 生效方式 |
| --- | --- | --- |
| 界面 | 隐藏底部会员购 | 重启 App；与 TAB 板块中的会员购选择同步 |
| 首页 | 移除创作推广卡片 | 下拉刷新首页 |
| 首页 | 移除会员购卡片 | 下拉刷新首页 |
| 首页 | 移除广告角标卡片 | 下拉刷新首页 |
| 首页 | 移除跨两列大卡片 | 下拉刷新首页，包括大视频、大广告和大直播卡片 |
| 首页 | 移除小游戏/广告 | 下拉刷新首页，识别小游戏角标、类型与小游戏跳转入口 |

首页规则根据封面角标、广告元数据和卡片布局类型识别，不扫描视频标题。普通双列网格中的小卡片不会仅因类型含 `double` 被当作跨列卡片。多个条件同时命中时，任意对应开关开启即移除；已有直播、图文、关键词规则也仍生效。关闭开关后需要请求新的推荐数据，已移除的旧卡片不会原地恢复。

默认备用测速 BV 号为 `BV1tFZZBQE57`；用户之前手动保存的 BV 号保留，可在 CDN 加速页自行修改。

9.12.0 兼容：网络过滤接入实际存在的 `BFCRequest.handleFinishCallbackWithData:response:error:`；旧版带 `priority` 的初始化方法只作为兼容回退。底部会员购同时在导航控制器、路由列表及 Tab 视图构建时过滤，覆盖本地缓存配置。已对本地 9.12.0 二进制核对这些方法名和参数类型；上述功能已获 9.12.0 真机正常反馈；其他客户端版本仍需另行验证。

## 从源码构建

使用 macOS、Xcode 和 [Theos](https://theos.dev/docs/installation-macos)，配置好 `THEOS` 环境变量后运行：

```bash
make clean release
```

输出文件：

```text
dist/BiliClean_1.0.28.dylib
dist/BiliClean_1.0.28.dylib.sha256
packages/com.imlr.bilibilisp_1.0.28_iphoneos-arm.deb
```

版本号取自 `control`。业务代码使用 Objective-C / Logos，音视频合并和相册保存使用系统 AVFoundation、Photos 框架。

CDN 地址选取的回归测试可在仅安装 Command Line Tools 的 Mac 上运行，无需连接手机或访问网络：

```bash
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -I . -framework Foundation tests/CDNSampleTests.m BLCCDNManager.m BLCCDNSpeedProbe.m -o /tmp/biliclean-cdn-tests
/tmp/biliclean-cdn-tests
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -I . -framework Foundation tests/CDNProbeTests.m BLCCDNSpeedProbe.m -o /tmp/biliclean-probe-tests
/tmp/biliclean-probe-tests
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -I . -framework Foundation tests/FeedFilterTests.m BLCFeedFilter.m BLCTabManager.m -o /tmp/biliclean-feed-tests
/tmp/biliclean-feed-tests
```

维护者在 GitHub 发布与 `control` 版本一致的 Release（例如 `v1.0.28`）后，发布工作流会自动构建并上传 **dylib 和 SHA-256 校验文件**。

## 免责声明

- 本项目旨在用于 iOS 逆向工程学习与技术研究，与哔哩哔哩官方无关联。
- 使用时请遵守适用法律法规及相关平台规则，尊重视频和其他内容的著作权，不得用于侵权或其他违法活动。
- 如认为项目中的内容侵犯了你的合法权益，请通过 [Issue](https://github.com/ahaduoduoduo/BiliClean/issues) 联系维护者并提供相关说明，核实后将及时处理。

## 鸣谢

- [TouchFriend / BiliBiliTweak](https://github.com/TouchFriend/BiliBiliTweak)：广告过滤、设置入口及播放功能的代码参考。
- [小电视空降助手](https://bsbsb.top/)及其社区贡献者：提供 B站赞助片段数据和 API。

## 项目信息

由 **ahaduoduoduo** 维护，主要代码由 AI 辅助编写。

采用 [MIT 许可证](LICENSE)。欢迎通过 Issue 反馈使用体验。
