# edgetunnel（VLESS / CF Workers）

本目录为 [cmliu/edgetunnel](https://github.com/cmliu/edgetunnel) 的本地整合副本，含 WebSocket 优先优化（见 [OPTIMIZATIONS.md](./OPTIMIZATIONS.md)）。

## 用法

1. 将 `_worker.js` 部署到 Cloudflare Workers / Pages  
2. 绑定 KV（变量名 `KV`），设置 `ADMIN` 密码  
3. 后台用 **优选订阅生成**，在 Magic 客户端更新订阅  

**不需要**环境变量 `PROXYIP`（本仓库默认按优选订阅流程使用）。

可选环境变量见根目录上游 README，以及本目录 `OPTIMIZATIONS.md`。

## 与 Magic 客户端

Magic（本 monorepo `lib/`）会在 `patchRawConfig` 中为 VLESS/WS 缺省补齐：

- `client-fingerprint: chrome`
- `udp` / `xudp`
- 路径含 `ed=` 时的 `ws-opts` early-data
