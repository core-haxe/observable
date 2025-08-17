package observable;

@:autoBuild(observable.ObservableBuilder.build())
interface IObservable {
    public var groupObservableChanges:Bool;

    private var changeListeners(get, set):Array<Array<ChangeInfo<Any>>->Void>;
    public function registerChangeListener(listener:Array<ChangeInfo<Any>>->Void):Void;

    private dynamic function notifyChanged(source:Any, field:String, newValue:Any, oldValue:Any):Void;
}
