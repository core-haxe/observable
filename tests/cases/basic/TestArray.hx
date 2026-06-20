package cases.basic;

import utest.Test;
import utest.Assert;
import utest.Async;

import cases.AssertTools.assertChangesContains;
import cases.AssertTools.findChange;
import observable.IObservable;
import observable.ObservableArray;
import observable.ObservableDefaults;
import observable.ObservableDynamic;

class TestArray extends Test {
    function test_Normal_Array(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(2, changes.items.length);
            var change = findChange(changes, o1, "normalArray", 0);
            Assert.notNull(change);
            var change = findChange(changes, o1.normalArray, "normalArray", 1);
            Assert.notNull(change);
            async.done();
        });

        o1.normalArray = [];
        o1.normalArray.push(1);
    }

    function test_Normal_Array_Remove_Found(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(2, changes.items.length);
            var change = findChange(changes, o1, "normalArray", 0);
            Assert.notNull(change);
            var change = findChange(changes, o1.normalArray, "normalArray", 1);
            Assert.notNull(change);
            async.done();
        });

        o1.normalArray = [1, 2, 3];
        o1.normalArray.remove(2);
    }

    function test_Normal_Array_Remove_NotFound(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            var change = findChange(changes, o1, "normalArray", 0);
            Assert.notNull(change);
            async.done();
        });

        o1.normalArray = [1, 2, 3];
        o1.normalArray.remove(4);
    }

    function test_Observable_Dynamic_Array_Remove_Raw_Item(async:Async) {
        var rawItem = { label: "one" };
        var observableItem:ObservableDynamic = rawItem;
        var items:ObservableArray<Dynamic> = [observableItem];

        items.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            Assert.equals(cast items, changes.items[0].source);
            async.done();
        });

        Assert.equals(true, items.contains(rawItem));
        Assert.equals(true, items.remove(rawItem));
        Assert.equals(false, items.contains(rawItem));
    }

    function test_Normal_Array_Index_Access_Primitive(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(2, changes.items.length);
            var change = findChange(changes, o1, "normalArray", 0);
            Assert.notNull(change);
            var change = findChange(changes, o1.normalArray, "normalArray", 1);
            Assert.notNull(change);
            async.done();
        });

        o1.normalArray = [1, 2, 3];
        o1.normalArray[1] = 22;
    }

    function test_Normal_Array_Index_Access_Observable(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(2, changes.items.length);
            var change = findChange(changes, o1, "objectArrayA", 0);
            Assert.notNull(change);
            var change = findChange(changes, o1.objectArrayA[1], "nullableStringValue", 1);
            Assert.notNull(change);
            async.done();
        });

        o1.objectArrayA = [new ObservableObjectA(), new ObservableObjectA(), new ObservableObjectA()];
        o1.objectArrayA[1].nullableStringValue = "change";
    }

    function test_Normal_Array_Dynamic_Assignment_Wraps_Raw_Array(async:Async) {
        withUngrouped(() -> {
            var o1 = new ObservableObjectA();
            var raw = [1, 2];
            var parentChangeCount = 0;
            var collectionChangeCount = 0;

            o1.registerChangeListener((changes) -> {
                if (findChange(changes, o1, "normalArray") != null) {
                    parentChangeCount++;
                }
                if (o1.normalArray != null && findChange(changes, o1.normalArray, "normalArray") != null) {
                    collectionChangeCount++;
                }
            });

            Reflect.setProperty(o1, "normalArray", raw);

            Assert.equals(1, parentChangeCount);
            Assert.equals(0, collectionChangeCount);
            Assert.equals(2, o1.normalArray.length);

            raw.push(3);
            Assert.equals(2, o1.normalArray.length);

            o1.normalArray.push(4);
            Assert.equals(1, collectionChangeCount);
            Assert.equals(3, o1.normalArray.length);
            async.done();
        });
    }

    function test_Observable_Array_Shared_Item_Notifies_All_Parents(async:Async) {
        withUngrouped(() -> {
            var item = new ObservableObjectA();
            var firstItems:ObservableArray<ObservableObjectA> = [item];
            var secondItems:ObservableArray<ObservableObjectA> = [item];
            var firstCount = 0;
            var secondCount = 0;

            firstItems.registerChangeListener((changes) -> {
                firstCount++;
                Assert.notNull(findChange(changes, item, "nullableStringValue"));
            });
            secondItems.registerChangeListener((changes) -> {
                secondCount++;
                Assert.notNull(findChange(changes, item, "nullableStringValue"));
            });

            item.nullableStringValue = "changed";

            Assert.equals(1, firstCount);
            Assert.equals(1, secondCount);
            async.done();
        });
    }

    function test_Observable_Array_Remove_Detaches_Item_Listener(async:Async) {
        withUngrouped(() -> {
            var item = new ObservableObjectA();
            var items:ObservableArray<ObservableObjectA> = [item];
            var changeCount = 0;

            Assert.equals(0, listenerCount(item));
            items.registerChangeListener((changes) -> changeCount++);
            Assert.equals(0, listenerCount(item));

            item.nullableStringValue = "attached";
            Assert.equals(1, changeCount);

            Assert.isTrue(items.remove(item));
            Assert.equals(0, listenerCount(item));

            changeCount = 0;
            item.nullableStringValue = "detached";
            Assert.equals(0, changeCount);
            async.done();
        });
    }

    function test_Observable_Array_Set_Detaches_Old_Item_And_Attaches_New_Item(async:Async) {
        withUngrouped(() -> {
            var oldItem = new ObservableObjectA();
            var newItem = new ObservableObjectA();
            var items:ObservableArray<ObservableObjectA> = [oldItem];
            var changeCount = 0;

            items.registerChangeListener((changes) -> changeCount++);
            Assert.equals(0, listenerCount(oldItem));
            Assert.equals(0, listenerCount(newItem));

            items[0] = newItem;

            Assert.equals(0, listenerCount(oldItem));
            Assert.equals(0, listenerCount(newItem));

            changeCount = 0;
            oldItem.nullableStringValue = "detached";
            Assert.equals(0, changeCount);
            newItem.nullableStringValue = "attached";
            Assert.equals(1, changeCount);
            async.done();
        });
    }

    function test_Observable_Array_Duplicate_Item_Detaches_After_Last_Remove(async:Async) {
        withUngrouped(() -> {
            var item = new ObservableObjectA();
            var items:ObservableArray<ObservableObjectA> = [item, item];
            var changeCount = 0;

            items.registerChangeListener((changes) -> changeCount++);
            Assert.equals(0, listenerCount(item));

            Assert.isTrue(items.remove(item));
            Assert.equals(0, listenerCount(item));

            changeCount = 0;
            item.nullableStringValue = "still attached";
            Assert.equals(1, changeCount);

            Assert.isTrue(items.remove(item));
            Assert.equals(0, listenerCount(item));

            changeCount = 0;
            item.nullableStringValue = "detached";
            Assert.equals(0, changeCount);
            async.done();
        });
    }

    function test_Observable_Array_Splice_Detaches_Removed_Items(async:Async) {
        withUngrouped(() -> {
            var firstItem = new ObservableObjectA();
            var secondItem = new ObservableObjectA();
            var thirdItem = new ObservableObjectA();
            var items:ObservableArray<ObservableObjectA> = [firstItem, secondItem, thirdItem];
            var changeCount = 0;

            items.registerChangeListener((changes) -> changeCount++);
            Assert.equals(0, listenerCount(firstItem));
            Assert.equals(0, listenerCount(secondItem));
            Assert.equals(0, listenerCount(thirdItem));

            items.splice(0, 2);

            Assert.equals(0, listenerCount(firstItem));
            Assert.equals(0, listenerCount(secondItem));
            Assert.equals(0, listenerCount(thirdItem));

            changeCount = 0;
            firstItem.nullableStringValue = "detached";
            secondItem.nullableStringValue = "detached";
            Assert.equals(0, changeCount);
            thirdItem.nullableStringValue = "attached";
            Assert.equals(1, changeCount);
            async.done();
        });
    }

    function test_Observable_Array_Sort_Keeps_Item_Attachments(async:Async) {
        withUngrouped(() -> {
            var firstItem = new ObservableObjectA();
            var secondItem = new ObservableObjectA();
            firstItem.nullableStringValue = "b";
            secondItem.nullableStringValue = "a";
            var items:ObservableArray<ObservableObjectA> = [firstItem, secondItem];
            var changeCount = 0;

            items.registerChangeListener((changes) -> changeCount++);
            Assert.equals(0, listenerCount(firstItem));
            Assert.equals(0, listenerCount(secondItem));

            items.sort((a, b) -> Reflect.compare(a.nullableStringValue, b.nullableStringValue));

            Assert.equals(0, listenerCount(firstItem));
            Assert.equals(0, listenerCount(secondItem));

            changeCount = 0;
            firstItem.nullableStringValue = "changed";
            Assert.equals(1, changeCount);
            async.done();
        });
    }

    function test_Observable_Array_Replacing_Parent_Array_Detaches_Old_Children(async:Async) {
        withUngrouped(() -> {
            var oldItem = new ObservableObjectA();
            var newItem = new ObservableObjectA();
            var parent = new ObservableObjectA();
            var parentChangeCount = 0;
            parent.registerChangeListener((changes) -> parentChangeCount++);

            parent.objectArrayA = [oldItem];
            parentChangeCount = 0;
            oldItem.nullableStringValue = "attached";
            Assert.equals(1, parentChangeCount);
            Assert.equals(0, listenerCount(newItem));

            parent.objectArrayA = [newItem];
            parentChangeCount = 0;
            oldItem.nullableStringValue = "detached";
            Assert.equals(0, listenerCount(oldItem));
            Assert.equals(0, parentChangeCount);
            newItem.nullableStringValue = "attached";
            Assert.equals(1, parentChangeCount);
            async.done();
        });
    }

    private function withUngrouped(run:Void->Void):Void {
        var originalGroupChanges = ObservableDefaults.GroupChanges;
        ObservableDefaults.GroupChanges = false;
        try {
            run();
        } catch (e:Dynamic) {
            ObservableDefaults.GroupChanges = originalGroupChanges;
            throw e;
        }
        ObservableDefaults.GroupChanges = originalGroupChanges;
    }

    private function listenerCount(item:IObservable):Int {
        var listeners = @:privateAccess item.changeListeners;
        return listeners == null ? 0 : listeners.length;
    }
}
