// created by ZuoXiaoFei at 2019/4/21
import 'dart:async';
import 'package:flutter/material.dart';


abstract class BlocBase{
  StreamController<BlocBase> _stateController;
  BlocBase(){
    initController();
  }
  bool get isClosed => _stateController.isClosed;
  Stream<BlocBase> get stream =>_stateController.stream;
  /// 如果是同步的方法更新数据，则可能先触发setState，有可能控制器的流是关闭状态
  setState(){
    if(_stateController.isClosed){
      initController();
    }
    _stateController.add(this);
  }

  initController(){
    _stateController = StreamController.broadcast();
  }

  @mustCallSuper
  void dispose(){
    print('${this} streamController close');
    _stateController.close();
  }
}

Type _typeOf<T>() => T;
// 通用的BlocProvider
class BlocProvider<T extends BlocBase> extends StatefulWidget{
  final T bloc;
  final Widget child;
  final bool shouldDispose;
  BlocProvider({
    Key key,
    @required this.child,
    @required this.bloc,
    this.shouldDispose = true
  }): super(key: key);

  @override
  _BlocProviderState<T> createState() => _BlocProviderState<T>();

  static T of<T extends BlocBase>(BuildContext context){
    final type = _typeOf<_BlocProviderInherited<T>>();
    // Calling this method is O(1) with a small constant factor.快速找到InheritedWidget,从而找到bloc;
    _BlocProviderInherited<T> provider =
        context.ancestorInheritedElementForWidgetOfExactType(type)?.widget;
    if(provider == null){
      return null;
    }
    return provider.bloc;
  }
}


class _BlocProviderState<T extends BlocBase> extends State<BlocProvider<T>>{
  @override
  void dispose(){
    if(widget.shouldDispose){
      widget.bloc.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return new _BlocProviderInherited<T>(
      bloc: widget.bloc,
      child: widget.child,
    );
  }
}

/// 使用inheritedWidget时为了让子孙通过of方法访问此widget的bloc时 时间复杂度未O(1);
class _BlocProviderInherited<T> extends InheritedWidget {
  _BlocProviderInherited({
    Key key,
    @required Widget child,
    @required this.bloc,
  }) : super(key: key, child: child);

  final T bloc;
  /// 返回false,防止此widget重建时更新子widget,应该根据流来更新;
  @override
  bool updateShouldNotify(_BlocProviderInherited oldWidget)  {
    return false;
  }
}

class AppBlocProvider<T extends BlocBase> extends StatefulWidget {
  final Widget child;
  final T appBloc;
  AppBlocProvider({this.appBloc,this.child});
  @override
  _AppBlocState createState() => _AppBlocState<T>();
}

class _AppBlocState<T extends BlocBase> extends State<AppBlocProvider> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<T>(child: widget.child, bloc:widget.appBloc );
  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    widget.appBloc.dispose();
  }
}
