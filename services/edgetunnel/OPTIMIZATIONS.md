# WebSocket 优先优化说明（fork: optimize-ws）

基于实测：**WebSocket 最稳、测速最快**。默认传输仍为 `ws`。

## 你的使用方式（无需 `PROXYIP` 环境变量）

部署后用后台 **【优选订阅生成】** → Magic 更新订阅即可。

## Worker（`_worker.js`）改动

| 项 | 作用 |
|----|------|
| 预加载竞速拨号**默认关** | 减少竞速失败带来的未捕获异常；需要时设 `PRELOAD_RACE_DIAL=1` |
| 反代并发默认 2 | 路径内反代更快试通 |
| 建连超时 1200ms 可配 | 直连失败更快回落 |
| DNS UDP 三路竞速 | 隧道内 DNS 更稳 |
| 旧配置缺省补齐 | 未设置时默认开 **0-RTT**、**UDP/XUDP**、指纹 chrome、传输 ws |
| Clash 热补丁增强 | 给 WS 节点补 `client-fingerprint` / `udp`/`xudp` / `max-early-data`（不覆盖已有值） |
| **错误率收敛** | `fetch` 顶层 try/catch；TCP/WS/gRPC 建连或握手失败改为关连接、不 `throw`（避免 Metrics「错误」≈ Uncaught Exception） |
| **管理后台在线优选** | 代理 `edt-pages` 管理页时去掉上游写死的 `disabled`（上游 2026-08-11 起误禁用） |
| **内置 CF 移动优选** | 25 条 IP + 17 条 CIDR 写死在代码；空 ADD / 本地随机默认用它，不依赖在线优选域名 |

### 关于 Cloudflare「错误率」

仪表盘 **Errors** 主要统计 **未捕获异常 / 超限**，不是 HTTP 4xx/5xx。建连失败若 `throw`，会抬高错误率，但客户端侧只是断线。收敛后失败应表现为静默关 WS，错误率应明显下降；业务成功率仍取决于优选线路质量。

## Magic 客户端（Bettbox `lib/state.dart`）改动

`patchRawConfig` 对订阅节点缺省补齐（不覆盖显式配置）：

- TLS 节点：`client-fingerprint: chrome`
- VLESS/VMess + WS：`udp` / `xudp`
- 路径含 `ed=` 时写入 `ws-opts.max-early-data` + `Sec-WebSocket-Protocol`

## 面板建议

1. 传输：**WebSocket**  
2. **启用 0-RTT**：开（旧配置若从未写过该字段，部署新 Worker 后会默认视为开）  
3. 指纹：chrome  
4. 跑一次 **优选订阅生成** → Magic 更新订阅  

## 可选环境变量（均非必须）

`PRELOAD_RACE_DIAL` / `TCP_CONCURRENT_DIAL` / `PROXY_CONCURRENT_DIAL` / `CONNECT_TIMEOUT_MS` / `DEBUG`

**不需要 `PROXYIP`。**

## 部署顺序

1. 部署本仓库 `_worker.js`  
2. 确认面板 0-RTT + WS  
3. 重新生成优选订阅  
4. 使用已改 `patchRawConfig` 的 Magic 客户端刷新配置  

## 边界

优选线路质量仍是测速上限主因；两侧优化主要改善 **建连、DNS、WS 首包、指纹/UDP 完整性**。
