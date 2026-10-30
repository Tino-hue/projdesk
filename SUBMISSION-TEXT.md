ProjDesk：模型工程工作台（Model Engineering Workbench）

一、基本信息

项目名称：ProjDesk：模型工程工作台（Model Engineering Workbench）
参赛者：Tino-hue
联系方式：Micxry060912@hotmil.com
GitHub 仓库链接：https://github.com/Tino-hue/projdesk
项目方向：MoonBit 模型工程工具链 / 编译器基础设施
是否为移植项目：否

二、项目简介

ProjDesk 是模型定义的正确性工具链：**判定一份 schema 自己还有没有解。**

生态里的 Schema 库（moon_zod、moonschema、colmugx/json-schema）回答"这个值合不合法"；schema diff 与迁移工具（moon_schema_plan、moon-data-contract、moonpack、moon_proto）回答"两个模型之间发生了什么"。都不回答第三类问题：**这份 schema 自己还有没有解**。

moon_zod 0.9.2 的 min/max 从不互相比对，于是 number().min(10).max(5) 被静默接受，导出成 minimum: 10, maximum: 5——一份没有任何值能满足的 schema（仓库里的 examples/moon_zod_dead_schema.json 就是它自己导出的那份产物，618 字节，sha256 3b4ee18b9e41aa6b…，逐字节未改）。

我们的第六个引擎读 JSON Schema，判定它还有没有解，并指出矛盾在哪儿：

    $ node cli/index.js check examples/moon_zod_dead_schema.json
    3 contradiction(s) found:
      [empty_range] /properties/level — no number satisfies these bounds: [10, 5]
      [empty_length] /properties/code — no string satisfies these length bounds
      [empty_items] /properties/tags — no array satisfies these item-count bounds

**这个能力不需要我们自己的记法**——已有 schema 的团队把文件交给 projdesk check 就能查。自定义 DSL 只是另一个输入前端，唯一的理由是跨字段约束引用（b: Int [over=a.least]）在 JSON Schema 里无处安放。

六个引擎共 4586 行（内核 6601 行实现 + 3378 行测试）。一句话概括边界：**生态负责"把模型变成产物"，ProjDesk 负责"证明这个模型是对的、这个产物是没丢的"。**

三、核心功能范围

- **Schema 可满足性判定**：对 JSON Schema 做静态可满足性分析——回答"这份 schema 还有解吗"，而不是"这个值合不合法"。区间代数作用在 allOf / anyOf / oneOf / not / $ref 上；数值边界、字符串长度、数组元素数三者互校；枚举与周边边界互校；检出悬空引用与非正 multipleOf；逐条按 JSON Pointer 给出位置。不需要我们自己的记法，直接读生态产出的 JSON Schema。
- **约束求解器**：区间冲突检测、蕴含与冗余分析、包含关系判定、固定点区间传播，输出类型化 Diagnosis（4 种）；跨字段约束引用符号化解析，检出未知引用与引用环路，并由区间传播判定整个约束系统是否有解。
- **Round-trip 验证**：DSL → AST → DSL → AST 逐字段逐类型逐约束比对（含嵌套模型与全部 12 种约束），任何丢失都被检出；失败是类型化的（RoundTripError），不是一句话。
- **契约保真度**：每个投影目标承载不了的约束都输出类型化丢弃报告（9 种 DropReason），逐条给出"丢了哪个字段的哪个约束、为什么"，而非静默丢弃。
- **迁移引擎**：结构化语义 diff（非文本对比），生成含破坏性变更标记的 ALTER TABLE，覆盖 Postgres/SQLite/MySQL。
- **等价检测**：类型加宽链（Int→Big→Real）、约束包含、嵌套模型与集合递归判定，分类为 Equivalent/SubtypeOf/SupertypeOf/Incompatible。
- **建模 DSL（仅作为输入记法）**：手写词法分析器、递归下降语法分析、AST 代码生成与反向打印；支持注释、嵌套模型、约束表达式、跨字段约束引用。
- **语义检查**：引用解析、自引用与环路检测。
- **属性测试框架**：自实现 xorshift64* PRNG 与随机模型生成器，在 100+ 随机模型上验证 12 条不变式。
- **工具链**：WASM ABI（12 导出）、CLI（gen/check/check-schema/contrast/migrate/verify/init）、VS Code 插件、GitHub Action、Workers 后端；全部编译为 wasm-gc，浏览器内零服务端依赖运行。

四、项目方向与通用性

面向所有需要管理数据模型的开发者，以及所有已经有 schema 的团队。六个引擎对应通用算法领域，不绑定任何前端框架、后端语言或数据库。

能力不限于 Web：CLI 可在 CI 校验模型与 schema，VS Code 插件可在开发时即时检查，GitHub Action 可在 PR 中阻止破坏性变更合入。各入口共用同一份 WASM 内核。

内核已发布到 Mooncakes（moon add Tino-hue/projdesk-kernel），任何项目都能直接消费。

五、预期使用场景

**已有 schema 的体检**：把团队现有的 JSON Schema（哪怕是 moon_zod 导出的）交给 projdesk check，直接得到"这份 schema 永远无解"以及矛盾的确切位置，而不是等运行时才发现每个值都被拒。

**提交前模型自检**：least=10 与 most=5 同时存在时，求解器在建模阶段即报空区间，早于任何一次数据写入。

**契约生成前的缺口盘点**：投影到七种目标时，逐字段列出每个目标承载不了的约束及原因。

**模型演进与迁移**：改模型后自动输出变更清单与 ALTER TABLE 脚本，标注破坏性变更供评审。

**多版本兼容性判定**：两份模型是等价、子类型还是存在无法自动迁移的冲突。

**定义正确性回归**：CI 中运行 Round-trip 验证，确认定义再生成后无损。

六、拟实现的核心功能

1. 六个 MoonBit 算法引擎 + 属性测试框架（12 条不变式、7 项性能基准）
2. 七种契约投影 + 类型化丢弃诊断（9 种 DropReason）
3. 浏览器工作台：模型编辑器、关系图、约束诊断、迁移预览、版本 Diff、Engine Playground（6 个引擎页签）
4. WASM ABI 12 导出
5. CLI（gen/check/check-schema/contrast/migrate/verify/init）、VS Code 插件、GitHub Action、Workers 后端
6. 测试与 CI：CI 安装 MoonBit 工具链，对内核源码跑 moon check（零警告）与 moon test（268 个测试），另有 95 个前端测试（含 26 个加载真实 WASM 内核的集成测试）全部通过，并自动部署演示站点

七、项目类型说明

原创项目，非移植、非参考已有开源项目。

依赖开源库 moonbitstack/moonmodel（Apache-2.0），仅提供 Model/Field/Check 数据结构与 JSON Schema / OpenAPI / SQL / GraphQL 四种投影后端，相当于编译器 AST 定义与后端代码生成。六个引擎、DSL 前端、求解算法、迁移生成、类型系统、验证框架与 Schema 可满足性判定均为自主实现，没有一行代码取自他人项目。（生态自身也是这个模式：moon_zod 同样依赖 moonbitlang/regexp 与 moonbitlang/async。）

与生态现有方案的分工是逐个点名的：moon_zod / moonschema / colmugx/json-schema 做实例级校验与契约导出，我们做 schema 可满足性判定；moon_schema_plan / moon-data-contract / moonpack / moon_proto 做两版之间的 diff 与门禁，我们提供语义 diff 与兼容判定引擎。主动交代：TypeScript / Zod / Prisma 三个 emitter 与通用 codegen 库（如 mizchi/codegen）确有功能重叠，我们承认，但它们都实现同一个 Projector trait，生态若提供模型语义的 emitter 可直接替换。

差别不是说法，是可以验证的：投影会把 minimum: 0 与 maximum: -1 一并写进 schema 而不作任何提示，求解器会报出空区间冲突。projdesk contrast examples/Conflicting.dsl 把两侧并排打出，仓库还以随机模型对该差异做了属性测试（moonbit/main/independence_test.mbt）。

八、GitHub 仓库链接

https://github.com/Tino-hue/projdesk

180 个以上有效提交，134 个跟踪文件。测试全绿：CI 中 268 个 MoonBit 测试（moon check 零警告）与 95 个前端测试全部通过，另有 26 个真实 WASM 集成测试验证已编译内核，并自动部署演示站点。

内核已发布到 Mooncakes：moon add Tino-hue/projdesk-kernel（仓库里的 node scripts/verify-registry-consumption.js 会拉取已发布版本、在全新模块里编译并运行，确认第三方真的能消费）。

在线演示：https://tino-hue.github.io/projdesk/

评审可在三分钟内自行复现（只需 Node 24 与仓库本身）：

    node cli/index.js check examples/moon_zod_dead_schema.json
    node cli/index.js contrast examples/CrossFieldConflict.dsl
    cd moonbit && moon check && moon test
