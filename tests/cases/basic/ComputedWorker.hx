package cases.basic;

import observable.IObservable;

class ComputedWorker implements IObservable {
    public var name:String;
    public var progressCurrent:Int = 0;
    public var progressMax:Int = 10;
}
