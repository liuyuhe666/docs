# 常用的 JVM 调优参数

通常，调优的核心围绕三个方面：内存设置、垃圾回收器选择和监控诊断。

## 内存相关参数（核心）

这是调优中最常见的部分，主要指定堆内存、非堆内存及各分区的大小。

| 参数                      | 默认值 (取决于平台)    | 说明                                                                                   | 常用示例/场景                |
| :------------------------ | :--------------------- | :------------------------------------------------------------------------------------- | :--------------------------- |
| `-Xms`                    | -                      | 初始堆大小。建议与 `-Xmx` 设置相同，以避免内存伸缩带来的性能损耗。                     | `-Xms4g`                     |
| `-Xmx`                    | -                      | 最大堆大小。这是最重要的参数之一。设置得过小可能导致 OOM，过大会导致 GC 停顿时间过长。 | `-Xmx4g`                     |
| `-Xmn`                    | -                      | 年轻代大小。增大年轻代会减小老年代的大小。官方推荐设置为整个堆的 1/2 到 1/4。          | `-Xmn2g`                     |
| `-XX:NewRatio`            | `2`                    | 老年代与年轻代的大小比例。例如 `-XX:NewRatio=3` 表示老年代:年轻代=3:1。                | `-XX:NewRatio=2`             |
| `-XX:SurvivorRatio`       | `8`                    | Eden 区与一个 Survivor 区的比例。例如 `-XX:SurvivorRatio=8` 表示 Eden:From:To=8:1:1。  | `-XX:SurvivorRatio=6`        |
| `-XX:MetaspaceSize`       | -                      | Metaspace 的初始大小。JDK8+ 中 PermGen 被 Metaspace 取代。                             | `-XX:MetaspaceSize=256m`     |
| `-XX:MaxMetaspaceSize`    | 无限（受限于物理内存） | Metaspace 的最大大小。防止 Metaspace（如加载过多类）无限扩张导致内存泄漏。             | `-XX:MaxMetaspaceSize=512m`  |
| `-XX:MaxDirectMemorySize` | -                      | 直接内存（Direct Buffer）的大小限制。默认与 `-Xmx` 一致。Netty 等 NIO 框架常用。       | `-XX:MaxDirectMemorySize=1g` |
| `-Xss`                    | `1m` (JDK5+)           | 线程栈大小。减小它可以创建更多线程，但可能引发 StackOverflowError。                    | `-Xss256k`                   |

## 垃圾回收器相关参数

选择不同的垃圾回收器（GC）是调优的关键。以下是主流 GC 的常用参数。

### 1. 通用 GC 参数

| 参数                           | 说明                                           |                  |
| :----------------------------- | :--------------------------------------------- | ---------------- |
| `-XX:+UseConcMarkSweepGC`      | 启用 CMS 垃圾回收器 (JDK 9 前常用，现已不推荐) |
| `-XX:+UseG1GC`                 | 启用 G1 垃圾回收器 (JDK 9+ 的默认 GC，推荐)    |
| `-XX:+UseZGC`                  | 启用 ZGC (JDK 11+，低停顿，大堆内存神器)       |
| `-XX:+UseShenandoahGC`         | 启用 ShenandoahGC (低停顿，与 ZGC 类似)        |
| `-XX:+PrintGC` / `-verbose:gc` | 打印简单的 GC 日志                             |
| `-XX:+PrintGCDetails`          | 打印详细的 GC 日志 (非常重要)                  |
| `-XX:+PrintGCDateStamps`       | 在 GC 日志中输出时间戳                         |
| `-Xloggc:<file>`               | 将 GC 日志输出到文件                           | `-Xloggc:gc.log` |

### 2. G1 GC 专用参数

| 参数                                 | 默认值  | 说明                                                                         |
| :----------------------------------- | :------ | :--------------------------------------------------------------------------- |
| `-XX:MaxGCPauseMillis`               | `200ms` | 期望的最大 GC 停顿时间目标。G1 会尽力实现，但不保证。                        |
| `-XX:InitiatingHeapOccupancyPercent` | `45`    | 触发 Mixed GC 的堆占用阈值。当老年代占整个堆的比例超过此值时，启动并发周期。 |
| `-XX:G1ReservePercent`               | `10`    | 设置堆的保留内存比例，防止晋升失败。                                         |

### 3. Parallel GC / CMS GC 参数 (传统 GC，了解即可)

| 参数                       | 说明                                                        |
| :------------------------- | :---------------------------------------------------------- |
| `-XX:ParallelGCThreads`    | 设置并行 GC 的线程数。                                      |
| `-XX:MaxTenuringThreshold` | 对象晋升老年代的年龄阈值（经过多少次 GC 后存活）。默认 15。 |

## 监控、诊断与故障排除参数

这些参数用于生成堆转储、分析内存泄漏、监控 JVM 状态等。

| 参数                                      | 说明                                                                         | 场景                                                      |
| :---------------------------------------- | :--------------------------------------------------------------------------- | :-------------------------------------------------------- |
| `-XX:+HeapDumpOnOutOfMemoryError`         | 在发生 OOM 时自动生成堆转储文件 (heap dump)。                                | 排查内存泄漏必备                                          |
| `-XX:HeapDumpPath=<path>`                 | 指定堆转储文件的保存路径。                                                   | `-XX:HeapDumpPath=./java_pid%p.hprof`                     |
| `-XX:NativeMemoryTracking=summary/detail` | 开启 Native Memory 追踪。用于分析 JVM 自身（线程、Metaspace 等）的内存使用。 | `-XX:NativeMemoryTracking=detail`，然后用 `jcmd` 命令查看 |
| `-XX:+PrintFlagsFinal`                    | 打印所有 JVM 参数的最终值。可用于查看参数的默认值。                          | `java -XX:+PrintFlagsFinal -version \| grep NewRatio`     |
| `-XX:+DisableExplicitGC`                  | 禁止在代码中调用 `System.gc()`。建议开启，防止代码中的误调用触发 Full GC。   |                                                           |

## 常用调优命令与工具

1.  查看 JVM 参数运行值：
    ```bash
    jinfo -flags <pid>
    ```
2.  查看 Java 进程：
    ```bash
    jps -l
    ```
3.  监控 JVM 状态：
    ```bash
    jstat -gcutil <pid> 1s  # 每秒打印一次GC和内存利用率摘要
    ```
4.  生成堆转储（手动）：
    ```bash
    jmap -dump:live,format=b,file=heap.hprof <pid>
    ```
5.  分析 NMT：
    ```bash
    jcmd <pid> VM.native_memory summary
    ```

## 一个典型的调优参数示例

这是一个面向 Web 服务（如 Spring Boot 应用）的常见配置，使用 `G1 GC`：

```bash
java -Xms4g -Xmx4g \          # 堆内存固定为4G，避免动态调整
     -Xmn2g \                 # 年轻代2G (约为堆的1/2)
     -XX:MetaspaceSize=256m \ # Metaspace初始大小
     -XX:MaxMetaspaceSize=512m \ # 限制Metaspace大小
     -XX:+UseG1GC \           # 使用G1垃圾回收器
     -XX:MaxGCPauseMillis=200 \ # 目标停顿200ms
     -XX:InitiatingHeapOccupancyPercent=45 \ # IHOP阈值
     -XX:+PrintGCDetails \    # 打印详细GC日志
     -XX:+PrintGCDateStamps \ # 带时间戳
     -Xloggc:/opt/app/logs/gc.log \ # GC日志输出到文件
     -XX:+HeapDumpOnOutOfMemoryError \ # OOM时生成Dump
     -XX:HeapDumpPath=/opt/app/logs \ # Dump文件路径
     -jar my-application.jar
```

## 总结

- 上述参数是通用建议，最佳配置需要通过压力测试和监控 GC 日志来不断调整。
- 先监控，后调优：使用 `jstat`, `visualvm`, `GCeasy` (在线 GC 日志分析), `Arthas` 等工具分析现状，找到瓶颈（是频繁 Young GC？还是 Full GC？），再有针对性地调整。
- 优先升级：很多时候，升级 JDK 版本（如从 JDK 8 升级到 JDK 17+ 并使用 ZGC）比在旧版本上费力调优效果更显著。
