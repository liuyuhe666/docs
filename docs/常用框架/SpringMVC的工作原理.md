# SpringMVC 的工作原理

SpringMVC（Spring Web MVC）是 Spring Framework 提供的一个 **基于模型-视图-控制器（MVC）设计模式** 的 Web 框架，用于简化 Web 应用的开发。
它的核心目标是把 **请求处理、业务逻辑、视图渲染** 分离开，使系统更清晰、易扩展、可维护。

## 🌐 SpringMVC 的整体工作流程

下面是 SpringMVC 的典型工作原理（请求执行流程）：

```
客户端（浏览器）
    ↓
DispatcherServlet（前端控制器）
    ↓
HandlerMapping（处理器映射器）
    ↓
Handler（处理器 / Controller）
    ↓
HandlerAdapter（处理器适配器）
    ↓
ModelAndView（模型与视图）
    ↓
ViewResolver（视图解析器）
    ↓
View（视图渲染）
    ↓
响应结果返回客户端
```

## ⚙️ 详细流程说明（逐步分析）

### 1️⃣ 客户端发送请求

用户通过浏览器访问一个 URL，比如：

```
http://localhost:8080/user/list
```

这个请求会先被 `DispatcherServlet`（前端控制器）拦截。

> 在 web.xml 或 Spring Boot 自动配置中，`DispatcherServlet` 是所有请求的入口。

### 2️⃣ DispatcherServlet 接收到请求

`DispatcherServlet` 是 SpringMVC 的核心组件，负责整个请求流程的调度。

它不处理业务逻辑，而是：

- 查找处理请求的控制器（Controller）
- 调用对应的处理器适配器
- 调用视图解析器渲染结果

### 3️⃣ HandlerMapping：查找处理器

`DispatcherServlet` 会通过 **`HandlerMapping`** 根据 URL 找到对应的 **处理器（Handler）**。

比如：

```java
@Controller
@RequestMapping("/user")
public class UserController {

    @GetMapping("/list")
    public String list(Model model) {
        model.addAttribute("users", userService.findAll());
        return "userList";
    }
}
```

`HandlerMapping` 根据请求 `/user/list` 找到 `UserController.list()` 方法。

### 4️⃣ HandlerAdapter：调用控制器方法

找到控制器后，SpringMVC 还需要一个 **`HandlerAdapter`（处理器适配器）** 来执行它。

适配器的作用是屏蔽不同类型控制器之间的差异，使 DispatcherServlet 不必关心具体的调用细节。

### 5️⃣ 执行 Controller（Handler）

`HandlerAdapter` 负责真正调用 `Controller` 中的方法。

控制器执行后通常会返回：

- 逻辑视图名（如 `"userList"`）
- 或一个 `ModelAndView` 对象，包含模型数据和视图名。

### 6️⃣ 返回 ModelAndView

控制器执行后返回：

```java
return new ModelAndView("userList", model);
```

或简化为：

```java
return "userList";
```

DispatcherServlet 接收这个结果，准备进入视图解析阶段。

### 7️⃣ ViewResolver：解析视图

`DispatcherServlet` 会调用 **`ViewResolver`（视图解析器）**，把逻辑视图名解析成真正的视图对象（通常是 JSP、Thymeleaf 模板、Freemarker 等）。

例如：

- 逻辑视图名 `"userList"`
- 视图解析器配置：

  ```properties
  spring.mvc.view.prefix=/WEB-INF/views/
  spring.mvc.view.suffix=.jsp
  ```

- 解析结果：`/WEB-INF/views/userList.jsp`

### 8️⃣ View 渲染

视图（View）拿到模型数据 `Model`，渲染成最终的 HTML 页面。

最终结果通过 `DispatcherServlet` 返回给客户端。

## 🧩 SpringMVC 核心组件总结

| 组件                      | 角色         | 作用                            |
| ------------------------- | ------------ | ------------------------------- |
| **DispatcherServlet**     | 前端控制器   | 统一请求入口，调度其他组件      |
| **HandlerMapping**        | 处理器映射器 | 根据 URL 找到对应的 Controller  |
| **HandlerAdapter**        | 处理器适配器 | 执行对应的 Controller 方法      |
| **Handler（Controller）** | 处理器       | 执行业务逻辑，返回 ModelAndView |
| **ModelAndView**          | 模型与视图   | 封装返回的数据和视图信息        |
| **ViewResolver**          | 视图解析器   | 将逻辑视图名解析成具体视图      |
| **View**                  | 视图         | 渲染页面，生成响应内容          |

## 🧠 简单示意图

```
        +----------------------+
        |  DispatcherServlet   |
        +----------+-----------+
                   |
                   v
        +----------+-----------+
        |     HandlerMapping   |
        +----------+-----------+
                   |
                   v
        +----------+-----------+
        |      Controller       |
        +----------+-----------+
                   |
                   v
        +----------+-----------+
        |    ViewResolver       |
        +----------+-----------+
                   |
                   v
              [HTML 页面输出]
```

## 📘 SpringMVC 的优点

- ✅ 职责分明：清晰的 MVC 分层结构

- ✅ 松耦合：各组件独立可替换

- ✅ 可扩展性强：支持自定义拦截器、视图解析器、异常解析器等

- ✅ 与 Spring 无缝集成：可方便使用 IoC、AOP、事务管理等特性
