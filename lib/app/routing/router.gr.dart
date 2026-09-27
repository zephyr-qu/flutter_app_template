// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'router.dart';

/// generated route for
/// [ArticleDetailPage]
class ArticleDetailRoute extends PageRouteInfo<ArticleDetailRouteArgs> {
  ArticleDetailRoute({
    required int articleId,
    Key? key,
    ArticleViewModel? viewModel,
    List<PageRouteInfo>? children,
  }) : super(
         ArticleDetailRoute.name,
         args: ArticleDetailRouteArgs(
           articleId: articleId,
           key: key,
           viewModel: viewModel,
         ),
         initialChildren: children,
       );

  static const String name = 'ArticleDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ArticleDetailRouteArgs>();
      return ArticleDetailPage(
        articleId: args.articleId,
        key: args.key,
        viewModel: args.viewModel,
      );
    },
  );
}

class ArticleDetailRouteArgs {
  const ArticleDetailRouteArgs({
    required this.articleId,
    this.key,
    this.viewModel,
  });

  final int articleId;

  final Key? key;

  final ArticleViewModel? viewModel;

  @override
  String toString() {
    return 'ArticleDetailRouteArgs{articleId: $articleId, key: $key, viewModel: $viewModel}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArticleDetailRouteArgs) return false;
    return articleId == other.articleId &&
        key == other.key &&
        viewModel == other.viewModel;
  }

  @override
  int get hashCode => articleId.hashCode ^ key.hashCode ^ viewModel.hashCode;
}

/// generated route for
/// [ArticleListPage]
class ArticleListRoute extends PageRouteInfo<ArticleListRouteArgs> {
  ArticleListRoute({
    Key? key,
    ArticleViewModel? viewModel,
    List<PageRouteInfo>? children,
  }) : super(
         ArticleListRoute.name,
         args: ArticleListRouteArgs(key: key, viewModel: viewModel),
         initialChildren: children,
       );

  static const String name = 'ArticleListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ArticleListRouteArgs>(
        orElse: () => const ArticleListRouteArgs(),
      );
      return ArticleListPage(key: args.key, viewModel: args.viewModel);
    },
  );
}

class ArticleListRouteArgs {
  const ArticleListRouteArgs({this.key, this.viewModel});

  final Key? key;

  final ArticleViewModel? viewModel;

  @override
  String toString() {
    return 'ArticleListRouteArgs{key: $key, viewModel: $viewModel}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArticleListRouteArgs) return false;
    return key == other.key && viewModel == other.viewModel;
  }

  @override
  int get hashCode => key.hashCode ^ viewModel.hashCode;
}

/// generated route for
/// [HomePage]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomePage();
    },
  );
}

/// generated route for
/// [LoginPage]
class LoginRoute extends PageRouteInfo<LoginRouteArgs> {
  LoginRoute({
    Key? key,
    AuthViewModel? viewModel,
    List<PageRouteInfo>? children,
  }) : super(
         LoginRoute.name,
         args: LoginRouteArgs(key: key, viewModel: viewModel),
         initialChildren: children,
       );

  static const String name = 'LoginRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return LoginPage(key: args.key, viewModel: args.viewModel);
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.viewModel});

  final Key? key;

  final AuthViewModel? viewModel;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, viewModel: $viewModel}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return key == other.key && viewModel == other.viewModel;
  }

  @override
  int get hashCode => key.hashCode ^ viewModel.hashCode;
}

/// generated route for
/// [MainPage]
class MainRoute extends PageRouteInfo<void> {
  const MainRoute({List<PageRouteInfo>? children})
    : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MainPage();
    },
  );
}

/// generated route for
/// [NotFoundPage]
class NotFoundRoute extends PageRouteInfo<void> {
  const NotFoundRoute({List<PageRouteInfo>? children})
    : super(NotFoundRoute.name, initialChildren: children);

  static const String name = 'NotFoundRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NotFoundPage();
    },
  );
}

/// generated route for
/// [ProfilePage]
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfilePage();
    },
  );
}

/// generated route for
/// [SplashPage]
class SplashRoute extends PageRouteInfo<void> {
  const SplashRoute({List<PageRouteInfo>? children})
    : super(SplashRoute.name, initialChildren: children);

  static const String name = 'SplashRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SplashPage();
    },
  );
}

/// generated route for
/// [StorageDemoPage]
class StorageDemoRoute extends PageRouteInfo<StorageDemoRouteArgs> {
  StorageDemoRoute({
    Key? key,
    StorageDemoViewModel? viewModel,
    List<PageRouteInfo>? children,
  }) : super(
         StorageDemoRoute.name,
         args: StorageDemoRouteArgs(key: key, viewModel: viewModel),
         initialChildren: children,
       );

  static const String name = 'StorageDemoRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<StorageDemoRouteArgs>(
        orElse: () => const StorageDemoRouteArgs(),
      );
      return StorageDemoPage(key: args.key, viewModel: args.viewModel);
    },
  );
}

class StorageDemoRouteArgs {
  const StorageDemoRouteArgs({this.key, this.viewModel});

  final Key? key;

  final StorageDemoViewModel? viewModel;

  @override
  String toString() {
    return 'StorageDemoRouteArgs{key: $key, viewModel: $viewModel}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StorageDemoRouteArgs) return false;
    return key == other.key && viewModel == other.viewModel;
  }

  @override
  int get hashCode => key.hashCode ^ viewModel.hashCode;
}
