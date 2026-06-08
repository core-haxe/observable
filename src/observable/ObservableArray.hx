package observable;

import observable.ObservableDynamic.ObservableDynamicImpl;

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

    private function unwrapItem(item:Dynamic):Dynamic {
        if (item is ObservableDynamicImpl) {
            return @:privateAccess cast(item, ObservableDynamicImpl)._object;
        }
        return item;
    }

    private function itemMatches(a:Dynamic, b:Dynamic):Bool {
        if (a == b) {
            return true;
        }
        if (a is ObservableDynamicImpl || b is ObservableDynamicImpl) {
            return unwrapItem(a) == unwrapItem(b);
        }
        return false;
    }

    private function indexOfItem(item:T):Int {
        for (i in 0..._array.length) {
            if (itemMatches(_array[i], item)) {
                return i;
            }
        }
        return -1;
    }

    private function containsExact(item:T):Bool {
        return _array.contains(item);
    }

    public function contains(item:T):Bool {
        return indexOfItem(item) != -1;
    }

    public function get(index:Int) {
        return _array[index];
    }

    public function set(index:Int, item:T) {
        var oldItem = _array[index];
        _array[index] = item;

        if (oldItem != null && oldItem != item && !containsExact(oldItem)) {
            detachItem(oldItem);
        }

        attachItem(item);
        notifyChanged(this, _fieldName, this, this);
    }

    public function remove(item:T) {
        var index = indexOfItem(item);
        if (index != -1) {
            var removedItem = _array.splice(index, 1)[0];
            if (!containsExact(removedItem)) {
                detachItem(removedItem);
            }
            notifyChanged(this, _fieldName, this, this);
            return true;
        }
        return false;
    }

    public function push(item:T) {
        _array.push(item);
        attachItem(item);
        notifyChanged(this, _fieldName, this, this);
    }

    public function sort(cmp:(T, T) -> Int) {
        _array.sort(cmp);
        notifyChanged(this, _fieldName, this, this);
    }

    public function splice(pos:Int, len:Int) {
        _array.splice(pos, len);
        notifyChanged(this, _fieldName, this, this);
    }

    public function iterator():Iterator<T> {
        return _array.iterator();
    }
}
