// ignore_for_file: prefer_typing_uninitialized_variables, curly_braces_in_flow_control_structures, empty_catches

import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

import 'country_selection_theme.dart';
import 'support/code_country.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


class SelectionList extends StatefulWidget {
  const SelectionList(this.elements, this.initialSelection,
      {Key? key,
      this.appBar,
      this.theme,
      this.countryBuilder,
      this.useUiOverlay = true,
      this.useSafeArea = false,  this.onChange})
      : super(key: key);

  final PreferredSizeWidget? appBar;
  final List elements;
  final CountryCode? initialSelection;
  final CountryTheme? theme;
  final Widget Function(BuildContext context, CountryCode)? countryBuilder;
  final bool useUiOverlay;
  final bool useSafeArea;
  final ValueChanged<CountryCode>? onChange;

  @override
  _SelectionListState createState() => _SelectionListState();
}

class _SelectionListState extends State<SelectionList> {
  late List countries;
  final TextEditingController _controller = TextEditingController();
  ScrollController? _controllerScroll;
  var diff = 0.0;

  var posSelected = 0;
  var height = 0.0;
  late var _sizeheightcontainer;
  late var _heightscroller;
  var _text;
  var _oldtext;
  final _itemsizeheight = 50.0;
  double _offsetContainer = 0.0;

  bool isShow = true;

  @override
  void initState() {
    countries = List.from(widget.elements);
    _sortDefault(countries);
    _controllerScroll = ScrollController();
    _controllerScroll!.addListener(_scrollListener);
    super.initState();
  }

  void _sendDataBack(BuildContext context, CountryCode initialSelection) {
    final isWideScreen = TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    if(isWideScreen){
      widget.onChange!(initialSelection);
    }else{
      Navigator.pop(context, initialSelection);
    }
  }

  final List _alphabet =
      List.generate(26, (i) => String.fromCharCode('A'.codeUnitAt(0) + i));

  @override
  Widget build(BuildContext context) {
    if (widget.useUiOverlay) {
      SystemChrome.setSystemUIOverlayStyle(
        immersiveOverlayForColors(
          statusBarBackground: AppTokens.surface,
          navigationBarBackground: AppTokens.surface,
        ),
      );
    }
    height = MediaQuery.of(context).size.height;
    Widget scaffold = Scaffold(
      appBar: widget.appBar,
      backgroundColor: AppTokens.surface,
      body: Container(
        color: AppTokens.surface,
        child: LayoutBuilder(builder: (context, contrainsts) {
          diff = height - contrainsts.biggest.height;
          _heightscroller = (contrainsts.biggest.height) / _alphabet.length;
          _sizeheightcontainer = (contrainsts.biggest.height);
          return Stack(
            children: <Widget>[
              CustomScrollView(
                controller: _controllerScroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(
                            widget.theme?.searchText ?? '搜索',
                            style: TextStyle(
                                color:
                                    widget.theme?.labelColor ?? AppTokens.ink700),
                          ),
                        ),
                        Container(
                          color: AppTokens.surface,
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                  left: 15, bottom: 0, top: 0, right: 15),
                              hintText:
                                  widget.theme?.searchHintText ?? '搜索国家、区号',
                            ),
                            onChanged: _filterElements,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Text(
                            widget.theme?.lastPickText ?? '最近选择',
                            style: TextStyle(
                                color:
                                    widget.theme?.labelColor ?? AppTokens.ink700),
                          ),
                        ),
                        Container(
                          color: AppTokens.surface,
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: Image.asset(
                                'lib/country_list_pick-1.0.1+5/${widget.initialSelection!.flagUri!}',
                                width: 32.0,
                              ),
                              title: Text(widget.initialSelection!.displayName(withDialCode: true)),
                              trailing: const Padding(
                                padding: EdgeInsets.only(right: 20.0),
                                child: Icon(Icons.check, color: Colors.green),
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 1, color: AppTokens.divider),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return widget.countryBuilder != null
                          ? widget.countryBuilder!(
                              context, countries.elementAt(index))
                          : getListCountry(countries.elementAt(index));
                    }, childCount: countries.length),
                  )
                ],
              ),
              if (isShow == true && !_isSearching && countries.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragStart: _onVerticalDragStart,
                    child: Container(
                      height: 20.0 * 30,
                      color: Colors.transparent,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [...List.generate(_alphabet.length,
                                (index) => _getAlphabetItem(index))],
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
    return widget.useSafeArea ? SafeArea(child: scaffold) : scaffold;
  }

  Widget getListCountry(CountryCode e) {
    return Container(
      height: 50,
      color: AppTokens.surface,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Image.asset(
            'lib/country_list_pick-1.0.1+5/${e.flagUri!}',
            width: 30.0,
          ),
          title: Text(e.displayName(withDialCode: true)),
          onTap: () {
            _sendDataBack(context, e);
          },
        ),
      ),
    );
  }

  _getAlphabetItem(int index) {
    return Expanded(
      child: InkWell(
        onTap: () => _jumpToAlphabet(index),
        child: Container(
          width: 40,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: index == posSelected
                ? widget.theme?.alphabetSelectedBackgroundColor ?? AppTokens.brand500
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            _alphabet[index],
            textAlign: TextAlign.center,
            style: (index == posSelected)
                ? TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        widget.theme?.alphabetSelectedTextColor ?? Colors.white)
                : TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: widget.theme?.alphabetTextColor ?? AppTokens.ink800),
          ),
        ),
      ),
    );
  }

  bool get _isSearching => _controller.text.trim().isNotEmpty;

  void _jumpToAlphabet(int index) {
    setState(() {
      posSelected = index;
      _text = _alphabet[posSelected];
      if (_text == _oldtext) return;
      HapticFeedback.selectionClick();
      final target = _firstCountryIndexForLetter(_text.toString());
      if (target >= 0) {
        _controllerScroll!.jumpTo((target * _itemsizeheight) + 10);
      }
      _oldtext = _text;
    });
  }

  int _firstCountryIndexForLetter(String letter) {
    final target = letter.toUpperCase();
    for (var i = 0; i < countries.length; i++) {
      if (_firstLetter(countries[i] as CountryCode) == target) return i;
    }
    return -1;
  }

  String _indexName(CountryCode country) {
    final en = country.englishName.trim();
    return en.isNotEmpty ? en : country.displayName();
  }

  String _firstLetter(CountryCode country) {
    final name = _indexName(country).trim();
    if (name.isEmpty) return '';
    return name[0].toUpperCase();
  }

  String _normalizeKeyword(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  String _digitsOnly(String text) => text.replaceAll(RegExp(r'\D'), '');

  String _searchText(CountryCode country) {
    final dial = country.dialCode?.replaceAll(' ', '') ?? '';
    return [
      country.code ?? '',
      dial,
      dial.replaceAll('+', ''),
      country.englishName,
      country.chineseName,
      country.displayName(withDialCode: true),
    ].join(' ').toUpperCase();
  }

  int _matchScore(CountryCode country, String rawKeyword) {
    final keyword = _normalizeKeyword(rawKeyword);
    if (keyword.isEmpty) return 0;

    final keywordDigits = _digitsOnly(keyword);
    final dial = (country.dialCode ?? '').replaceAll(' ', '').toUpperCase();
    final dialDigits = _digitsOnly(dial);
    final iso = (country.code ?? '').toUpperCase();
    final en = country.englishName.toUpperCase();
    final zh = country.chineseName.toUpperCase();
    final display = country.displayName(withDialCode: true).toUpperCase();

    if (keyword == iso || keyword == dial) return 0;
    if (keywordDigits.isNotEmpty) {
      if (dialDigits == keywordDigits) return 1;
      if (dialDigits.startsWith(keywordDigits)) return 2;
      if (dialDigits.contains(keywordDigits)) return 4;
    }
    if (en == keyword || zh == keyword) return 1;
    if (en.startsWith(keyword) || zh.startsWith(keyword)) return 3;
    if (iso.startsWith(keyword)) return 5;
    if (display.contains(keyword) || _searchText(country).contains(keyword)) {
      return 8;
    }
    return 9999;
  }

  void _sortDefault(List list) {
    list.sort((a, b) => _indexName(a as CountryCode)
        .compareTo(_indexName(b as CountryCode)));
  }

  void _filterElements(String s) {
    final keyword = s.trim();
    setState(() {
      if (keyword.isEmpty) {
        countries = List.from(widget.elements);
        _sortDefault(countries);
        posSelected = 0;
      } else {
        final scored = <MapEntry<CountryCode, int>>[];
        for (final raw in widget.elements) {
          final country = raw as CountryCode;
          final score = _matchScore(country, keyword);
          if (score < 9999) scored.add(MapEntry(country, score));
        }
        scored.sort((a, b) {
          final byScore = a.value.compareTo(b.value);
          if (byScore != 0) return byScore;
          final aDial = a.key.dialCode ?? '';
          final bDial = b.key.dialCode ?? '';
          final byDialLength = aDial.length.compareTo(bDial.length);
          if (byDialLength != 0) return byDialLength;
          return _indexName(a.key).compareTo(_indexName(b.key));
        });
        countries = scored.map((e) => e.key).toList();
        posSelected = 0;
      }
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      if ((_offsetContainer + details.delta.dy) >= 0 &&
          (_offsetContainer + details.delta.dy) <=
              (_sizeheightcontainer - _heightscroller)) {
        _offsetContainer += details.delta.dy;
        posSelected =
            ((_offsetContainer / _heightscroller) % _alphabet.length).round();
        _text = _alphabet[posSelected];
        if (_text != _oldtext) {
          HapticFeedback.selectionClick();
          final target = _firstCountryIndexForLetter(_text.toString());
          if (target >= 0) {
            _controllerScroll!.jumpTo((target * _itemsizeheight) + 15);
          }
          _oldtext = _text;
        }
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _offsetContainer = details.globalPosition.dy - diff;
  }

  _scrollListener() {
    int scrollPosition =
        (_controllerScroll!.position.pixels / _itemsizeheight).round();
    if (scrollPosition < countries.length) {
      try{
        final countryName = _indexName(countries.elementAt(scrollPosition));
        setState(() {
          final first = countryName.isEmpty ? 'A' : countryName[0].toUpperCase();
          posSelected = first.codeUnitAt(0) - 'A'.codeUnitAt(0);
          if (posSelected < 0 || posSelected >= _alphabet.length) {
            posSelected = 0;
          }
        });
      }catch(e){}
    }

    if ((_controllerScroll!.offset) >=
        (_controllerScroll!.position.maxScrollExtent)) {}
    if (_controllerScroll!.offset <=
            _controllerScroll!.position.minScrollExtent &&
        !_controllerScroll!.position.outOfRange) {}
  }
}
