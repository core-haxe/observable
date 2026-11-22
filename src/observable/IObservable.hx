package observable;

@:autoBuild(observable.ObservableBuilder.build())
interface IObservable {
    public var groupObservableChanges:Bool;

    private var changeListeners(get, set):Array<{listener: Changes->Void}>;
    public function registerChangeListener(listener:Changes->Void):Void;
    public function unregisterChangeListener(listener:Changes->Void):Void;

    // Called when the first consumer connects or the last consumer disconnects.
    private function onObservationChanged(observed:Bool):Void;

    private dynamic function notifyChanged(source:Any, field:String, newValue:Any, oldValue:Any):Void;
}
