`ReentrantLock` 内部有一个继承自 AQS 的同步器（`Sync`），并且根据公平性策略，有两个具体的实现：`NonfairSync`（非公平锁）和 `FairSync`（公平锁）。它们都是通过操作 AQS 的 `state` 字段来实现锁的获取与释放。

我们以非公平锁为例，看看它是如何工作的：

## 1. 加锁过程（lock() -> acquire(1)）

假设初始状态 `state = 0`。

- 线程 A 调用 `lock()`：

  - 非公平锁会首先直接尝试“抢”一下（CAS 操作，将 state 从 0 改为 1）。
  - 如果抢成功（`compareAndSetState(0, 1)`），就将独占线程（`exclusiveOwnerThread`）设置为线程 A 自身，然后直接进入临界区。
  - 如果抢失败（因为 state 已经不是 0 了），则调用 AQS 的 `acquire(1)` 方法。

  `acquire(1)` 的模板逻辑如下：

  1.  `tryAcquire(arg)`：再次尝试获取锁（这是由`NonfairSync`实现的）。
      - 如果当前 `state == 0`，再尝试用 CAS 抢一次。
      - 如果 `state != 0`，检查当前持有锁的线程是不是自己（`current == owner`）。如果是，则 `state++`，这就是可重入的实现。
      - 如果以上都不成功，返回 false，进入下一步。
  2.  `addWaiter(Node.EXCLUSIVE)`：如果 `tryAcquire` 返回 false，说明获取失败，AQS 将当前线程包装成一个独占模式的 Node，加入到等待队列的尾部。
  3.  `acquireQueued(...)`：在队列中不断自旋尝试获取资源，如果还获取不到，就调用 `LockSupport.park()` 将线程挂起，等待被唤醒。

- 线程 B 也调用 `lock()`：
  - 同样的流程，CAS 抢锁失败，`tryAcquire` 也失败（因为 state 是 1，且 owner 是线程 A），最终线程 B 的 Node 被加入队列并挂起。

## 2. 解锁过程（unlock() -> release(1)）

- 线程 A 执行完，调用 `unlock()`：
  - 调用 AQS 的 `release(1)` 方法。
  - `release(1)` 会先调用子类实现的 `tryRelease(1)` （由`Sync`实现）：
    - 因为锁是可重入的，所以 `state--`。
    - 如果 `state` 减为 0，表示锁完全释放了，将 `exclusiveOwnerThread` 设为 null，并返回 true。
  - 如果 `tryRelease` 返回 true，AQS 会唤醒等待队列中头节点的下一个节点（即线程 B）。
- 线程 B 被唤醒：
  - 线程 B 从之前挂起的地方继续执行，再次尝试 `tryAcquire(1)`。
  - 这次因为 state 已经是 0 了，线程 B 通过 CAS 成功地将 state 设置为 1，并将 owner 设为自己，然后开始执行。
  - 线程 B 成功从队列中移除，成为新的头节点。

## 公平锁与非公平锁的区别

两者的核心区别就在于 `tryAcquire` 方法的实现：

- 非公平锁（NonfairSync.tryAcquire）：

  - 不管等待队列里有没有线程在排队，我上来就先 CAS 抢一下。抢不到再检查队列。
  - 优点：效率高，可以减少线程挂起和唤醒的开销。
  - 缺点：可能导致“饥饿”，即队列中的线程可能长期等待。

- 公平锁（FairSync.tryAcquire）：
  - 在尝试 CAS 设置 state 之前，会先调用 `hasQueuedPredecessors()` 方法检查等待队列中是否有其他线程在排队。
  - 如果有，那么当前线程自觉放弃抢锁，直接返回 false，然后把自己加入队列排队。非常“讲武德”。
  - 优点：所有线程公平获取，不会饥饿。
  - 缺点：性能开销稍大，吞吐量通常低于非公平锁。
