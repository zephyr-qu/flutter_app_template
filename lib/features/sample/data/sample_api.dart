import 'package:dio/dio.dart';
import 'package:my_app/features/sample/data/models/sample_item.dart';
import 'package:retrofit/retrofit.dart';

part 'sample_api.g.dart';

/// 示例条目的远程端点（Retrofit 形态）。
///
/// 路径与 `core/data/network/dio_client.dart` 注册的 Mock 规则逐一对应，
/// 开发期没有后端也能跑通；规则必须用 `MockRule.regex` 且锚定结尾
/// （见 backend/network-guidelines.md）。
@RestApi()
abstract class SampleApi {
  factory(Dio dio) = _SampleApi;

  @GET('/sample-items')
  Future<List<SampleItem>> getItems();

  @GET('/sample-items/{id}')
  Future<SampleItem> getItem(@Path('id') int id);
}
