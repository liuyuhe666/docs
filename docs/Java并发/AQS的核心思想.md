# AQS 的核心思想

AQS（AbstractQueuedSynchronizer，抽象队列同步器）是 Java 并发包（`java.util.concurrent.locks`）的核心基础组件。它的核心思想可以概括为：

“一个状态位（state） + 一个 FIFO 线程等待队列（CLH 变种）”，通过模板方法模式，让子类通过继承并管理这个状态位（state）来实现各种同步器（如锁、信号量等）。

具体来说，其核心思想包含三个关键点：

1.  共享的状态变量（state）：

    - 这是一个 `volatile int` 类型的变量，用于表示同步状态。
    - 不同的用法代表不同的含义，这正是 AQS 灵活和强大的地方。例如：
      - 在 `ReentrantLock` 中，`state=0` 表示锁未被占用，`state=1` 表示锁被占用，`state>1` 表示锁被同一个线程重入。
      - 在 `Semaphore` 中，`state` 表示剩余的许可证数量。
      - 在 `CountDownLatch` 中，`state` 表示计数器的初始值。

2.  一个 FIFO 的线程等待队列（CLH 队列的变体）：

    - 当多个线程竞争共享状态 `state` 失败时，AQS 会将当前线程以及等待状态（如独占或共享）包装成一个节点（Node），并将其加入一个先进先出（FIFO）的双向队列中阻塞等待。
    - 当持有同步状态的线程释放资源时，会从这个队列里唤醒一个或多个线程，让它们再次尝试获取状态。

3.  期望子类实现的获取/释放方法：
    - AQS 采用了模板方法模式，它定义了顶级逻辑骨架（如获取资源、释放资源的入口方法 `acquire`、`release`），而将一些关键操作（如何具体获取和释放资源）以 protected 方法的形式留给子类去实现。
    - 子类需要根据是独占模式（如 ReentrantLock）还是共享模式（如 Semaphore）来重写以下方法：
      - `tryAcquire(int arg)`：尝试以独占方式获取资源。
      - `tryRelease(int arg)`：尝试以独占方式释放资源。
      - `tryAcquireShared(int arg)`：尝试以共享方式获取资源。
      - `tryReleaseShared(int arg)`：尝试以共享方式释放资源。
      - `isHeldExclusively()`：当前同步器是否被当前线程独占。

工作流程简述：

- 线程 A 调用`acquire(1)`：
  1.  先调用子类实现的 `tryAcquire(1)` 尝试直接获取资源（操作 state）。
  2.  如果成功，线程 A 直接执行临界区代码。
  3.  如果失败，AQS 会将线程 A 包装成 Node，加入等待队列并可能将其挂起（park）。
- 线程 B 调用`release(1)`：
  1.  先调用子类实现的 `tryRelease(1)` 尝试释放资源（操作 state）。
  2.  如果成功，AQS 会从等待队列中唤醒头节点的下一个有效节点（线程）。
  3.  被唤醒的线程（线程 A）会再次尝试调用 `tryAcquire(1)` 获取资源。
