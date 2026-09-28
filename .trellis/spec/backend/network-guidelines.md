# 网络规范

> 本项目的 HTTP 层怎么接起来。

> **脚手架说明**：网络能力分成两半 —— **与状态管理无关**的那半在 `lib/core/data/network/`（`dio_factory.dart` 的拦截器栈），**装配**那半留在同目录的 `dio_client.dart`。各 feature 只写 Retrofit 接口（`features/{feature}/data/{feature}_api.dart`），不接触 Dio 与 Mock。

---

## 概览

| 文件 | 职责 |
| --- | --- |
| `lib/core/data/network/dio_factory.dart` | `createDio()`：拦截器栈 + 兜底解码 + Retry + Mock，**不依赖状态管理与装配层** |
| `lib/core/config/network_config.dart` | 不可变的网络配置（超时、重试次数、mock 开关） |
| `lib/core/data/network/dio_client.dart` | `networkConfigProvider` / `dioProvider`：取编译期配置、取调试开关、注册本应用专属 Mock 规则，产出的 `Dio` 必须是单例 |

**本项目无认证**：没有令牌、没有 401 自动刷新、没有 `TokenStore` 契约。需要时自行接入（见 [optional-additions.md](../../../docs/optional-additions.md)）。

---

## 配置：dotenv 只读一次

网络配置**只在 `networkConfigProvider` 一处从 `dotenv.env` 构造**（`lib/core/data/network/dio_client.dart` 的 `NetworkConfig.fromEnv(dotenv.env)`），之后所有消费者拿到的都是同一个不可变 `NetworkConfig`；`bootstrap()` 在 `ProviderScope` 装配前 fail fast。

- env 怎么加载（哪份文件、为什么换环境不能靠换文件）见 [../cross-cutting.md](../cross-cutting.md)「环境配置与 release 构建」，本文件不重复。
- 不要在别处读 `dotenv`：`NetworkConfig` 只有这一个来源。
- 测试用 `dotenv.loadFromString(...)` 造配置，或覆盖 provider：`networkConfigProvider.overrideWithValue(const NetworkConfig(baseUrl: 'http://localhost:8080/api'))`。

---

## `Dio` 必须是单例

`dioProvider` 是 `@Riverpod(keepAlive: true)`，**不能**给每个 API 客户端各建一个。它读 `userPreferencesProvider` 而**不是** `appSettingsProvider` —— 后者一变 provider 就重建；代价是调试开关**重启后生效**。

调试日志是**条件注册**的：只在 `kDebugMode && preferences.enableDebugLogging` 时才加 `PrettyDioLogger`。它的日志体会先过 `LogRedactor` 脱敏（`password` / `accessToken` / `refreshToken` 等），约定见 [logging-guidelines.md](./logging-guidelines.md)。

---

## 拦截器顺序（改之前先跑测试）

Dio 对**请求**按添加顺序正向穿过，对**响应 / 错误**按相反顺序回溯 —— 先加的在最外层、最后一个收到错误：

```
请求 →  解码 → Retry → Mock
错误 ←  解码 ← Retry ← Mock
```

这个顺序承载两条语义：**Retry 在解码之前判定** —— 重试看的是原始响应（`dio_smart_retry` 的 `defaultRetryableStatuses` 默认只覆盖 408 / 429 / 5xx，本仓 `dio_factory.dart` 只传 `retries: config.retries`，没有覆盖状态码清单），解码只作用在最后一次的响应上；**Mock 在最外层** —— 命中即短路，不发真实请求。

解码拦截器是给「后端以 `text/plain` 返回 JSON 字符串」兜底的，解析失败只记 warning、保留原始字符串。

> 改拦截器顺序或增删拦截器前，先跑 `test/core/data/network/dio_factory_test.dart` —— 它钉住 `createDio` 装出来的栈（解码 → Retry 的相对顺序、mock 开关、调试日志开关）与 `BaseOptions` 的来源。
> 断言拦截器清单时**不要直接数 `dio.interceptors.length`**：`Dio` 自己会在最前面插一个 `ImplyContentTypeInterceptor`（`msw_dio_interceptor` 还会再加一个）。按类型过滤后再断言（见 `dio_factory_test.dart` 的 `appInterceptors()`）。

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
- `:id` 这类占位符同样不被支持（也是全等比较），要写成 `r'/sample-items/\d+$'`

现有规则都在 `dio_client.dart` 的 `_registerMockRules()` 里。

> 快照（2026-09）：`GET /sample-items`、`GET /sample-items/{id}`。新增接口时照这个形状加。

---

## 常见错误

- ❌ **给某个 API 单独建 `Dio`**
- ❌ **把拦截器顺序当成无关紧要**
- ❌ **用 `MockRule(path: ...)` 写 mock 规则**
- ❌ **在 feature 里直接读环境（`String.fromEnvironment`）或自建 `NetworkConfig`** —— 配置只有 `networkConfigProvider` 一个来源
