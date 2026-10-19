# Whale Alive 在本机的安装说明

本机（Desktop 版 DSH，profile `desktop`）安装情况与仓库自带的 `Connect-DSH.cmd` 不同，原因见下。以后按本文件操作即可。

## 已安装的内容

| 位置 | 内容 |
| --- | --- |
| `default-workspace\WhaleAlive\` | 仓库源码（git clone，分支 main） |
| `WhaleAlive\prototype\bin\Release\net9.0-windows\WhaleAlive.exe` | 已编译的桌宠本体 |
| `WhaleAlive\node_modules\` | MCP 服务依赖（`@modelcontextprotocol/sdk` 等，pnpm hoisted 安装） |
| `%USERPROFILE%\.dsh\profiles\desktop\cordis.patch.yml` | `whale-alive-state` + `whale-alive-mcp` 两条 insert 条目 |
| `default-workspace\.tools\dotnet\` | 本地安装的 .NET 9.0.101 SDK（未改系统 PATH、未装全局 SDK） |

## 日常启动

1. 启动桌宠（DSH 在运行也可以随时启动）：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "...\default-workspace\WhaleAlive\Start-WhaleAlive.ps1"
   ```

   或直接双击 `Start-WhaleAlive.cmd`。启动后只显示桌宠；右键桌宠弹出菜单，「设置」打开主窗口。
2. 首次使用如需搬动真实图标、窗口或鼠标，须在「设置 → 更多行为与权限」里**每次启动后手动开启**对应权限。
3. 退出请用菜单「退出桌宠」。

## DSH 接入

- `cordis.patch.yml` 已注册 MCP 服务（`serverName: whale_alive`），模型侧工具名为 `mcp__whale_alive__<工具>`，共 15 个。
- 启动命令使用本机 DSH 自带的 Node：`command: "D:/deepseek/DeepSeek Harness.exe"` + `env: ELECTRON_RUN_AS_NODE: "1"`。**本机没有 Node.js/npm**，如以后另装 Node，可改回 `node`。
- `whale-alive-state` 订阅 DSH 的 `session/event` 与 `agent/request-error`，只转发思考/执行/等待确认/完成/异常等阶段，不转发提示词、聊天内容、路径或凭据。

## 与仓库 `Connect-DSH.cmd` 的差异（不要直接运行它）

1. 它要求 **DSH 源码仓库 + pnpm**，本机是 Desktop 安装版，不适用。
2. 它会用 `--patch` overlay **另起一个 `dsh web`**，端口与会话都不同，会打断当前 Desktop 界面。
3. 它会在**父目录**（`Documents\deepseek-harness`，即 `/` 级工作区根）执行 `npm ci`/`git clone`，污染共享工作区。
4. 它的 overlay 里 `command: node` 在本机不存在。

本安装改为直接在 profile 的 `cordis.patch.yml` 注册，等效于其 overlay 内容，但不影响端口和登录状态。

## 安装过程中踩到并已解决的问题

- **系统 schannel 不可用**（`SEC_E_NO_CREDENTIALS`）：git、curl、PowerShell、dotnet 的 HTTPS 全部失败；`git clone` 需 `-c http.sslBackend=openssl`，其余下载通过 DSH 自带 Electron Node（OpenSSL）完成。
- **无 .NET SDK**：只有运行时。SDK 装在 `.tools\dotnet`，编译时需设置 `DOTNET_CLI_HOME`/`APPDATA`/`NUGET_PACKAGES` 指向 `.tools` 下（见下方命令）。
- **NuGet 无法联网**：`Microsoft.Windows.SDK.NET.Ref` 包无法下载，已通过 Node 单独下载 **10.0.19041.54**（SDK 9.0.101 固定的版本）放入 `.tools\nuget-feed`，NuGet 源配置指向本地 feed。
- **pnpm 需要 hoisted + autoInstallPeers**：否则 SDK 的服务端 peer 依赖缺失；已在 `pnpm-workspace.yaml` 固定，并额外声明了 `ajv`、`ajv-formats`、`cross-spawn`、`zod-to-json-schema`。

## 重新编译桌宠

```powershell
$w = "C:\Users\YGO\Documents\deepseek-harness\default-workspace"
$env:APPDATA = "$w\.tools\appdata"
$env:LOCALAPPDATA = "$w\.tools\localappdata"
$env:DOTNET_CLI_HOME = "$w\.tools\clihome"
$env:NUGET_PACKAGES = "$w\.tools\nuget\packages"
& "$w\.tools\dotnet\dotnet.exe" build "$w\WhaleAlive\prototype\WhaleAlive.csproj" -c Release --nologo
```

## 卸载

1. 删除 `cordis.patch.yml` 里以 `# Whale Alive desktop pet` 开头的 `- insert:` 条目（或直接结束该段），重启 DSH。
2. 用菜单「退出桌宠」关闭桌宠，然后删除 `default-workspace\WhaleAlive`。
3. 删除 `default-workspace\.tools`（SDK 与 NuGet 缓存）、`default-workspace\.pnpm-store`，以及 `%LOCALAPPDATA%\WhaleAlive`（撤销历史与连接状态）。

## 已知限制

- 本 DSH 会话无法直接验证桌宠命名管道（沙箱禁止连接 `\\.\pipe\`），MCP 服务也因沙箱禁止带管道 stdio 的子进程而显示 `server is disconnected`；这两项在宿主进程内应正常工作。请在界面上点一下桌宠或让模型调用一次 `pet_status` 确认。
- 桌宠需在 DSH 之外手动启动；未启动时 MCP 工具可列出但调用会返回「请先启动 Whale Alive 桌宠」。
