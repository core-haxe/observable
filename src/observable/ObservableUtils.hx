package observable;

import haxe.ds.ObjectMap;

private typedef ObservableNotify = Any->String->Any->Any->Void;

private class ObservableNotifyDispatcher {
    public var originalNotifyChanged(default, null):ObservableNotify;
    public var notifyChanged(default, null):ObservableNotify;
    public var listeners(default, null):Array<ObservableNotify> = [];

    public function new(originalNotifyChanged:ObservableNotify) {
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

class ObservableUtils {
    private static var _notifyDispatchers:ObjectMap<IObservable, ObservableNotifyDispatcher> = new ObjectMap();

    public static function forwardedFieldName(parentField:String, childField:String, isCollection:Bool):String {
        if (isCollection) {
            return (childField == null || childField.length == 0) ? parentField : childField;
        }

        if (childField == null || childField.length == 0) {
            return parentField;
        }
        if (parentField == null || parentField.length == 0) {
            return childField;
        }
        if (childField == parentField || StringTools.startsWith(childField, parentField + ".")) {
            return childField;
        }
        return parentField + "." + childField;
    }

    public static inline function isFunctionEqual(a:Dynamic, b:Dynamic):Bool {
        #if neko
        return a == b || Reflect.compareMethods(a, b);
        #else
        return a == b;
        #end
    }

    public static function addForwarder(observable:IObservable, listener:ObservableNotify):Void {
        if (observable == null || listener == null) {
            return;
        }

        var dispatcher = _notifyDispatchers.get(observable);
        if (dispatcher == null) {
            dispatcher = new ObservableNotifyDispatcher(@:privateAccess observable.notifyChanged);
            _notifyDispatchers.set(observable, dispatcher);
            @:privateAccess observable.notifyChanged = dispatcher.notifyChanged;
        }

        for (existing in dispatcher.listeners) {
            if (isFunctionEqual(existing, listener)) {
                return;
            }
        }
        dispatcher.listeners.push(listener);
    }

    public static function removeForwarder(observable:IObservable, listener:ObservableNotify):Void {
        if (observable == null || listener == null) {
            return;
        }

        var dispatcher = _notifyDispatchers.get(observable);
        if (dispatcher == null) {
            return;
        }

        var toRemove = null;
        for (existing in dispatcher.listeners) {
            if (isFunctionEqual(existing, listener)) {
                toRemove = existing;
                break;
            }
        }
        if (toRemove != null) {
            dispatcher.listeners.remove(toRemove);
        }

        if (dispatcher.listeners.length == 0) {
            if (isFunctionEqual(@:privateAccess observable.notifyChanged, dispatcher.notifyChanged)) {
                @:privateAccess observable.notifyChanged = dispatcher.originalNotifyChanged;
            }
            _notifyDispatchers.remove(observable);
        }
    }
}
