import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/black.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models_new/blacklist/data.dart';
import 'package:PiliPlus/models_new/blacklist/list.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/services/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class BlackListController
    extends CommonListController<BlackListData, BlackListItem> {
  RxInt total = (-1).obs;

  @override
  void onInit() {
    super.onInit();
    queryData();
  }

  @override
  List<BlackListItem>? getDataList(BlackListData response) {
    total.value = response.total ?? 0;
    logger.i(
      'BlackListPage loaded page=$page count=${response.list?.length ?? 0} '
      'total=${total.value}',
    );
    return response.list;
  }

  @override
  void checkIsEnd(int length) {
    if (length >= total.value) {
      isEnd = true;
    }
  }

  void onRemove(BuildContext context, int index, name, mid) {
    showConfirmDialog(
      context: context,
      title: Text('确定将 $name 移出黑名单？'),
      onConfirm: () async {
        final result = await VideoHttp.relationMod(mid: mid, act: 6, reSrc: 11);
        if (result.isSuccess) {
          loadingState
            ..value.data!.removeAt(index)
            ..refresh();
          total.value -= 1;
          logger.i('BlackListPage remove mid=$mid total=${total.value}');
          SmartDialog.showToast('移除成功');
        } else {
          logger.w('BlackListPage remove failed mid=$mid result=$result');
        }
      },
    );
  }

  @override
  Future<LoadingState<BlackListData>> customGetData() =>
      BlackHttp.blackList(pn: page);
}
