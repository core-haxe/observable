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
    private static function fromDynamic(object:Dynamic):ObservableDynamic {
        var observableDynamic = new ObservableDynamic();
        @:privateAccess observableDynamic._object = object;
        return observableDynamic;
    }
}

class ObservableDynamicImpl implements IObservable {
    private var _object:Dynamic = {};

    public function new() {
    }

    public function get(name:String):Any {
        return Reflect.getProperty(_object, name);
    }

    public function set(name:String, value:Any) {
        var oldValue = get(name);
        Reflect.setProperty(_object, name, value);
        notifyChanged(this, name, value, oldValue);
    }
}