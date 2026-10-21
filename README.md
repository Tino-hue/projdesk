# ProjDesk — 一定义，四张图

> **纯浏览器运行的「模型描述 → 多目标投影」工作台**
> 用表单声明一个业务对象，页面同时生成并实时刷新：JSON Schema / OpenAPI / SQL DDL / GraphQL SDL。

**与 Depsight 的差异**：Depsight 做依赖分析与供应链诊断；ProjDesk 做元数据/契约层的多目标投影生成。两者功能零重叠，不是同一作品的延续。

---

## 核心 Job

「当我要声明一个业务对象时，帮我一次说清楚，并立刻看到它在四个世界里长什么样；改一处约束，四个产物一起变；哪个目标装不下，要诚实告诉我原因。」

### 产品三原则

1. **一份真相，四种投影** — 投影算法全部在 MoonBit 内核，前端禁止自己实现 schema/sql/sdl 生成
2. **诚实投影** — 某目标放不下的约束必须显示「已丢弃 + 原因」，禁止悄悄美化或丢弃
3. **演示优先** — 任意编辑后四栏同步刷新要流畅

---

## 架构

```
┌─────────────────────────────────────────────────────┐
│                    Web 前端 (React)                  │
│   表单编辑器 ──→ ABI 序列化 ──→ 四栏展示 + 丢弃报告   │
│                  (TypeScript)                        │
└────────────────────────┬────────────────────────────┘
                         │ JSON string (js-string builtins)
                         ▼
┌─────────────────────────────────────────────────────┐
│              MoonBit 内核 (wasm-gc)                  │
│                                                     │
│  parse_input ──→ moonmodel.Model ──→ project_all     │
│                                      │              │
│                    ┌─────────────────┼──────────┐   │
│                    ▼        ▼        ▼          ▼   │
│               JSON Schema  OpenAPI  SQL DDL  SDL    │
│               + drops      + drops  + drops  +drops │
│                                                     │
│  依赖：moonbitstack/moonmodel (json/open/sql/sdl)    │
└─────────────────────────────────────────────────────┘
```

## 快速开始

### 前置要求

- [MoonBit 工具链](https://www.moonbitlang.cn/)
- Node.js ≥ 18

### 一键构建

```bash
make all
```

### 分步执行

```bash
# 1. 编译 MoonBit 内核
cd moonbit
moon build --target wasm-gc --release
# 产物: _build/wasm-gc/release/build/main/main.wasm

# 2. 运行内核契约测试
moon test

# 3. 构建前端
cd ../web
npm install
npm run build

# 4. 运行前端测试
npm run test

# 5. 本地预览
npm run dev
# 打开 http://127.0.0.1:5173
```

---

## 与 moonmodel 的关系

ProjDesk 的投影能力完全由 [moonbitstack/moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel) 提供：

| 子包 | 功能 |
|------|------|
| `moonmodel` | Model / Field / Check / Type 核心类型 |
| `moonmodel/json` | JSON Schema 2020-12 投影 |
| `moonmodel/open` | OpenAPI Schema Object 投影 (2.0/3.0/3.1) |
| `moonmodel/sql` | SQL DDL 投影 (SQLite/Postgres/MySQL) |
| `moonmodel/sdl` | GraphQL SDL 投影 |

ProjDesk 在其上增加了：
- **丢弃原因分析**：逐约束检查各目标能否承载，输出结构化 DropReason
- **WASM ABI**：JSON 字符串进/出的浏览器调用接口
- **预设样例**：User / Order / Address

> **兼容性说明**：moonmodel 0.1.0 使用了已废弃的 `Int32` 类型（当前 MoonBit 中为 `Int`）。构建时对 `.mooncakes` 缓存源码做了最小 `Int32→Int` 补丁，不改变业务逻辑。

---

## MoonBit 深度点

| 技术点 | 用在哪 |
|--------|--------|
| **ADT / enum** | `Type` 的 13 种类型变体（含递归 `List(Type)` / `Dict(Type)` / `Nest(Model)`） |
| **模式匹配** | `parse_type` / `type_to_json` 的双向映射 |
| **`pub(all)` 结构体** | `DropReason` / `ProjectionResult` 跨包使用 |
| **`raise` + `try/catch`** | JSON 解析错误处理 |
| **wasm-gc + js-string** | String 参数零编解码直传 JS |
| **`#export_name`** | 稳定 ABI 导出 |
| **契约测试** | 21 个 `moon test` 锁住 required×nullable×四目标语义 |

---

## 已知限制

- OpenAPI 版本固定 3.0（V1 可扩展 2.0/3.1 切换）
- SQL 方言固定 Postgres（V1 可扩展 SQLite/MySQL）
- GraphQL 的 `options` 不会自动生成 enum 类型
- 多模型 Ref 图 / URL 分享暂未实现

---

## 验收清单

### A. 功能
- [x] 打开页面 10 秒内可用预设样例，四栏立刻有输出
- [x] 修改字段/约束后，四栏同步正确更新
- [x] required 与 nullable 独立，且四个目标语义正确
- [x] 丢弃报告真实反映各目标无法承载的约束，有原因
- [x] 可复制/导出四种产物
- [x] 前端不包含任何 schema/sql/sdl 生成算法

### B. 质量
- [x] moon test 全绿（21 个契约测试）
- [x] web 侧测试全绿（5 个 ABI 测试）
- [x] npm run build 通过
- [x] make all 一键完成全链路

### C. 仓库
- [x] README.md（定位、架构、步骤、限制）
- [x] DEMO.md（3 分钟演示脚本）
- [x] LICENSE (MIT)
- [x] Makefile

### E. 合规
- [x] 与 Depsight 零功能重叠
- [x] 不依赖旧 FractMoon/Depsight 业务代码

---

## License

MIT
