import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_game_settings.dart';

void main() {
  group('SangongGameSettings', () {
    test('parses banker and player rake fields', () {
      final settings = SangongGameSettings.fromJson({
        'doorCount': 6,
        'minBet': 20,
        'maxBet': 80000,
        'points': [
          {
            'point': 0,
            'label': '0点',
            'odds': 1.0,
            'bankerRakePoints': 6,
            'playerRakePoints': 0,
          },
          {
            'point': 9,
            'label': '9点',
            'odds': 1.2,
            'bankerRakePoints': 5,
            'playerRakePoints': 2,
          },
        ],
        'pair': {
          'label': '对子',
          'odds': 1.5,
          'bankerRakePoints': 5,
          'playerRakePoints': 0,
        },
        'maxHand': {
          'label': '1.00',
          'odds': 1.0,
          'bankerRakePoints': 8,
          'playerRakePoints': 0,
        },
        'imGroupGameId': '@TGS#2ZTSEOM5C4',
        'imGroupAdminStatsId': '@TGS#2RXTEOM5CZ',
        'imBotUserId': 'rqwm8onw3j',
      });

      expect(settings.points.first.bankerRakePoints, 6);
      expect(settings.points.first.playerRakePoints, 0);
      expect(settings.points[9].bankerRakePoints, 5);
      expect(settings.points[9].playerRakePoints, 2);
      expect(settings.pair.bankerRakePoints, 5);
      expect(settings.maxHand.playerRakePoints, 0);
      expect(settings.imGroupGameId, '@TGS#2ZTSEOM5C4');
      expect(settings.imGroupAdminStatsId, '@TGS#2RXTEOM5CZ');
      expect(settings.imBotUserId, 'rqwm8onw3j');
    });

    test('toJson includes im group ids when set', () {
      final settings = SangongGameSettings.defaults().copyWith(
        imGroupGameId: '@TGS#GAME',
        imGroupAdminStatsId: '@TGS#STATS',
        imBotUserId: 'bot_user_1',
      );
      final json = settings.toJson();
      expect(json['imGroupGameId'], '@TGS#GAME');
      expect(json['imGroupAdminStatsId'], '@TGS#STATS');
      expect(json['imBotUserId'], 'bot_user_1');
    });

    test('fromJson accepts snake_case imBotUserId', () {
      final settings = SangongGameSettings.fromJson({
        'doorCount': 6,
        'im_bot_user_id': 'rqwm8onw3j',
      });
      expect(settings.imBotUserId, 'rqwm8onw3j');
    });

    test('falls back legacy rakePoints to banker rake', () {
      final rule = SangongHandRule.fromJson({
        'label': '对子',
        'odds': 1.5,
        'rakePoints': 5,
      });
      expect(rule.bankerRakePoints, 5);
      expect(rule.playerRakePoints, 0);
    });

    test('toJson includes dual rake fields', () {
      final original = SangongGameSettings.defaults();
      final json = original.toJson();
      final point = (json['points'] as List).first as Map<String, dynamic>;
      expect(point.containsKey('bankerRakePoints'), isTrue);
      expect(point.containsKey('playerRakePoints'), isTrue);
    });

    test('computeBankerWater uses rake percent on total bet', () {
      final settings = SangongGameSettings.fromJson({
        'doorCount': 6,
        'points': [
          {'point': 0, 'odds': 1, 'bankerRakePoints': 6, 'playerRakePoints': 0},
        ],
        'pair': {'odds': 1.5, 'bankerRakePoints': 5, 'playerRakePoints': 0},
        'maxHand': {'odds': 1, 'bankerRakePoints': 8, 'playerRakePoints': 0},
      });
      expect(settings.computeBankerWater(12058), 723);
      expect(settings.computeBankerWater(12058, bankerRakePoints: 5), 603);
      expect(settings.computeBankerWater(0), 0);
    });
    test('maxBet zero means unlimited', () {
      final settings = SangongGameSettings.fromJson({'maxBet': 0});
      expect(settings.maxBet, 0);
      expect(settings.maxBetUnlimited, isTrue);
    });

    test('maxBet accepts server upper bound', () {
      final settings = SangongGameSettings.fromJson({
        'maxBet': SangongGameSettings.maxMaxBet,
      });
      expect(settings.maxBet, SangongGameSettings.maxMaxBet);
      expect(settings.maxBetUnlimited, isFalse);
    });
  });
}
