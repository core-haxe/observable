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

    private function set_changeListeners(value:Array<Array<ChangeInfo<Any>>->Void>):Array<Array<ChangeInfo<Any>>->Void> {
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

    public function get(index:Int) {
        return _array[index];
    }

    public function push(item:T) {
        _array.push(item);
        if (item is IObservable) {
            @:privateAccess cast(item, IObservable).notifyChanged = this.notifyChanged;
            @:privateAccess cast(item, IObservable).changeListeners = this.changeListeners;
        }
        notifyChanged(this, _fieldName, item, null);
    }
}