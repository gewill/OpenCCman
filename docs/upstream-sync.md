# OpenCC 上游同步

本指南是两个仓库共用的协调器操作入口。引擎源码、资源生成及兼容性要求见 [SwiftyOpenCC 维护指南](https://github.com/gewill/SwiftyOpenCC/blob/master/docs/upstream-sync.md)。

## 仓库职责与合并顺序

| 位置 | 职责 | 更新方式 |
| --- | --- | --- |
| `ddddxxx/SwiftyOpenCC/master` | Swift wrapper 上游 | 合并尚未包含的上游提交，保留 fork 补丁 |
| `BYVoid/OpenCC` 正式 Release | OpenCC 核心与词库来源 | 同步锁定版本的源码、配置、生成词典和测试语料 |
| [SwiftyOpenCC/master](https://github.com/gewill/SwiftyOpenCC/tree/master) | 兼容桥接、资源与引擎 CI | 第一层 PR，使用 merge commit 合并 |
| [OpenCCman/main](https://github.com/gewill/OpenCCman/tree/main) | 协调器、配置、定时工作流 | 自动化改动单独向 main 提 PR |
| [OpenCCman/build](https://github.com/gewill/OpenCCman/tree/build) | 应用代码、精确依赖与应用 CI | 第二层 PR，采用已合并且验证成功的 fork SHA |

```text
ddddxxx/SwiftyOpenCC 提交 + BYVoid/OpenCC 正式版
  → SwiftyOpenCC/master 同步 PR
  → 维护者以 merge commit 合并，等待合并后 OpenCC Compatibility 成功
  → OpenCCman/build 精确 revision PR
  → 维护者审查 App Regression 后合并
```

协调器只开 PR，不自动合并；所有候选都在临时 checkout 准备，不切换或重置开发者工作区。不要为了同步依赖把 main 的旧应用代码合入 build。

## 日常操作

[Sync OpenCC](https://github.com/gewill/OpenCCman/actions/workflows/sync-opencc.yml) 每周一 UTC 01:17（台北 09:17）检查，也可在 Actions 页面选择 **Run workflow → main**。每次只推进一层；fork 仍待审或 CI 未通过时，应用层等待。fork 合并且 CI 通过后，重新运行或等待下一次周检。

查看运行摘要中的 `fork`／`app` 状态和 PR 链接；失败时下载 `detection`／`candidate` artifact（保留 7 天），先看 `report.md`、`failure.json` 和 `prepare.log`。若失败发生在准备之前，以 job 日志和已生成的检测 JSON 为准。

本地从 **OpenCCman/main 的 checkout** 执行下节命令；SwiftyOpenCC 不另设定时发布器。分支、来源和检查名以 [协调器配置](../scripts/upstream-sync.json) 为准，运行步骤以 [工作流](../.github/workflows/sync-opencc.yml) 为准。

## 初次配置与恢复

以下用于新环境配置或恢复现有集成；日常同步不需要重新创建 App 或私钥。

1. 先人工合并 SwiftyOpenCC 的官方 `SimpleConverter`／JSON 配置迁移，使 fork/master 包含 `scripts/update-opencc-resources.py`、`Sources/OpenCC/Resources/manifest.json`（`schemaVersion=1`、`bridgeVersion=1`）与 `OpenCC Compatibility` CI。旧桥接不能仅替换子模块来升级。
2. 让协调器进入 OpenCCman/main；让应用回归脚本与 `App Regression` CI 进入 build。两个 CI 的 **job 名称**也必须分别为 `OpenCC Compatibility`、`App Regression`。fork CI 必须测试 `push: master`，因为应用推广检查的是合并后的精确 SHA。
3. 创建专用 GitHub App，仅安装至 `gewill/OpenCCman` 与 `gewill/SwiftyOpenCC`，仓库权限只选 **Contents: read/write、Pull requests: read/write**。不请求 Actions、Workflows、Administration 或自动批准权限。
4. 在 OpenCCman 设置变量 `OPENCC_SYNC_APP_ID`、secret `OPENCC_SYNC_APP_PRIVATE_KEY`。这把私钥只传给发布 job；每次令牌仅允许写入当前目标仓库，任务结束撤销。App 私钥不进入检测／构建 job。公开来源与 check 信息使用当前 job 的只读 `GITHUB_TOKEN` 认证读取；发布步骤以 `GH_READ_TOKEN` 单独传入该读令牌，`GH_TOKEN` 中的 App 写令牌只供变更 API／Git push 使用，未扩大 App 权限。
5. 给 fork/master、App/build 配置分支保护：要求 PR、相应 CI 成功、禁止 force-push。机器人不加入绕过列表。个人仓库单人维护时不强制另一位 reviewer，以免唯一维护者无法合并自己的人工 PR。

GitHub 定时任务只从默认分支运行；公开仓库 60 天无活动会停用 schedule，定时运行也可能延迟，因此它不是可靠的定时提醒服务。[官方事件说明](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule)

`GITHUB_TOKEN` 创建／更新 PR 所触发的 CI 当前需要人工批准，push 不触发后续 CI。本方案用 GitHub App 令牌发布候选，让普通 PR CI 自动启动，同时保留人工 merge。[令牌触发规则](https://docs.github.com/en/actions/concepts/security/github_token)、[App 权限](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/choosing-permissions-for-a-github-app)

## 本地命令与两层流程

需要 Python 3、Git、已登录的 `gh`；准备候选还需要 macOS、Xcode 命令行工具、Swift、CMake，以及 fork 资源脚本声明的构建工具。执行位置任意，脚本配置相对脚本定位。

本地发布通过命令专用 `gh auth git-credential` 使用 `gh` 登录、`GH_TOKEN` 或 `GITHUB_TOKEN`，不改全局 Git 凭证设置。准备进程会移除显式 token 环境变量；本地运行仍可访问开发者原有 Git／钥匙串配置，它不是无凭证沙箱。Actions 的写入私钥和令牌只存在于独立发布 job。

GET 优先使用 `GH_READ_TOKEN`，未设置时复用 `gh` 的现有认证。公开 API 不再匿名请求，避免共享 runner 出口的每小时 60 次匿名限额。`Upstream Coordinator Tests` 会实际用只读 job token 验证两个仓库的 checks API 可读；403／限额错误仍返回退出码 5，不降级为匿名请求或解释为没有 CI。[GitHub API 限额](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)、[公开 Checks API 权限](https://docs.github.com/en/rest/checks/runs#list-check-runs-for-a-git-reference)

```sh
python3 scripts/sync-upstream.py check --stage fork
python3 scripts/sync-upstream.py prepare --stage fork
python3 scripts/sync-upstream.py pr --stage fork

# fork 合并且合并后的 CI 成功后，再处理应用层
python3 scripts/sync-upstream.py check --stage app
python3 scripts/sync-upstream.py pr --stage app
```

- `check` 读取远端状态；`prepare` 在独立临时 checkout 生成、测试候选，不 push。未传 `--output` 时创建持久临时目录，JSON 的 `artifact_directory` 返回路径。
- 本地 `pr` 先准备、验证，然后发布。复用已验证产物可执行 `pr --stage fork --prepared /绝对路径/产物目录`；此路径完全不运行候选代码。Actions 强制使用此模式，把验证和写权限隔离。
- 一次只推进一层。fork PR 人工 **Create a merge commit** 合入 master 后，再手动运行 workflow，或等下一次周检，才生成 App PR。也可把上述命令的 `--stage fork` 换为 `--stage app`。
- App 只采用 fork/master 已合入且精确 SHA 上 `OpenCC Compatibility` 成功的版本；App/build 当前精确 SHA 也必须已有成功的 `App Regression`，发布前再核对两项。修改工程 requirement 为 revision，并更新 `Package.resolved` 中该 pin。执行 `xcodebuild -resolvePackageDependencies -skipPackageUpdates` 校验依赖解析，允许 Xcode 管理 `originHash`，但其他 pin／锁文件字段有任何变化立即失败，不提交。

应用层按 fork/master 的完整提交 SHA 判断更新，不按引擎版本号或文件类型过滤。因此 fork 上仅文档变更的合并，待 CI 通过后也可能产生新的应用 revision PR；这是当前实现的行为。

## 同步规则与产物

[scripts/upstream-sync.json](../scripts/upstream-sync.json) 定义两个目标、来源、检查名和回滚忽略清单。OpenCC 只选择公开正式 Release 中最大的 `ver.X.Y.Z`，排除 draft／prerelease；锁完整 SHA，拒绝已接纳 tag 改指向、降级和主版本自动跨越。wrapper 保持跟踪 `ddddxxx/SwiftyOpenCC/master`，保留现 fork 的本地修复。若 wrapper 涉及 workflow 改动，停止并交人工合并，不给机器人 `Workflows:write`。[Release API](https://docs.github.com/en/rest/releases/releases)、[fork 同步](https://docs.github.com/en/pull-requests/how-tos/work-with-forks/syncing-a-fork)

每层最多一条待审 PR。候选标识由来源 SHA 确定，分支固定为 `codex/sync-fork-<id>` 或 `codex/sync-app-<id>`。同候选重试复用 PR；人工关闭但未合并的候选不自动重开；另一候选到达时有旧 PR 待审则等待。出现人工修改、远端 base 变化、合并冲突或非目标依赖漂移时停止，不覆盖或 force-push。

相同来源与 base 的重新准备使用固定提交元数据，因此 push 成功、PR 创建失败后可以直接重跑并恢复。若在这两步之间 base 已前进，新候选与遗留分支必然不同，自动化会明确停止：先审查报告中的旧分支，确认没有 PR 或人工修改后由维护者删除该孤立分支，再重新运行；不能用 force-push 跳过这个检查。

成功的 `prepare` 输出 `candidate.json`、`candidate.bundle`、`diff.patch`、`report.md`、`prepare.log`。发布再次核对 base、来源 SHA、bundle checksum 和变更范围，并从 bundle 推送经过验证的那个 commit。失败时保留 `failure.json`、报告、命令日志和可获得的 diff，随后删除隔离 checkout；失败候选不能发布。

stdout 只输出一条 JSON；详细日志在 stderr／产物内。`status` 为 `noop`、`changed`、`waiting`、`blocked`、`error`。退出码：`0` 正常（包括无变化和等待），`2` 参数／迁移前置条件，`3` 冲突／策略阻断，`4` 验证失败，`5` 网络／认证失败。网络失败不解释为“没有更新”。

无变化只用 Ubuntu；有候选才使用一个固定 macos-15 job。fork 执行资源生成、`--check`、`swift test`，App 执行锁定解析与 core／quota／pasteboard 回归；不启动模拟器或完整 App build。两仓库目前公开，标准 GitHub-hosted runner 免费，仍限制超时和并发以节省等待。[计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

## 常见状态与恢复

| 状态或问题 | 处理方式 |
| --- | --- |
| `noop` | 已同步，或候选已被配置忽略；查看 `reason` 区分 |
| `waiting` | 查看待审 PR 或缺失的精确 SHA 检查；等待解决后再运行 |
| 冲突、上游 workflow 改动、主版本升级、移动 tag | 审查来源与冲突路径，必要时单独做兼容迁移 PR；不要强制覆盖 |
| 资源生成、转换回归或依赖解析失败 | 查看候选日志并修复；不能跳过验证发布 |
| 403／认证／限额错误 | 查看失败 job 使用的是只读令牌还是发布 App 令牌，核对安装范围、变量与 secret；恢复后重试 |
| base 或候选分支发生变化 | 重新准备；存在人工改动时先审查，不覆盖旧分支 |

## 回滚与维护

合并前直接关闭不接受的 PR。合并后先开 App PR 恢复原 revision；需要时再通过 Revert PR 撤销整个 fork 同步 merge（子模块、配置、字典及 manifest 一起恢复），不重写历史。把报告中的候选 id 加入 main 配置的 `ignoredCandidates.fork`／`ignoredCandidates.app`，防止被撤回的候选再次提出。新来源 SHA 会生成新 id，不受旧候选忽略影响。[GitHub 回滚 PR](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/reverting-a-pull-request)

协调器源码／配置变更走 main PR，`Upstream Coordinator Tests` 在 Ubuntu 自动跑本地 Git 与假 GitHub 集成回归。手动复现：

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

覆盖正常候选、PR 重试／POST 不确定结果、人工拒绝、同名外部 fork、冲突、移动 tag、降级／主版本、base 并发变化、bundle 篡改、测试失败产物、来源门禁、非目标 pin 漂移及验证进程无 token。测试只推送临时本地 fixture 仓库，不访问真实写入 API。

## 首次运行记录（2026-09-12）

首次接通时修复了共享 runner 匿名 API 限额，以及 SwiftPM 从 Git revision 读取包清单时无法访问相邻资源文件的问题。当前流程使用认证读取；引擎清单不再在求值时读取资源 JSON。

- [协调器准备与发布成功](https://github.com/gewill/OpenCCman/actions/runs/34683913795)，通过 GitHub App 创建 [应用依赖 PR #5](https://github.com/gewill/OpenCCman/pull/5)，PR CI 自动启动。
- PR #5 将应用固定到已通过 CI 的 fork `eacb73dcb28c26e7cc5d8d9cb405e88fa2d59b13`（OpenCC 1.4.2），其余 14 个依赖保持不变；[合并后应用 CI](https://github.com/gewill/OpenCCman/actions/runs/34684262879) 成功。
- 当时两层 `check` 均返回 `noop`。以上是该次运行证据；以后升级仍须通过各自候选的检查，当前版本以工程锁文件及引擎 manifest 为准。
