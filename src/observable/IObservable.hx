package observable;

@:autoBuild(observable.ObservableBuilder.build())
interface IObservable {
    public var groupObservableChanges:Bool;

    private var changeListeners(get, set):Array<Changes->Void>;
    public function registerChangeListener(listener:Changes->Void):Void;

    private dynamic function notifyChanged(source:Any, field:String, newValue:Any, oldValue:Any):Void;
}
