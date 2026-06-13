package observable;

import haxe.ds.ObjectMap;
import observable.ObservableDynamic.ObservableDynamicImpl;

private typedef ObservableArrayItemNotify = Any->String->Any->Any->Void;

private typedef ObservableArrayItemAttachment = {
    var listener:ObservableArrayItemNotify;
    var count:Int;
}

private class ObservableArrayItemDispatcher {
    public var originalNotifyChanged(default, null):ObservableArrayItemNotify;
    public var notifyChanged(default, null):ObservableArrayItemNotify;
    public var listeners(default, null):Array<ObservableArrayItemNotify> = [];

    public function new(originalNotifyChanged:ObservableArrayItemNotify) {
        this.originalNotifyChanged = originalNotifyChanged;
        this.notifyChanged = dispatch;
    }

    private function dispatch(source:Any, field:String, newValue:Any, oldValue:Any):Void {
        if (originalNotifyChanged != null) {
            originalNotifyChanged(source, field, newValue, oldValue);
        }

        var listenersCopy = listeners.copy();
        for (listener in listenersCopy) {
            listener(source, field, newValue, oldValue);
        }
    }
}

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
    private static var _itemDispatchers:ObjectMap<IObservable, ObservableArrayItemDispatcher> = new ObjectMap();

    private var _array:Array<T> = [];
    private var _fieldName:String = null;
    private var _attachedItems:ObjectMap<IObservable, ObservableArrayItemAttachment> = null;
    private var _itemChangeListener:ObservableArrayItemNotify = null;

    public function new() {
    }

    public var length(get, never):Int;
    private function get_length():Int {
        return _array.length;
    }

    private function set_changeListeners(value:Array<{listener: Changes->Void}>):Array<{listener: Changes->Void}> {
        _changeListeners = value;
        if (value == null) {
            clearAttachedItems();
        } else {
            updateChangeListeners();
        }
        return value;
    }

    private function updateChangeListeners() {
        clearAttachedItems();
        if (_array != null) {
            for (item in _array) {
                attachItem(item);
            }
        }
    }

    private function ensureAttachedItems():ObjectMap<IObservable, ObservableArrayItemAttachment> {
        if (_attachedItems == null) {
            _attachedItems = new ObjectMap();
        }
        return _attachedItems;
    }

    private function observableItem(item:T):IObservable {
        if (item is IObservable) {
            return cast item;
        }
        return null;
    }

    private function itemChangeListener():ObservableArrayItemNotify {
        if (_itemChangeListener == null) {
            _itemChangeListener = onItemChanged;
        }
        return _itemChangeListener;
    }

    private function onItemChanged(source:Any, field:String, newValue:Any, oldValue:Any):Void {
        if (notifyChanged != null) {
            notifyChanged(source, field, newValue, oldValue);
        }
    }

    private static function addItemListener(observable:IObservable, listener:ObservableArrayItemNotify):Void {
        var dispatcher = _itemDispatchers.get(observable);
        if (dispatcher == null) {
            dispatcher = new ObservableArrayItemDispatcher(@:privateAccess observable.notifyChanged);
            _itemDispatchers.set(observable, dispatcher);
            @:privateAccess observable.notifyChanged = dispatcher.notifyChanged;
        }
        dispatcher.listeners.push(listener);
    }

    private static function removeItemListener(observable:IObservable, listener:ObservableArrayItemNotify):Void {
        var dispatcher = _itemDispatchers.get(observable);
        if (dispatcher == null) {
            return;
        }

        var toRemove = null;
        for (itemListener in dispatcher.listeners) {
            if (ObservableUtils.isFunctionEqual(itemListener, listener)) {
                toRemove = itemListener;
                break;
            }
        }
        if (toRemove != null) {
            dispatcher.listeners.remove(toRemove);
        }

        if (dispatcher.listeners.length == 0) {
            if (ObservableUtils.isFunctionEqual(@:privateAccess observable.notifyChanged, dispatcher.notifyChanged)) {
                @:privateAccess observable.notifyChanged = dispatcher.originalNotifyChanged;
            }
            _itemDispatchers.remove(observable);
        }
    }

    private function attachItem(item:T):Void {
        var observable = observableItem(item);
        if (observable == null) {
            return;
        }

        var attachedItems = ensureAttachedItems();
        var attachment = attachedItems.get(observable);
        if (attachment != null) {
            attachment.count++;
            return;
        }

        var listener = itemChangeListener();
        attachedItems.set(observable, {
            listener: listener,
            count: 1
        });
        addItemListener(observable, listener);
    }

    private function detachItem(item:T):Void {
        var observable = observableItem(item);
        if (observable == null || _attachedItems == null) {
            return;
        }

        var attachment = _attachedItems.get(observable);
        if (attachment == null) {
            return;
        }

        attachment.count--;
        if (attachment.count > 0) {
            return;
        }

        removeItemListener(observable, attachment.listener);
        _attachedItems.remove(observable);
    }

    private function clearAttachedItems():Void {
        if (_attachedItems == null) {
            return;
        }
        for (observable in _attachedItems.keys()) {
            var attachment = _attachedItems.get(observable);
            if (attachment != null) {
                removeItemListener(observable, attachment.listener);
            }
        }
        _attachedItems = null;
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

    public function contains(item:T):Bool {
        return indexOfItem(item) != -1;
    }

    public function get(index:Int) {
        return _array[index];
    }

    public function set(index:Int, item:T) {
        var oldItem = _array[index];
        _array[index] = item;

        if (oldItem != item) {
            detachItem(oldItem);
            attachItem(item);
        }

        notifyChanged(this, _fieldName, this, this);
    }

    public function remove(item:T) {
        var index = indexOfItem(item);
        if (index != -1) {
            var removedItem = _array.splice(index, 1)[0];
            detachItem(removedItem);
            notifyChanged(this, _fieldName, this, this);
            return true;
        }
        return false;
    }

    public function insert(pos:Int, item:T):Void {
        _array.insert(pos, item);
        attachItem(item);
        notifyChanged(this, _fieldName, this, this);
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
        var removedItems = _array.splice(pos, len);
        for (item in removedItems) {
            detachItem(item);
        }
        notifyChanged(this, _fieldName, this, this);
    }

    public function iterator():Iterator<T> {
        return _array.iterator();
    }
}
