# Redis 数据结构及应用场景总结

Redis 支持多种数据结构，每种结构都有其独特的用途和适用场景。以下是 Redis 核心数据结构及其关键特性的总结：

## String（字符串）

- **底层实现**：简单动态字符串（SDS，Simple Dynamic String），支持二进制安全。
- **用途**：
  - 缓存文本、数值、二进制数据（如图片）。
  - 计数器（`INCR`/`DECR`）。
  - 分布式锁（`SETNX`）。
- **示例命令**：
  ```bash
  SET key value
  GET key
  INCR counter
  ```

## List（列表）

- **底层实现**：
  - 早期：`ziplist`（压缩列表，内存紧凑）和 `linkedlist`（双向链表）。
  - Redis 3.2+：统一为 `quicklist`（链表 + ziplist 的混合结构）。
- **用途**：
  - 消息队列（`LPUSH` + `BRPOP`）。
  - 最新消息列表（按插入顺序存储）。
- **示例命令**：
  ```bash
  LPUSH list value
  RPOP list
  LRANGE list 0 -1
  ```

## Hash（哈希表）

- **底层实现**：
  - `ziplist`（字段较少时）或 `hashtable`（默认）。
- **用途**：
  - 存储对象（如用户信息，键对应多个字段）。
  - 避免序列化开销（可单独修改字段）。
- **示例命令**：
  ```bash
  HSET user:1 name "Alice"
  HGET user:1 name
  ```

## Set（集合）

- **底层实现**：
  - `intset`（元素为整数且数量较少时）或 `hashtable`（元素为字符串）。
- **用途**：
  - 去重存储（如标签、用户关注列表）。
  - 集合运算（`SINTER` 交集，`SUNION` 并集）。
- **示例命令**：
  ```bash
  SADD tags "redis"
  SMEMBERS tags
  ```

## Sorted Set（有序集合）

- **底层实现**：
  - `ziplist`（元素较少时）或 `跳表（skiplist）` + `hashtable`（支持快速范围查询和单键查找）。
- **用途**：
  - 排行榜（按分数排序）。
  - 范围查询（如时间区间内的数据）。
- **示例命令**：
  ```bash
  ZADD leaderboard 100 "user1"
  ZRANGE leaderboard 0 10 WITHSCORES
  ```

## 高级数据结构

### **Bitmaps**

- **本质**：基于 String 的位操作。
- **用途**：
  - 布尔统计（如用户每日签到）。
  ```bash
  SETBIT sign:user:2023 10 1  # 记录第10天签到
  BITCOUNT sign:user:2023     # 统计总签到次数
  ```

### **HyperLogLog**

- **用途**：基数统计（如 UV 统计，误差约 0.81%）。
  ```bash
  PFADD uv:2023 "user1"
  PFCOUNT uv:2023
  ```

### **Geospatial（地理空间）**

- **底层实现**：基于 Sorted Set 的 GeoHash 编码。
- **用途**：地理位置查询（如附近的人）。
  ```bash
  GEOADD cities 116.40 39.90 "Beijing"
  GEORADIUS cities 116 39 100 km
  ```

### **Stream**

- **用途**：消息队列（支持消费者组、消息持久化）。
  ```bash
  XADD mystream * field1 value1
  XREAD COUNT 10 STREAMS mystream 0
  ```

## **底层优化机制**

- **编码转换**：根据数据规模和类型自动切换底层结构（如 Hash 从 `ziplist` 转 `hashtable`）。
- **内存效率**：优先使用紧凑结构（如 `ziplist`）减少碎片。

## **选择数据结构的建议**

1. **高频更新**：优先选择时间复杂度低的结构（如 Hash 代替多个 String）。
2. **范围查询**：使用 Sorted Set 或 List。
3. **去重统计**：Set 或 HyperLogLog（根据精度需求）。
