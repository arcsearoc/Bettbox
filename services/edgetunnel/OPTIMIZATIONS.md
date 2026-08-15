# WebSocket 优先优化说明（fork: optimize-ws）

基于实测：**WebSocket 最稳、测速最快**。默认传输仍为 `ws`。

## 你的使用方式（无需 `PROXYIP` 环境变量）

部署后用后台 **【优选订阅生成】** → Magic 更新订阅即可。

## Worker（`_worker.js`）改动

| 项 | 作用 |
|----|------|
| 预加载竞速拨号默认开 | 域名多 IP 竞速建连 |
| 反代并发默认 2 | 路径内反代更快试通 |
| 建连超时 1200ms 可配 | 直连失败更快回落 |
| DNS UDP 三路竞速 | 隧道内 DNS 更稳 |
| 旧配置缺省补齐 | 未设置时默认开 **0-RTT**、**UDP/XUDP**、指纹 chrome、传输 ws |
| Clash 热补丁增强 | 给 WS 节点补 `client-fingerprint` / `udp`/`xudp` / `max-early-data`（不覆盖已有值） |

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

---

## 在线优选 / 错误率优化（2026-08-13）

针对「优选IP 域名（如 cm优选）在本地被阻断」、以及监控里订阅拉取错误率偏高的问题。

### 一、优选IP 获取全部走服务器（Worker）中转

后台【在线优选】UI 请改为调用 Worker 端点，由服务器代为请求，浏览器不再直连被阻断的域名：

```
GET /admin/getADDAPI?url=<优选API地址>&port=443
```

返回：

```json
{ "success": true, "source": "server", "count": N, "data": ["ip:port#备注", ...] }
```

- `source: "server"` 表示数据由 Worker 服务器获取（绕过本地阻断）。
- 失败时 `success: false`，`msg` 含失败原因。

### 二、`_worker.js` 后端改动（降错误率）

| 项 | 作用 |
|----|------|
| `获取优选订阅生成器数据` 加 `AbortController` 超时 + 1 次重试 | 优选域名不可达时快速失败，不再长时间挂住 |
| `请求优选API` 的 `sub://` 分支统一应用超时 | 此前只有普通 URL 分支有超时，`sub://` 会挂死 |
| `请求优选API` 入口加 **60s 实例级缓存** | 同一组优选API 在 60s 内只请求一次，大幅减少对不稳定域名的重复子请求（降错误率最直接） |
| 订阅转换后端 fetch 加 **5s 超时** | 转换后端不可达时快速返回提示，不拖死整个订阅请求 |
| `admin/getADDAPI` 返回 `source`/`count` 字段 | 便于前端区分数据来源、确认是否命中 |

### 三、诊断结论

经核查，错误率主要来自 **订阅生成 / 优选IP 拉取路径**（优选域名被阻断导致 fetch 挂死/失败），而非 WS 代理路径——WS 的 101 响应已提前返回，代理异常都被 `.catch` 静默关闭，不会变成 5xx。本次改动集中在拉取路径的超时、重试与缓存。

---

## 内置 CF 三网优选 CIDR + 默认联通（2026-08-14）

针对「内置 CF 移动优选 IP」与作者家用联通不匹配、以及 `raw.githubusercontent.com` 被阻断时优选 IP 回退到单一默认段的问题。

### 改动

| 项 | 作用 |
|----|------|
| **内置三网 CF-CIDR 常量**（`内置CF优选CIDR`） | 把 ct/cu/cmcc/cf 四组 CIDR 直接写进 `_worker.js`，raw 域名被阻断时也能正常生成优选 IP（不再回退到单一 `104.16.0.0/13`） |
| **默认运营商改为联通**（`默认运营商 = 'cu'`） | 未识别出运营商时默认用 `CF联通优选`，而非 `CF官方优选`。ASN 自动识别仍保留（联通 ASN → cu，电信 → ct，移动 → cmcc） |
| 运行时拉取改为「覆盖更新」 | 先用内置 CIDR 生成，同时尝试 3s 超时拉取最新数据覆盖；拉取失败不影响（沿用内置） |
| 大 CIDR 段随机精度修复 | hostBits ≥ 20 时（如 `/13`）用两次随机避免精度丢失 |

### 数据来源

内置 CIDR 取自 `cmliu/cmliu` 仓库 `CF-CIDR/{ct,cu,cmcc}.txt`（项目原作者维护），联通段补充了 CF 全网 anycast 优质段（`104.16.0.0/13`、`172.64.0.0/13`、`162.159.0.0/16`）。

### 强制指定运营商

订阅/优选请求仍可用 `cnIspCode` 参数强制指定：`?cnIspCode=cu`（联通）/ `ct`（电信）/ `cmcc`（移动）/ `cf`（官方）。

### 本地压测验证

- 默认订阅节点备注 = `CF联通优选` ✓
- `cnIspCode=ct/cmcc/cf` 分别生成对应运营商节点，IP 落在对应内置 CIDR 段 ✓
- 错误率 0.00%，订阅本地生成 RPS ~75 ✓

---

## 优选 IP 三网合并（2026-08-14）

在上一节基础上进一步**取消三网分流**：优选 IP 不再区分运营商。

### 改动

| 项 | 说明 |
|----|------|
| 新增 `三网合并CIDR池` 常量 | cu + ct + cmcc + cf 全部段去重合并为一个池，`生成随机IP` 统一从中随机 |
| 节点备注统一为 `CF优选N` | 不再有 `CF联通优选/CF电信优选/CF移动优选` 之分 |
| 远程拉取改用汇总文件 | 只拉 `CF-CIDR.txt`（三网汇总），不再按运营商拉分文件 |
| 移除 `cnIspCode` 分流 | `生成随机IP` 不再读取该参数；订阅转换回调 URL 中的 `&cnIspCode=` 一并移除 |
| `识别运营商` 保留 | 仍用于移动网络下自动降低 TCP 并发拨号数（与优选池无关） |

### 效果

- 不管访客是哪家运营商，优选节点都从三网全量段随机生成，通用性更好（换宽带/多设备共享订阅不再受运营商匹配限制）。
- 内置合并池保证 raw 域名被阻断时依然可用。

### 验证

- `/admin/ADD.txt` 默认输出 `#CF优选1~N`，IP 跨原三网段混合（104.26.x / 104.19.x / 172.66.x / 198.41.x）✓
- 传 `cnIspCode=ct` 同样输出混合池（参数已忽略）✓
- 压测错误率 0.00%，无性能回退 ✓

---

## 修复 WS 隧道 outcome:"exception"（2026-08-15）

线上日志：`GET /` + `upgrade: websocket`（Go 客户端带 base64url 早期数据，如 Cursor 流量），`outcome: "exception"`、cpuTime 17ms、wallTime 777ms。

### 定位过程（本地复现）

用日志里原始的 `sec-websocket-protocol` 早期数据 + VLESS 首包打本地 wrangler dev，稳定复现 `Uncaught Error: Network connection lost.`（无堆栈 = runtime 包装的未观察 promise 拒绝）。插桩追踪确认调用链：直连 → 下行无数据 retry → 反代重拨 → 第二次 connectStreams → 未观察的 rejection 逃逸。

### 根因

拨号失败/连接异常断开时，socket 的原生 `opened`/`closed` promise 会以 `Network connection lost` 拒绝。若该 socket 尚未进入 `connectStreams`（那里才挂 `closed` 的 catch），例如 `写入首包` 失败即抛、socket 被关闭的路径，这些 rejection 无人观察 → CF 记为 `outcome:"exception"`。实测该逃逸与**预加载竞速拨号**（默认开）强相关：竞速解析出的 IP 拨号失败时必现。

### 修复（`_worker.js`）

| 项 | 作用 |
|----|------|
| `创建请求TCP连接器` 统一预观察 `opened`/`closed` | 所有 socket 创建即挂兜底 catch，拨号失败/异常断开的 rejection 不再逃逸（不影响后续正常使用，多处观察者并存无害） |
| 裸调用 `connectStreams(...)`（木马 UDP 反代路径）补 `.catch` | 该路径下行异常不再逃逸 |
| WS 升级分支（101 返回前）整体 try/catch | 建连阶段异常返回 502，而非 outcome:"exception" |

### 验证

- 同一复现请求连跑 5 次：独立 Uncaught **0 次**（修复前每次必现/偶现）✓
- serverSock error 事件路径本就有处理（`处理WS显式传输错误` → 干净关闭），保持不变 ✓
- 完整压测错误率 0.00%，订阅 RPS 无回退 ✓

### 附：internal error 缓解（拨号切换 cloudflare:sockets）

线上另一类错误 `internal error; reference = ...` 是 workerd 运行时内部错误，常见诱因是出站 TCP 绑定在入站请求上下文（`request.fetcher.connect`）后、WS 请求上下文异常销毁。

改动：

| 项 | 说明 |
|----|------|
| 模块级动态 `import("cloudflare:sockets")`，失败置 null | 不支持的环境不会启动失败 |
| `创建请求TCP连接器` 优先 `cloudflare:sockets` 的 `connect`，回退 `request.fetcher.connect` | 出站连接与入站请求上下文解耦，降低 runtime internal error 概率 |

验证：本地 echo 服务器端到端测试——VLESS 隧道 101 → 上行 64B → 下行回显 66B（2B 响应头 + 64B 数据）内容正确；原异常复现 5 次独立 Uncaught 仍为 0；订阅路径正常。


