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
        @:privateAccess observableMap._map = map.copy();
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

    private function initMapForKey(key:K):Void {
        if (_map != null) {
            return;
        }

        _map = switch (Type.typeof(key)) {
            case TInt:
                cast new haxe.ds.IntMap<V>();
            case TClass(String):
                cast new haxe.ds.StringMap<V>();
            case TEnum(_):
                cast new haxe.ds.EnumValueMap<EnumValue, V>();
            case TObject, TClass(_):
                cast new haxe.ds.ObjectMap<{}, V>();
            case TNull:
                throw "ObservableMap cannot infer backing map from a null key";
            case _:
                throw "ObservableMap does not support this key type";
        }
    }

    public function get(key:K):V {
        if (_map == null) {
            return null;
        }
        return _map.get(key);
    }

    public function set(key:K, item:V):Void {
        initMapForKey(key);

        var oldItem = _map.get(key);
        _map.set(key, item);

        if (oldItem != null && oldItem != item && !existsItem(oldItem)) {
            detachItem(oldItem);
        }

        attachItem(item);
        notifyChanged(this, _fieldName, this, this);
    }

    public function exists(key:K):Bool {
        if (_map == null) {
            return false;
        }
        return _map.exists(key);
    }

    private function existsItem(item:V):Bool {
        if (_map == null) {
            return false;
        }

        for (key in _map.keys()) {
            if (_map.get(key) == item) {
                return true;
            }
        }

        return false;
    }

    public function remove(key:K):Bool {
        if (_map == null) {
            return false;
        }

        var oldItem = _map.get(key);
        var removed = _map.remove(key);
        if (removed) {
            if (oldItem != null && !existsItem(oldItem)) {
                detachItem(oldItem);
            }
            notifyChanged(this, _fieldName, this, this);
        }

        return removed;
    }

    private function set_changeListeners(value:Array<{listener: Changes->Void}>):Array<{listener: Changes->Void}> {
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

    public function iterator():Iterator<V> {
        if (_map == null) {
            return new ObservableMapEmptyIterator<V>();
        }
        return _map.iterator();
    }

    public function keys():Iterator<K> {
        if (_map == null) {
            return new ObservableMapEmptyIterator<K>();
        }
        return _map.keys();
    }

	public function keyValueIterator():KeyValueIterator<K, V> {
        if (_map == null) {
            return new ObservableMapEmptyKeyValueIterator<K, V>();
        }
		return _map.keyValueIterator();
	}
}

private class ObservableMapEmptyIterator<T> {
    public function new() {
    }

    public function hasNext():Bool {
        return false;
    }

    public function next():T {
        throw "No more elements";
    }
}

private class ObservableMapEmptyKeyValueIterator<K, V> {
    public function new() {
    }

    public function hasNext():Bool {
        return false;
    }

    public function next():{key:K, value:V} {
        throw "No more elements";
    }
}