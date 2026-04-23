package observable;

@:forward
@:forward.new
@:forward.variance
@:forwardStatics
abstract ObservableMap<K, V>(ObservableMapImpl<K, V>) {
    @:arrayAccess
    public inline function get(key:K) {
        return this.get(key);
    }

    @:from
    private static inline function fromMap<K, V>(map:Map<K, V>):ObservableMap<K, V> {
        var observableMap = new ObservableMap();
        @:privateAccess observableMap._map = map;
        @:privateAccess observableMap.updateChangeListeners();
        return observableMap;
    }
 
    /*
	@:from
    private static macro function fromEmptyArray(e) {
		return switch haxe.macro.Context.typeExpr(e).expr {
			case TArrayDecl([]): macro new Foo();
			case _: e;
		}
	}
    */    
}

class ObservableMapImpl<K, V> implements IObservable {
    private var _map:Map<K, V> = null;//new Map<K, V>();
    private var _fieldName:String = null;

    public function new() {
    }

    public function get(key:K):V {
        return _map.get(key);
    }

    public function set(key:K, item:V):Void {
        var oldItem = _map.get(key);
        if (oldItem != null && oldItem != item) {
            detachItem(oldItem);
        }

        _map.set(key, item);
        attachItem(item);

        notifyChanged(this, _fieldName, item, oldItem);
    }

    private function set_changeListeners(value:Array<Changes->Void>):Array<Changes->Void> {
        _changeListeners = value;
        updateChangeListeners();
        return value;
    }

    private function updateChangeListeners() {
        if (_map != null) {
            for (key in _map.keys()) {
                var item = _map.get(key);
                if (item is IObservable) {
                    @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
                    @:privateAccess cast(item, IObservable).changeListeners = _changeListeners;
                }
            }
        }
    }

    private function attachItem(item:V):Void {
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
            @:privateAccess cast(item, IObservable).changeListeners = this.changeListeners;
        }
    }

    private function detachItem(item:V):Void {
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = null;
            @:privateAccess cast(item, IObservable).changeListeners = null;
        }
    }
}