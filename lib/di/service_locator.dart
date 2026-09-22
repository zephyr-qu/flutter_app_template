import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:my_app/di/service_locator.config.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() => getIt.init();
