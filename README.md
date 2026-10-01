# observable

Implement `IObservable` to have ordinary fields report changes. A read-only
property can opt into automatic change notifications with `@:computed`:

```haxe
class WorkerModel implements observable.IObservable {
    public var workers:Array<Worker> = [];

    @:computed public var totalCount(get, never):Int;
    private function get_totalCount():Int return workers.length;

    @:computed public var completedCount(get, never):Int;
    private function get_completedCount():Int {
        var completed = 0;
        for (worker in workers) {
            if (worker.progressCurrent >= worker.progressMax) completed++;
        }
        return completed;
    }
}
```

The build macro examines each marked getter and watches fields it reads. It
distinguishes collection changes from item changes: `workers.length` responds
to collection changes, while the loop also responds to changes in the item
fields it reads. The getter is reevaluated after a relevant change, and the
computed property reports a change only when its result differs. Local
variables in the getter need no special treatment.

Computed getters should be side-effect-free. Automatic dependency inference
does not follow arbitrary helper-method calls or external state. Add
`@:dependsOn(a, b)` to a computed property when its getter delegates reads of
those fields to a helper method. Dependencies listed this way supplement the
automatically inferred ones. The property must use
`(get, never)` and have a matching `get_<name>()` method.
