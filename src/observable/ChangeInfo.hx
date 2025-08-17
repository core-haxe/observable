package observable;

@:structInit
class ChangeInfo<T> {
    @:optional public var timestamp:Float;
    @:optional public var source:Any;
    @:optional public var field:String;
    @:optional public var newValue:T;
    @:optional public var oldValue:T;
}