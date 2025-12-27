package observable;

import haxe.macro.ExprTools;
import haxe.macro.Type.ClassType;
import haxe.macro.TypeTools;
#if macro
import haxe.macro.Compiler;
import haxe.macro.Expr.Field;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.ComplexTypeTools;
#end

class ObservableBuilder {
    public static macro function build():Array<Field> {
        if (Context.getLocalClass().get().name != "ObservableArrayImpl" && Context.getLocalClass().get().name != "ObservableMapImpl") {
            Sys.println("observable  > building observable for " + Context.getLocalClass().toString());
        }

        var fields = Context.getBuildFields();

        buildVars(fields);
        buildNotifyChanged(fields);
        buildOnTick(fields);

        var observableSubObjects:Array<{name:String, expr:Expr}> = [];
        if (Context.getLocalClass().get().name != "ObservableArrayImpl" && Context.getLocalClass().get().name != "ObservableMapImpl") {
            observableSubObjects = buildObservableProperties(fields);
        }

        buildChangeListeners(fields, observableSubObjects);
        buildConstructor(fields, observableSubObjects);

        return fields;
    }

    #if macro
    private static function getField(name:String, fields:Array<Field>):Field {
        for (f in fields) {
            if (f.name == name) {
                return f;
            }
        }

        return null;
    }

    private static function buildConstructor(fields:Array<Field>, observableSubObjects:Array<{name:String, expr:Expr}>) {
        var ctor = getField("new", fields);
        var assignmentExprs:Array<Expr> = [];
        for (observableSubObject in observableSubObjects) {
            if (observableSubObject.expr != null) {
                var varName = observableSubObject.name.substring(1);
                var e = observableSubObject.expr;
                if (e != null) {
                    assignmentExprs.push(macro {
                        $i{varName} = $e;
                    });
                }
            }
        }
        if (ctor == null) {
            if (Context.getLocalClass().get().superClass != null) {
                ctor = {
                    name: "new",
                    access: [APublic],
                    kind: FFun({
                        args:[],
                        expr: macro {
                            super();
                            {
                                $a{assignmentExprs}
                            }
                            set_changeListeners(_changeListeners);
                        }
                    }),
                    pos: Context.currentPos()
                }
            } else {
                ctor = {
                    name: "new",
                    access: [APublic],
                    kind: FFun({
                        args:[],
                        expr: macro {
                            {
                                $a{assignmentExprs}
                            }
                            set_changeListeners(_changeListeners);
                        }
                    }),
                    pos: Context.currentPos()
                }
            }
            fields.push(ctor);
        } else {
            // TODO: if ctor exists, add 'set_changeListeners(_changeListeners)' to it
            switch (ctor.kind) {
                case FFun(f):
                    switch (f.expr.expr) {
                        case EBlock(exprs):
                            exprs.insert(1, macro {
                                {
                                    $a{assignmentExprs}
                                }
                                set_changeListeners(_changeListeners);
                            });
                        case _:    
                    }
                case _:    
            }
        }
    }

    private static function buildVars(fields:Array<Field>) {
        var existingChangesToNotify = TypeTools.findField(Context.getLocalClass().get(), "changesToNotify");
        if (existingChangesToNotify == null) {
            var changesToNotify = getField("changesToNotify", fields);
            if (changesToNotify == null) {
                changesToNotify = {
                    name: "changesToNotify",
                    access: [APrivate],
                    kind: FVar(macro: Array<observable.ChangeInfo<Any>>, macro []),
                    pos: Context.currentPos()
                }
                fields.push(changesToNotify);
            }
        }

        var existingWaitingForTick = TypeTools.findField(Context.getLocalClass().get(), "waitingForTick");
        if (existingWaitingForTick == null) {
            var waitingForTick = getField("waitingForTick", fields);
            if (waitingForTick == null) {
                waitingForTick = {
                    name: "waitingForTick",
                    access: [APrivate],
                    kind: FVar(macro: Bool, macro false),
                    pos: Context.currentPos()
                }
                fields.push(waitingForTick);
            }
        }

        var existingGroupObservableChanges = TypeTools.findField(Context.getLocalClass().get(), "groupObservableChanges");
        if (existingGroupObservableChanges == null) {
            var groupObservableChanges = getField("groupObservableChanges", fields);
            if (groupObservableChanges == null) {
                groupObservableChanges = {
                    name: "groupObservableChanges",
                    access: [APublic],
                    kind: FVar(macro: Bool, macro observable.ObservableDefaults.GroupChanges),
                    pos: Context.currentPos()
                }
                fields.push(groupObservableChanges);
            }
        }
    }

    private static function buildChangeListeners(fields:Array<Field>, observableSubObjects:Array<{name:String, expr:Expr}>) {
        var existing_changeListeners = TypeTools.findField(Context.getLocalClass().get(), "_changeListeners");
        if (existing_changeListeners == null) {
            var _changeListeners = getField("_changeListeners", fields);
            if (_changeListeners == null) {
                _changeListeners = {
                    name: "_changeListeners",
                    access: [APrivate],
                    kind: FVar(macro: Array<observable.Changes->Void>, macro []),
                    pos: Context.currentPos()
                }
                fields.push(_changeListeners);
            }

            var changeListeners = getField("changeListeners", fields);
            if (changeListeners == null) {
                changeListeners = {
                    name: "changeListeners",
                    access: [APrivate],
                    kind: FProp("get", "set", macro: Array<observable.Changes->Void>),
                    pos: Context.currentPos()
                }
                fields.push(changeListeners);
            }

            var get_changeListeners = getField("get_changeListeners", fields);
            if (get_changeListeners == null) {
                get_changeListeners = {
                    name: "get_changeListeners",
                    access: [APrivate],
                    kind: FFun({
                        args:[],
                        expr: macro {
                            return _changeListeners;
                        }
                    }),
                    pos: Context.currentPos()
                }
                fields.push(get_changeListeners);
            }

            var set_changeListeners = getField("set_changeListeners", fields);
            if (set_changeListeners == null) {
                var exprs:Array<Expr> = [];
                for (observableSubObject in observableSubObjects) {
                    exprs.push(macro {
                        if ($i{observableSubObject.name} != null) {
                            @:privateAccess $i{observableSubObject.name}.notifyChanged = this.notifyChanged;
                            @:privateAccess $i{observableSubObject.name}.changeListeners = value;
                        }
                    });
                }
                set_changeListeners = {
                    name: "set_changeListeners",
                    access: [APrivate],
                    kind: FFun({
                        args:[{ name: "value", type: macro: Array<observable.Changes->Void>}],
                        expr: macro {
                            _changeListeners = value;
                            {
                                $a{exprs}
                            }
                            return value;
                        }
                    }),
                    pos: Context.currentPos()
                }
                fields.push(set_changeListeners);
            }
        }

        var existingRegisterChangeListener = TypeTools.findField(Context.getLocalClass().get(), "registerChangeListener");
        if (existingRegisterChangeListener == null) {
            var registerChangeListener = getField("registerChangeListener", fields);
            if (registerChangeListener == null) {
                registerChangeListener = {
                    name: "registerChangeListener",
                    access: [APublic],
                    kind: FFun({
                        args:[{ name: "listener", type: macro: observable.Changes->Void}],
                        expr: macro {
                            _changeListeners.push(listener);
                        }
                    }),
                    pos: Context.currentPos()
                }
                fields.push(registerChangeListener);
            }
        }
    }

    private static function buildNotifyChanged(fields:Array<Field>) {
        var existingNotifyChanged = TypeTools.findField(Context.getLocalClass().get(), "notifyChanged");
        if (existingNotifyChanged == null) {
            var notifyChanged = getField("notifyChanged", fields);
            if (notifyChanged == null) {
                notifyChanged = {
                    name: "notifyChanged",
                    access: [APrivate, ADynamic],
                    kind: FFun({
                        args:[
                            { name: "source", type: macro: Any},
                            { name: "field", type: macro: String},
                            { name: "newValue", type: macro: Any},
                            { name: "oldValue", type: macro: Any}
                        ],
                        expr: macro {}
                    }),
                    pos: Context.currentPos()
                }
                fields.push(notifyChanged);
            }

            switch (notifyChanged.kind) {
                case FFun(f):
                    f.expr = macro {
                        if (groupObservableChanges) {
                            changesToNotify.push({
                                timestamp: Date.now().getTime(),
                                source: source,
                                field: field,
                                newValue: newValue,
                                oldValue: oldValue
                            });
                            if (!waitingForTick) {
                                waitingForTick = true;
                                observable.ObservableDefaults.onTick(onTick);
                            }
                        } else {
                            if (changeListeners != null) {
                                for (listener in changeListeners) {
                                    var changes = new observable.Changes();
                                    changes.items = [{
                                        timestamp: Date.now().getTime(),
                                        source: source,
                                        field: field,
                                        newValue: newValue,
                                        oldValue: oldValue
                                    }];
                                    listener(changes);
                                }
                            }
                        }
                    }
                case _:
            }
        }
    }

    private static function buildOnTick(fields:Array<Field>) {
        var existingOnTick = TypeTools.findField(Context.getLocalClass().get(), "onTick");
        if (existingOnTick == null) {
            var onTick = getField("onTick", fields);
            if (onTick == null) {
                onTick = {
                    name: "onTick",
                    access: [APrivate],
                    kind: FFun({
                        args:[],
                        expr: macro {}
                    }),
                    pos: Context.currentPos()
                }
                fields.push(onTick);
            }

            switch (onTick.kind) {
                case FFun(f):
                    f.expr = macro {
                        var copy = changesToNotify.copy();
                        changesToNotify = [];
                        waitingForTick = false;
                        var changes = new observable.Changes();
                        changes.items = copy;
                        for (listener in changeListeners) {
                            listener(changes);
                        }
                    }
                case _:
            }
        }
    }

    private static function buildObservableProperties(fields:Array<Field>):Array<{name:String, expr:Expr}> {
        var allowPublic:Bool = true;
        var allowPrivate:Bool = true;
        var defines = Context.getDefines();
        if (defines.exists("observable.defaults.public")) {
            allowPublic = (defines.get("observable.defaults.public") == "observed");
        }
        if (defines.exists("observable.defaults.private")) {
            allowPrivate = (defines.get("observable.defaults.private") == "observed");
        }

        var fieldsToAdd:Array<Field> = [];
        var fieldsToRemove:Array<Field> = [];
        var observableSubObjects:Array<{name:String, expr:Expr}> = [];

        for (field in fields) {
            if (field.name == "groupObservableChanges" || field.name == "changesToNotify" || field.name == "waitingForTick" || field.name == "_changeListeners") {
                continue;
            }

            var useField = true;
            if (!allowPublic && field.access.contains(APublic)) {
                useField = false;
            }
            if (!allowPrivate && field.access.contains(APrivate)) {
                useField = false;
            }

            if (hasMeta("observable", field.meta)) {
                useField = true;
                var observableMeta = getMeta("observable", field.meta);
                if (observableMeta.params.length > 0) {
                    useField = ExprTools.getValue(observableMeta.params[0]);
                }
            }

            if (!useField) {
                continue;
            }

            switch (field.kind) {
                case FVar(t, e):
                    fieldsToRemove.push(field);
                    var varName = "_" + field.name;
                    var newType = t;
                    if (isArray(field)) { // we'll change Array<T> => ObservableArray<T>
                        switch (t) {
                            case TPath(p):
                                var tp0 = switch(p.params[0]) {
                                    case TPType(t): t;
                                    case _: null;
                                }
                                newType = macro: observable.ObservableArray<$tp0>;
                            case _:
                                trace(t);
                        }
                    } else if (isMap(field)) { // we'll change Map<K, V> => ObservableMap<K, V>
                        switch (t) {
                            case TPath(p):
                                var tp0 = switch(p.params[0]) {
                                    case TPType(t): t;
                                    case _: null;
                                }
                                var tp1 = switch(p.params[1]) {
                                    case TPType(t): t;
                                    case _: null;
                                }
                                newType = macro: observable.ObservableMap<$tp0, $tp1>;
                            case _:
                                trace(t);
                        }
                    }

                    var newField = {
                        name: varName,
                        access: [APrivate],
                        kind: FVar(newType, e),
                        pos: Context.currentPos()
                    }
                    fieldsToAdd.push(newField);

                    var newField = {
                        name: field.name,
                        access: field.access,
                        kind: FProp("get", "set", newType),
                        pos: Context.currentPos()
                    }
                    fieldsToAdd.push(newField);

                    var newField = {
                        name: "get_" + field.name,
                        access: [APrivate],
                        kind: FFun({
                            args:[],
                            expr: macro {
                                return $i{varName};
                            },
                            ret: newType
                        }),
                        pos: Context.currentPos()
                    }
                    fieldsToAdd.push(newField);

                    if (isArray(field) || isMap(field)) {
                        //observableSubObjects.push({name: varName, expr: null});
                        observableSubObjects.push({name: varName, expr: e});
                        var newField = {
                            name: "set_" + field.name,
                            access: [APrivate],
                            kind: FFun({
                                args:[{name: "value", type: newType}],
                                expr: macro {
                                    if ($i{varName} == value) {
                                        return value;
                                    }
                                    var oldValue = $i{varName};
                                    $i{varName} = value;
                                    if (oldValue != null) {
                                        @:privateAccess oldValue.notifyChanged = null;
                                        @:privateAccess oldValue.changeListeners = null;
                                    }
                                    @:privateAccess $i{varName}.notifyChanged = this.notifyChanged;
                                    @:privateAccess $i{varName}.changeListeners = this.changeListeners;
                                    @:privateAccess $i{varName}._fieldName = $v{field.name};
                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return value;
                                },
                                ret: newType
                            }),
                            pos: Context.currentPos()
                        }
                        fieldsToAdd.push(newField);
                    } else if (isObservable(field)) {
                        observableSubObjects.push({name: varName, expr: e});
                        var newField = {
                            name: "set_" + field.name,
                            access: [APrivate],
                            kind: FFun({
                                args:[{name: "value", type: t}],
                                expr: macro {
                                    if ($i{varName} == value) {
                                        return value;
                                    }
                                    var oldValue = $i{varName};
                                    $i{varName} = value;
                                    if (oldValue != null) {
                                        @:privateAccess oldValue.notifyChanged = null;
                                        @:privateAccess oldValue.changeListeners = null;
                                    }
                                    @:privateAccess $i{varName}.notifyChanged = this.notifyChanged;
                                    @:privateAccess $i{varName}.changeListeners = this.changeListeners;
                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return value;
                                },
                                ret: t
                            }),
                            pos: Context.currentPos()
                        }
                        fieldsToAdd.push(newField);
                    } else {
                        var newField = {
                            name: "set_" + field.name,
                            access: [APrivate],
                            kind: FFun({
                                args:[{name: "value", type: t}],
                                expr: macro {
                                    if ($i{varName} == value) {
                                        return value;
                                    }
                                    var oldValue = $i{varName};
                                    $i{varName} = value;
                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return value;
                                },
                                ret: t
                            }),
                            pos: Context.currentPos()
                        }
                        fieldsToAdd.push(newField);
                    }
                case FProp(get, set, t, e):    
                    //trace("PROP", field.name);
                case _:    
            }
        }

        for (f in fieldsToRemove) {
            fields.remove(f);
        }
        for (f in fieldsToAdd) {
            fields.push(f);
        }
        return observableSubObjects;
    }

    private static function isArray(field:Field):Bool {
        return switch (field.kind) {
            case FVar(t, e):
                switch (t) {
                    case TPath(p): p.name == "Array" || p.name == "ObservableArray";
                    case _: false;
                }
            case _: false;
        }
    }

    private static function isMap(field:Field):Bool {
        return switch (field.kind) {
            case FVar(t, e):
                switch (t) {
                    case TPath(p): p.name == "Map" || p.name == "ObservableMap";
                    case _: false;
                }
            case _: false;
        }
    }

    private static function isObservable(field:Field):Bool {
        switch (field.kind) {
            case FVar(t, e):
                var t = ComplexTypeTools.toType(t);
                switch (t) {
                    case TInst(t, params):
                        return hasObservableInterface(t.get());
                     case _:   
                        return false;
                }
            case _:
                return false;
        }
        return false;
    }

    private static function hasObservableInterface(classType:ClassType):Bool {
        if (classType == null) {
            return false;
        }
        if (classType.interfaces != null) {
            for (i in classType.interfaces) {
                if (i.t.toString() == "observable.IObservable") {
                    return true;
                }
            }
        }
        if (classType.superClass == null) {
            return false;
        }
        return hasObservableInterface(classType.superClass.t.get());
    }

    private static function hasMeta(name:String, meta:Metadata) {
        if (meta == null) {
            return false;
        }
        for (m in meta) {
            if (m.name == name || m.name == ":" + name) {
                return true;
            }
        }
        return false;
    }

    private static function getMeta(name:String, meta:Metadata):MetadataEntry {
        if (meta == null) {
            return null;
        }
        for (m in meta) {
            if (m.name == name || m.name == ":" + name) {
                return m;
            }
        }
        return null;
    }
    #end
}