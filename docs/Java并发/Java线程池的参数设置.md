# Java 线程池的参数设置

Java 线程池的参数设置主要通过 `ThreadPoolExecutor` 类完成。了解各个参数的含义与配置策略非常重要，因为它直接影响性能、吞吐量和系统稳定性。

下面是详细说明 👇

## 🧩 构造函数

```java
public ThreadPoolExecutor(
    int corePoolSize,          // 核心线程数
    int maximumPoolSize,       // 最大线程数
    long keepAliveTime,        // 非核心线程空闲存活时间
    TimeUnit unit,             // keepAliveTime 的时间单位
    BlockingQueue<Runnable> workQueue,  // 任务队列
    ThreadFactory threadFactory,        // 线程工厂
    RejectedExecutionHandler handler    // 拒绝策略
)
```

## ⚙️ 参数详解

| 参数名              | 说明                                                           | 常见配置策略                                                                                |
| ------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| **corePoolSize**    | 核心线程数。线程池中始终保留的线程数量，即使空闲也不会被回收。 | 通常设为：<br>• CPU 密集型任务：`CPU核心数 + 1`<br>• IO 密集型任务：`CPU核心数 × 2` 或更多  |
| **maximumPoolSize** | 最大线程数。当任务过多、队列满时可扩容到该数量。               | 一般是 `corePoolSize` 的 2~4 倍；也可以根据吞吐压力测试调整。                               |
| **keepAliveTime**   | 非核心线程空闲多久会被销毁。                                   | 一般设为几秒到几分钟，例如 `60L`。如果 `allowCoreThreadTimeOut(true)`，则核心线程也可回收。 |
| **unit**            | 时间单位（例如 `TimeUnit.SECONDS`）。                          | 常用：`SECONDS`、`MILLISECONDS`。                                                           |
| **workQueue**       | 任务队列，用于存放等待执行的任务。                             | 常见几种类型 👇                                                                             |
| **threadFactory**   | 线程工厂，用于给线程命名或设置为守护线程。                     | 可使用 `Executors.defaultThreadFactory()` 或自定义实现。                                    |
| **handler**         | 拒绝策略。当任务太多且无法接收新任务时执行的策略。             | 可选策略如下 👇                                                                             |

## 📦 常见任务队列类型（`BlockingQueue`）

| 队列类型                | 特点                         | 适用场景                           |
| ----------------------- | ---------------------------- | ---------------------------------- |
| `ArrayBlockingQueue`    | 有界队列，数组实现           | 推荐：可避免 OOM                   |
| `LinkedBlockingQueue`   | 可有界或无界（默认无界）     | 默认使用时需谨慎，可能堆积大量任务 |
| `SynchronousQueue`      | 不存储任务，直接交给线程执行 | 适用于高并发、短任务场景           |
| `PriorityBlockingQueue` | 按优先级执行任务             | 适合有优先级的任务调度             |

## 🚫 拒绝策略（`RejectedExecutionHandler`）

| 策略                  | 说明                                        |
| --------------------- | ------------------------------------------- |
| `AbortPolicy`         | 默认策略，抛出 `RejectedExecutionException` |
| `CallerRunsPolicy`    | 由提交任务的线程（调用者）执行任务          |
| `DiscardOldestPolicy` | 丢弃队列中最旧的任务，再尝试执行新任务      |
| `DiscardPolicy`       | 直接丢弃新提交的任务，不抛异常              |

## 💡 示例

```java
ExecutorService executor = new ThreadPoolExecutor(
    4,                      // corePoolSize
    8,                      // maximumPoolSize
    60L,                    // keepAliveTime
    TimeUnit.SECONDS,       // unit
    new ArrayBlockingQueue<>(100), // workQueue
    Executors.defaultThreadFactory(), // threadFactory
    new ThreadPoolExecutor.AbortPolicy() // handler
);
```

## 🧠 经验与调优建议

1. **避免使用 `Executors.newFixedThreadPool()` 等快捷方法**
   因为它们默认使用无界队列 (`LinkedBlockingQueue`)，可能导致内存溢出。

2. **根据任务类型调整参数**

   - **CPU 密集型**：线程数 ≈ CPU 核心数 + 1
   - **IO 密集型**：线程数 ≈ CPU 核心数 × 2 或更多

3. **监控线程池指标**

   - 使用 `ThreadPoolExecutor#getPoolSize()`、`getActiveCount()`、`getQueue().size()` 等方法实时监控。
   - 可结合 `JMX` 或日志采样。

4. **拒绝策略要明确**

   - 高可靠系统可用 `CallerRunsPolicy`，保证不丢任务。
   - 实时系统可用 `DiscardPolicy`，保证响应速度。
