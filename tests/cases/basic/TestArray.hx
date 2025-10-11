package cases.basic;

import utest.Test;
import utest.Assert;
import utest.Async;

import cases.AssertTools.assertChangesContains;
import cases.AssertTools.findChange;

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
}