package observable;

@:forward
@:forward.new
@:forward.variance
@:forwardStatics
abstract ObservableDynamic(ObservableDynamicImpl) {
    @:op(a.b)
    public function fieldRead(name:String):Any {
        return this.get(name);
    }

    @:op(a.b)
    public function fieldWrite(name:String, value:Any) {
        this.set(name, value);
    }

    @:from
    public static function fromDynamic(object:Dynamic):ObservableDynamic {
        return fromValue(object);
    }

    public static function fromValue(object:Dynamic):ObservableDynamic {
        if (object is ObservableDynamicImpl) {
            return cast object;
        }

        var observableDynamic = new ObservableDynamic();
        @:privateAccess observableDynamic._object = object;
        return observableDynamic;
    }

    public function unwrap():Dynamic {
        return @:privateAccess this._object;
    }
}

class ObservableDynamicImpl implements IObservable {
    private var _object:Dynamic = {};

    public function new() {
    }

    public function get(name:String):Any {
        return Reflect.getProperty(_object, name);
    }

    public function unwrap():Dynamic {
        return _object;
    }

    public function set(name:String, value:Any) {
        var oldValue = get(name);
        if (oldValue == value) {
            return;
        }
        Reflect.setProperty(_object, name, value);
        notifyChanged(this, name, value, oldValue);
    }

    public function toString():String {
        return Std.string(_object);
    }
}
