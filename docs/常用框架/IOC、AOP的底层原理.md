# IOC 和 AOP 的底层原理

## IOC (控制反转) 的底层原理

### 核心思想

**控制反转 (IoC)** 是一种设计思想，它将传统上由程序代码直接操控的对象调用权交给一个**容器**来统一管理。简单说就是：**将对象的创建、依赖注入、生命周期管理的控制权从应用程序代码反转到容器（如 Spring 容器）**。

它的实现方式是依赖注入 (DI)

- **没有 IOC 时**：`Class A` 需要 `Class B` 时，`A` 会主动通过 `new B()` 来创建 `B` 的实例。控制权在 `A` 手中。
- **有 IOC 时**：`Class A` 需要 `Class B`，但它不自己创建，而是声明自己需要 `B`（比如通过构造函数、setter 方法、注解）。容器在创建 `A` 时，会发现它依赖 `B`，于是容器会创建（或查找）一个 `B` 的实例并**注入**给 `A`。控制权在容器手中。

### 底层实现原理

IOC 的底层实现可以概括为：**工厂模式 + 反射机制 + XML/注解解析**。

**关键步骤：**

1.  读取配置 (Configuration Metadata Loading)

    - 容器启动时，会读取配置文件（如 `applicationContext.xml`）或扫描指定的 Java 包（通过 `@Configuration`, `@ComponentScan` 等注解）。
    - 解析这些配置信息，确定哪些类需要被容器管理，以及它们之间的依赖关系。

2.  实例化 Bean (Bean Instantiation)

    - 根据配置信息，容器使用 **Java 反射机制 (Reflection)** 来动态地创建这些类的实例（Bean）。
    - 例如：`Class.forName("com.example.MyService").newInstance()`。这避免了在代码中写死的 `new` 关键字，实现了程序的“动态”装配。

3.  依赖注入 (Dependency Injection)

    - 容器分析已创建 Bean 的依赖关系（通过 `@Autowired`, `@Resource` 等）。
    - 容器将其管理的其他 Bean（依赖）通过**反射**设置到目标 Bean 的属性或构造函数中。
    - 例如：找到 `MyService` 中带有 `@Autowired` 的 `MyRepository` 字段，然后从容器中获取一个 `MyRepository` 实例，并通过 `field.set(myServiceInstance, myRepositoryInstance)` 的方式注入进去。

4.  管理生命周期 (Lifecycle Management)

    - 容器还负责管理 Bean 的整个生命周期，如调用初始化方法（`@PostConstruct`）、销毁方法（`@PreDestroy`）等。

5.  核心接口

- `BeanFactory`：IOC 容器的最基本接口，提供了基础的 DI 功能。它是**懒加载**的，只有在第一次请求某个 Bean 时才会创建它。
- `ApplicationContext`：`BeanFactory` 的子接口，提供了更多企业级功能（如国际化、事件传播、资源访问等）。它在**容器启动时就会预初始化所有的单例 Bean**。

**简单总结：IOC 的底层就是通过解析配置，利用反射技术动态地创建对象、组装对象之间的依赖关系，并由一个统一的容器来管理这些对象。**

## AOP (面向切面编程) 的底层原理

### 核心思想

AOP 允许将那些与核心业务逻辑无关的**横切关注点**（如日志、事务、安全等）**模块化**，然后通过声明的方式将它们**织入**到核心业务逻辑中。

- **目的**：解耦，提高代码的复用性和可维护性。你只需要关注业务逻辑，而通用功能由 AOP 统一添加。

### 底层实现原理

AOP 的底层实现主要依赖于 **动态代理 (Dynamic Proxy)** 技术。Spring AOP 默认使用两种动态代理：

`a) JDK 动态代理 (默认策略)`

- **条件**：**目标类实现了至少一个接口**。
- **原理**：
  1.  在运行时，JDK 的 `java.lang.reflect.Proxy` 类会动态地创建一个新的类（代理类）。
  2.  这个代理类实现了目标类所实现的所有接口。
  3.  代理对象内部持有一个 `InvocationHandler` 的实例（Spring 中通常是 `JdkDynamicAopProxy`）。
  4.  当调用代理对象的任何方法时，调用都会被重定向到 `InvocationHandler` 的 `invoke()` 方法。
  5.  在 `invoke()` 方法中，Spring AOP 可以执行前置通知 (@Before)、后置通知 (@After)等增强逻辑，并通过**反射** `method.invoke(target, args)` 来调用目标对象的原始方法。

`b) CGLIB 动态代理`

- **条件**：**目标类没有实现任何接口**。
- **原理**：
  1.  CGLIB (Code Generation Library) 是一个强大的、高性能的**代码生成库**。
  2.  它通过在运行时**动态生成目标类的子类**来创建代理对象。
  3.  这个子类重写了目标类的所有 **非 final** 方法。
  4.  在重写的方法中，除了调用目标方法外，还加入了增强逻辑（通知）。
  5.  因为是通过继承实现，所以**不能代理声明为 `final` 的类或方法**。

**Spring AOP 如何选择？**

- 如果目标对象实现了接口，默认使用 **JDK 动态代理**。
- 如果目标对象没有实现任何接口，则使用 **CGLIB**。
- 你也可以强制 Spring AOP 始终使用 CGLIB（在配置中添加 `@EnableAspectJAutoProxy(proxyTargetClass = true)`）。

### 核心概念与流程

- Aspect (切面)：将横切关注点模块化的类，使用 `@Aspect` 注解声明。它包含了 **Advice** 和 **Pointcut**。
- Advice (通知)：切面中的方法，定义了“何时”和“做什么”。例如：`@Before`, `@After`, `@Around`。
- Pointcut (切点)：一个表达式，定义了“在哪里”进行切入，即匹配哪些类的哪些方法。
- Weaving (织入)：将切面应用到目标对象并创建代理对象的过程。Spring AOP 在**运行时**完成织入。

**工作流程：**

1.  解析所有切面定义（`@Aspect` 类）。
2.  根据 Pointcut 表达式，为每个 Bean 计算其方法是否匹配任何 Pointcut。
3.  如果匹配，则使用**动态代理**技术为该 Bean 创建代理对象。
4.  当调用代理对象的方法时，代理会拦截调用，执行相关的 Advice 链（通知序列），并最终决定是否调用原始目标方法。

## 总结

| 特性         | IOC (控制反转)                       | AOP (面向切面编程)                         |
| :----------- | :----------------------------------- | :----------------------------------------- |
| **核心思想** | 将对象的创建和管理权交给容器         | 将横切关注点与业务逻辑分离                 |
| **实现目标** | 解耦**对象间的依赖关系**             | 解耦**通用功能与核心业务**                 |
| **底层技术** | **工厂模式**、**反射**、XML/注解解析 | **动态代理** (JDK Proxy / CGLIB)           |
| **核心概念** | Bean、容器、依赖注入(DI)             | 切面(Aspect)、通知(Advice)、切点(Pointcut) |

两者之间的关系： **AOP 的实现依赖于 IOC**。AOP 代理对象本身就是 IOC 容器所管理和注入的一个 Bean。

简单来说：

- **IOC** 是 Spring 的**基础**，它管理着所有的 Bean，包括 AOP 创建的代理对象。
- **AOP** 是 Spring 的**强大功能**，它依赖于 IOC 容器，通过动态代理技术对 IOC 容器中的 Bean 进行功能增强。
