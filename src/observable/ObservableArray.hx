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
        @:privateAccess observableArray._array = array.copy();
        @:privateAccess observableArray.updateChangeListeners();
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

    private function set_changeListeners(value:Array<{listener: Changes->Void}>):Array<{listener: Changes->Void}> {
        _changeListeners = value;
        updateChangeListeners();
        return value;
    }

    private function updateChangeListeners() {
        if (_array != null) {
            for (item in _array) {
                if (item is IObservable) {
                    @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
                    @:privateAccess cast(item, IObservable).changeListeners = _changeListeners;
                }
            }
        }
    }

    private function attachItem(item:T):Void {
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
            @:privateAccess cast(item, IObservable).changeListeners = this.changeListeners;
        }
    }

    private function detachItem(item:T):Void {
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = null;
            @:privateAccess cast(item, IObservable).changeListeners = null;
        }
    }

    public function contains(item:T):Bool {
        return _array.contains(item);
    }

    public function get(index:Int) {
        return _array[index];
    }

    public function set(index:Int, item:T) {
        var oldItem = _array[index];
        _array[index] = item;

        if (oldItem != null && oldItem != item && !_array.contains(oldItem)) {
            detachItem(oldItem);
        }

        attachItem(item);
        notifyChanged(this, _fieldName, this, this);
    }

    public function remove(item:T) {
        var found = _array.remove(item);
        if (found) {
            if (!_array.contains(item)) {
                detachItem(item);
            }
            notifyChanged(this, _fieldName, this, this);
        }
        return found;
    }

    public function push(item:T) {
        _array.push(item);
        attachItem(item);
        notifyChanged(this, _fieldName, this, this);
    }

    public function iterator():Iterator<T> {
        return _array.iterator();
    }
}