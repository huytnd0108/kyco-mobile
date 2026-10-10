import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/text_fold.dart';

void main() {
  test('Vietnamese diacritics fold to ASCII for comparison only (OCD-028)', () {
    expect(foldViText('XÓA'), 'xoa');
    expect(foldViText(' xóa '), 'xoa');
    expect(foldViText('xoa'), 'xoa');
    expect(foldViText('Đặt đơn Hủy'), 'dat don huy');
    expect(foldViText('ĂÂÊÔƠƯ àằầẩẫậ ềễệ ồổỗộ ờởỡợ ừửữự ỳỷỹỵ'), 'aaeoou aaaaaa eee oooo oooo uuuu yyyy');
    expect(foldViText('DELETE'), 'delete');
  });
}
