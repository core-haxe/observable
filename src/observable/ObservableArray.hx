package observable;

@:forward
@:forward.new
@:forward.variance
@:forwardStatics
abstract ObservableArray<T>(ObservableArrayImpl<T>) {
    @:arrayAccess
    public inline function get(index:Int) {
        return this.get(index);
    }

    @:arrayAccess
    public inline function set(index:Int, value:T) {
        return this.set(index, value);
    }

    @:from
    private static inline function fromArray<T>(array:Array<T>):ObservableArray<T> {
        var observableArray = new ObservableArray();
        @:privateAccess observableArray._array = array;
        return observableArray;
    }
}

class ObservableArrayImpl<T> implements IObservable {
    private var _array:Array<T> = [];
    private var _fieldName:String = null;

    public function new() {
    }

    public var length(get, never):Int;
    private function get_length():Int {
        return _array.length;
    }

    private function set_changeListeners(value:Array<Changes->Void>):Array<Changes->Void> {
        _changeListeners = value;
        if (_array != null) {
            for (item in _array) {
                if (item is IObservable) {
                    @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
                    @:privateAccess cast(item, IObservable).changeListeners = value;
                }
            }
        }
        return value;
    }

    public function contains(item:T):Bool {
        return _array.contains(item);
    }

    public function get(index:Int) {
        return _array[index];
    }

    public function set(index:Int, item:T) {
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
            @:privateAccess cast(item, IObservable).changeListeners = this.changeListeners;
        }
        _array[index] = item;
        notifyChanged(this, _fieldName, item, null);
    }

    public function remove(item:T) {
        var found = _array.remove(item);
        if (found) {
            notifyChanged(this, _fieldName, item, null);
        }
        return found;
    }

    public function push(item:T) {
        _array.push(item);
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
            @:privateAccess cast(item, IObservable).changeListeners = this.changeListeners;
        }
        notifyChanged(this, _fieldName, item, null);
    }

    public function iterator():Iterator<T> {
        return _array.iterator();
    }
}