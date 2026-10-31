# 驳回意见逐条应答

初审的驳回理由与逐条回应。每条都附可复现的命令——评审可以自己跑一遍。

## 驳回理由一：核心差异分析、类型兼容性和迁移能力与现有有效项目明显重叠

我们把"重叠"拆成具体的项目逐个点名，而不是泛泛地说"我们不一样"：

- **moon_schema_plan / moon-data-contract / moonpack / moon_proto** 做的是**两份 schema 之间**的 diff、迁移规划与门禁，输入是 schema 本身。
- 我们做的是**模型语义**层面的 diff 与兼容判定：这次改动**有效约束集**变了没有、两个版本的约束系统还相容吗、两版的有效约束集是否等价。在此之上还有生态里没有的两件事——**投影的保真度**（每个目标承载不了的约束被逐条列出）与**定义的往返无损**（逐字段逐类型逐约束比对）。
- 主动交代重叠：TypeScript / Zod / Prisma 三个 emitter 与通用 codegen 库（如 mizchi/codegen）确有功能重叠，我们承认。三个都在同一个 `Projector` trait 后面，生态一旦提供模型语义的 emitter 可直接替换。**重叠面只有三个 emitter，五个引擎不在里面。**

**证据**

```
node cli/index.js contrast examples/CrossFieldConflict.dsl
```

## 驳回理由二：自定义 DSL 和工作台重建了数据建模、约束检查与契约生成体系

DSL 不是产品，是输入前端之一，**我们不要求任何人用我们的 DSL**：

```
node cli/index.js check examples/moon_zod_dead_schema.json   # 直接吃生态的 JSON Schema
```

引入 DSL 的唯一理由：字段的约束可以引用另一字段的约束（`b: Int [over=a.least]`）。这种"约束依赖约束"在 JSON Schema / Zod / moon_zod 的数据模型里**无处安放**——那几处的约束是挂在单个字段上的常量。没有跨字段约束引用，就只剩逐字段校验，那正是生态已经有的东西。

## 驳回理由三：未能体现相较现有生态的实质增量价值

增量是**生态里做不出来的那件事**：判定一份 schema 还有没有解。这是对**输入**的判定，不是对**实例**的判定。

一个"延展别人项目"的做法，做不出**关于那个项目自身产物的缺陷报告**。我们能——下面这份文件是 `moon_zod` 0.9.2 自己导出的，618 字节，sha256 `3b4ee18b9e41aa6b…`，逐字节未改：

```
node cli/index.js check examples/moon_zod_dead_schema.json
# 3 contradiction(s) found:
#   [empty_range] /properties/level — no number satisfies these bounds: [10, 5]
#   [empty_length] /properties/code — no string satisfies these length bounds
#   [empty_items] /properties/tags — no array satisfies these item-count bounds
```

它也不误报：`moon_zod` 0.9.2 包内的 `examples/resources/Product_Json_Schema.json` 是一份健康的 schema，我们的检查器对它报 0 条。CI 里还检查了本内核自己投影出的 JSON Schema 同样是 0 条。

## 我们不主张什么

- 不主张迁移引擎与 moon_schema_plan / moon-data-contract 没有重叠——有，我们提供的是模型语义那一层的引擎，它们做的是 schema 那一层。
- 不主张 TypeScript / Zod / Prisma 三个 emitter 是我们独有的。
- 不主张内核没有依赖：它依赖 `moonbitstack/moonmodel`（Apache-2.0）提供 Model/Field/Check 数据结构与四种投影后端，相当于编译器的 AST 定义与后端代码生成；六个引擎、DSL 前端、求解算法、迁移生成、类型系统、验证框架与 schema 可满足性判定共 4586 行均为自主实现。

## 被追问时的一句话

- "你们和 moon_zod 差在哪？" —— 它判**值**合不合法，我们判**schema** 还有没有解；这份 schema 是它自己导出的。
- "迁移和 diff 呢？" —— 那部分确实和 moon_schema_plan 一类工具重叠，我们提供的是模型语义那一层的引擎，另外多了投影保真度和定义往返两项生态没有的检查。
- "为什么要写 DSL？" —— 只有一处需要它：跨字段的约束引用。JSON Schema 无处安放。其余输入走生态的 JSON Schema。
- "凭什么说你们不是套壳？" —— 内核只依赖一个库（moonmodel），六千余行引擎代码没有一行取自他人项目；而我们的工具能报出 moon_zod 自己的产物里的矛盾——延展别人项目做不到这件事。

## 评审可自行复现的三条命令

```
node cli/index.js check examples/moon_zod_dead_schema.json
node cli/index.js contrast examples/CrossFieldConflict.dsl
cd moonbit && moon check && moon test
```
