package cases.basic;

import observable.IObservable;

class ComputedBase implements IObservable {
    public var baseValue:Int = 1;

    @:computed public var baseDouble(get, never):Int;
    private function get_baseDouble():Int return baseValue * 2;
}
