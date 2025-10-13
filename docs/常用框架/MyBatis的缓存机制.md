# MyBatis 的缓存机制

MyBatis 的缓存机制是其性能优化的重要特性之一，用于减少数据库访问次数、提高查询效率。它主要分为 **一级缓存（本地缓存）** 和 **二级缓存（全局缓存）**。下面是详细讲解 👇

## 一级缓存（Local Cache）

### 📘 概念

- 一级缓存是 **SqlSession 级别** 的缓存。
- 默认 **开启**，无法关闭。
- 同一个 `SqlSession` 中执行的多次相同查询会从缓存中读取数据，而不再访问数据库。

### ⚙️ 工作原理

1. MyBatis 执行查询时，先在 `SqlSession` 的缓存（一个 `HashMap`）中查找是否有相同的查询结果。
2. 如果有，直接返回缓存结果。
3. 如果没有，执行 SQL 查询并将结果放入缓存中。

### 🚫 缓存失效的几种情况

一级缓存会在以下情况下失效：

- 使用了不同的 `SqlSession`；
- 执行了 `update`、`insert`、`delete` 操作（会清空缓存）；
- 手动调用 `sqlSession.clearCache()`；
- 查询参数或 SQL 不同。

### ✅ 示例

```java
SqlSession session = sqlSessionFactory.openSession();
UserMapper mapper = session.getMapper(UserMapper.class);

// 第一次查询，走数据库
User u1 = mapper.selectUserById(1);

// 第二次查询，相同 SQL，走缓存
User u2 = mapper.selectUserById(1);

System.out.println(u1 == u2); // true，同一 SqlSession
```

## 🧭 二级缓存（Global Cache）

### 📘 概念

- 二级缓存是 **Mapper 映射级别（namespace 级别）** 的缓存。
- 不同的 `SqlSession` 之间可以共享缓存。
- 默认 **关闭**，需要手动配置。

### ⚙️ 开启方式

#### 1. 全局配置中启用缓存

```xml
<settings>
    <setting name="cacheEnabled" value="true"/>
</settings>
```

#### 2. 在对应的 Mapper XML 中配置

```xml
<cache eviction="LRU" flushInterval="60000" size="512" readOnly="false"/>
```

### 💡 常用属性说明

| 属性            | 说明                                  | 默认值         |
| --------------- | ------------------------------------- | -------------- |
| `eviction`      | 缓存清除策略（LRU、FIFO、SOFT、WEAK） | LRU            |
| `flushInterval` | 自动刷新时间（毫秒）                  | 无（手动刷新） |
| `size`          | 最大缓存对象数                        | 1024           |
| `readOnly`      | 只读缓存（true 时可被多个线程共享）   | false          |

### ⚠️ 注意事项

- 二级缓存的数据是序列化到磁盘或内存的；
- 缓存的 key 由 SQL + 参数 + 环境信息 组成；
- 当执行 `insert/update/delete` 操作时，对应 namespace 的缓存会被清空；
- 只有当 `SqlSession` 关闭或提交时，一级缓存的数据才会写入二级缓存。

## 🔧 自定义缓存实现

MyBatis 提供了 `org.apache.ibatis.cache.Cache` 接口，可以自定义缓存，如使用 Redis、Ehcache 等。

示例：

```xml
<cache type="org.mybatis.caches.ehcache.EhcacheCache"/>
```

## 🧠 总结

| 缓存级别 | 作用范围          | 默认开启 | 生命周期        | 常见失效情况                 |
| -------- | ----------------- | -------- | --------------- | ---------------------------- |
| 一级缓存 | SqlSession        | ✅       | 同一 SqlSession | DML 操作、手动清空           |
| 二级缓存 | Mapper(namespace) | ❌       | 跨 SqlSession   | DML 操作、flushInterval 到期 |
