package cases.basic;

class ComputedChild extends ComputedBase {
    public var localValue:Int = 2;

    @:computed public var doubled(get, never):Int;
    private function get_doubled():Int return localValue * 2;

    @:computed public var combined(get, never):Int;
    private function get_combined():Int return baseValue + localValue;

    public function new() {
        super();
        localValue = 3;
    }
}
