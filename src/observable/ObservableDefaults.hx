package observable;

class ObservableDefaults {
    public static var GroupChanges:Bool = true;
    public static var EliminateDuplicates:Bool = true;

    public static dynamic function onTick(fn:Void->Void) {
        #if nodejs

        haxe.Timer.delay(fn, 0);

        #elseif js

        js.Browser.window.requestAnimationFrame((_) -> {
            fn();
        });

        #else

        haxe.Timer.delay(fn, 0);

        #end
    }
}