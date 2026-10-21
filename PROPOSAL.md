# ProjDesk 项目申报书

## 基本信息

- **项目名称**：ProjDesk — 一定义，四张图
- **参赛者**：Tino-hue
- **联系方式**：（请补充）
- **GitHub 仓库链接**：https://github.com/Tino-hue/projdesk
- **项目方向**：元数据 / 契约层工具 · 代码生成基础设施
- **是否为移植项目**：否

## 项目简介

ProjDesk 是一个纯浏览器运行的「模型描述 → 多目标投影」工作台。用户通过表单声明一个业务对象（字段名、类型、约束、required/nullable、文档），页面同时生成并实时刷新四种产物：JSON Schema 2020-12、OpenAPI Schema Object、SQL DDL（Postgres）、GraphQL SDL。

核心价值：当开发者需要定义一个数据模型时，不必在四个生态里写四遍 schema。在这里说一次，四个世界同时看到结果；改一处约束，四个产物一起变；哪个目标放不下，诚实告诉你原因。

## 项目方向与通用性

本项目面向所有需要做数据契约 / API 规范 / 数据库建模的开发者，属于通用的元数据基础设施工具。不绑定特定语言栈或框架，输出的四种产物是行业通用标准（JSON Schema / OpenAPI / SQL / GraphQL），可直接用于前后端对接、数据库建表、API 文档生成等场景。MoonBit 内核编译为 wasm-gc，嵌入浏览器即可运行，无服务端依赖。

## 预期使用场景

**场景一：API 契约设计。** 后端开发者在设计接口时，用 ProjDesk 声明请求/响应的数据结构，同时拿到 JSON Schema（前端表单校验）、OpenAPI（接口文档）、GraphQL SDL（GraphQL 服务端），三处保持一致，减少手工同步错误。

**场景二：数据库建模。** 数据库设计者在建表前用 ProjDesk 声明字段的类型、长度、唯一性等约束，直接导出 CREATE TABLE 语句；同时对照 SQL 的丢弃报告，知道哪些约束（如 pattern、format）需要在应用层补做校验。

**场景三：教学与规范培训。** 讲解数据建模时，同一个模型在四个目标下的不同表达方式（required 如何对应 required[]、NOT NULL、GraphQL !）可以直观对比展示，丢弃报告本身就是一份「各目标表达能力」的对照表。

**场景四：多语言项目的数据层对齐。** 同一个业务对象分别对接 JSON API、SQL 数据库和 GraphQL 服务时，用 ProjDesk 统一源头，避免多处维护的 schema 出现分歧。

## 拟实现的核心功能

- 字段编辑器：支持 Bool / Int / Big / Real / Text / Bytes / Stamp / List / Dict / Ref / Nest / Any 等类型，required 与 nullable 独立控制
- 约束面板：支持 least / most / over / under / step / shortest / longest / pattern / format / options / distinct / unique
- 四栏同步输出：JSON Schema 2020-12、OpenAPI 3.0、SQL DDL（Postgres）、GraphQL SDL
- 丢弃报告：逐约束分析各目标能否承载，输出「字段 + 约束 + 原因」，诚实投影不美化
- 预设样例：User / Order / Address（含 Ref 引用、unique、bounds、options 等），打开即用
- 复制 / 导出：四种产物均支持一键复制或下载文件

## 项目类型

本项目为**原创项目**。投影能力依赖开源库 [moonbitstack/moonmodel](https://mooncakes.io/packages/moonbitstack/moonmodel)（Apache-2.0），ProjDesk 在其上构建了丢弃原因分析、WASM ABI、预设样例和完整前端交互层，不属于移植项目。

## GitHub 仓库

https://github.com/Tino-hue/projdesk

当前分支 master，含内核源码、前端、测试、文档与构建脚本。持续补充 commits 中（要求 ≥ 10 个有效提交）。
