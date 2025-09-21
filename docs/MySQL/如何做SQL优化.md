# 如何做 SQL 优化

## 核心优化思路

1.  发现问题：首先要知道哪里慢。使用监控工具（如慢查询日志）找到消耗资源最多、执行时间最长的 SQL 语句。
2.  分析原因：为什么慢？是因为全表扫描？内存不够？锁冲突？还是数据库结构设计问题？
3.  解决问题：针对性地采取优化措施，如添加索引、重写 SQL、调整数据库配置等。
4.  持续迭代：优化是一个持续的过程，需要不断观察和调整。

## 方法论和步骤

第 1 步：识别瓶颈（发现慢 SQL）

- 开启慢查询日志 (Slow Query Log)：这是最重要的一步。在 MySQL 等数据库中开启慢查询日志，记录所有执行时间超过指定阈值的 SQL 语句。
  - MySQL 设置示例（在 `my.cnf` 中）:
    ```ini
    slow_query_log = 1
    slow_query_log_file = /var/log/mysql/mysql-slow.log
    long_query_time = 2   # 执行时间超过2秒的SQL会被记录
    log_queries_not_using_indexes = 1 # 记录未使用索引的查询（谨慎开启，可能日志量巨大）
    ```
- 使用性能分析工具：
  - `EXPLAIN` / `EXPLAIN ANALYZE` (后面详细讲解)
  - 监控平台：如 Prometheus + Grafana 监控数据库的 QPS、连接数、缓存命中率等关键指标。
  - 数据库自带工具：如 MySQL 的 `SHOW PROCESSLIST` 查看当前正在执行的 SQL 和状态。

第 2 步：分析执行计划（读懂 EXPLAIN）

拿到慢 SQL 后，使用 `EXPLAIN` 关键字查看数据库是如何执行这条 SQL 的。这是 SQL 优化的核心工具。

EXPLAIN 关键字段解读（以 MySQL 为例）：

- type：访问类型，非常重要！从好到坏大致是：
  - `system` > `const` > `eq_ref` > `ref` > `range` > `index` > `ALL`
  - 至少要优化到 `range` 级别，最好能达到 `ref`。
  - `ALL`：全表扫描，最差的情况，必须优化。
- key：实际使用的索引。如果为 NULL，则未使用索引。
- rows：预估需要读取的行数。数值越小越好。
- Extra：包含额外信息，常见的重要值：
  - `Using filesort`：表示 MySQL 无法利用索引完成排序，需要额外的排序操作，开销大。
  - `Using temporary`：使用了临时表，常见于排序和分组查询，性能极差。
  - `Using index`：覆盖索引，表示查询只需要通过索引就可以获取所需数据，无需回表，性能极佳。

示例：

```sql
EXPLAIN SELECT * FROM users WHERE name = '张三';
```

分析输出结果，如果 `type` 是 `ALL`，`key` 是 `NULL`，说明进行了全表扫描，你需要为 `name` 字段建立索引。

更强大的 `EXPLAIN ANALYZE` (MySQL 8.0+, PostgreSQL)
它会实际执行查询，并输出详细的执行时间和实际花费的行数，比 `EXPLAIN` 的预估更准确。

第 3 步：采取优化措施

1. 索引优化（最常用、最有效）

- 确保索引有效：
  - 为 `WHERE`, `ORDER BY`, `GROUP BY`, `JOIN ON` 子句中的字段建立索引。
  - 使用复合索引（联合索引）并遵守最左前缀原则。
    - 例如创建索引 `idx_age_name (age, name)`，那么 `WHERE age = ?` 和 `WHERE age = ? AND name = ?` 都能用到索引，但 `WHERE name = ?` 用不到。
- 避免索引失效：
  - 不要在索引列上进行运算、函数操作或类型转换。`WHERE YEAR(create_time) = 2023` 会导致索引失效。
  - 使用 `LIKE` 时，前缀模糊匹配 `‘%abc’` 会导致索引失效，后缀匹配 `‘abc%’` 可以使用索引。
  - 使用 `OR` 要小心，如果 `OR` 的条件中有一个字段没索引，整个查询可能会全表扫描。
  - 使用 `!=` 或 `<>` 通常会导致索引失效。
- 利用覆盖索引：让索引包含查询所需的所有字段，避免回表（访问数据行）。
  - 坏：`SELECT * FROM table WHERE key = ?` （即使 key 有索引，`SELECT *` 也可能需要回表）
  - 好：`SELECT id, name FROM table WHERE key = ?` （如果索引是 `(key, name, id)`，则无需回表）

2. SQL 语句优化

- 避免 `SELECT *`：只取需要的字段，减少网络传输和数据量，更利于覆盖索引。
- 优化分页查询：
  - 糟糕的分页：`SELECT * FROM table LIMIT 1000000, 20;` （会取出 1000020 行然后扔掉 1000000 行）
  - 优化方案：使用子查询或利用上一页的主键 ID。
    ```sql
    SELECT * FROM table WHERE id > 1000000 ORDER BY id LIMIT 20;
    ```
- 避免使用 `OR` 来连接多个条件：可改用 `UNION` 或 `UNION ALL`。
  - 坏：`SELECT * FROM t WHERE a = 1 OR b = 2`
  - 好：`SELECT * FROM t WHERE a = 1 UNION ALL SELECT * FROM t WHERE b = 2` (前提是 a, b 都有索引)
- 使用 `EXISTS` 代替 `IN`：对于大数据集，`EXISTS` 通常比 `IN` 性能更好。
  - `SELECT * FROM A WHERE id IN (SELECT id FROM B)` →
  - `SELECT * FROM A WHERE EXISTS (SELECT 1 FROM B WHERE B.id = A.id)`
- JOIN 优化：
  - `JOIN` 的表字段都要有索引，并且类型要一致，否则会触发隐式类型转换导致索引失效。
  - 小表驱动大表。MySQL 的 Nested-Loop Join 算法中，应该让结果集小的表做驱动表。

3. 数据库设计优化

- 选择合适的数据类型：越小越好，越简单越好。例如用 `INT` 而不是 `VARCHAR` 存数字，用 `DATETIME` 而不是 `VARCHAR` 存时间。
- 适度规范化：通常遵循第三范式，但有时为了性能可以反规范化，通过空间换时间（例如增加冗余字段避免多表 JOIN）。
- 垂直拆分/水平拆分（分库分表）：
  - 垂直拆分：将不常用的字段或大字段（如 TEXT/BLOB）拆分到扩展表中。
  - 水平拆分（分表）：当单表数据量过大时（如超过千万级），按某种规则（如时间、ID 哈希）将数据分布到多个结构相同的表中。这是最后的手段，会极大增加应用复杂度。

4. 系统配置优化

- 调整缓冲区大小：如 `innodb_buffer_pool_size` (MySQL InnoDB 引擎)，这是 InnoDB 最重要的配置，应设置为可用内存的 70%-80%，用于缓存数据和索引。
- 调整连接数：`max_connections`。

_注意：系统配置优化需要根据服务器硬件和具体 workload 进行调整，最好有 DBA 参与。_

## 总结

当遇到慢 SQL 时，可以按以下顺序排查：

1.  用 `EXPLAIN` 分析：查看执行计划，重点关注 `type`, `key`, `rows`, `Extra`。
2.  检查索引：
    - 是否缺少索引？（`WHERE`, `ORDER BY`, `GROUP BY` 的字段）
    - 是否使用了错误的索引？（`key` 字段）
    - 索引是否失效？（函数、运算、类型转换、模糊查询）
    - 是否可以应用覆盖索引？（`Extra: Using index`）
3.  检查 SQL 语句：
    - 是否用了 `SELECT *`？
    - 分页是否高效？
    - `OR`, `IN`, `LIKE` 使用是否合理？
    - 是否有不必要的子查询？
4.  检查表结构：
    - 字段类型是否合理？
    - 是否需要进行范式/反范式优化？
5.  考虑系统层面：
    - 数据库参数配置是否合理？（如缓冲池大小）
    - 硬件资源（CPU、内存、磁盘 IO）是否瓶颈？
