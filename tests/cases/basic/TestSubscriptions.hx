package cases.basic;

import observable.Changes;
import observable.IObservable;
import observable.ObservableArray;
import observable.ObservableArray.ObservableArrayImpl;
import observable.ObservableDefaults;
import observable.ObservableMap;
import observable.ObservableUtils;
import utest.Assert;
import utest.Test;

// Characterize today's lifecycle and delivery order. Tests named "Currently"
// document existing limitations, not the desired subscription policy.
class TestSubscriptions extends Test {
    private function withSubscriptions(grouped:Bool, run:SubscriptionFixture->Void) {
        var previousTick = ObservableDefaults.onTick;
        var previousGrouping = ObservableDefaults.GroupChanges;
        var previousDuplicates = ObservableDefaults.EliminateDuplicates;
        var fixture = new SubscriptionFixture();
        ObservableDefaults.GroupChanges = grouped;
        ObservableDefaults.EliminateDuplicates = true;
        ObservableDefaults.onTick = fn -> fixture.pending.push(fn);
        try {
            run(fixture);
            fixture.flush();
        } catch (error:Dynamic) {
            fixture.dispose();
            ObservableDefaults.onTick = previousTick;
            ObservableDefaults.GroupChanges = previousGrouping;
            ObservableDefaults.EliminateDuplicates = previousDuplicates;
            throw error;
        }
        fixture.dispose();
        ObservableDefaults.onTick = previousTick;
        ObservableDefaults.GroupChanges = previousGrouping;
        ObservableDefaults.EliminateDuplicates = previousDuplicates;
    }

    function test_ArrayCurrentlyAttachesBeforeSubscriptionAndRetainsItemsAfterLastUnsubscribe() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            Assert.isTrue(f.tracks(items, item));
            var calls = 0;
            var listener = (_:Changes) -> calls++;
            f.listen(cast items, listener);
            item.value = 1;
            f.flush();
            Assert.equals(1, calls);

            items.unregisterChangeListener(listener);
            Assert.isTrue(f.tracks(items, item));
            item.value = 2;
            Assert.equals(0, f.pending.length);
            f.flush();
            Assert.equals(1, calls);
        });
    }

    function test_RemovingOneConsumerPreservesOtherListenersAndTheirRegistrationOrder() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            var trace:Array<String> = [];
            var first = (_:Changes) -> trace.push("first");
            var second = (_:Changes) -> trace.push("second");
            f.listen(cast items, first);
            f.listen(cast items, first);
            f.listen(cast items, second);
            item.value = 1;
            f.flush();
            Assert.equals("first,second", trace.join(","));

            trace = [];
            items.unregisterChangeListener(first);
            items.unregisterChangeListener(first);
            item.value = 2;
            f.flush();
            Assert.equals("second", trace.join(","));
            trace = [];
            items.registerChangeListener(first);
            item.value = 3;
            f.flush();
            Assert.equals("second,first", trace.join(","));
        });
    }

    function test_ResubscriptionObservesCurrentItemsAfterUnobservedReplacements() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var oldItem = f.item();
            var replacement = f.item();
            var items = f.array([oldItem]);
            var calls = 0;
            var listener = (changes:Changes) -> {
                calls++;
                Assert.equals(replacement, changes.items[0].source);
                Assert.equals("value", changes.items[0].field);
            };
            f.listen(cast items, listener);
            items.unregisterChangeListener(listener);
            items.set(0, replacement);
            replacement.value = 1;
            f.flush();
            Assert.equals(0, calls);
            Assert.isFalse(f.tracks(items, oldItem));
            Assert.isTrue(f.tracks(items, replacement));

            items.registerChangeListener(listener);
            oldItem.value = 2;
            f.flush();
            Assert.equals(0, calls);
            replacement.value = 2;
            f.flush();
            Assert.equals(1, calls);
        });
    }

    function test_ExplicitListenerClearCurrentlyDoesNotReattachExistingItemsOnRegistration() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var original = f.item();
            var inserted = f.item();
            var items = f.array([original]);
            var calls = 0;
            var listener = (_:Changes) -> calls++;
            f.listen(cast items, listener);
            // This is the cleanup operation currently used by ItemContainer.
            @:privateAccess cast(items, ObservableArrayImpl<Dynamic>).set_changeListeners(null);
            Assert.isFalse(f.tracks(items, original));

            items.registerChangeListener(listener);
            original.value = 1;
            f.flush();
            Assert.equals(0, calls);
            Assert.isFalse(f.tracks(items, original));
            items.push(inserted);
            f.flush();
            Assert.equals(1, calls);
            inserted.value = 1;
            original.value = 2;
            f.flush();
            Assert.equals(2, calls);
            Assert.isTrue(f.tracks(items, inserted));
            Assert.isFalse(f.tracks(items, original));
        });
    }

    function test_QueuedChangesAreDeliveredToListenersPresentAtFlushIncludingNewSubscribers() {
        withSubscriptions(true, f -> {
            var item = f.item();
            var items = f.array([item]);
            var firstCalls = 0;
            var secondCalls = 0;
            var first = (_:Changes) -> firstCalls++;
            var second = (changes:Changes) -> {
                secondCalls++;
                Assert.equals(1, changes.items.length);
                Assert.equals(item, changes.items[0].source);
                Assert.equals(0, changes.items[0].oldValue);
                Assert.equals(1, changes.items[0].newValue);
            };
            f.listen(cast items, first);
            item.value = 1;
            Assert.equals(1, f.pending.length);
            items.unregisterChangeListener(first);
            f.listen(cast items, second);
            Assert.equals(0, firstCalls);
            Assert.equals(0, secondCalls);
            f.flush();
            Assert.equals(0, firstCalls);
            Assert.equals(1, secondCalls);
            Assert.equals(0, f.pending.length);
        });
    }

    function test_QueuedChangesWithNoRemainingConsumerDrainWithoutDelivery() {
        withSubscriptions(true, f -> {
            var item = f.item();
            var items = f.array([item]);
            var calls = 0;
            var listener = (_:Changes) -> calls++;
            f.listen(cast items, listener);
            item.value = 1;
            items.unregisterChangeListener(listener);
            f.flush();
            Assert.equals(0, calls);
            Assert.equals(0, f.pending.length);
            items.registerChangeListener(listener);
            f.flush();
            Assert.equals(0, calls);
            item.value = 2;
            f.flush();
            Assert.equals(1, calls);
        });
    }

    function test_SharedArrayKeepsOtherParentsAndDirectConsumerAfterOneParentReplacesIt() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            var firstParent = f.arrayParent(items);
            var secondParent = f.arrayParent(items);
            var firstCalls = 0;
            var secondCalls = 0;
            var directCalls = 0;
            f.listen(firstParent, _ -> firstCalls++);
            f.listen(secondParent, _ -> secondCalls++);
            f.listen(cast items, _ -> directCalls++);
            item.value = 1;
            f.flush();
            Assert.equals(1, firstCalls);
            Assert.equals(1, secondCalls);
            Assert.equals(1, directCalls);

            firstParent.items = null;
            f.flush();
            firstCalls = secondCalls = directCalls = 0;
            item.value = 2;
            f.flush();
            Assert.equals(0, firstCalls);
            Assert.equals(1, secondCalls);
            Assert.equals(1, directCalls);
            secondParent.items = null;
            f.flush();
            firstCalls = secondCalls = directCalls = 0;
            item.value = 3;
            f.flush();
            Assert.equals(0, firstCalls);
            Assert.equals(0, secondCalls);
            Assert.equals(1, directCalls);
        });
    }

    function test_ParentForwardingSurvivesRemovalOfTheLastDirectArrayListener() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            var parent = f.arrayParent(items);
            var parentCalls = 0;
            var directCalls = 0;
            var direct = (_:Changes) -> directCalls++;
            f.listen(parent, _ -> parentCalls++);
            f.listen(cast items, direct);
            items.unregisterChangeListener(direct);
            item.value = 1;
            f.flush();
            Assert.equals(1, parentCalls);
            Assert.equals(0, directCalls);
            Assert.isTrue(f.tracks(items, item));
        });
    }

    function test_ComputedCollectionValuesStayCurrentWithoutAnyDirectSubscribers() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            var parent = new SubscriptionComputedParent();
            parent.items = items;
            f.cleanups.push(() -> parent.items = null);
            Assert.equals(0, parent.total);
            item.value = 4;
            Assert.equals(4, parent.total);
            var second = f.item();
            second.value = 3;
            items.push(second);
            Assert.equals(7, parent.total);
            Assert.equals(0, f.pending.length);

            parent.items = f.array([second]);
            Assert.equals(3, parent.total);
            item.value = 9;
            Assert.equals(3, parent.total);
            second.value = 5;
            Assert.equals(5, parent.total);
        });
    }

    function test_SharedDuplicateItemsStayAttachedUntilEachCollectionRemovesItsLastOccurrence() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var first = f.array([item, item]);
            var second = f.array([item]);
            var firstCalls = 0;
            var secondCalls = 0;
            var itemCalls = 0;
            f.listen(cast first, _ -> firstCalls++);
            f.listen(cast second, _ -> secondCalls++);
            f.listen(item, _ -> itemCalls++);
            first.remove(item);
            f.flush();
            firstCalls = secondCalls = itemCalls = 0;
            item.value = 1;
            f.flush();
            Assert.equals(1, firstCalls);
            Assert.equals(1, secondCalls);
            Assert.equals(1, itemCalls);
            first.remove(item);
            f.flush();
            firstCalls = secondCalls = itemCalls = 0;
            item.value = 2;
            f.flush();
            Assert.equals(0, firstCalls);
            Assert.equals(1, secondCalls);
            Assert.equals(1, itemCalls);
            second.remove(item);
            f.flush();
            firstCalls = secondCalls = itemCalls = 0;
            item.value = 3;
            f.flush();
            Assert.equals(0, firstCalls);
            Assert.equals(0, secondCalls);
            Assert.equals(1, itemCalls);
        });
    }

    function test_ArrayAndObjectForwardersCurrentlyDispatchInGroupsBasedOnFirstAttachment() {
        for (grouped in [false, true]) for (arrayFirst in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var trace:Array<String> = [];
            f.listen(item, _ -> trace.push("item"));
            for (i in 1...3) {
                var name = Std.string(i);
                var addArray = () -> {
                    var array = f.array([item]);
                    f.listen(cast array, _ -> trace.push("array" + name));
                };
                var addParent = () -> {
                    var parent = f.itemParent(item);
                    f.listen(parent, _ -> trace.push("parent" + name));
                };
                if (arrayFirst) { addArray(); addParent(); }
                else { addParent(); addArray(); }
            }
            // The two dispatcher layers group their listeners. They currently
            // do not interleave in the overall connection-registration order.
            var expected = arrayFirst ? "item,array1,array2,parent1,parent2" : "item,parent1,parent2,array1,array2";
            item.value = 1;
            Assert.equals(grouped ? "" : expected, trace.join(","));
            f.flushOne();
            Assert.equals(expected, trace.join(","));
            Assert.equals(0, f.pending.length);
        });
    }

    function test_ForwardingIsSynchronousAndGroupedConsumersDeliverInTheSameFlush() {
        withSubscriptions(true, f -> {
            var item = f.item();
            var items = f.array([item]);
            var parent = f.arrayParent(items);
            var trace:Array<String> = [];
            f.listen(item, _ -> trace.push("item"));
            f.listen(cast items, _ -> trace.push("array"));
            f.listen(parent, _ -> trace.push("parent"));
            f.forward(cast items, (source, field, next, previous) -> {
                Assert.equals(item, source);
                Assert.equals("value", field);
                Assert.equals(1, next);
                Assert.equals(0, previous);
                trace.push("forward");
            });

            item.value = 1;
            Assert.equals("forward", trace.join(","));
            Assert.equals(3, f.pending.length);
            f.flushOne();
            Assert.equals("forward,item,array,parent", trace.join(","));
            Assert.equals(0, f.pending.length);
        });
    }

    function test_RemovingAndReaddingAParentForwarderDoesNotDisconnectItsSharedArray() {
        for (grouped in [false, true]) for (arrayFirst in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items:ObservableArray<SubscriptionItem> = null;
            var parent:SubscriptionItemParent = null;
            if (arrayFirst) { items = f.array([item]); parent = f.itemParent(item); }
            else { parent = f.itemParent(item); items = f.array([item]); }
            var arrayCalls = 0;
            var parentCalls = 0;
            f.listen(cast items, _ -> arrayCalls++);
            f.listen(parent, _ -> parentCalls++);
            parent.child = null;
            f.flush();
            arrayCalls = parentCalls = 0;
            item.value = 1;
            f.flush();
            Assert.equals(1, arrayCalls);
            Assert.equals(0, parentCalls);
            parent.child = item;
            f.flush();
            arrayCalls = parentCalls = 0;
            item.value = 2;
            f.flush();
            Assert.equals(1, arrayCalls);
            Assert.equals(1, parentCalls);
        });
    }

    function test_MapCurrentlyReplacesAnItemsDirectAndArrayNotificationPaths() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            var map = f.map();
            var trace:Array<String> = [];
            f.listen(item, _ -> trace.push("item"));
            f.listen(cast items, _ -> trace.push("array"));
            f.listen(cast map, _ -> trace.push("map"));
            map.set("item", item);
            f.flush();
            trace = [];
            item.value = 1;
            f.flush();
            Assert.equals("map", trace.join(","));
            Assert.isTrue(f.tracks(items, item));
        });
    }

    function test_MapCurrentlyClearsAnItemsNotifyCallbackAfterItsLastKeyIsRemoved() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var map = f.map();
            var calls = 0;
            f.listen(cast map, _ -> calls++);
            map.set("first", item);
            map.set("second", item);
            map.remove("first");
            f.flush();
            calls = 0;
            item.value = 1;
            f.flush();
            Assert.equals(1, calls);
            map.remove("second");
            f.flush();
            Assert.isNull(@:privateAccess item.notifyChanged);
            var threw = false;
            try { item.value = 2; } catch (_:Dynamic) { threw = true; }
            Assert.isTrue(threw);
        });
    }

    function test_ArrayInsideAMapForwardsItemChangesToTheParentWithoutDirectCollectionListeners() {
        for (grouped in [false, true]) withSubscriptions(grouped, f -> {
            var item = f.item();
            var items = f.array([item]);
            var map = f.map();
            var parent = new SubscriptionMapParent();
            parent.values = map;
            f.cleanups.push(() -> parent.values = null);
            map.set("items", items);
            var calls = 0;
            f.listen(parent, changes -> {
                calls++;
                Assert.equals(item, changes.items[0].source);
                Assert.equals("value", changes.items[0].field);
            });
            item.value = 1;
            f.flush();
            Assert.equals(1, calls);
        });
    }
}

private class SubscriptionFixture {
    public var pending:Array<Void->Void> = [];
    public var cleanups:Array<Void->Void> = [];

    public function new() {}

    public function flushOne() {
        var callbacks = pending;
        pending = [];
        for (callback in callbacks) callback();
    }

    public function flush() {
        for (_ in 0...20) {
            if (pending.length == 0) return;
            flushOne();
        }
        Assert.fail("Subscription notifications did not settle");
    }

    public function dispose() {
        cleanups.reverse();
        for (cleanup in cleanups) cleanup();
        pending = [];
    }

    public function item():SubscriptionItem {
        var value = new SubscriptionItem();
        cleanups.push(() -> @:privateAccess value.set_changeListeners(null));
        return value;
    }

    public function array(values:Array<SubscriptionItem>):ObservableArray<SubscriptionItem> {
        var result:ObservableArray<SubscriptionItem> = values;
        cleanups.push(() -> @:privateAccess cast(result, ObservableArrayImpl<Dynamic>).set_changeListeners(null));
        return result;
    }

    public function tracks(array:ObservableArray<SubscriptionItem>, item:SubscriptionItem):Bool {
        // Notification counts alone cannot establish whether subscriptions were
        // released when there are no consumers. Keep this inspection in one place.
        var attached = @:privateAccess cast(array, ObservableArrayImpl<Dynamic>)._attachedItems;
        return attached != null && attached.exists(item);
    }

    public function listen(source:IObservable, listener:Changes->Void) {
        source.registerChangeListener(listener);
        cleanups.push(() -> source.unregisterChangeListener(listener));
    }

    public function forward(source:IObservable, listener:Any->String->Any->Any->Void) {
        ObservableUtils.addForwarder(source, listener);
        cleanups.push(() -> ObservableUtils.removeForwarder(source, listener));
    }

    public function arrayParent(items:ObservableArray<SubscriptionItem>):SubscriptionArrayParent {
        var parent = new SubscriptionArrayParent();
        parent.items = items;
        cleanups.push(() -> parent.items = null);
        return parent;
    }

    public function itemParent(item:SubscriptionItem):SubscriptionItemParent {
        var parent = new SubscriptionItemParent();
        parent.child = item;
        cleanups.push(() -> parent.child = null);
        return parent;
    }

    public function map():ObservableMap<String, Dynamic> {
        var map = new ObservableMap<String, Dynamic>();
        cleanups.push(() -> {
            var keys = [for (key in map.keys()) key];
            for (key in keys) map.remove(key);
            @:privateAccess map.set_changeListeners(null);
        });
        return map;
    }
}

private class SubscriptionItem implements IObservable {
    public var value:Int = 0;
    public function new() {}
}

private class SubscriptionArrayParent implements IObservable {
    public var items:Array<SubscriptionItem> = null;
    public function new() {}
}

private class SubscriptionItemParent implements IObservable {
    public var child:SubscriptionItem = null;
    public function new() {}
}

private class SubscriptionMapParent implements IObservable {
    public var values:Map<String, Dynamic> = null;
    public function new() {}
}

private class SubscriptionComputedParent implements IObservable {
    public var items:Array<SubscriptionItem> = null;
    @:computed public var total(get, never):Int;
    private function get_total():Int {
        var result = 0;
        if (items != null) for (item in items) result += item.value;
        return result;
    }
    public function new() {}
}
