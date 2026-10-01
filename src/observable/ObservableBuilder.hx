package observable;

#if macro
import haxe.macro.ExprTools;
import haxe.macro.Type.ClassType;
import haxe.macro.TypeTools;
import haxe.macro.Compiler;
import haxe.macro.Expr.Field;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.ComplexTypeTools;

private enum ComputedDependency {
    Field(name:String);
    NestedField(name:String, child:String);
    CollectionStructure(name:String);
    CollectionItem(name:String, child:String);
    CollectionAny(name:String);
}

private typedef ComputedProperty = {
    var name:String;
    var type:ComplexType;
    var getter:String;
    var dependencies:Array<ComputedDependency>;
}
#end

class ObservableBuilder {
    public static macro function build():Array<Field> {
        if (Context.getLocalClass().get().name != "ObservableArrayImpl" && Context.getLocalClass().get().name != "ObservableMapImpl" && Context.getLocalClass().get().name != "ObservableDynamicImpl") {
            Sys.println("observable  > building observable for " + Context.getLocalClass().toString());
        }

        var fields = Context.getBuildFields();

        var computedProperties = analyzeComputedProperties(fields);

        buildVars(fields);
        buildNotifyChanged(fields);
        buildOnTick(fields);

        var observableSubObjects:Array<{name:String, fieldName:String, forwarderName:String, expr:Expr, ?isDynamic:Bool, ?isCollection:Bool}> = [];
        if (Context.getLocalClass().get().name != "ObservableArrayImpl" && Context.getLocalClass().get().name != "ObservableMapImpl" && Context.getLocalClass().get().name != "ObservableDynamicImpl") {
            observableSubObjects = buildObservableProperties(fields);
        }

        buildObservableForwarders(fields, observableSubObjects);
        buildChangeListeners(fields, observableSubObjects);
        buildConstructor(fields, observableSubObjects);
        buildComputedProperties(fields, computedProperties);

        return fields;
    }

    #if macro
    private static function hasField(name:String, fields:Array<Field>):Bool {
        return (getField(name, fields) != null);
    }

    private static function getField(name:String, fields:Array<Field>):Field {
        for (f in fields) {
            if (f.name == name) {
                return f;
            }
        }

        return null;
    }

    private static function noCompletionMeta(?meta:Metadata):Metadata {
        var result = (meta == null) ? [] : meta.copy();
        if (!hasMeta("noCompletion", result)) {
            result.push({name: ":noCompletion", params: [], pos: Context.currentPos()});
        }
        return result;
    }

    private static function analyzeComputedProperties(fields:Array<Field>):Array<ComputedProperty> {
        var result:Array<ComputedProperty> = [];
        var modelFields:Map<String, Field> = new Map();
        for (field in fields) {
            switch (field.kind) {
                case FVar(_, _), FProp(_, _, _, _): modelFields.set(field.name, field);
                case _:
            }
        }
        var superclass = Context.getLocalClass().get().superClass;
        while (superclass != null) {
            var parent = superclass.t.get();
            for (inherited in parent.fields.get()) {
                if (!inherited.isPublic || modelFields.exists(inherited.name)) continue;
                switch (inherited.kind) {
                    case FVar(_, _):
                        modelFields.set(inherited.name, {
                            name: inherited.name,
                            access: [APublic],
                            kind: FVar(TypeTools.toComplexType(inherited.type)),
                            pos: inherited.pos
                        });
                    case _:
                }
            }
            superclass = parent.superClass;
        }

        for (property in fields) {
            if (!hasMeta("computed", property.meta)) {
                continue;
            }
            var propertyType = switch (property.kind) {
                case FProp("get", "never", t, _): t;
                case _:
                    Context.error("@:computed requires a read-only getter property", property.pos);
                    null;
            }
            var getterName = "get_" + property.name;
            var getter = getField(getterName, fields);
            if (getter == null) {
                Context.error("@:computed requires " + getterName + "()", property.pos);
            }
            var body = switch (getter.kind) {
                case FFun(fn): fn.expr;
                case _:
                    Context.error(getterName + " must be a function", getter.pos);
                    null;
            }

            var dependencies:Array<ComputedDependency> = [];
            collectComputedDependencies(body, modelFields, new Map(), new Map(), dependencies);
            var explicitDependencies = getMeta("dependsOn", property.meta);
            if (explicitDependencies != null) {
                for (expression in explicitDependencies.params) {
                    var inferred:Array<ComputedDependency> = [];
                    collectComputedDependencies(expression, modelFields, new Map(), new Map(), inferred);
                    if (inferred.length == 0) {
                        Context.error("Cannot resolve @:dependsOn entry for " + property.name, expression.pos);
                    }
                    for (dependency in inferred) addComputedDependency(dependencies, dependency);
                }
            }
            if (dependencies.length == 0) {
                Context.error("Cannot infer dependencies for " + property.name + "; read an observable field or use @:dependsOn", property.pos);
            }
            for (dependency in dependencies) {
                if (computedDependencyRoot(dependency) == property.name) {
                    Context.error("Computed property " + property.name + " cannot depend on itself", property.pos);
                }
            }
            result.push({name: property.name, type: propertyType, getter: getterName, dependencies: dependencies});
        }
        rejectComputedCycles(result, fields);
        return result;
    }

    private static function rejectComputedCycles(properties:Array<ComputedProperty>, fields:Array<Field>) {
        var byName:Map<String, ComputedProperty> = new Map();
        var states:Map<String, Int> = new Map();
        for (property in properties) byName.set(property.name, property);

        var visit:String->Void = null;
        visit = function(name:String):Void {
            var state = states.get(name);
            if (state == 2) return;
            if (state == 1) {
                Context.error("Circular @:computed dependency involving " + name, getField(name, fields).pos);
            }
            states.set(name, 1);
            for (dependency in byName.get(name).dependencies) {
                var upstream = computedDependencyRoot(dependency);
                if (upstream != null && byName.exists(upstream)) visit(upstream);
            }
            states.set(name, 2);
        }
        for (property in properties) visit(property.name);
    }

    private static function computedDependencyRoot(dependency:ComputedDependency):String {
        return switch (dependency) {
            case Field(name), NestedField(name, _), CollectionStructure(name), CollectionItem(name, _), CollectionAny(name): name;
        }
    }

    private static function collectComputedDependencies(expr:Expr, modelFields:Map<String, Field>, locals:Map<String, Bool>, loopSources:Map<String, String>, dependencies:Array<ComputedDependency>) {
        if (expr == null) return;

        switch (expr.expr) {
            case EBlock(expressions):
                var blockLocals = copyMap(locals);
                for (expression in expressions) {
                    collectComputedDependencies(expression, modelFields, blockLocals, loopSources, dependencies);
                }

            case EVars(vars):
                for (variable in vars) {
                    collectComputedDependencies(variable.expr, modelFields, locals, loopSources, dependencies);
                    locals.set(variable.name, true);
                }

            case EFor(iterator, body):
                switch (iterator.expr) {
                    case EBinop(OpIn, variable, collection):
                        var collectionName = readModelField(collection, modelFields, locals);
                        var variableName = switch (variable.expr) {
                            case EConst(CIdent(name)): name;
                            case _: null;
                        }
                        if (collectionName != null && isCollectionType(modelFields.get(collectionName)) && variableName != null) {
                            addComputedDependency(dependencies, CollectionStructure(collectionName));
                            var bodyLocals = copyMap(locals);
                            var bodySources = copyMap(loopSources);
                            bodyLocals.set(variableName, true);
                            bodySources.set(variableName, collectionName);
                            collectComputedDependencies(body, modelFields, bodyLocals, bodySources, dependencies);
                        } else {
                            collectComputedDependencies(iterator, modelFields, locals, loopSources, dependencies);
                            collectComputedDependencies(body, modelFields, copyMap(locals), loopSources, dependencies);
                        }
                    case _:
                        collectComputedDependencies(iterator, modelFields, locals, loopSources, dependencies);
                        collectComputedDependencies(body, modelFields, copyMap(locals), loopSources, dependencies);
                }

            case EField(base, member, _):
                var loopName = readIdentifier(base);
                if (loopName != null && loopSources.exists(loopName)) {
                    addComputedDependency(dependencies, CollectionItem(loopSources.get(loopName), member));
                    return;
                }
                var ownerName = readModelField(base, modelFields, locals);
                if (ownerName != null) {
                    if (isCollectionType(modelFields.get(ownerName))) {
                        addComputedDependency(dependencies, member == "length" ? CollectionStructure(ownerName) : CollectionAny(ownerName));
                    } else {
                        addComputedDependency(dependencies, NestedField(ownerName, member));
                    }
                    return;
                }
                if (isThis(base) && modelFields.exists(member)) {
                    addDirectComputedDependency(dependencies, member, modelFields);
                    return;
                }
                collectComputedDependencies(base, modelFields, locals, loopSources, dependencies);

            case EConst(CIdent(name)):
                if (loopSources.exists(name)) {
                    addComputedDependency(dependencies, CollectionAny(loopSources.get(name)));
                } else if (!locals.exists(name) && modelFields.exists(name)) {
                    addDirectComputedDependency(dependencies, name, modelFields);
                }

            case EFunction(_, fn):
                var functionLocals = copyMap(locals);
                for (arg in fn.args) functionLocals.set(arg.name, true);
                collectComputedDependencies(fn.expr, modelFields, functionLocals, loopSources, dependencies);

            case _:
                ExprTools.iter(expr, child -> collectComputedDependencies(child, modelFields, locals, loopSources, dependencies));
        }
    }

    private static function addDirectComputedDependency(dependencies:Array<ComputedDependency>, name:String, modelFields:Map<String, Field>) {
        addComputedDependency(dependencies, isCollectionType(modelFields.get(name)) ? CollectionAny(name) : Field(name));
    }

    private static function addComputedDependency(dependencies:Array<ComputedDependency>, dependency:ComputedDependency) {
        var key = Std.string(dependency);
        for (existing in dependencies) {
            if (Std.string(existing) == key) return;
        }
        dependencies.push(dependency);
    }

    private static function readModelField(expr:Expr, modelFields:Map<String, Field>, locals:Map<String, Bool>):String {
        if (expr == null) return null;
        return switch (expr.expr) {
            case EConst(CIdent(name)) if (!locals.exists(name) && modelFields.exists(name)): name;
            case EField(base, name, _) if (isThis(base) && modelFields.exists(name)): name;
            case EParenthesis(inner): readModelField(inner, modelFields, locals);
            case _: null;
        }
    }

    private static function readIdentifier(expr:Expr):String {
        if (expr == null) return null;
        return switch (expr.expr) {
            case EConst(CIdent(name)): name;
            case EParenthesis(inner): readIdentifier(inner);
            case _: null;
        }
    }

    private static function isThis(expr:Expr):Bool {
        return readIdentifier(expr) == "this";
    }

    private static function isCollectionType(field:Field):Bool {
        if (field == null) return false;
        var type = switch (field.kind) {
            case FVar(t, _), FProp(_, _, t, _): t;
            case _: null;
        }
        return switch (type) {
            case TPath(path): path.name == "Array" || path.name == "ObservableArray";
            case _: false;
        }
    }

    private static function copyMap<T>(source:Map<String, T>):Map<String, T> {
        var copy:Map<String, T> = new Map();
        for (key in source.keys()) copy.set(key, source.get(key));
        return copy;
    }

    private static function buildComputedProperties(fields:Array<Field>, properties:Array<ComputedProperty>) {
        if (properties.length == 0) return;

        var classSuffix = StringTools.replace(Context.getLocalClass().toString(), ".", "_");
        var changeMethodName = "__observableComputedChanged_" + classSuffix;
        var initializers:Array<Expr> = [];
        var checks:Array<Expr> = [];
        for (property in properties) {
            var valueName = "__observableComputedValue_" + classSuffix + "_" + property.name;
            if (getField(valueName, fields) != null) {
                Context.error("Reserved computed property field already exists: " + valueName, Context.currentPos());
            }
            fields.push({
                name: valueName,
                access: [APrivate],
                kind: FVar(property.type),
                meta: noCompletionMeta(),
                pos: Context.currentPos()
            });
            initializers.push(macro $i{valueName} = $i{property.getter}());

            var condition:Expr = macro false;
            for (dependency in property.dependencies) {
                var next = computedDependencyCondition(dependency);
                condition = macro ($e{condition} || $e{next});
            }
            checks.push(macro {
                if ($e{condition}) {
                    var nextValue = $i{property.getter}();
                    if (nextValue != $i{valueName}) {
                        var previousValue = $i{valueName};
                        $i{valueName} = nextValue;
                        notifyChanged(this, $v{property.name}, nextValue, previousValue);
                    }
                }
            });
        }

        fields.push({
            name: changeMethodName,
            access: [APrivate],
            kind: FFun({
                args: [
                    {name: "source", type: macro: Any},
                    {name: "field", type: macro: String}
                ],
                ret: macro: Void,
                expr: macro { $a{checks} }
            }),
            meta: noCompletionMeta(),
            pos: Context.currentPos()
        });

        var constructor = getField("new", fields);
        switch (constructor.kind) {
            case FFun(fn):
                switch (fn.expr.expr) {
                    case EBlock(expressions):
                        for (initializer in initializers) expressions.push(initializer);
                        expressions.push(macro {
                            var previousNotify = @:privateAccess this.notifyChanged;
                            @:privateAccess this.notifyChanged = function(source:Any, field:String, newValue:Any, oldValue:Any):Void {
                                $i{changeMethodName}(source, field);
                                previousNotify(source, field, newValue, oldValue);
                            };
                        });
                    case _:
                        Context.error("@:computed requires a block constructor", constructor.pos);
                }
            case _:
                Context.error("@:computed requires a constructor", constructor.pos);
        }
    }

    private static function computedDependencyCondition(dependency:ComputedDependency):Expr {
        return switch (dependency) {
            case Field(name):
                macro (source == this && field == $v{name});

            case NestedField(name, child):
                var path = name + "." + child;
                macro ((source == this && field == $v{name})
                    || (field != null && (field == $v{path} || StringTools.startsWith(field, $v{path + "."}))));

            case CollectionStructure(name):
                macro ((source == this && field == $v{name})
                    || ($i{name} != null && source == (cast $i{name})));

            case CollectionItem(name, child):
                macro ($i{name} != null && source != this && source != (cast $i{name})
                    && $i{name}.contains(cast source)
                    && field != null && (field == $v{child} || StringTools.startsWith(field, $v{child + "."})));

            case CollectionAny(name):
                macro ((source == this && field == $v{name})
                    || ($i{name} != null && (source == (cast $i{name})
                        || (source != this && $i{name}.contains(cast source)))));
        }
    }

    private static function buildConstructor(fields:Array<Field>, observableSubObjects:Array<{name:String, fieldName:String, forwarderName:String, expr:Expr, ?isDynamic:Bool, ?isCollection:Bool}>) {
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
                    meta: noCompletionMeta(),
                    pos: Context.currentPos()
                }
                fields.push(changesToNotify);
            }
        }

        var existingChangesToNotifyIndex = TypeTools.findField(Context.getLocalClass().get(), "changesToNotifyIndex");
        if (existingChangesToNotifyIndex == null) {
            var changesToNotifyIndex = getField("changesToNotifyIndex", fields);
            if (changesToNotifyIndex == null) {
                changesToNotifyIndex = {
                    name: "changesToNotifyIndex",
                    access: [APrivate],
                    kind: FVar(
                        macro: haxe.ds.ObjectMap<Dynamic, Map<String, observable.ChangeInfo<Any>>>,
                        macro new haxe.ds.ObjectMap()
                    ),
                    meta: noCompletionMeta(),
                    pos: Context.currentPos()
                }
                fields.push(changesToNotifyIndex);
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
                    meta: noCompletionMeta(),
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

    private static function buildObservableForwarders(fields:Array<Field>, observableSubObjects:Array<{name:String, fieldName:String, forwarderName:String, expr:Expr, ?isDynamic:Bool, ?isCollection:Bool}>) {
        for (observableSubObject in observableSubObjects) {
            if (getField(observableSubObject.forwarderName, fields) != null) {
                continue;
            }

            var fieldName = observableSubObject.fieldName;
            var isCollection = (observableSubObject.isCollection == true);
            fields.push({
                name: observableSubObject.forwarderName,
                access: [APrivate],
                kind: FFun({
                    args:[
                        {name: "source", type: macro: Any},
                        {name: "field", type: macro: String},
                        {name: "newValue", type: macro: Any},
                        {name: "oldValue", type: macro: Any}
                    ],
                    expr: macro {
                        notifyChanged(source, observable.ObservableUtils.forwardedFieldName($v{fieldName}, field, $v{isCollection}), newValue, oldValue);
                    },
                    ret: macro: Void
                }),
                meta: noCompletionMeta(),
                pos: Context.currentPos()
            });
        }
    }

    private static function buildChangeListeners(fields:Array<Field>, observableSubObjects:Array<{name:String, fieldName:String, forwarderName:String, expr:Expr, ?isDynamic:Bool, ?isCollection:Bool}>) {
        var existing_changeListeners = TypeTools.findField(Context.getLocalClass().get(), "_changeListeners");
        var propagateExprs:Array<Expr> = [];
        for (observableSubObject in observableSubObjects) {
            propagateExprs.push(macro {
                if ($i{observableSubObject.name} != null) {
                    observable.ObservableUtils.addForwarder(cast $i{observableSubObject.name}, $i{observableSubObject.forwarderName});
                }
            });
        }
        if (existing_changeListeners == null) {
            var _changeListeners = getField("_changeListeners", fields);
            if (_changeListeners == null) {
                _changeListeners = {
                    name: "_changeListeners",
                    access: [APrivate],
                    kind: FVar(macro: Array<{listener: observable.Changes->Void}>, macro []),
                    meta: noCompletionMeta(),
                    pos: Context.currentPos()
                }
                fields.push(_changeListeners);
            }

            var changeListeners = getField("changeListeners", fields);
            if (changeListeners == null) {
                changeListeners = {
                    name: "changeListeners",
                    access: [APrivate],
                    kind: FProp("get", "set", macro: Array<{listener: observable.Changes->Void}>),
                    meta: noCompletionMeta(),
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
                    meta: noCompletionMeta(),
                    pos: Context.currentPos()
                }
                fields.push(get_changeListeners);
            }

            var set_changeListeners = getField("set_changeListeners", fields);
            if (set_changeListeners == null) {
                set_changeListeners = {
                    name: "set_changeListeners",
                    access: [APrivate],
                    kind: FFun({
                        args:[{ name: "value", type: macro: Array<{listener: observable.Changes->Void}>}],
                        expr: macro {
                            _changeListeners = value;
                            {
                                $a{propagateExprs}
                            }
                            return value;
                        }
                    }),
                    meta: noCompletionMeta(),
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
                            if (_changeListeners == null) {
                                _changeListeners = [];
                            }
                            for (item in _changeListeners) {
                                if (observable.ObservableUtils.isFunctionEqual(item.listener, listener)) {
                                    return;
                                }
                            }
                            _changeListeners.push({ listener: listener });
                        }
                    }),
                    pos: Context.currentPos()
                }
                fields.push(registerChangeListener);
            }
        }
        if (existing_changeListeners != null && observableSubObjects.length > 0 && getField("set_changeListeners", fields) == null) {
            var set_changeListeners = {
                name: "set_changeListeners",
                access: [APrivate, AOverride],
                kind: FFun({
                    args:[{ name: "value", type: macro: Array<{listener: observable.Changes->Void}>}],
                    expr: macro {
                        super.changeListeners = value;
                        {
                            $a{propagateExprs}
                        }
                        return value;
                    }
                }),
                meta: noCompletionMeta(),
                pos: Context.currentPos()
            }
            fields.push(set_changeListeners);
        }

        var existingUnregisterChangeListener = TypeTools.findField(Context.getLocalClass().get(), "unregisterChangeListener");
        if (existingUnregisterChangeListener == null) {
            var unregisterChangeListener = getField("unregisterChangeListener", fields);
            if (unregisterChangeListener == null) {
                unregisterChangeListener = {
                    name: "unregisterChangeListener",
                    access: [APublic],
                    kind: FFun({
                        args:[{ name: "listener", type: macro: observable.Changes->Void}],
                        expr: macro {
                            if (_changeListeners == null) {
                                return;
                            }
                            var toRemove = null;
                            for (item in _changeListeners) {
                                if (observable.ObservableUtils.isFunctionEqual(item.listener, listener)) {
                                    toRemove = item;
                                    break;
                                }
                            }
                            if (toRemove != null) {
                                _changeListeners.remove(toRemove);
                            }
                        }
                    }),
                    pos: Context.currentPos()
                }
                fields.push(unregisterChangeListener);
            }
        }

        var registerChangeListener = getField("registerChangeListener", fields);
        if (registerChangeListener == null) {
            if (registerChangeListener == null) {
                registerChangeListener = {
                    name: "registerChangeListener",
                    access: [APublic, AOverride],
                    kind: FFun({
                        args:[{ name: "listener", type: macro: observable.Changes->Void}],
                        expr: macro {
                            super.registerChangeListener(listener);
                        }
                    }),
                    pos: Context.currentPos()
                }
                fields.push(registerChangeListener);
            }
        } else {

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
                    meta: noCompletionMeta(),
                    pos: Context.currentPos()
                }
                fields.push(notifyChanged);
            }

            switch (notifyChanged.kind) {
                case FFun(f):
                    f.expr = macro {
                        if (changeListeners == null || changeListeners.length == 0) {
                            return;
                        }

                        if (groupObservableChanges) {
                            var now = Date.now().getTime();

                            if (observable.ObservableDefaults.EliminateDuplicates) {
                                var byField = changesToNotifyIndex.get(source);
                                if (byField == null) {
                                    byField = new Map<String, observable.ChangeInfo<Any>>();
                                    changesToNotifyIndex.set(source, byField);
                                }

                                var fieldKey = (field == null) ? "\x00" : field;
                                var existing = byField.get(fieldKey);
                                if (existing == null) {
                                    existing = {
                                        timestamp: now,
                                        source: source,
                                        field: field,
                                        newValue: newValue,
                                        oldValue: oldValue
                                    };
                                    byField.set(fieldKey, existing);
                                    changesToNotify.push(existing);
                                } else {
                                    existing.timestamp = now;
                                    existing.newValue = newValue;
                                }
                            } else {
                                changesToNotify.push({
                                    timestamp: now,
                                    source: source,
                                    field: field,
                                    newValue: newValue,
                                    oldValue: oldValue
                                });
                            }

                            if (!waitingForTick) {
                                waitingForTick = true;
                                observable.ObservableDefaults.onTick(onTick);
                            }
                        } else {
                            var listenersCopy = changeListeners.copy();
                            for (listener in listenersCopy) {
                                var changes = new observable.Changes();
                                changes.items = [{
                                    timestamp: Date.now().getTime(),
                                    source: source,
                                    field: field,
                                    newValue: newValue,
                                    oldValue: oldValue
                                }];
                                listener.listener(changes);
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
                    meta: noCompletionMeta(),
                    pos: Context.currentPos()
                }
                fields.push(onTick);
            }

            switch (onTick.kind) {
                case FFun(f):
                    f.expr = macro {
                        var copy = changesToNotify;
                        changesToNotify = [];
                        changesToNotifyIndex = new haxe.ds.ObjectMap();
                        waitingForTick = false;

                        var changes = new observable.Changes();
                        changes.items = copy;
                        var listenersCopy = (changeListeners == null) ? [] : changeListeners.copy();
                        for (listener in listenersCopy) {
                            listener.listener(changes);
                        }
                    }
                case _:
            }
        }
    }

    private static function buildObservableProperties(fields:Array<Field>):Array<{name:String, fieldName:String, forwarderName:String, expr:Expr, ?isDynamic:Bool, ?isCollection:Bool}> {
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
        var observableSubObjects:Array<{name:String, fieldName:String, forwarderName:String, expr:Expr, ?isDynamic:Bool, ?isCollection:Bool}> = [];

        for (field in fields) {
            if (field.name == "groupObservableChanges" || field.name == "changesToNotify"|| field.name == "changesToNotifyIndex" || field.name == "waitingForTick" || field.name == "_changeListeners") {
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
                                var isDynamic = switch(tp0) {
                                    case TPath(p):
                                        p.name == "Dynamic";
                                    case _: false;
                                }
                                if (isDynamic) {
                                    tp0 = macro: observable.ObservableDynamic;
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
                    } else if (isDynamic(field)) {
                        newType = macro: observable.ObservableDynamic;
                    }

                    var newField = {
                        name: varName,
                        access: [APrivate],
                        kind: FVar(newType, e),
                        meta: noCompletionMeta(),
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
                        meta: noCompletionMeta(),
                        pos: Context.currentPos()
                    }
                    fieldsToAdd.push(newField);

                    if (isArray(field)) {
                        var forwarderName = "__observableForward_" + field.name;
                        observableSubObjects.push({name: varName, fieldName: field.name, forwarderName: forwarderName, expr: e, isCollection: true});
                        var newField = {
                            name: "set_" + field.name,
                            access: [APrivate],
                            kind: FFun({
                                args:[{name: "value", type: newType}],
                                expr: macro {
                                    var normalizedValue:Dynamic = value;
                                    if (normalizedValue is Array) {
                                        var array:Array<Dynamic> = cast normalizedValue;
                                        var observableArray:observable.ObservableArray<Dynamic> = array;
                                        normalizedValue = observableArray;
                                    }

                                    if ($i{varName} == normalizedValue) {
                                        return cast normalizedValue;
                                    }
                                    var oldValue = $i{varName};
                                    $i{varName} = cast normalizedValue;
                                    if (oldValue != null) {
                                        observable.ObservableUtils.removeForwarder(cast oldValue, $i{forwarderName});
                                    }
                                    if ($i{varName} != null) {
                                        observable.ObservableUtils.addForwarder(cast $i{varName}, $i{forwarderName});
                                        @:privateAccess $i{varName}._fieldName = $v{field.name};
                                    }
                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return cast normalizedValue;
                                },
                                ret: newType
                            }),
                            meta: noCompletionMeta(),
                            pos: Context.currentPos()
                        }
                        fieldsToAdd.push(newField);
                    } else if (isMap(field)) {
                        var forwarderName = "__observableForward_" + field.name;
                        observableSubObjects.push({name: varName, fieldName: field.name, forwarderName: forwarderName, expr: e, isCollection: true});
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
                                        observable.ObservableUtils.removeForwarder(cast oldValue, $i{forwarderName});
                                    }
                                    if ($i{varName} != null) {
                                        observable.ObservableUtils.addForwarder(cast $i{varName}, $i{forwarderName});
                                        @:privateAccess $i{varName}._fieldName = $v{field.name};
                                    }
                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return value;
                                },
                                ret: newType
                            }),
                            meta: noCompletionMeta(),
                            pos: Context.currentPos()
                        }
                        fieldsToAdd.push(newField);
                    } else if (isDynamic(field)) {
                        var forwarderName = "__observableForward_" + field.name;
                        observableSubObjects.push({name: varName, fieldName: field.name, forwarderName: forwarderName, expr: e, isDynamic: true});
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
                                        observable.ObservableUtils.removeForwarder(cast oldValue, $i{forwarderName});
                                    }
                                    if ($i{varName} != null) {
                                        observable.ObservableUtils.addForwarder(cast $i{varName}, $i{forwarderName});
                                    }

                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return value;
                                },
                                ret: t
                            }),
                            meta: noCompletionMeta(),
                            pos: Context.currentPos()
                        }
                        fieldsToAdd.push(newField);
                    } else if (isObservable(field)) {
                        var forwarderName = "__observableForward_" + field.name;
                        observableSubObjects.push({name: varName, fieldName: field.name, forwarderName: forwarderName, expr: e});
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
                                        observable.ObservableUtils.removeForwarder(cast oldValue, $i{forwarderName});
                                    }
                                    if ($i{varName} != null) {
                                        observable.ObservableUtils.addForwarder(cast $i{varName}, $i{forwarderName});
                                    }
                                    notifyChanged(this, $v{field.name}, $i{varName}, oldValue);
                                    return value;
                                },
                                ret: t
                            }),
                            meta: noCompletionMeta(),
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
                            meta: noCompletionMeta(),
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

    private static function isDynamic(field:Field):Bool {
        return switch (field.kind) {
            case FVar(t, e):
                switch (t) {
                    case TPath(p): p.name == "Dynamic" || p.name == "ObservableDynamic";
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
