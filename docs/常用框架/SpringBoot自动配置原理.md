# SpringBoot 自动配置原理

## 核心思想：约定优于配置

Spring Boot 自动配置的核心思想是**约定优于配置 (Convention over Configuration)**。它预先定义了一整套的默认配置，基于你引入的依赖和现有的配置，去“猜测”你想要如何配置应用程序，并自动帮你完成这些配置。

例如，当你引入了 `spring-boot-starter-data-jpa` 和 H2 数据库的依赖后，Spring Boot 会自动为你配置一个内存级的 H2 数据库、一个 `JdbcTemplate` 和一个 `EntityManager`，你无需手动编写任何相关的 `@Bean` 配置。

自动配置的实现可以概括为以下几个关键步骤和组件：

1. 起点：`@SpringBootApplication` 注解

一切的起点都在主类上的 `@SpringBootApplication` 注解。它是一个复合注解，其中最关键的是 `@EnableAutoConfiguration`。

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

`@SpringBootApplication` 的核心组成包括：

- `@SpringBootConfiguration`: 表明这是一个配置类。
- `@ComponentScan`: 开启组件扫描，注册被 `@Component`, `@Service`, `@Controller` 等注解的 Bean。
- **`@EnableAutoConfiguration`**: **这是开启自动配置的“开关”**。

2. 核心开关：`@EnableAutoConfiguration`

`@EnableAutoConfiguration` 注解的作用是启用 Spring Boot 的自动配置机制。它的定义如下：

```java
@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class)
public @interface EnableAutoConfiguration {
    // ...
}
```

这里最关键的是 `@Import(AutoConfigurationImportSelector.class)`。它通过 `ImportSelector` 接口动态地向 Spring 容器中导入大量的自动配置类。

3. 配置类的加载：`AutoConfigurationImportSelector`

`AutoConfigurationImportSelector` 是自动配置的“大脑”，它的工作流程如下：

1.  **`getCandidateConfigurations` 方法**： 该方法会从 classpath 下所有的 jar 包中寻找一个特定的文件。
2.  **关键文件：`META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`** (在 Spring Boot 2.7 之前是 `spring.factories` 文件)。

    - Spring Boot 在自己的自动配置 jar 包 (`spring-boot-autoconfigure-xxx.jar`) 中提供了这个文件。
    - 这个文件里列出了一长串的**全限定类名**，这些就是 Spring Boot 准备好的所有**自动配置类** (`XXXAutoConfiguration`)。

    _示例 (`org.springframework.boot.autoconfigure.AutoConfiguration.imports` 文件片段)：_

    ```
    org.springframework.boot.autoconfigure.admin.SpringApplicationAdminJmxAutoConfiguration
    org.springframework.boot.autoconfigure.aop.AopAutoConfiguration
    org.springframework.boot.autoconfigure.amqp.RabbitAutoConfiguration
    org.springframework.boot.autoconfigure.batch.BatchAutoConfiguration
    org.springframework.boot.autoconfigure.cache.CacheAutoConfiguration
    org.springframework.boot.autoconfigure.cassandra.CassandraAutoConfiguration
    ... (超过100个)
    ```

3.  **筛选**： `AutoConfigurationImportSelector` 并不会把所有列出的配置类都加载进来。它会根据项目实际情况（如 classpath 下存在的类、已定义的 Bean、配置文件中的设置等）进行筛选，只加载那些**条件成立**的配置类。这个过程就叫**按需加载**。

4.  条件配置：`@Conditional` 系列注解

按需加载是如何实现的？答案就是 **`@Conditional`** 及其衍生注解。这些注解被标注在每一个自动配置类 (`XXXAutoConfiguration`) 上，决定这个配置类是否生效。

常见的条件注解有：

- **`@ConditionalOnClass`**: classpath 下存在指定的类时生效。
  - _例如：`DataSourceAutoConfiguration` 上标有 `@ConditionalOnClass({ DataSource.class, EmbeddedDatabaseType.class })`，只有在存在 `DataSource` 类时，数据源的自动配置才会生效。_
- **`@ConditionalOnBean`**: Spring 容器中存在指定的 Bean 时生效。
- **`ConditionalOnMissingBean`**: Spring 容器中**不存在**指定的 Bean 时生效。**这是覆盖自动配置的关键**。
  - _如果你自己定义了一个 `DataSource` Bean，那么这个条件不成立，Spring Boot 就不会配置它默认的数据源。_
- **`@ConditionalOnProperty`**: 指定的配置属性有特定值时生效。
- **`@ConditionalOnWebApplication`**: 当前应用是 Web 应用时生效。

5. 自动配置类：`XXXAutoConfiguration`

每个自动配置类都是一个标准的 Spring `@Configuration` 配置类。它的内部使用 `@Bean` 注解来创建所需的组件。

这些 `@Bean` 方法上也广泛使用了 `@ConditionalOnMissingBean` 等条件注解，实现了“用户有配置则用用户的，用户没配置则用我的默认的”这一策略。

以 `DataSourceAutoConfiguration` 为例（简化版）：

```java
@Configuration(proxyBeanMethods = false)
@ConditionalOnClass({DataSource.class, EmbeddedDatabaseType.class}) // 条件1：存在相关类
@ConditionalOnMissingBean(type = "DataSource") // 条件2：用户自己没有定义DataSource
@EnableConfigurationProperties(DataSourceProperties.class) // 绑定配置属性
public class DataSourceAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean // 条件3：用户没有自己定义DataSource才生效
    public DataSource dataSource(DataSourceProperties properties) {
        // 利用 properties 中的配置（如url, username, password）来创建DataSource
        return properties.initializeDataSourceBuilder().build();
    }
}
```

6. 配置属性：`@EnableConfigurationProperties` 和 `XXXProperties`

自动配置类通常会和 `XXXProperties` 类绑定。这些属性类通过 `@ConfigurationProperties` 注解，将 `application.properties` 或 `application.yml` 文件中的前缀属性映射到类的字段上。

例如，`DataSourceProperties` 绑定了 `spring.datasource` 前缀：

```java
@ConfigurationProperties(prefix = "spring.datasource")
public class DataSourceProperties {
    private String url;
    private String username;
    private String password;
    // ... getters and setters
}
```

这样，你就可以在 `application.properties` 中通过 `spring.datasource.url=jdbc:mysql://localhost/test` 来覆盖默认的数据库连接配置。

## 自动配置的完整流程

1.  **启动应用**： Spring Boot 启动，加载主配置类。
2.  **启用自动配置**： `@EnableAutoConfiguration` 注解生效。
3.  **加载候选配置**： `AutoConfigurationImportSelector` 读取 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 文件，获取所有自动配置类的列表。
4.  **过滤与筛选**： 遍历所有候选配置类，根据 `@Conditional` 等条件注解进行筛选，只加载满足条件的配置类（如 classpath 下有特定类、没有用户自定义的 Bean 等）。
5.  **执行自动配置**： 被加载的自动配置类 (`XXXAutoConfiguration`) 开始工作：
    - 它们与 `XXXProperties` 类绑定，读取用户的外部配置 (`application.properties`)。
    - 根据条件（主要是 `@ConditionalOnMissingBean`）向容器中添加默认的 `@Bean` 定义。
6.  **用户控制**： 如果用户在自己的配置中定义了某个 Bean（例如自己定义了一个 `DataSource`），则由于 `@ConditionalOnMissingBean` 条件不成立，自动配置将不会生效，从而实现了对自动配置的覆盖。

## 如何查看和调试自动配置？

- **开启调试日志**：在 `application.properties` 中添加 `debug=true`。启动时，控制台会输出一份报告，显示哪些自动配置类生效了 (`Positive matches`)，哪些没有生效 (`Negative matches`)及其原因。这是学习自动配置的绝佳方式。
- **查看 `spring-boot-autoconfigure` 源码**： 这是最直接的方式。查看这个 jar 包下的 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 文件和各个 `XXXAutoConfiguration`、`XXXProperties` 类的源码，你能最深入地理解其工作原理。
