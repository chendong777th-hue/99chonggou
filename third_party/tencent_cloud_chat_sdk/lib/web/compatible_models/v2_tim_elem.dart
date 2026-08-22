/// V2TIMElem
class V2TIMElem {
  Map<String, dynamic>? nextElem;
  int? elemType;
  dynamic _message;
  int _elemIndex = 0;

  V2TIMElem({this.nextElem, this.elemType});

  void setMessageInternal(dynamic message) {
    _message = message;
  }

  void setElemIndexInternal(int index) {
    _elemIndex = index;
  }
}
