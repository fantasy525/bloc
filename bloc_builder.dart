// created by ZuoXiaoFei at 2019/4/21
import 'dart:async';

import 'package:flutter/material.dart';

import 'bloc_provider.dart';
typedef ViewStateBuilder<ViewModel> = Widget Function(
    BuildContext context,
    ViewModel vm,
    );
///根据传入的bloc返回bloc的ViewState类型的属性
@deprecated
typedef BlocConverter<Bloc,ViewState> = ViewState Function(
    Bloc bloc,
    );

typedef Prop <Bloc,ViewState> = ViewState Function(Bloc bloc);
typedef CanUpdate<ViewState> = bool Function(ViewState previousProp, ViewState currentProp);
///当我们调用bloc的流控制器的add方法后，这个widget会转换流，看下面的[_BlocStreamListenerState]
class StateProvider<Bloc extends BlocBase,ViewState> extends StatelessWidget {
  final Bloc bloc; // 可选的参数,如果我们没有为该Bloc提供BlocProvider的话，就需要手动指定bloc
  final ViewStateBuilder<ViewState> builder;
  final CanUpdate<ViewState> canUpdate;
  final Prop<Bloc,ViewState> prop;
  final bool distinct;
  StateProvider({
    Key key,
    @required this.prop,
    @required this.builder,
    this.canUpdate,
    this.distinct = false,
    this.bloc
  }) : assert(prop!=null),assert(builder!=null),super(key: key);
  @override
  Widget build(BuildContext context) {
    Bloc bloc = BlocProvider.of<Bloc>(context);
    if(bloc == null){
      // 这种情况发生在你没有给该类型的BLoc提供BlocProvider,如果想让bloc!=null,
      // 你可以在BlocToState的顶层加入BlocProvider组件，提供bloc,否则你需要在使用BlocToState的地方手动提供bloc
       assert(this.bloc !=null);
       bloc = this.bloc;
    }
    assert(bloc !=null);
    assert(prop != null);
    return BlocStreamListener<Bloc,ViewState>(
        bloc: bloc,
        prop: this.prop,
        builder: this.builder,
        distinct: this.distinct,
        canUpdate: this.canUpdate
    );
  }
}
class BlocStreamListener<Bloc extends BlocBase,ViewState> extends StatefulWidget {
  final ViewStateBuilder<ViewState> builder;
  final BlocBase bloc;
  final bool distinct;
  final CanUpdate<ViewState> canUpdate;
  final Prop<Bloc,ViewState> prop;
  BlocStreamListener({
    Key key,
    @required this.bloc,
    @required this.builder,
    this.distinct=true,
    this.canUpdate,
    @required this.prop}):assert(prop!=null),assert(bloc!=null),assert(builder!=null);
  @override
  State<StatefulWidget> createState() => _BlocStreamListenerState<Bloc,ViewState>();
}
///我们在这里对bloc的流进行转换，转换为ViewState的流，这样我们就能获取bloc的属性，
///ViewState是我们想把某个Bloc的属性转换成的类型
class _BlocStreamListenerState<Bloc extends BlocBase,ViewState> extends State<BlocStreamListener<Bloc,ViewState>> {
  Stream<ViewState> stream;

  int listPropLength;
  int mapPropKeyLength;

  bool isListProp = false;
  bool isMapProp = false;

  List copyList;
  Map  copyMap;

  @deprecated
  ViewState latestValue;
  ViewState previousProp;
  /// 如果prop 是List类型，我们进行浅克隆，到一个新的数据，深克隆会比较麻烦，如果如果list的元素是class 的实例时就无法克隆，为了简单，只做浅克隆
  /// 如果真的必须是要深克隆，其实没必要，flutter会复用element,我们优化的只是防止不必要的widget rebuild,我们可以通过代码优化，在使用list元素的地方使用这个组件
  /// 总之，尽量保持类型简单，尽量在最深处使用数据的地方使用这个组件，我们使用数据时数据的类型肯定是基本类型了.
  _initListType(ViewState vs){
    copyList = [];
    isListProp =true;
    listPropLength = (vs as List).length;
    (vs as List).forEach((value){
      copyList.add(value);
    });
  }
  bool _compareList( ViewState vs){
    bool flag =false;
    if(listPropLength != (vs as List).length){
      flag = true;
    }else {
      copyList.asMap().forEach((index,value){
        if((vs as List)[index] != value) flag =true;
      });
    }
    return flag;
  }

  _initMapType(ViewState vs){
    copyMap = {};
    isMapProp =true;
    mapPropKeyLength = (vs as Map).keys.length;
    (vs as Map).keys.forEach((key){
      copyMap[key] = (vs as Map)[key];
    });
  }
  bool _compareMap(ViewState vs){
    bool flag = false;
    if(mapPropKeyLength != (vs as Map).keys.length){
      flag = true;
    }else{
      copyMap.keys.forEach((key){
        if(copyMap[key] != (vs as Map)[key]) flag = true;
      });
    }
    return flag;
  }
  _onInit(){

    previousProp = widget.prop(widget.bloc);

    if(previousProp is List && widget.canUpdate != null){
      throw 'canUpdate is unnecessary  when ViewState is List type';
    }else if(previousProp is Map && widget.canUpdate != null){
      throw 'canUpdate is unnecessary  when ViewState is Map type';
    }

    if(previousProp is List){
      _initListType(previousProp);
    }else if(previousProp is Map){
      _initMapType(previousProp);
    }

    /// 如果控制器是关闭状态，则需要先初始化新的流
    if(widget.bloc.isClosed){
      widget.bloc.initController();
    }

    var _stream = widget.bloc.stream;
    assert(_stream != null);
    /// prop函数返回我们想要的state,此处对流里面的数据和类型进行转换
    stream = _stream.map<ViewState>((_) {
      return widget.prop(_);
    });
    ///过滤数据，只留下数据变化过的流，在我们想更细致的控局部刷新时可以设置 distinct 为true
    if(widget.distinct){
      stream = stream.where((vs){
        if(widget.canUpdate ==null) {/// 默认如果没传的话我们简单的比较 ==
          if(isListProp){// 如果是list,我们比较长度是否相等来决定是否更新，注意：更新list的某一个时该方法无效，因为长度并没有变化
            return _compareList(vs);
          }else if(isMapProp){
            return _compareMap(vs);
          }
          return previousProp != vs;
        }else{/// 用户自定义过滤条件
          return widget.canUpdate(previousProp, vs);
        }
      });
    }
    stream = stream.transform(StreamTransformer.fromHandlers(handleData: (vs,sink){
      if(isListProp){
        _initListType(vs);
      }else if(isMapProp){
        _initMapType(vs);
      }else {
        previousProp = vs;
      }
      print('⚡️⚡️${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} previous: ${previousProp.toString()} => next:${vs.toString()}⚡️⚡️');
      sink.add(vs);
    }));
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _onInit();
  }
  @override
  void didUpdateWidget(BlocStreamListener<Bloc, ViewState> oldWidget) {
    // TODO: implement didUpdateWidget
    if(widget.bloc != oldWidget.bloc){
      _onInit();
    }
    super.didUpdateWidget(oldWidget);
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ViewState>(
      stream: stream,
      builder: (context, snapshot){
        return widget.builder(
            context,
            snapshot.hasData ? snapshot.data : previousProp
        );
      },
    );
  }
}
