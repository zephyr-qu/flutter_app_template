# Network Guidelines

> How the HTTP layer is wired in this project.

> **Scaffold note**: 网络能力分成两半 —— **与状态管理无关**的那半在
> `lib/core/data/network/`（`dio_factory.dart` 只看配置与 `TokenStore`，
> **不知道 signals / DI 的存在**），**装配**那半留在同目录的 `dio_client.dart`。
> 各 feature 只写 Retrofit 接口（`features/{feature}/data/{feature}_api.dart`），
> 不接触 Dio、令牌、Mock。

---

## Overview

| 文件 | 职责 |
| --- | --- |
| `lib/core/data/network/dio_factory.dart` | `createDio()`：拦截器栈 + 兜底解码 + Retry + Mock，**不知道 signals / Riverpod 的存在** |
| `lib/core/data/network/auth_interceptor.dart` | 请求附加令牌；401 时刷新并重放；刷新用尽则清凭证 |
| `lib/core/data/network/token_refresher.dart` | single-flight 换令牌 |
| `lib/core/data/network/token_store.dart` | 令牌存取的**能力契约**（`ready` / 读写 / 过期判断 / 清除），各栈自己实现 |
| `lib/core/data/network/auth_extra_keys.dart` | `RequestOptions.extra` 的两个标记键 |
| `lib/core/config/network_config.dart` | 不可变的网络配置（超时、重试次数、mock 开关） |
| `lib/core/data/network/dio_client.dart` | `NetworkModule`：构造编译期 `NetworkConfig`、取调试开关、注册本应用专属 Mock 规则，产出的 `Dio` 必须是单例 |

`TokenStore` 是这层的反转点：网络层只依赖它，令牌存在哪里（安全存储 + 内存缓存）
以及登录态用哪种状态管理暴露，都不是网络层该知道的事。本项目的实现是
`lib/core/data/storage/auth_storage.dart`。代价是网络层测试要用假 `TokenStore` 驱动
（`test/core/support/` 的 `fake_token_store.dart`）。

401 刷新的完整约定在 [error-handling.md](./error-handling.md#401-与令牌刷新)，本页不重复。

---

## 配置：只有一个来源

`NetworkModule.networkConfig()` 是**全项目唯一**构造 `NetworkConfig` 的地方（内部读 `--dart-define`
注入的编译期常量），之后所有消费者拿到的都是同一个不可变 `NetworkConfig`。

- 不要写成 `static` 类：`static` 字段是全局可变状态，测试里没有干净的覆盖点，用例之间会互相污染
- 测试直接构造自己的实例即可：`const NetworkConfig(baseUrl: 'http://localhost:8080/api')`
- 正常路径走不到「`BASE_URL` 缺失」的回退值 —— `bootstrap()` 会在 DI 初始化前 fail fast

---

## `Dio` 必须是单例

`NetworkModule.dio` 用 `@lazySingleton`，**不能**给每个 API 客户端各建一个。理由与后果见 [error-handling.md](./error-handling.md#401-与令牌刷新) 的约束列表（single-flight 失效会误登出用户；mock 规则会重复注册）。

调试日志是**条件注册**的：只在 `kDebugMode && preferences.enableDebugLogging.value` 时才加 `PrettyDioLogger`。它的日志体会先过 `LogRedactor` 脱敏（`password` / `accessToken` / `refreshToken` 等），约定见 [logging-guidelines.md](./logging-guidelines.md)。

---

## 拦截器顺序（改之前先跑测试）

Dio 对**请求**按添加顺序正向穿过，对**响应 / 错误**按相反顺序回溯 —— 先加的在最外层、最后一个收到错误：

```
请求 →  Auth → 解码 → Retry → Mock
错误 ←  Auth ← 解码 ← Retry ← Mock
```

这个顺序承载两条语义，都不能破：

1. **Retry 先看到错误，但不能吞掉 401**。`dio_smart_retry` 默认只重试 408 / 429 / 5xx（`defaultRetryableStatuses`），401 不在其中，会原样穿过交给 `AuthInterceptor` 处理。
2. **重放必须走完整条链**。`AuthInterceptor` 持有的是同一个 Dio 实例，刷新成功后的 `_dio.fetch(options)` 会**从头**再过一遍 mock / 解码 / 重试。这正是它不自建「干净」客户端的原因 —— 否则 mock 模式下重放会直接打到真实网络。

解码拦截器是给「后端以 `text/plain` 返回 JSON 字符串」兜底的，解析失败只记 warning、保留原始字符串。

> 改拦截器顺序或增删拦截器前，先跑这两个：
>
> - `test/core/data/network/dio_factory_test.dart` —— 钉住 `createDio`
>   装出来的栈（Auth → 解码 → Retry 的相对顺序、mock 开关、调试日志开关），
>   以及「Retry 不吞 401 / 5xx 走重试」两条语义
> - `test/core/data/network/interceptor_stack_test.dart` —— 钉住 lib 侧
>   `NetworkModule.dio()` 的等价行为（同一套栈，另加 `UserPreferences` / `NetworkConfig` 装配）
>
> 别拿 `token_refresh_test.dart` 当替代：它自建的 Dio 只挂了 `AuthInterceptor`，
> 那条链上根本不存在 Retry，上面两点它验不到。
>
> 断言拦截器清单时**不要直接数 `dio.interceptors.length`**：`Dio` 自己会在最前面插一个
> `ImplyContentTypeInterceptor`（`msw_dio_interceptor` 还会再加一个），数量断言会变成
> 对 Dio 内部实现的测试。按类型过滤后再断言（见 `dio_factory_test.dart` 的
> `appInterceptors()`）。

---

## Mock

Mock 只在 `NetworkConfig.isMock`（环境变量 `USE_MOCK=true`）时注册。

```dart
if (config.isMock) {
  dio.interceptors.add(MockInterceptor(engine: MockHttpEngine()));
  _registerMockRules();
}
```

**必须用 `MockRule.regex` 且锚定 URL 结尾，不能用 `MockRule(path: ...)`**：

- Dio 的 `options.uri.path` 含 baseUrl 的路径前缀（`http://host/api` + `/login` → `/api/login`），而 `MockMatcher` 对 path 规则做的是**全等比较**，`path: '/login'` 永远打不中
- 打不中的后果是**静默失效**：Mock 不生效，请求直接打到真实网络，本地调试会以为是后端问题
- `:id` 这类占位符同样不被支持（也是全等比较），要写成 `r'/articles/\d+$'`

现有规则都在 `dio_client.dart` 的 `_registerMockRules()` 里（写这份 spec 时是
`GET /articles`、`GET /articles/{id}`、`POST /login`、`POST /refresh`）。新增接口时照这个形状加。

---

## `extra` 标记而不是判断 URL

「这次请求的语义」通过 `RequestOptions.extra` 传递（键在 `auth_extra_keys.dart`），**不要**按 URL 或路径去猜：

- `kSkipAuthRefresh` —— 这个请求本身就是刷新请求
- `kAuthRetried` —— 这个请求已经用新令牌重放过一次

重放时 `RequestOptions` 被原样复用，标记自动跟着走；按 URL 判断则要维护一份「哪些路径算刷新接口」的映射。

---

## Common Mistakes

- ❌ **给某个 API 单独建 `Dio`** —— 拦截器栈各一套，single-flight 与 Mock 都会失效
- ❌ **在业务代码里自己加 `Authorization` 头** —— 交给 `AuthInterceptor`，否则会出现两套令牌来源
- ❌ **把拦截器顺序当成无关紧要** —— 顺序反了会让 Retry 吞掉 401，或让重放绕开 Mock
- ❌ **用 `MockRule(path: ...)` 写 mock 规则** —— 静默失效，请求会打到真实网络
- ❌ **在 feature 里自建 `NetworkConfig`** —— 配置只有 `networkConfig()` 一个来源
- ❌ **在拦截器里做页面跳转** —— 拦截器没有 `BuildContext`；只清凭证，导航由路由守卫负责（见 [error-handling.md](./error-handling.md#登出语义)）
