import 'package:flutter/material.dart';

class UserAgreementLocalizations {
  const UserAgreementLocalizations._();

  static String title(Locale locale) {
    if (_isZhHant(locale)) return '用戶協議';
    switch (locale.languageCode) {
      case 'en':
        return 'User Agreement';
      case 'ja':
        return 'User Agreement';
      case 'ko':
        return 'User Agreement';
      default:
        return '用户协议';
    }
  }

  static String body(Locale locale) {
    if (_isZhHant(locale)) return _zhHant;
    switch (locale.languageCode) {
      case 'en':
        return _en;
      case 'ja':
        return _ja;
      case 'ko':
        return _ko;
      default:
        return _zhHans;
    }
  }

  static bool _isZhHant(Locale locale) {
    return locale.languageCode == 'zh' &&
        (locale.scriptCode == 'Hant' ||
            locale.countryCode == 'TW' ||
            locale.countryCode == 'HK' ||
            locale.countryCode == 'MO');
  }

  static const String _zhHans = '''
99Chat 用户协议

欢迎您使用 99Chat 即时通讯服务。为了保障用户的合法权益，维护平台正常运营秩序，请您在注册、登录或使用 99Chat 服务前，认真阅读并充分理解本《99Chat 用户协议》（以下简称“本协议”）的全部内容。当您完成注册、登录或开始使用本服务时，即表示您已同意接受本协议全部条款的约束。

1、服务内容

99Chat 是一款提供即时通讯、好友互动、群组聊天、文件传输及相关互联网信息服务的平台。平台将持续优化产品体验，并根据业务发展新增或调整功能服务。部分功能可能需要网络支持或系统权限授权。

2、账号注册与安全

用户在注册账号时，应提供真实、合法、有效的信息，并对所注册账号承担全部责任。
用户应妥善保管账号及密码，不得将账号转让、出租、出售或借用给他人使用。
因用户保管不善导致账号泄露、被盗或产生其他损失的，由用户自行承担责任。
用户发现账号存在异常登录、未经授权使用等情况时，应立即联系平台处理。

3、用户行为规范

用户在使用 99Chat 服务过程中，不得从事以下行为：

发布、传播违反法律法规的信息；
发布虚假、诈骗、赌博、色情、暴力、侵权等违法内容；
冒充他人、组织或机构；
利用平台从事恶意营销、骚扰、刷屏等行为；
破坏平台系统安全、攻击服务器或干扰正常运营；
未经授权获取其他用户隐私信息。

对于违反上述规定的用户，99Chat 有权视情况采取警告、限制功能、封禁账号等处理措施，并保留追究法律责任的权利。

4、隐私与数据保护

99Chat 重视用户隐私与数据安全。平台将依据相关法律法规采取合理措施保护用户信息安全。未经用户同意，平台不会向第三方公开用户个人信息，但以下情况除外：

法律法规要求；
司法机关或监管部门依法要求；
为保障平台及用户合法权益所必需；
用户自行公开的信息。

用户理解并同意，为提升服务质量，平台可能会对匿名化数据进行统计分析与产品优化。

5、知识产权

99Chat 平台中的软件、界面设计、商标、图标、文字、图片及相关技术内容均受法律保护，相关知识产权归 99Chat 或相关权利人所有。未经授权，任何单位或个人不得复制、修改、传播或用于商业用途。

6、服务变更与中断

平台有权根据运营需要，对服务内容进行调整、升级或暂停。因系统维护、网络故障、不可抗力等原因导致服务中断的，99Chat 将尽合理努力恢复服务，但不承担由此造成的损失责任。

7、免责声明

用户因使用第三方链接、第三方服务产生的风险与责任，由用户自行承担；
因网络环境、设备故障或不可抗力导致的服务异常，平台不承担赔偿责任；
用户在平台内发布的内容仅代表其个人立场，与 99Chat 无关。

8、协议修改

99Chat 有权根据法律法规及业务发展需要，对本协议进行修改。修改后的协议将在平台公布并生效。用户继续使用服务，即视为接受修改后的协议内容。

9、法律适用

本协议的订立、生效、履行及争议解决均适用相关法律法规。如双方发生争议，应优先通过友好协商解决；协商不成的，可提交有管辖权的法院处理。

感谢您选择 99Chat。我们将持续致力于为用户提供安全、稳定、便捷的即时通讯服务。
''';

  static const String _zhHant = '''
99Chat 用戶協議

歡迎您使用 99Chat 即時通訊服務。為了保障用戶的合法權益，維護平台正常運營秩序，請您在註冊、登入或使用 99Chat 服務前，認真閱讀並充分理解本《99Chat 用戶協議》（以下簡稱「本協議」）的全部內容。當您完成註冊、登入或開始使用本服務時，即表示您已同意接受本協議全部條款的約束。

1、服務內容

99Chat 是一款提供即時通訊、好友互動、群組聊天、檔案傳輸及相關網際網路資訊服務的平台。平台將持續優化產品體驗，並根據業務發展新增或調整功能服務。部分功能可能需要網路支援或系統權限授權。

2、帳號註冊與安全

用戶在註冊帳號時，應提供真實、合法、有效的資訊，並對所註冊帳號承擔全部責任。
用戶應妥善保管帳號及密碼，不得將帳號轉讓、出租、出售或借用給他人使用。
因用戶保管不善導致帳號洩露、被盜或產生其他損失的，由用戶自行承擔責任。
用戶發現帳號存在異常登入、未經授權使用等情況時，應立即聯繫平台處理。

3、用戶行為規範

用戶在使用 99Chat 服務過程中，不得從事以下行為：

發布、傳播違反法律法規的資訊；
發布虛假、詐騙、賭博、色情、暴力、侵權等違法內容；
冒充他人、組織或機構；
利用平台從事惡意行銷、騷擾、洗版等行為；
破壞平台系統安全、攻擊伺服器或干擾正常運營；
未經授權獲取其他用戶隱私資訊。

對於違反上述規定的用戶，99Chat 有權視情況採取警告、限制功能、封禁帳號等處理措施，並保留追究法律責任的權利。

4、隱私與資料保護

99Chat 重視用戶隱私與資料安全。平台將依據相關法律法規採取合理措施保護用戶資訊安全。未經用戶同意，平台不會向第三方公開用戶個人資訊，但以下情況除外：

法律法規要求；
司法機關或監管部門依法要求；
為保障平台及用戶合法權益所必需；
用戶自行公開的資訊。

用戶理解並同意，為提升服務品質，平台可能會對匿名化資料進行統計分析與產品優化。

5、知識產權

99Chat 平台中的軟體、介面設計、商標、圖示、文字、圖片及相關技術內容均受法律保護，相關知識產權歸 99Chat 或相關權利人所有。未經授權，任何單位或個人不得複製、修改、傳播或用於商業用途。

6、服務變更與中斷

平台有權根據運營需要，對服務內容進行調整、升級或暫停。因系統維護、網路故障、不可抗力等原因導致服務中斷的，99Chat 將盡合理努力恢復服務，但不承擔由此造成的損失責任。

7、免責聲明

用戶因使用第三方連結、第三方服務產生的風險與責任，由用戶自行承擔；
因網路環境、設備故障或不可抗力導致的服務異常，平台不承擔賠償責任；
用戶在平台內發布的內容僅代表其個人立場，與 99Chat 無關。

8、協議修改

99Chat 有權根據法律法規及業務發展需要，對本協議進行修改。修改後的協議將在平台公布並生效。用戶繼續使用服務，即視為接受修改後的協議內容。

9、法律適用

本協議的訂立、生效、履行及爭議解決均適用相關法律法規。如雙方發生爭議，應優先通過友好協商解決；協商不成的，可提交有管轄權的法院處理。

感謝您選擇 99Chat。我們將持續致力於為用戶提供安全、穩定、便捷的即時通訊服務。
''';

  static const String _en = '''
99Chat User Agreement

Welcome to 99Chat instant messaging service. To protect users' lawful rights and maintain the normal operation order of the platform, please read and fully understand this 99Chat User Agreement ("Agreement") before registering, logging in to, or using 99Chat services. By completing registration, logging in, or starting to use the service, you agree to be bound by all terms of this Agreement.

1. Service Content

99Chat is a platform that provides instant messaging, friend interaction, group chat, file transfer, and related internet information services. The platform will continue to optimize the product experience and may add or adjust functional services according to business development needs. Some features may require network support or system permission authorization.

2. Account Registration and Security

When registering an account, users shall provide true, legal, and valid information and shall bear full responsibility for the registered account.
Users shall properly keep their account and password and shall not transfer, rent, sell, or lend the account to others.
Any loss caused by account leakage, theft, or other issues due to improper custody by the user shall be borne by the user.
If users discover abnormal login, unauthorized use, or other abnormal situations involving their account, they shall contact the platform immediately.

3. User Conduct Rules

When using 99Chat services, users shall not engage in the following behaviors:

Publishing or spreading information that violates laws or regulations;
Publishing illegal content such as false information, fraud, gambling, pornography, violence, or infringement;
Impersonating others, organizations, or institutions;
Conducting malicious marketing, harassment, or spamming through the platform;
Damaging platform system security, attacking servers, or interfering with normal operations;
Obtaining other users' private information without authorization.

For users who violate the above provisions, 99Chat has the right to take measures such as warnings, function restrictions, or account bans depending on the circumstances, and reserves the right to pursue legal liability.

4. Privacy and Data Protection

99Chat values user privacy and data security. The platform will take reasonable measures in accordance with relevant laws and regulations to protect user information security. Without the user's consent, the platform will not disclose users' personal information to third parties, except in the following cases:

As required by laws and regulations;
As required by judicial or regulatory authorities in accordance with law;
As necessary to protect the lawful rights and interests of the platform and users;
Information voluntarily disclosed by the user.

Users understand and agree that, in order to improve service quality, the platform may conduct statistical analysis and product optimization on anonymized data.

5. Intellectual Property

The software, interface design, trademarks, icons, texts, images, and related technical content of the 99Chat platform are protected by law. The relevant intellectual property rights belong to 99Chat or the relevant rights holders. Without authorization, no entity or individual may copy, modify, disseminate, or use them for commercial purposes.

6. Service Changes and Interruptions

The platform has the right to adjust, upgrade, or suspend service content according to operational needs. In case of service interruption caused by system maintenance, network failure, force majeure, or other reasons, 99Chat will make reasonable efforts to restore the service, but shall not be liable for losses caused thereby.

7. Disclaimer

Users shall bear the risks and responsibilities arising from the use of third-party links or third-party services;
The platform shall not be liable for compensation for service abnormalities caused by network environment, device failure, or force majeure;
Content published by users on the platform only represents their personal views and is unrelated to 99Chat.

8. Agreement Modification

99Chat has the right to modify this Agreement according to laws, regulations, and business development needs. The modified Agreement will take effect after being published on the platform. Continued use of the service indicates acceptance of the modified Agreement.

9. Governing Law

The conclusion, effectiveness, performance, and dispute resolution of this Agreement shall be governed by relevant laws and regulations. In the event of a dispute, both parties shall first seek an amicable settlement. If no settlement can be reached, the dispute may be submitted to a court with jurisdiction.

Thank you for choosing 99Chat. We will continue to provide users with safe, stable, and convenient instant messaging services.
''';

  static const String _ja = '''
99Chat 利用規約

99Chat のインスタントメッセージサービスをご利用いただきありがとうございます。ユーザーの正当な権利利益を保護し、プラットフォームの正常な運営秩序を維持するため、99Chat のサービスに登録、ログイン、または利用する前に、本「99Chat 利用規約」（以下「本規約」）をよく読み、十分に理解してください。登録の完了、ログイン、または本サービスの利用開始をもって、本規約のすべての内容に同意したものとみなします。

1、サービス内容

99Chat は、インスタントメッセージ、友だちとの交流、グループチャット、ファイル転送、および関連するインターネット情報サービスを提供するプラットフォームです。プラットフォームは継続的に製品体験を最適化し、事業発展に応じて機能やサービスを追加または調整する場合があります。一部の機能には、ネットワーク接続またはシステム権限の許可が必要です。

2、アカウント登録と安全

ユーザーはアカウント登録時に、真実かつ合法で有効な情報を提供し、登録したアカウントに関する一切の責任を負うものとします。
ユーザーはアカウントおよびパスワードを適切に管理し、他人に譲渡、貸与、販売、または使用させてはなりません。
ユーザーの管理不備によってアカウントの漏えい、盗難、その他の損失が生じた場合、その責任はユーザー自身が負うものとします。
アカウントに異常なログインや無断使用などの事象が見つかった場合、ユーザーは直ちにプラットフォームに連絡するものとします。

3、ユーザー行為規範

ユーザーは 99Chat の利用にあたり、以下の行為を行ってはなりません。

法令に違反する情報の投稿または配信；
虚偽情報、詐欺、賭博、わいせつ、暴力、権利侵害などの違法コンテンツの投稿；
他人、団体、機関になりすます行為；
プラットフォームを利用した悪質なマーケティング、嫌がらせ、スパム行為；
プラットフォームのシステム安全を破壊し、サーバーを攻撃し、正常な運営を妨害する行為；
他のユーザーの個人情報を無断で取得する行為。

上記に違反したユーザーに対して、99Chat は状況に応じて警告、機能制限、アカウント停止などの措置を講じる権利を有し、法的責任を追及する権利を留保します。

4、プライバシーとデータ保護

99Chat はユーザーのプライバシーとデータセキュリティを重視します。プラットフォームは関連法令に従い、合理的な措置を講じてユーザー情報を保護します。ユーザーの同意がない限り、プラットフォームはユーザーの個人情報を第三者に開示しません。ただし、以下の場合を除きます。

法令に基づく場合；
司法機関または監督機関から法に基づく要求がある場合；
プラットフォームおよびユーザーの正当な権利利益を保護するために必要な場合；
ユーザーが自ら公開した情報。

ユーザーは、サービス品質向上のため、プラットフォームが匿名化されたデータを統計分析および製品改善に利用することに同意するものとします。

5、知的財産権

99Chat プラットフォーム上のソフトウェア、画面設計、商標、アイコン、文章、画像、および関連技術コンテンツは法的保護を受けており、その知的財産権は 99Chat または関連権利者に帰属します。許可なく、いかなる組織または個人も複製、改変、配布、または商用利用してはなりません。

6、サービスの変更および中断

プラットフォームは運営上の必要に応じて、サービス内容を調整、アップグレード、または一時停止する権利を有します。システム保守、ネットワーク障害、不可抗力などによりサービスが中断した場合、99Chat は合理的な範囲で復旧に努めますが、それにより生じた損害について責任を負いません。

7、免責事項

第三者リンクまたは第三者サービスの利用に伴うリスクと責任は、ユーザー自身が負うものとします；
ネットワーク環境、端末故障、不可抗力により発生したサービス異常について、プラットフォームは賠償責任を負いません；
プラットフォーム内でユーザーが投稿した内容は、その個人の見解を示すものであり、99Chat とは無関係です。

8、規約の変更

99Chat は、法令または事業発展上の必要に応じて本規約を変更する権利を有します。変更後の規約はプラットフォーム上で公表された時点で効力を生じます。ユーザーが引き続きサービスを利用した場合、変更後の規約に同意したものとみなします。

9、準拠法

本規約の締結、効力、履行、および紛争解決には関連法令が適用されます。紛争が発生した場合、当事者はまず友好的に協議して解決するものとし、協議が整わない場合は、管轄権を有する裁判所に提起することができます。

99Chat をご利用いただきありがとうございます。私たちは今後も、安全で安定した便利なインスタントメッセージサービスの提供に努めます。
''';

  static const String _ko = '''
99Chat 이용약관

99Chat 메신저 서비스를 이용해 주셔서 감사합니다. 이용자의 합법적인 권익을 보호하고 플랫폼의 정상적인 운영 질서를 유지하기 위해, 회원가입, 로그인 또는 99Chat 서비스 이용 전에 본 「99Chat 이용약관」(이하 "본 약관")의 모든 내용을 충분히 읽고 이해해 주시기 바랍니다. 회원가입을 완료하거나 로그인하거나 서비스를 이용하기 시작하는 경우, 본 약관의 모든 내용에 동의한 것으로 간주됩니다.

1. 서비스 내용

99Chat은 실시간 메신저, 친구 상호작용, 그룹 채팅, 파일 전송 및 관련 인터넷 정보 서비스를 제공하는 플랫폼입니다. 플랫폼은 지속적으로 제품 경험을 개선하며, 사업 발전에 따라 기능과 서비스를 추가하거나 조정할 수 있습니다. 일부 기능은 네트워크 연결 또는 시스템 권한 허용이 필요할 수 있습니다.

2. 계정 등록 및 보안

이용자는 계정 등록 시 진실하고 합법적이며 유효한 정보를 제공해야 하며, 등록한 계정에 대한 모든 책임을 부담합니다.
이용자는 계정과 비밀번호를 적절히 보관해야 하며, 타인에게 양도, 대여, 판매 또는 사용하게 해서는 안 됩니다.
이용자의 관리 소홀로 인해 계정 유출, 도난 또는 기타 손실이 발생한 경우 그 책임은 이용자 본인에게 있습니다.
이용자는 계정에 비정상 로그인 또는 무단 사용 등의 이상이 발견되면 즉시 플랫폼에 연락해야 합니다.

3. 이용자 행위 규범

이용자는 99Chat 서비스를 이용하는 과정에서 다음 행위를 해서는 안 됩니다.

법률 및 규정을 위반하는 정보의 게시 또는 전파；
허위 정보, 사기, 도박, 음란물, 폭력, 권리 침해 등 불법 콘텐츠 게시；
타인, 단체 또는 기관을 사칭하는 행위；
플랫폼을 이용한 악의적 마케팅, 괴롭힘, 도배 행위；
플랫폼 시스템 보안을 훼손하거나 서버를 공격하거나 정상 운영을 방해하는 행위；
다른 이용자의 개인정보를 무단으로 취득하는 행위。

위 규정을 위반한 이용자에 대해 99Chat은 상황에 따라 경고, 기능 제한, 계정 정지 등의 조치를 취할 권리가 있으며, 법적 책임을 추궁할 권리를 보유합니다.

4. 개인정보 및 데이터 보호

99Chat은 이용자의 개인정보와 데이터 보안을 중요하게 생각합니다. 플랫폼은 관련 법률과 규정에 따라 합리적인 조치를 취하여 이용자 정보를 보호합니다. 이용자의 동의 없이 제3자에게 개인정보를 공개하지 않지만, 다음의 경우는 예외입니다.

법률 및 규정에 따른 요구；
사법기관 또는 감독기관의 법적 요구；
플랫폼 및 이용자의 정당한 권익 보호를 위해 필요한 경우；
이용자가 스스로 공개한 정보。

이용자는 서비스 품질 향상을 위해 플랫폼이 익명화된 데이터를 통계 분석 및 제품 개선에 활용할 수 있음에 동의합니다.

5. 지식재산권

99Chat 플랫폼의 소프트웨어, 인터페이스 디자인, 상표, 아이콘, 문자, 이미지 및 관련 기술 콘텐츠는 법률의 보호를 받으며, 관련 지식재산권은 99Chat 또는 관련 권리자에게 귀속됩니다. 허가 없이 어떠한 단체나 개인도 이를 복제, 수정, 배포하거나 상업적 목적으로 사용할 수 없습니다.

6. 서비스 변경 및 중단

플랫폼은 운영상 필요에 따라 서비스 내용을 조정, 업그레이드 또는 일시 중단할 권리가 있습니다. 시스템 유지보수, 네트워크 장애, 불가항력 등의 사유로 서비스가 중단되는 경우, 99Chat은 합리적인 범위 내에서 복구를 위해 노력하지만, 그로 인해 발생한 손실에 대해서는 책임을 지지 않습니다.

7. 면책조항

이용자가 제3자 링크 또는 제3자 서비스를 이용함으로써 발생하는 위험과 책임은 이용자 본인이 부담합니다；
네트워크 환경, 기기 고장 또는 불가항력으로 인한 서비스 이상에 대해 플랫폼은 배상 책임을 지지 않습니다；
플랫폼 내에서 이용자가 게시한 내용은 해당 이용자 개인의 입장만을 나타내며 99Chat과는 무관합니다。

8. 약관 변경

99Chat은 관련 법률, 규정 및 사업 발전 필요에 따라 본 약관을 수정할 권리가 있습니다. 수정된 약관은 플랫폼에 게시되는 즉시 효력이 발생합니다. 이용자가 계속해서 서비스를 이용하는 경우, 수정된 약관에 동의한 것으로 간주됩니다.

9. 준거법

본 약관의 체결, 효력 발생, 이행 및 분쟁 해결에는 관련 법률 및 규정이 적용됩니다. 분쟁이 발생한 경우 당사자는 우선 원만한 협의를 통해 해결해야 하며, 협의가 이루어지지 않을 경우 관할 법원에 제기할 수 있습니다.

99Chat을 선택해 주셔서 감사합니다. 저희는 앞으로도 안전하고 안정적이며 편리한 메신저 서비스를 제공하기 위해 최선을 다하겠습니다.
''';
}
