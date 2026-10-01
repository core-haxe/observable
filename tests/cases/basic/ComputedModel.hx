package cases.basic;

import observable.IObservable;

class ComputedModel implements IObservable {
    public var a:Int = 1;
    public var b:Int = 2;
    public var workers:Array<ComputedWorker> = [];
    public var person:ComputedPerson;

    @:computed public var sum(get, never):Int;
    private function get_sum():Int return a + b;

    @:computed public var doubleSum(get, never):Int;
    private function get_doubleSum():Int return sum * 2;

    @:computed public var totalCount(get, never):Int;
    private function get_totalCount():Int {
        TestComputed.totalCountReads++;
        return workers.length;
    }

    @:computed public var completedCount(get, never):Int;
    private function get_completedCount():Int {
        TestComputed.completedCountReads++;
        var completed = 0;
        for (worker in workers) {
            if (worker.progressCurrent >= worker.progressMax) completed++;
        }
        return completed;
    }

    @:computed public var personName(get, never):String;
    private function get_personName():String return person == null ? null : person.name;

    @:computed @:dependsOn(a, b) public var helperSum(get, never):Int;
    private function get_helperSum():Int return calculateHelperSum();
    private function calculateHelperSum():Int return a + b;
}
