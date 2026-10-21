# ProjDesk 3 分钟演示脚本

## 开场（20 秒）

> 「我是 ProjDesk——一定义，四张图。当你要声明一个业务对象时，不用再写四遍 schema。在这里说一次，四个世界同时看到结果。」

**展示产品三原则**（口播）：
1. 一份真相，四种投影——算法全在 MoonBit 内核
2. 诚实投影——放不下的约束，告诉你为什么
3. 演示优先——改一处，四栏同步

---

## 高潮 1：打开 User 样例，改 longest（40 秒）

1. 打开页面 → User 样例自动加载，四栏立刻有输出
2. 找到 `name` 字段的约束面板
3. 把 `longest` 从 **64** 改成 **32**
4. **指向四栏**：
   - JSON Schema：`"maxLength": 32`
   - OpenAPI：同上
   - SQL：`CHECK (length(name) <= 32)`
   - GraphQL：**不变**（丢弃报告亮起：「GraphQL SDL 不承载长度约束」）

> 「改一处，四栏同步。GraphQL 装不下？诚实告诉你。」

---

## 高潮 2：打开 id.unique（30 秒）

1. 找到 `id` 字段
2. 勾选 `unique`
3. **指向结果**：
   - SQL：出现 `UNIQUE` ✓
   - JSON Schema / OpenAPI / GraphQL：丢弃报告亮起
     - 「JSON Schema 只能表达 uniqueItems，无法表达记录级 unique」
     - 「GraphQL SDL 不承载记录级唯一约束」

> 「SQL 装得下，其他三个装不下——原因各不相同，全部诚实展示。」

---

## 高潮 3：拨动 required / nullable（30 秒）

1. 选 `avatar` 字段（当前：required=false, nullable=true）
2. 先勾选 `required`，再取消 `nullable`
3. **指向四栏差异**：
   - JSON Schema：`"required"` 数组出现 `avatar`；type 不再含 `"null"`
   - OpenAPI：`"nullable": false`
   - SQL：出现 `NOT NULL`
   - GraphQL：类型后出现 `!`

> 「required 和 nullable 是两个独立开关，四个目标的语义各不相同——这就是为什么要一次定义、四张图。」

---

## 高潮 4：跑 moon test（30 秒）

1. 切到终端
2. `cd moonbit && moon test`
3. 展示 **21 个测试全绿**
4. （可选）`moon build --target wasm-gc --release`

> 「投影算法在 MoonBit 内核，契约测试锁住语义，仓库可复现。」

---

## 收尾（20 秒）

> 「ProjDesk：元数据/契约层的一次描述、多种投影。不是 ORM，不是迁移器，不是 GraphQL 服务端——就是帮你在四个世界里把话说清楚。」

**可选加分**：展示 Trait `Projector` 扩展点、`DropReason` 类型化结果、wasm ABI 注释。
