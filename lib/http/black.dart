import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/blacklist/data.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class BlackHttp {
  static Future<LoadingState<BlackListData>> blackList({
    required int pn,
    int ps = 50,
  }) async {
    final res = await Request().get(
      Api.blackLst,
      queryParameters: {
        'pn': pn,
        'ps': ps,
        're_version': 0,
        'jsonp': 'jsonp',
        'csrf': Accounts.main.csrf,
      },
    );
    if (res.data['code'] == 0) {
      return Success(BlackListData.fromJson(res.data['data']));
    } else {
      return Error(res.data['message']);
    }
  }

  static Future<LoadingState<Set<int>>> syncBlackMids({
    int ps = 50,
    String source = 'manual',
  }) async {
    if (!Accounts.main.isLogin) {
      logger.i('BlackMidSync skip source=$source reason=not_login');
      return const Error('not login');
    }

    final mids = <int>{};
    var page = 1;
    int? total;
    logger.i(
      'BlackMidSync start source=$source cached=${GlobalData().blackMids.length}',
    );

    while (true) {
      final res = await blackList(pn: page, ps: ps);
      if (res case Success(:final response)) {
        total ??= response.total ?? 0;
        final pageMids =
            response.list?.map((item) => item.mid).whereType<int>().toSet() ??
            const <int>{};
        mids.addAll(pageMids);
        logger.i(
          'BlackMidSync page=$page loaded=${pageMids.length} '
          'accumulated=${mids.length} total=$total',
        );

        if (mids.length >= total || pageMids.isEmpty) {
          GlobalData().blackMids = mids;
          Pref.blackMids = mids;
          logger.i('BlackMidSync finish source=$source total=${mids.length}');
          return Success(mids);
        }
        page++;
      } else {
        final errMsg = res is Error ? res.errMsg : null;
        logger.w(
          'BlackMidSync failed source=$source page=$page '
          'accumulated=${mids.length} error=$errMsg',
        );
        return Error(errMsg);
      }
    }
  }
}
