# Java 逃逸分析

Java **逃逸分析（Escape Analysis）** 是 JVM（主要是 HotSpot）在 **JIT（Just-In-Time）编译优化阶段** 的一项重要技术，用于**分析对象的作用范围**，判断对象是否会“逃逸”出当前方法或线程，从而决定是否可以进行一些优化。

## 什么是逃逸分析？

逃逸分析的核心问题是：**一个对象是否会在当前方法或线程之外被访问到**。
JVM 通过分析代码，判断对象的“逃逸程度”，从而决定是否可以：

- 将对象分配在栈上而不是堆上；
- 消除不必要的同步；
- 进行标量替换等优化。

## 逃逸的几种类型

| 类型                          | 含义                                                               | 示例                       |
| ----------------------------- | ------------------------------------------------------------------ | -------------------------- |
| **无逃逸（No Escape）**       | 对象只在当前方法内部使用，没有返回或传递出去                       | 局部对象，仅在方法内部使用 |
| **方法逃逸（Method Escape）** | 对象作为参数传递到其他方法中，可能被外部访问                       | 调用其他方法并传入该对象   |
| **线程逃逸（Thread Escape）** | 对象被其他线程访问，比如赋值给类的成员变量、静态变量或放入共享集合 | 被其他线程共享             |

## 逃逸分析能带来的优化

### 1. 栈上分配（Stack Allocation）

如果对象不会逃逸出当前方法（**无逃逸**），那么 JVM 可以将其分配在**栈上**而不是堆上。
优点：

- 无需 GC 管理，方法结束后自动销毁；
- 大幅减少 GC 压力。

```java
public void test() {
    User user = new User(); // 如果没有逃逸，可以放在栈上
    user.setName("Tom");
    System.out.println(user.getName());
}
```

### 2. 标量替换（Scalar Replacement）

如果对象不会逃逸，JVM 甚至可以**不创建对象**，而是将对象的成员变量拆解为局部变量进行优化。

```java
class Point {
    int x;
    int y;
}
```

```java
public void calc() {
    Point p = new Point();
    p.x = 1;
    p.y = 2;
    int z = p.x + p.y;
}
```

在 JIT 优化下，`Point` 对象可能不会被真正创建，直接替换为两个局部变量 `x`、`y`。

### 3. 同步消除（Lock Elimination）

如果逃逸分析发现某个对象不会被多个线程共享，那么该对象上的同步（`synchronized`）可以被安全地移除。

```java
public void append(String s) {
    StringBuilder sb = new StringBuilder();
    sb.append(s).append(" world");
    System.out.println(sb.toString());
}
```

这里的 `StringBuilder` 是线程不安全的，但它在方法内创建并销毁，没有逃逸，所以可以安全地移除锁。

## 如何启用或查看逃逸分析

HotSpot JVM 默认**启用逃逸分析**，但你也可以手动配置参数：

| 选项                        | 说明                                 |
| --------------------------- | ------------------------------------ |
| `-XX:+DoEscapeAnalysis`     | 启用逃逸分析（默认开启）             |
| `-XX:-DoEscapeAnalysis`     | 禁用逃逸分析                         |
| `-XX:+PrintEscapeAnalysis`  | 打印逃逸分析的详细信息（JDK 8 之前） |
| `-XX:+EliminateAllocations` | 启用标量替换优化                     |
| `-XX:+EliminateLocks`       | 启用锁消除                           |

## 示例：逃逸与非逃逸

```java
// 不逃逸（可优化）
public void noEscape() {
    User u = new User();
    u.setName("Alice");
    System.out.println(u.getName());
}

// 逃逸（无法优化）
public User escape() {
    User u = new User();
    return u; // 返回对象，逃逸出方法
}
```

## 总结

| 优化手段 | 前提         | 效果               |
| -------- | ------------ | ------------------ |
| 栈上分配 | 对象无逃逸   | 减少堆内存分配     |
| 标量替换 | 对象无逃逸   | 进一步消除对象创建 |
| 锁消除   | 对象线程私有 | 减少同步开销       |

✅ **一句话总结：**
逃逸分析是 JVM JIT 的一种静态分析技术，用来判断对象的作用范围。
只要对象不逃逸，JVM 就能在运行时进行**栈上分配、标量替换、锁消除**等高级优化，从而显著提高性能、减少 GC 负担。
