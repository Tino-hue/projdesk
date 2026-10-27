# 报名表纯文本版（直接复制粘贴）

> 报名系统通常不支持 markdown 表格，下面是去掉表格符号的纯文本版本，按 moon_elk 参考格式组织。

---

## 基本信息

项目名称：ProjDesk：模型工程工作台（Model Engineering Workbench）

参赛者：Tino-hue

联系方式：Micxry060912@hotmil.com

GitHub 仓库链接：https://github.com/Tino-hue/projdesk

项目方向：MoonBit 模型工程工具链 / 编译器基础设施

是否为移植项目：否

---

## 项目简介（粘贴这段）

ProjDesk 是一个用 MoonBit 实现的模型工程工作台，为数据模型的完整生命周期提供自动化工具：定义、分析、演化、对比、验证。项目面向需要在前后端之间保持数据契约一致的开发者、API 设计者与数据库工程师。

项目核心是五个从零手写的 MoonBit 算法引擎，分别落在编译器前端、约束求解、版本演化、类型理论、形式化验证五个算法领域，共 2308 行独立 MoonBit 实现。开发者用一套极简建模 DSL 声明业务对象，工作台随即完成约束推理、版本迁移推演、语义等价判定与正确性验证，最后把模型投影为 JSON Schema、OpenAPI、SQL DDL、GraphQL SDL、TypeScript、Zod、Prisma 七种契约格式。

投影环节由开源库 moonbitstack/moonmodel 承担，相当于编译器的后端代码生成；五个引擎全部由本项目独立实现，moonmodel 不提供任何相关能力，与之无功能重叠。

---

## 核心功能范围（粘贴这段）

提供一套建模 DSL（model User { id: Big @unique, name: Text [longest=64] }），实现内容包括手写词法分析器（Token ADT 与字符级扫描器）、递归下降语法分析器（AST 与带行列号的错误恢复）、AST 代码生成器，支持行注释、嵌套模型与 List/Dict/Ref 复合类型。

提供约束求解器，对模型中的数值区间、长度区间、闭集选项、正则与格式约束进行冲突检测、蕴含与冗余分析、包含关系判定，输出类型化的 Diagnosis 诊断结果（Conflict、Redundant、Warning、NoConstraints 四类九变体）。

提供模型迁移引擎，对两个模型版本做结构化语义 diff（非文本行对比），判定字段增删、类型变更、约束增删、可空性与必填性变更，生成含破坏性变更标记的 SQL DDL 迁移脚本，覆盖 Postgres、SQLite、MySQL 三种方言。

提供语义等价检测引擎，基于类型加宽链（Int 到 Big 到 Real）、约束包含关系与嵌套模型、集合类型的递归判定，将两个模型分类为 Equivalent、SubtypeOf、SupertypeOf 或 Incompatible。

提供 Round-trip 形式化验证框架，将模型序列化为 DSL、重新解析、逐字段比对，验证定义与再生成过程中无字段或约束丢失。

提供属性测试框架，自实现 xorshift64 星确定性伪随机数生成器与随机模型生成器，在随机模型上验证 round-trip 保持性、DSL 完备性、求解器可靠性、diff 对称性、加字段非破坏性、自等价性、子类型方向性七条不变式。

提供七种契约投影输出（JSON Schema 2020-12、OpenAPI 3.0/3.1/2.0、SQL DDL、GraphQL SDL、TypeScript、Zod、Prisma），对目标无法承载的约束输出类型化丢弃报告而非静默丢弃。

提供 WASM ABI（8 个导出）供浏览器前端交互调用，提供 CLI 工具（gen / check / migrate 三个子命令，支持 DSL 与 JSON 双输入）、VS Code 插件、GitHub Action 与 Cloudflare Workers 后端。

全部 MoonBit 代码编译为 wasm-gc，在浏览器中零服务端依赖运行。

---

## 项目方向与通用性（粘贴这段）

项目属于 MoonBit 的模型工程与编译器基础设施方向，提供的能力不绑定任何前端框架、后端语言或数据库，仅面向数据模型这一通用对象本身。

五个引擎各自对应一个通用算法领域：编译器前端、约束求解、版本演化、类型理论、形式化验证。这些能力不限于 Web 项目，CLI 可在 CI 流水线中校验模型，VS Code 插件可在开发时即时检查，GitHub Action 可在 PR 中阻止破坏性模型变更合入。CLI、编辑器插件、CI 集成与浏览器工作台共用同一份 WASM 内核，行为完全一致。

---

## 预期使用场景（粘贴这段，5 个）

场景一：API 契约设计与跨端一致性。后端开发者用 DSL 一次声明请求与响应结构，前端据此获得 TypeScript 类型与 Zod 校验器，后端据此获得 JSON Schema 与 OpenAPI 契约。契约不再需要在多个文件间手工同步，改一处 DSL，四端产物同时更新。

场景二：提交前的约束冲突排查。模型中同时存在 least=10 与 most=5 时，约束求解器在建模阶段即报出空区间冲突，而不是等到运行时数据写入失败。冗余约束、闭集选项与长度上限的矛盾也会一并检出，避免把语义歧义带入生产。

场景三：模型演进与数据库迁移。模型新增字段、删除字段或调整类型后，迁移引擎输出结构化变更清单与可直接执行的 ALTER TABLE 脚本，并标注哪些变更会破坏既有数据。评审时可据此判断变更是否允许合入。

场景四：多版本模型的兼容性判定。在重构或并行开发两个分支时，等价检测引擎判定两份模型是等价、子类型还是存在无法自动迁移的冲突，避免因模型分歧导致的接口不一致。

场景五：模型定义的正确性回归。CI 中运行 Round-trip 验证，确认任一模型定义经序列化、解析、再生成后字段与约束完全一致，防止定义环节引入的静默丢失。

---

## 拟实现的核心功能（粘贴这段）

一、五个独立 MoonBit 算法引擎：DSL 编译器、约束求解器、模型迁移引擎、语义等价检测引擎、Round-trip 验证框架。

二、属性测试框架与性能基准：确定性 PRNG、随机模型生成器、七条不变式验证、七项基于 monotonic_clock 的耗时上限断言。

三、七种契约投影输出与类型化丢弃诊断报告。

四、浏览器工作台前端：模型编辑器（拖拽排序、搜索过滤、暗色主题）、Canvas 模型关系图、约束诊断面板、迁移预览、版本 Diff 与快照、Engine Playground 交互面板。

五、WASM ABI 八个导出。

六、CLI 工具（gen / check / migrate）、VS Code 插件、GitHub Action、Cloudflare Workers + D1 后端。

七、CI 流水线：moon check（零警告）、moon test（150 个）、前端测试（80 个，含 15 个加载真实 WASM 内核的端到端集成测试）、构建与自动部署。

---

## 项目类型说明（粘贴这段）

原创项目，非移植、非参考已有开源项目。

项目依赖开源库 moonbitstack/moonmodel（Apache-2.0，https://github.com/moonbitstack/moonmodel ），仅用于提供 Model/Field/Check 数据结构与七种契约投影的格式转换，相当于编译器中的 AST 定义与后端代码生成。本项目的五个算法引擎、DSL 前端、约束推理算法、迁移生成、类型系统与验证框架均为自主实现，与 moonmodel 无功能重叠。

---

## GitHub 仓库链接（粘贴这段）

https://github.com/Tino-hue/projdesk

仓库含 95 个以上有效提交，覆盖五个引擎的独立开发、属性测试框架、前端工作台、CLI、VS Code 插件与后端。CI 全绿：moon check 零警告，150 个 MoonBit 测试与 80 个前端测试全部通过。在线演示：https://tino-hue.github.io/projdesk/
