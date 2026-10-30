ProjDesk：模型工程工作台（Model Engineering Workbench）

一、基本信息

项目名称：ProjDesk：模型工程工作台（Model Engineering Workbench）
参赛者：Tino-hue
联系方式：Micxry060912@hotmil.com
GitHub 仓库链接：https://github.com/Tino-hue/projdesk
项目方向：MoonBit 模型工程工具链 / 编译器基础设施
是否为移植项目：否

二、项目简介

ProjDesk 用 MoonBit 实现的是**模型定义的正确性工具链**：判定一个数据模型自身是否自洽、两个版本是否兼容、投影成契约时到底丢了什么、以及定义在整条工具链里是否无损。

核心是五个从零手写的 MoonBit 算法引擎，共 3691 行独立实现（整个内核 5613 行实现代码 + 3225 行测试代码），分别落在编译器前端、约束求解、版本演化、类型理论、形式化验证五个领域。

**与生态现有方案是互补，不是重复。** MoonBit 生态里已经有成熟的 Schema 库（Betterlol/moon_zod、QuietlyChan/moonschema、moonbitstack/moonschema、colmugx/json-schema 等）负责"把模型变成产物"，也有 schema diff / 迁移 / 兼容性工具（kath61105/moon_schema_plan、lyjttio/moon-data-contract、001-Elsa/moonpack、123123213weqw/moon_proto）负责"两个模型之间发生了什么"。ProjDesk 负责的是这些工具**不回答**的那一类问题：

- **模型本身自不自洽**（在任何数据存在之前判定）；
- **投影有没有悄悄丢信息**（逐字段逐约束量化）；
- **定义在工具链中是否无损**（往返逐字段比对）。

一句话概括边界：**生态负责"把模型变成产物"，ProjDesk 负责"证明这个模型是对的、这个产物是没丢的"。**

投影由开源库 moonmodel 承担（相当于编译器后端），JSON Schema / OpenAPI / SQL / GraphQL 四种格式我们不重复造。

三、核心功能范围

- **约束求解器（模型自洽性）**：区间冲突检测、蕴含与冗余分析、包含关系判定、固定点区间传播，输出类型化 Diagnosis 诊断（4 种：Conflict / Redundant / Warning / NoConstraints）；跨字段约束引用在建模层符号化解析（可前向或后向引用），检出未知引用与引用环路，并由区间传播引擎判定整个约束系统是否有解。
- **Round-trip 验证（定义无损）**：DSL → AST → DSL → AST 逐字段逐类型逐约束比对（含嵌套模型与全部 12 种约束），任何字段、类型或约束丢失都会被检出。
- **契约保真度（投影丢了什么）**：每个投影目标对承载不了的约束输出类型化丢弃报告（9 种 DropReason），逐条给出"丢了哪个字段的哪个约束、为什么"，而非静默丢弃。
- **迁移引擎**：结构化语义 diff（非文本对比），生成含破坏性变更标记的 ALTER TABLE，覆盖 Postgres/SQLite/MySQL。
- **等价检测**：类型加宽链（Int→Big→Real）、约束包含、嵌套模型与集合递归判定，分类为 Equivalent/SubtypeOf/SupertypeOf/Incompatible。
- **建模 DSL（仅作为上述能力的输入记法）**：手写词法分析器（Token ADT + 字符级扫描）、递归下降语法分析（AST + 行列号错误恢复）、AST 代码生成、AST 反向打印；支持行注释与块注释、嵌套模型、约束表达式（算术运算、内置函数 min/max/abs/ceil/floor）、跨字段约束引用（b: Int [over=a.least]，编译期求值）。
- **语义检查**：引用解析、自引用与环路检测。
- **属性测试框架**：自实现 xorshift64* PRNG 与随机模型生成器，在 100+ 随机模型上验证 12 条不变式（round-trip 保持性、DSL 完备性、diff 对称性等）。
- **工具链**：WASM ABI（11 导出）、CLI（gen/check/contrast/migrate/verify/init，contrast 并排展示投影与求解器的差异）、VS Code 插件、GitHub Action、Cloudflare Workers 后端。

全部 MoonBit 代码编译为 wasm-gc，浏览器内零服务端依赖运行。

四、为什么需要自定义建模记法（而不是直接用 Schema 库）

自定义记法存在的**唯一**理由，是让"约束求解器"这项能力在语言层面成为可能：

> **一个字段的约束可以引用另一个字段的约束** —— `b: Int [over=a.least]` 意思是"b 的下界来自 a 的下界"。

在 JSON Schema / Zod / moon_zod 的数据模型里，约束是挂在**单个字段上的常量**，没有地方安放"约束依赖约束"。因此：

- 生态的校验器（moon_zod 的 parse / safe_parse、moonschema 的 validator）判定的是**一个实例的值**合不合法 —— 需要先有数据；
- ProjDesk 的求解器判定的是**约束系统本身有没有解** —— 只需要模型，输入侧零数据。

最能说明差别的是一个**逐字段检查根本看不见**的冲突（仓库 `examples/CrossFieldConflict.dsl`）：

```
model Pair {
  low: Int [least=10]                // 单独看完全合法
  high: Int [over=low.least, most=5]  // 借用了 low 的下界之后才矛盾
}
```

`node cli/index.js contrast examples/CrossFieldConflict.dsl` 的实际输出：

```
Model: Pair

  low (Int)
    projection (moonmodel)  format: int32  minimum: 10
    solver (this project)   no findings
  high (Int)
    projection (moonmodel)  format: int32  maximum: 5  exclusiveMinimum: 10
    solver (this project)   [CONFLICT] high: over(10) >= most(5): impossible

The projection carries these through without saying anything about them.
```

投影把 `exclusiveMinimum: 10` 和 `maximum: 5` 一起写进 schema —— 一个值都不可能满足 —— 且不作任何提示；求解器先解析跨字段引用，再报出矛盾。按字段校验的库无法报告这个冲突：它只能拿着一个实例去判值。

另有 `least=0` 与 `most=-1` 的空区间、`Text [longest=3, options=[toollong]]` 的闭集越界、字段间互相引用构成的引用环路（`examples/Conflicting.dsl`）。

所以记法是为能力服务的，不是为了"再来一套建模"。模型数据结构与四种投影后端直接复用 moonmodel，运行时校验交给 moon_zod 这类库 —— 我们不重复造生态已有的部分。

五、与生态现有项目的边界

| 生态已有 | 它做什么 | ProjDesk 的关系 |
|---|---|---|
| Betterlol/moon_zod、QuietlyChan/moonschema、moonbitstack/moonschema、colmugx/json-schema | Schema 定义与**实例级**运行时校验；导出 JSON Schema | 互补：它们判"值合不合法"，我们判"模型自不自洽"（模型级、静态、数据无关） |
| kath61105/moon_schema_plan、lyjttio/moon-data-contract、001-Elsa/moonpack、123123213weqw/moon_proto | schema diff、迁移规划、破坏性变更门禁、新旧兼容性检查 | 互补：我们提供语义 diff 与兼容判定**引擎**（可被这类工具调用），并额外覆盖"契约投影的保真度"与"定义往返无损" |
| mizchi/codegen、moonbitstack/moonmodel | 通用 IR 与多目标 emitter（JSON Schema / Zod / …） | 部分重叠，见下 |
| wflixu/Orion | Schema DSL + CRUD + 迁移 SQL 生成 | 我们的迁移引擎面向**模型语义**（约束、引用、枚举值）而非数据库表结构 |

**主动交代重叠部分**：七种契约里 JSON Schema / OpenAPI / SQL / GraphQL 由 moonmodel 投影；TypeScript / Zod / Prisma 三个 emitter 是我们写的，**这部分与通用 codegen 库（如 mizchi/codegen）确实存在功能重叠，我们承认**。保留它们是因为它们必须理解模型语义（约束、引用、枚举值），而通用 IR 不表达这些；但三个 emitter 都实现同一个 Projector trait，生态一旦提供模型语义的 emitter 可直接替换掉。重叠面仅限这三个 emitter，五个引擎不在其中。

六、项目方向与通用性

面向所有需要管理数据模型的开发者。五个引擎对应通用算法领域，不绑定任何前端框架、后端语言或数据库。

能力不限于 Web：CLI 可在 CI 校验模型，VS Code 插件可在开发时即时检查，GitHub Action 可在 PR 中阻止破坏性变更合入。各入口共用同一份 WASM 内核，行为一致。

七、预期使用场景

**提交前模型自检**：模型里同时存在 least=10 与 most=5 时，求解器在建模阶段即报空区间 —— 早于任何一次数据写入。

**契约生成前的缺口盘点**：投影到七种目标时，逐字段列出每个目标承载不了的约束及原因，评审时能直接看到"这份契约在 TypeScript 端会丢什么"。

**模型演进与迁移**：改模型后自动输出变更清单与 ALTER TABLE 脚本，标注破坏性变更供评审。

**多版本兼容性判定**：两份模型是等价、子类型还是存在无法自动迁移的冲突。

**定义正确性回归**：CI 中运行 Round-trip 验证，确认定义再生成后无损。

八、拟实现的核心功能

1. 五个 MoonBit 算法引擎 + 属性测试框架（12 条不变式、7 项性能基准）
2. 七种契约投影 + 类型化丢弃诊断（9 种 DropReason）
3. 浏览器工作台：模型编辑器（拖拽/搜索/暗色）、关系图、约束诊断、迁移预览、版本 Diff、Engine Playground（6 个引擎页签）
4. WASM ABI 11 导出
5. CLI（gen/check/contrast/migrate/verify/init）、VS Code 插件、GitHub Action、Workers 后端
6. 测试与 CI：CI 直接安装 MoonBit 工具链，对内核源码跑 moon check（零警告）与 moon test（251 个测试），另有 95 个前端测试（含 26 个加载真实 WASM 内核的集成测试）全部通过，并自动部署演示站点

九、项目类型说明

原创项目，非移植、非参考已有开源项目。

依赖开源库 moonbitstack/moonmodel（Apache-2.0，https://github.com/moonbitstack/moonmodel ），仅提供 Model/Field/Check 数据结构与投影格式转换，相当于编译器 AST 定义与后端代码生成。五个引擎、DSL 前端、求解算法、迁移生成、类型系统与验证框架均为自主实现。

两者的差别不是说法，是可以验证的：**投影会把 minimum: 0 与 maximum: -1 一并写进 schema 而不作任何提示，求解器会报出空区间冲突**。`projdesk contrast examples/Conflicting.dsl` 把两侧并排打出，仓库还以随机模型对该差异做了属性测试（moonbit/main/independence_test.mbt）。

同样的差异常规化到契约目标上：每个目标承载不了的约束都会被逐条列出（9 种 DropReason），而不是静默丢失 —— `node cli/index.js gen models/Order.dsl` 后查看 projdesk-out/drops.txt。

十、GitHub 仓库链接

https://github.com/Tino-hue/projdesk

167 个提交（136 个非合并），128 个跟踪文件。测试全绿：CI 中 251 个 MoonBit 测试（moon check 零警告）与 95 个前端测试全部通过；另有 26 个真实 WASM 集成测试验证已编译内核，并自动部署演示站点。

内核已发布到 Mooncakes：`moon add Tino-hue/projdesk-kernel`，仓库里 `node scripts/verify-registry-consumption.js` 会拉取已发布版本、在一个全新模块里编译并运行它，确认第三方真的能消费。

在线演示：https://tino-hue.github.io/projdesk/
