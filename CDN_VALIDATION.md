# CDN 清单验证记录

验证时间（UTC）：2026-09-27T05:23:31.516950+00:00

## 来源

- [BiliRoamingX 指定版本](https://github.com/BiliRoamingX/BiliRoamingX/blob/ae58109f3acdd53ec2d2b3fb439c2a2ef1886221/patches/src/main/resources/bilibili/host/values/strings_raw.xml)：20 个点播候选。
- [录播姬 Equinix IX](https://rec.danmuji.org/dev/cdn-info/#cdn-eq)：香港 01-01 至 01-14；页面标注更新于 2023/11/21，原本是直播 CDN 资料，本次逐个验证点播兼容性。
- 合并已有 20 个节点后，共 35 个去重候选。未批量加入该页面其他直播节点。

## 方法与范围

- 使用公开视频 `BV1fK4y1t7hj` 的新鲜 playurl，替换候选域名后请求 `Range: bytes=0-16383`。
- 保持 HTTPS 证书验证；不跟随跳转。要求 HTTP 200/206、至少 1024 字节且头部为 MP4 ftyp/styp，避免误认错误页面。
- 最多使用 3 个主备样本，尝试 App/网页请求头；首轮未通过项延长超时复测。
- 本次 31 个节点均实际返回 HTTP 206 及 MP4 媒体数据。此为当前 Mac 网络和一个公开视频的兼容性验证，不保证所有地区、账号、视频和未来持续可用。
- 四个域名两轮均返回 curl 6（解析失败）。公开 DNS 复核请求超时，不能断言全球 NXDOMAIN 或永久下线；未通过有效性验证，暂不收录。

## 更新结果

- 原有 20 个节点保留 17 个，新增 14 个，总计 31 个。
- 新增百度云 mirrorbos 与 13 个香港 Equinix 节点（01-07 除外）。

| 节点 | 结果 | 处理 |
| --- | --- | --- |
| `upos-sz-mirrorali.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirroralib.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirroralio1.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorcos.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorcosb.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorcoso1.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorhw.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorhwb.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorhwo1.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirror08c.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirror08h.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirror08ct.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-tf-all-hw.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-tf-all-tx.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-hz-mirrorakam.akamaized.net` | 206 + MP4 | 保留 |
| `upos-sz-mirrorakam.akamaized.net` | 两轮 DNS 解析失败，未验证有效 | 移出内置列表 |
| `upos-sz-mirroraliov.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorcosov.bilivideo.com` | 206 + MP4 | 保留 |
| `upos-sz-mirrorhwov.bilivideo.com` | 两轮 DNS 解析失败，未验证有效 | 移出内置列表 |
| `cn-hk-eq-bcache-01.bilivideo.com` | 两轮 DNS 解析失败，未验证有效 | 移出内置列表 |
| `upos-sz-mirrorbos.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-01.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-02.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-03.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-04.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-05.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-06.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-07.bilivideo.com` | 两轮 DNS 解析失败，未验证有效 | 不加入 |
| `cn-hk-eq-01-08.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-09.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-10.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-11.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-12.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-13.bilivideo.com` | 206 + MP4 | 新增 |
| `cn-hk-eq-01-14.bilivideo.com` | 206 + MP4 | 新增 |
