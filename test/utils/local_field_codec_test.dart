import 'package:PiliPlus/utils/local_field_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('敏感字段编码后可还原，且不包含明文', () {
    const plain = 'https://dav.example.com/path?x=1';
    final sealed = LocalFieldCodec.seal(plain);
    expect(sealed, startsWith('pp1:'));
    expect(sealed, isNot(contains('dav.example.com')));
    expect(LocalFieldCodec.unseal(sealed), plain);
    // 随机 IV：同一明文每次编码结果都不一样。
    expect(LocalFieldCodec.seal(plain), isNot(sealed));
    expect(LocalFieldCodec.seal(''), '');
    expect(LocalFieldCodec.unseal(''), '');
  });

  test('历史明文按原样返回，损坏密文返回空串', () {
    expect(LocalFieldCodec.unseal('alice'), 'alice');
    expect(LocalFieldCodec.unseal(null), '');
    expect(LocalFieldCodec.unseal('pp1:not-base64!!'), '');
  });
}
