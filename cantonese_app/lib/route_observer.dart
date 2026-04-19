import 'package:flutter/material.dart';

/// 用于在从「设置」等页返回时刷新首页各 Tab 的 SharedPreferences 状态
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();
