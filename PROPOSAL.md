# ProjDesk 项目申报书

## 基本信息

- 项目名称：ProjDesk：模型描述的多目标投影工作台
- 参赛者：Tino-hue
- 联系方式：（请补充）
- GitHub 仓库链接：https://github.com/Tino-hue/projdesk
- 项目方向：元数据 / 契约层工具 · 代码生成基础设施
- 是否为移植项目：否

## 项目简介

ProjDesk 是一个纯浏览器运行的「模型描述 → 多目标投影」工作台。用户通过表单声明一个业务对象（字段名、类型、约束、required/nullable、文档），页面同时生成并实时刷新四种产物：JSON Schema 2020-12、OpenAPI Schema Object、SQL DDL、GraphQL SDL。改一处约束，四个产物一起变；哪个目标放不下，诚实告诉你原因。

## 项目方向与通用性

本项目面向所有需要做数据契约 / API 规范 / 数据库建模的开发者，不绑定特定语言栈或框架。输出的四种产物均为行业通用标准，可直接用于前后端对接、数据库建表、API 文档生成。MoonBit 内核编译为 wasm-gc，嵌入浏览器即可运行，无服务端依赖。

## 预期使用场景

- **API 契约设计**：后端设计接口时声明数据结构，同时拿到 JSON Schema（前端校验）、OpenAPI（接口文档）、GraphQL SDL，三处保持一致。
- **数据库建模**：建表前声明字段约束，直接导出 CREATE TABLE；对照丢弃报告，知道哪些约束需在应用层补做校验。
- **教学与规范培训**：同一模型在四个目标下的 required 表达差异（required[] / NOT NULL / GraphQL !）可直观对比。
- **多语言项目数据层对齐**：同一业务对象对接 JSON API、SQL、GraphQL 时，统一源头避免多处分歧。

## 拟实现的核心功能

- 字段编辑器：Bool / Int / Big / Real / Text / Bytes / Stamp / List / Dict / Ref / Nest / Any 等类型，required 与 nullable 独立控制
- 约束面板：least / most / over / under / step / shortest / longest / pattern / format / options / distinct / unique
- 四栏同步输出：JSON Schema 2020-12、OpenAPI 3.0、SQL DDL（Postgres）、GraphQL SDL
- 丢弃报告：逐约束分析各目标能否承载，输出「字段 + 约束 + 原因」
- 预设样例：User / Order / Address，打开即用
- 复制 / 导出：四种产物均支持一键复制或下载

## 项目类型

原创项目。投影能力依赖开源库 moonbitstack/moonmodel（Apache-2.0），ProjDesk 在其上构建了丢弃原因分析、WASM ABI、预设样例和前端交互层。

## GitHub 仓库

https://github.com/Tino-hue/projdesk
