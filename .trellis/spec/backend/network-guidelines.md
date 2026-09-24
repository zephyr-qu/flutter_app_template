# Network Guidelines

> How the HTTP layer is wired in this project.

> **Scaffold note**: 网络能力分成两半 —— **与状态管理无关**的那半在
> `lib/core/data/network/`（`dio_factory.dart` 的拦截器栈），
> **装配**那半留在同目录的 `dio_client.dart`。
> 各 feature 只写 Retrofit 接口（`features/{feature}/data/{feature}_api.dart`），
> 不接触 Dio 与 Mock。

---

## Overview

| 文件 | 职责 |
| --- | --- |
| `lib/core/data/network/dio_factory.dart` | `createDio()`：拦截器栈 + 兜底解码 + Retry + Mock，**不依赖状态管理与装配层** |
| `lib/core/config/network_config.dart` | 不可变的网络配置（超时、重试次数、mock 开关） |
| `lib/core/data/network/dio_client.dart` | `networkConfigProvider` / `dioProvider`：取 `dotenv` 配置、取调试开关、注册本应用专属 Mock 规则，产出的 `Dio` 必须是单例 |

**本项目无认证**：没有令牌、没有 401 自动刷新、没有 `TokenStore` 契约。需要时自行接入（判断规则见 [optional-additions.md](../../../docs/optional-additions.md)）。

---

## 配置：`dotenv` 只读一次

网络配置**只在 `networkConfigProvider` 一处读 `dotenv.env`**（`lib/core/data/network/dio_client.dart`），之后所有消费者拿到的都是同一个不可变 `NetworkConfig`（`bootstrap()._validateEnv` 只做存在性校验，不建配置）。

- 不要写成 `static` 类：`static` + `dotenv.env` 是全局可变状态，测试里没有干净的覆盖点，用例之间会互相污染
- 测试直接构造自己的实例即可：`const NetworkConfig(baseUrl: 'http://localhost:8080/api')`
- 正常路径走不到「`BASE_URL` 缺失」的回退值 —— `bootstrap()` 的 `_validateEnv()` 会在 `ProviderScope` 装配前 fail fast

---

## `Dio` 必须是单例

`dioProvider` 是 `@Riverpod(keepAlive: true)`，**不能**给每个 API 客户端各建一个：拦截器栈各一套会让 mock 规则重复注册、调试日志重复输出，在飞请求与重试状态也会被丢掉。

它读的是 `userPreferencesProvider` 而**不是** `appSettingsProvider`：后者一变 provider 就会被重建，而「Dio 必须单例」优先——重建会丢掉在飞请求、重放状态与 mock 注册。代价是调试开关**重启后生效**。

调试日志是**条件注册**的：只在 `kDebugMode && preferences.enableDebugLogging` 时才加 `PrettyDioLogger`。它的日志体会先过 `LogRedactor` 脱敏（`password` / `accessToken` / `refreshToken` 等），约定见 [logging-guidelines.md](./logging-guidelines.md)。

---

## 拦截器顺序（改之前先跑测试）

Dio 对**请求**按添加顺序正向穿过，对**响应 / 错误**按相反顺序回溯 —— 先加的在最外层、最后一个收到错误：

```
请求 →  解码 → Retry → Mock
错误 ←  解码 ← Retry ← Mock
```

这个顺序承载两条语义：

1. **Retry 在解码之前判定**。重试看的是原始响应（`dio_smart_retry` 默认只重试 408 / 429 / 5xx，见 `defaultRetryableStatuses`），解码只作用在最后一次的响应上。
2. **Mock 在最外层**：命中即短路，不发真实请求。

解码拦截器是给「后端以 `text/plain` 返回 JSON 字符串」兜底的，解析失败只记 warning、保留原始字符串。

> 改拦截器顺序或增删拦截器前，先跑 `test/core/data/network/dio_factory_test.dart` ——
> 它钉住 `createDio` 装出来的栈（解码 → Retry 的相对顺序、mock 开关、调试日志开关）
> 与 `BaseOptions` 的来源。
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

- Dio 的 `options.uri.path` 含 baseUrl 的路径前缀（`http://host/api` + `/sample-items` → `/api/sample-items`），而 `MockMatcher` 对 path 规则做的是**全等比较**，`path: '/sample-items'` 永远打不中
- 打不中的后果是**静默失效**：Mock 不生效，请求直接打到真实网络，本地调试会以为是后端问题
- `:id` 这类占位符同样不被支持（也是全等比较），要写成 `r'/sample-items/\d+$'`

现有规则都在 `dio_client.dart` 的 `_registerMockRules()` 里。

> 快照（2026-09）：`GET /sample-items`、`GET /sample-items/{id}`。
> 新增接口时照这个形状加。

---

## Common Mistakes

- ❌ **给某个 API 单独建 `Dio`** —— 拦截器栈各一套，Mock 与调试日志都会失效
- ❌ **把拦截器顺序当成无关紧要** —— 顺序反了会让解码拿到未重试的响应
- ❌ **用 `MockRule(path: ...)` 写 mock 规则** —— 静默失效，请求会打到真实网络
- ❌ **在 feature 里读 `dotenv` 或自建 `NetworkConfig`** —— 配置只有 `networkConfigProvider` 一个来源
