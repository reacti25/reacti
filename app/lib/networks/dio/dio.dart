import 'package:achiar_expert_app/helpers/di.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';
import '../endpoints.dart';
import 'log.dart';

final class DioSingleton {
  static final DioSingleton _singleton = DioSingleton._internal();
  static CancelToken cancelToken = CancelToken();
  DioSingleton._internal();

  static DioSingleton get instance => _singleton;

  late Dio dio;

  void create() {
    BaseOptions options = BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      headers: {NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE},
    );
    dio = Dio(options)..interceptors.add(Logger());
  }

  void update(String auth) {
    if (kDebugMode) {
      print("Dio update");
    }

    BaseOptions options = BaseOptions(
      baseUrl: url,
      responseType: ResponseType.json,
      headers: {
        NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE,
        NetworkConstants.AUTHORIZATION: "Bearer $auth",
      },
      connectTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
    );
    dio = Dio(options)..interceptors.add(Logger());
  }

  void updateLanguage(String countryCode) {
    if (kDebugMode) {
      print("Dio update $countryCode");
    }
    BaseOptions options = BaseOptions(
      baseUrl: url,
      responseType: ResponseType.json,
      headers: {
        NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE,
        NetworkConstants.AUTHORIZATION:
            "Bearer ${appData.read(kKeyAccessToken)} ",
      },
      connectTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
    );
    dio = Dio(options)..interceptors.add(Logger());
  }
}

Future<Response> postHttp(
  String path, [
  dynamic data,
  ProgressCallback? onSendProgress,
]) => DioSingleton.instance.dio.post(
  path,
  data: data,
  cancelToken: DioSingleton.cancelToken,
  onSendProgress: onSendProgress, // This will be used if provided
);

Future<Response> putHttp(String path, [dynamic data]) => DioSingleton
    .instance
    .dio
    .put(path, data: data, cancelToken: DioSingleton.cancelToken);

Future<Response> getHttp(String path, [dynamic data]) =>
    DioSingleton.instance.dio.get(path, cancelToken: DioSingleton.cancelToken);

Future<Response> deleteHttp(String path, [dynamic data]) => DioSingleton
    .instance
    .dio
    .delete(path, data: data, cancelToken: DioSingleton.cancelToken);
