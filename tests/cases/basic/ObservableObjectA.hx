package cases.basic;

import observable.IObservable;

class ObservableObjectA implements IObservable {
    public var nullableIntValue:Null<Int>;
    public var nullableFloatValue:Null<Float>;
    public var nullableBoolValue:Null<Bool>;
    public var nullableStringValue:String;

    public var intValueWithDefault:Int = 111;
    public var floatValueWithDefault:Float = 222.22;
    public var boolValueWithDefault:Bool = true;
    public var stringValueWithDefault:String = "tim";

    public var subObjectA:ObservableObjectA;
    public var subObjectB:ObservableObjectB;

    public var subObjectAWithDefault:ObservableObjectB = new ObservableObjectB();

    public var normalArray:Array<Int>;
    public var normalArrayWithEmptyDefault:Array<Int> = [];
    public var normalArrayWithDefault:Array<Int> = [111, 222, 333];

    public var objectArrayA:Array<ObservableObjectA> = [];
}