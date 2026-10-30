# ProjDesk 项目申报书

## 基本信息

- 项目名称：ProjDesk：模型工程工作台（Model Engineering Workbench）
- 参赛者：Tino-hue
- 联系方式：Micxry060912@hotmil.com
- GitHub 仓库链接：https://github.com/Tino-hue/projdesk
- 项目方向：MoonBit 模型工程工具链 / 编译器基础设施
- 是否为移植项目：否（原创项目）

## 项目简介

MoonBit 生态里的 Schema 库（moon_zod、moonschema、colmugx/json-schema）回答的是"这个值合不合法"，schema diff 与迁移工具（moon_schema_plan、moon-data-contract、moonpack、moon_proto）回答的是"两个模型之间发生了什么"。ProjDesk 回答这两类工具都不回答的第三类问题：**这份 schema 自己还有没有解**。moon_zod 0.9.2 的 min/max 是一个一个套用的、从不互相比对，于是 `number().min(10).max(5)` 被静默接受，导出成 `minimum: 10, maximum: 5`——一份没有任何值能满足的 schema。ProjDesk 的第六个引擎读 JSON Schema，判定它还有没有解并指出矛盾在哪儿；仓库里的 `examples/moon_zod_dead_schema.json` 就是 moon_zod 自己导出的那份产物（618 字节，sha256 `3b4ee18b9e41aa6b…`），`node cli/index.js check examples/moon_zod_dead_schema.json` 可复现这个判定。

## 项目方向与通用性

面向所有需要管理数据模型的开发者，以及所有已经有 schema 的团队。六个引擎分别对应编译器前端、约束求解、版本演化、类型理论、形式化验证与 schema 可满足性判定，都是通用算法，不绑定任何前端框架、后端语言或数据库。能力不限于 Web：CLI 可在 CI 校验模型与 schema，VS Code 插件可在开发时即时检查，GitHub Action 可在 PR 中阻止破坏性变更合入，各入口共用同一份 WASM 内核。内核已发布到 Mooncakes（`moon add Tino-hue/projdesk-kernel`），任何项目都能直接消费。

## 核心功能范围

以下均已实现并有测试覆盖。

- **Schema 可满足性判定**：静态分析 JSON Schema 有没有解——区间代数作用在 allOf / anyOf / oneOf / not / $ref 上，数值边界、字符串长度、数组元素数互校，检出悬空引用，结论按 JSON Pointer 给出位置。
- **约束求解器**：区间冲突、蕴含与冗余、包含关系、固定点区间传播；跨字段约束引用符号化解析，检出未知引用与引用环路。
- **Round-trip 验证**：DSL → AST → DSL → AST 逐字段逐类型逐约束比对，覆盖嵌套模型与全部 12 种约束，失败是类型化的。
- **契约保真度**：每个投影目标承载不了的约束都输出类型化丢弃报告，逐条说明丢了什么、为什么，而非静默丢弃。
- **迁移引擎**：结构化语义 diff（非文本对比），生成含破坏性变更标记的 ALTER TABLE，覆盖 Postgres / SQLite / MySQL。
- **等价检测**：类型加宽链、约束包含、嵌套与集合递归判定，分类为 Equivalent / SubtypeOf / SupertypeOf / Incompatible。
- **工具链**：WASM ABI 12 导出；CLI（gen/check/check-schema/contrast/migrate/verify/init）、VS Code 插件、GitHub Action、Workers 后端；浏览器工作台含模型编辑器、关系图、约束诊断、迁移预览、版本 Diff 与 6 个引擎页签。

## 预期使用场景

1. **已有 schema 的体检**：把团队现有的 JSON Schema（哪怕是 moon_zod 导出的）交给 `projdesk check`，直接得到"这份 schema 永远无解"以及矛盾的确切位置，而不是等到运行时才发现每个值都被拒。
2. **提交前模型自检**：`least=10` 与 `most=5` 同时存在时，求解器在建模阶段即报空区间——早于任何一次数据写入；字段之间互相引用构成的约束环也被报出。
3. **契约生成前的缺口盘点**：投影到七种目标时，逐字段列出每个目标承载不了的约束及原因，评审时能直接看到"这份契约在 TypeScript 端会丢什么"。
4. **模型演进与多版本判定**：改模型后输出变更清单与 ALTER TABLE 脚本并标注破坏性变更；两份模型是等价、子类型还是存在无法自动迁移的冲突，也一并判定。

## 项目类型说明

原创项目，非移植、非参考已有开源项目。依赖开源库 moonbitstack/moonmodel（Apache-2.0，https://github.com/moonbitstack/moonmodel），仅提供 Model/Field/Check 数据结构与 JSON Schema / OpenAPI / SQL / GraphQL 四种投影后端，相当于编译器 AST 定义与后端代码生成；六个引擎、DSL 前端、求解算法、迁移生成、类型系统、验证框架与 schema 可满足性判定均为自主实现，没有一行代码取自他人项目。（生态自身也是这个模式：moon_zod 同样依赖 moonbitlang/regexp 与 moonbitlang/async。）

## GitHub 仓库链接

https://github.com/Tino-hue/projdesk —— 180 个以上有效提交，无空提交、无重复提交信息、无无意义拆分（提交改动行数中位数 146）。CI 全绿：268 个 MoonBit 测试（`moon check` 零警告）与 95 个前端测试全部通过，另有 26 个真实 WASM 集成测试验证已编译内核。在线演示：https://tino-hue.github.io/projdesk/ 。评审可自行复现：

    node cli/index.js check examples/moon_zod_dead_schema.json
    node cli/index.js contrast examples/CrossFieldConflict.dsl
    cd moonbit && moon check && moon test
