# WebSocket 优先优化说明（fork: optimize-ws）

基于实测：**WebSocket 最稳、测速最快**。默认传输仍为 `ws`。

## 你的使用方式（无需 `PROXYIP` 环境变量）

部署后用后台 **【优选订阅生成】** → Magic 更新订阅即可。

## Worker（`_worker.js`）改动

| 项 | 作用 |
|----|------|
| 同主机只拨一路 | 无预加载多 IP 时不再对同一 hostname 空并发 |
| 反代解析缓存 45s | 减少重复 DoH |
| 预加载竞速拨号**默认关** | 需要时设 `PRELOAD_RACE_DIAL=1` |
| 反代并发默认 2 | 路径内反代更快试通 |
| 建连超时 1200ms 可配 | 直连失败更快回落 |
| DNS UDP 三路竞速 | 隧道内 DNS 更稳 |
| 旧配置缺省补齐 | 未设置时默认开 **0-RTT**、**UDP/XUDP**、指纹 chrome、传输 ws |
| Clash 热补丁增强 | 给 WS 节点补 `client-fingerprint` / `udp`/`xudp` / `max-early-data` |
| **错误率收敛** | 顶层 try/catch；建连/握手失败关连接不 `throw` |
| **管理后台在线优选** | 代理 edt-pages 时去掉上游写死的 `disabled` |

### 已回退（会导致全量 Timeout）

曾尝试的 **直连/反代对冲竞速**、**提前回 VLESS 头**、**DoH 改写隧道 DNS** 存在竞态/兼容问题，已回退。建连仍为：**先直连，失败再反代**。

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

`PRELOAD_RACE_DIAL` / `TCP_CONCURRENT_DIAL` / `PROXY_CONCURRENT_DIAL` / `CONNECT_TIMEOUT_MS` / `DEBUG`

**不需要 `PROXYIP`。**

## 部署顺序

1. 部署本仓库 `_worker.js`（版本串含 `wsfix`）
2. 确认面板 0-RTT + WS
3. 重新生成优选订阅
4. Magic 刷新配置后测延迟

## 边界

优选入口 IP 质量仍是测速上限主因。
