package observable;

class ObservableUtils {
    public static inline function isFunctionEqual(a:Dynamic, b:Dynamic):Bool {
        #if neko
        return a == b || Reflect.compareMethods(a, b);
        #else
        return a == b;
        #end
    }
}
