# ProjDesk 项目申报书

## 基本信息

- 项目名称：ProjDesk：模型工程工作台（Model Engineering Workbench）
- 参赛者：Tino-hue
- 联系方式：（请补充）
- GitHub 仓库链接：https://github.com/Tino-hue/projdesk
- 项目方向：模型工程 / 数据契约工具链 · 编译器基础设施
- 是否为移植项目：否

## 项目简介

ProjDesk 是一个纯浏览器运行的**模型工程工作台**，用 MoonBit 实现数据模型的完整生命周期管理：**定义 → 分析 → 演化 → 对比 → 验证**。

核心是五个独立的 MoonBit 算法引擎，全部手写实现，不依赖第三方库：

1. **DSL 编译器**：手写词法分析器 + 递归下降解析器 + AST 代码生成，支持 `model User { id: Big @unique }` 建模语言
2. **约束求解器**：约束冲突/冗余/不可满足性分析（空区间、蕴含、包含关系）
3. **模型迁移引擎**：结构化模型 diff + SQL ALTER TABLE 生成 + 破坏性变更检测
4. **语义等价检测**：类型子类型系统（Int→Big→Real）、约束包含、等价/子类型/不兼容判定
5. **Round-trip 验证框架**：生成→解析→比较的形式化正确性验证

投影（JSON Schema/OpenAPI/SQL/GraphQL/TypeScript/Zod/Prisma）由 moonmodel 库提供，只是工作台的一个输出环节，不是产品核心。

## 项目方向与通用性

面向所有需要管理数据模型的开发者。五个引擎（编译器、求解器、迁移、等价、验证）是通用的模型工程能力，不绑定任何特定技术栈。MoonBit 编译为 wasm-gc，纯浏览器运行。

## 预期使用场景

- **模型定义**：用 DSL 快速声明业务对象，替代繁琐的表单操作
- **约束诊断**：提交模型前自动检测约束冲突（如 least=10, most=5 的空区间）
- **安全迁移**：改模型后自动生成 ALTER TABLE，标记破坏性变更
- **版本对比**：判断两个模型是否语义等价或存在子类型关系
- **正确性验证**：round-trip 确保模型定义-解析-再生成的稳定性

## 拟实现的核心功能

- 五个 MoonBit 算法引擎（编译器/求解器/迁移/等价/验证）
- 78 个引擎专项测试 + 15 个契约测试
- WASM ABI 暴露全部引擎给前端
- 7 种投影输出（moonmodel 提供）
- 完整前端交互（编辑、诊断、迁移预览、等价对比）

## 项目类型

原创项目。moonmodel 仅提供模型数据结构与投影转换，本项目的核心工程价值是五个自研 MoonBit 算法引擎，均为独立实现，与 moonmodel 无功能重叠。

## GitHub 仓库

https://github.com/Tino-hue/projdesk

93 个 MoonBit 测试 + 60 个前端测试全绿，80+ 有效 commits。
