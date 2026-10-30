ProjDesk：模型工程工作台（Model Engineering Workbench）

一、基本信息

项目名称：ProjDesk：模型工程工作台（Model Engineering Workbench）
参赛者：Tino-hue
联系方式：Micxry060912@hotmil.com
GitHub 仓库链接：https://github.com/Tino-hue/projdesk
项目方向：MoonBit 模型工程工具链 / 编译器基础设施
是否为移植项目：否

二、项目简介

ProjDesk 是一个用 MoonBit 实现的模型工程工作台，覆盖数据模型的完整生命周期：定义、分析、演化、对比、验证。

核心是五个从零手写的 MoonBit 算法引擎，共 3691 行独立实现（整个内核 5613 行实现代码 + 3225 行测试代码），分别落在编译器前端、约束求解、版本演化、类型理论、形式化验证五个领域。开发者用一套建模 DSL 声明业务对象，工作台完成约束推理、迁移推演、等价判定与正确性验证，最后投影为 JSON Schema、OpenAPI、SQL、GraphQL、TypeScript、Zod、Prisma 七种契约。

投影由开源库 moonmodel 承担（相当于编译器后端）；五个引擎均本项目独立实现，与其无功能重叠。

三、核心功能范围

- 建模 DSL：手写词法分析器（Token ADT + 字符级扫描）、递归下降语法分析（AST + 行列号错误恢复）、AST 代码生成、AST 反向打印；支持行注释与块注释、嵌套模型、约束表达式（算术运算、内置函数 min/max/abs/ceil/floor）、跨字段约束引用（b: Int [over=a.least]，编译期求值）；
- 约束求解器：区间冲突检测、蕴含与冗余分析、包含关系判定、固定点区间传播，输出类型化 Diagnosis 诊断（9 变体）；跨字段约束引用在建模层符号化解析（可前向或后向引用），检出未知引用与引用环路，并由区间传播引擎判定整个约束系统是否有解；
- 迁移引擎：结构化语义 diff（非文本对比），生成含破坏性变更标记的 ALTER TABLE，覆盖 Postgres/SQLite/MySQL；
- 等价检测：类型加宽链（Int→Big→Real）、约束包含、嵌套模型与集合递归判定，分类为 Equivalent/SubtypeOf/SupertypeOf/Incompatible；
- Round-trip 验证：DSL → AST → DSL → AST 逐字段逐约束比对（含嵌套模型与全部 12 种约束），任何字段、类型或约束丢失都会被检出；
- 语义检查：引用解析、自引用与环路检测；
- 属性测试框架：自实现 xorshift64* PRNG 与随机模型生成器，在 100+ 随机模型上验证 12 条不变式（round-trip 保持性、DSL 完备性、diff 对称性等）；
- 七种契约投影：对目标无法承载的约束输出类型化丢弃报告，而非静默丢弃；
- 工具链：WASM ABI（11 导出）、CLI（gen/check/contrast/migrate/verify/init，contrast 并排展示投影与求解器的差异）、VS Code 插件、GitHub Action、Cloudflare Workers 后端。

全部 MoonBit 代码编译为 wasm-gc，浏览器内零服务端依赖运行。

四、项目方向与通用性

面向所有需要管理数据模型的开发者。五个引擎对应通用算法领域，不绑定任何前端框架、后端语言或数据库。

能力不限于 Web：CLI 可在 CI 校验模型，VS Code 插件可在开发时即时检查，GitHub Action 可在 PR 中阻止破坏性变更合入。各入口共用同一份 WASM 内核，行为一致。

五、预期使用场景

API 契约跨端一致性：用 DSL 一次声明结构，前端得 TypeScript 与 Zod，后端得 JSON Schema 与 OpenAPI，改一处四端同步更新。

提交前约束排查：同时存在 least=10 与 most=5 时，求解器在建模阶段即报空区间，而非运行时写入失败。

模型演进与迁移：改模型后自动输出变更清单与 ALTER TABLE 脚本，标注破坏性变更供评审。

多版本兼容性判定：两份模型是等价、子类型还是存在无法自动迁移的冲突。

定义正确性回归：CI 中运行 Round-trip 验证，确认序列化再生成后定义无损。

六、拟实现的核心功能

1. 五个 MoonBit 算法引擎 + 属性测试框架（12 条不变式、7 项性能基准）
2. 七种契约投影 + 类型化丢弃诊断
3. 浏览器工作台：模型编辑器（拖拽/搜索/暗色）、关系图、约束诊断、迁移预览、版本 Diff、Engine Playground（6 个引擎页签）
4. WASM ABI 11 导出
5. CLI（gen/check/migrate/verify/init）、VS Code 插件、GitHub Action、Workers 后端
6. 测试与 CI：CI 直接安装 MoonBit 工具链，对内核源码跑 moon check（零警告）与 moon test（251 个测试），另有 95 个前端测试（含 26 个加载真实 WASM 内核的集成测试）全部通过，并自动部署演示站点

七、项目类型说明

原创项目，非移植、非参考已有开源项目。

依赖开源库 moonbitstack/moonmodel（Apache-2.0，https://github.com/moonbitstack/moonmodel ），仅提供 Model/Field/Check 数据结构与投影格式转换，相当于编译器 AST 定义与后端代码生成。五个引擎、DSL 前端、求解算法、迁移生成、类型系统与验证框架均为自主实现。

两者的差别不是说法，是可以验证的：投影会把 minimum: 0 与 maximum: -1 一并写进 schema 而不作任何提示，求解器会报出空区间冲突。projdesk contrast examples/Conflicting.dsl 把两侧并排打出，仓库还以随机模型对该差异做了属性测试（moonbit/main/independence_test.mbt）。

八、GitHub 仓库链接

https://github.com/Tino-hue/projdesk

118 个以上有效提交。测试全绿：CI 中 251 个 MoonBit 测试（moon check 零警告）与 95 个前端测试全部通过；另有 26 个真实 WASM 集成测试验证已编译内核，并自动部署演示站点。

在线演示：https://tino-hue.github.io/projdesk/
