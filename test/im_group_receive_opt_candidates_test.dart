import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_group_receive_opt.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

void main() {
  test('orderCandidates puts custom @TGS#_mc before bad @TGS#_@TGS#m2 expand',
      () {
    const bad = '@TGS#_@TGS#m2O5P4YN5CI';
    const real = '@TGS#_mcKE2PNMM62C2';
    final ordered = ImGroupReceiveOpt.orderCandidates(
      raw: bad,
      resolved: real,
    );
    expect(ordered.first, real);
    expect(ordered, contains(bad));
    expect(ordered.indexOf(real), lessThan(ordered.indexOf(bad)));
  });

  test('orderCandidates without resolved keeps IM original first', () {
    const original = '@TGS#_@TGS#m2MUSSKN5C3';
    final ordered = ImGroupReceiveOpt.orderCandidates(
      raw: original,
      resolved: '',
    );
    expect(ordered.first, original);
    expect(ordered, contains('m2MUSSKN5C3'));
  });

  test('imGroupIdCandidates original-first for IM forms', () {
    final full = ChatIdFormat.imGroupIdCandidates('@TGS#_@TGS#m2MUSSKN5C3');
    expect(full.first, '@TGS#_@TGS#m2MUSSKN5C3');
    expect(full, contains('m2MUSSKN5C3'));

    final single = ChatIdFormat.imGroupIdCandidates('@TGS#c2SX4NMM62CZ');
    expect(single.first, '@TGS#c2SX4NMM62CZ');
  });
}
