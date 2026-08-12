# WebSocket 优先优化说明（fork: optimize-ws）

基于实测：**WebSocket 最稳、测速最快**。默认传输仍为 `ws`。

## 你的使用方式（无需 `PROXYIP` 环境变量）

部署后用后台 **【优选订阅生成】** → Magic 更新订阅即可。

## Worker（`_worker.js`）改动

| 项 | 作用 |
|----|------|
| 同主机只拨一路 | 无预加载多 IP 时不再对同一 hostname 空并发 |
| 直连/反代对冲 | 直连约 280ms 未成则并行启动反代（`CONNECT_HEDGE_MS`） |
| 直连超时更快 | 有反代时可对冲时直连超时 ≤650ms，总默认 900ms |
| 反代并发默认 3 | 路径内反代更快试通 |
| 反代解析缓存 45s | 减少重复 DoH |
| VLESS 响应头提前回 | 建连成功即回协议头，不等远端首字节 |
| 下行首包立即刷出 | 降低浏览 TTFB；合包等待轮次降为 1 |
| 隧道 DNS：DoH+TCP 竞速 | CF 上 DoH 通常更快；TCP 上游超时 450ms |
| 预加载竞速拨号**默认关** | 需要时设 `PRELOAD_RACE_DIAL=1`（多 IP 域名更有用） |
| 旧配置缺省补齐 | 未设置时默认开 **0-RTT**、**UDP/XUDP**、指纹 chrome、传输 ws |
| Clash 热补丁增强 | 给 WS 节点补 `client-fingerprint` / `udp`/`xudp` / `max-early-data` |
| **错误率收敛** | 顶层 try/catch；建连/握手失败关连接不 `throw` |
| **管理后台在线优选** | 代理 edt-pages 时去掉上游写死的 `disabled` |

### 关于 Cloudflare「错误率」

仪表盘 **Errors** 主要统计 **未捕获异常 / 超限**，不是 HTTP 4xx/5xx。收敛后失败应表现为静默关 WS；业务成功率仍取决于优选线路质量。

## Magic 客户端（Bettbox `lib/state.dart`）改动

`patchRawConfig` 对订阅节点缺省补齐（不覆盖显式配置）：

- TLS 节点：`client-fingerprint: chrome`
- VLESS/VMess + WS：`udp` / `xudp`
- 路径含 `ed=` 时写入 `ws-opts.max-early-data` + `Sec-WebSocket-Protocol`

## 面板建议

1. 传输：**WebSocket**
2. **启用 0-RTT**：开
3. 指纹：chrome
4. 跑一次 **优选订阅生成** → Magic 更新订阅

## 可选环境变量（均非必须）

| 变量 | 默认 | 说明 |
|------|------|------|
| `PRELOAD_RACE_DIAL` | 关 | `1`/`true` 开启域名多 IP 竞速 |
| `TCP_CONCURRENT_DIAL` | `2` | 预加载时最多竞速 IP 数 |
| `PROXY_CONCURRENT_DIAL` | `3` | 反代并发拨号数 |
| `CONNECT_TIMEOUT_MS` | `900` | TCP 建连超时 |
| `CONNECT_HEDGE_MS` | `280` | 直连未成时启动反代对冲的延迟；`0` 关闭对冲 |
| `DEBUG` | 关 | 详细日志 |

**不需要 `PROXYIP`。**

## 部署顺序

1. 部署本仓库 `_worker.js`
2. 确认面板 0-RTT + WS
3. 重新生成优选订阅
4. 使用已改 `patchRawConfig` 的 Magic 客户端刷新配置

## 边界

优选入口 IP 质量仍是测速上限主因；Worker 侧优化主要改善 **建连失败回落、DNS、首包/TTFB、反代解析重复开销**。
