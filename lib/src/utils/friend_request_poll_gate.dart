/// 好友申请 HTTP 轮询门禁：TCP 已就绪时跳过周期拉取。
bool shouldPollFriendRequests({required bool realtimeReady}) => !realtimeReady;
