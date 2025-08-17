package cases.basic;

import utest.Test;
import utest.Assert;
import utest.Async;

import cases.AssertTools.assertChangesContains;

class TestSubObject extends Test {
    function test_Assignment(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.length);
            assertChangesContains(changes, o1, "subObjectA", o1.subObjectA, null);
            async.done();
        });

        o1.subObjectA = new ObservableObjectA();
    }

    function test_Assignment_And_Set(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(3, changes.length);
            assertChangesContains(changes, o1, "subObjectA", o1.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA, "nullableIntValue", 111, null);
            assertChangesContains(changes, o1.subObjectA, "intValueWithDefault", 222, 111);
            async.done();
        });

        o1.subObjectA = new ObservableObjectA();
        o1.subObjectA.nullableIntValue = 111;
        o1.subObjectA.intValueWithDefault = 222;
    }

    function test_Deeply_Nested_SubObjects(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(8, changes.length);
            assertChangesContains(changes, o1, "subObjectA", o1.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA, "subObjectA", o1.subObjectA.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA.subObjectA, "subObjectA", o1.subObjectA.subObjectA.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA.subObjectA.subObjectA, "subObjectA", o1.subObjectA.subObjectA.subObjectA.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA.subObjectA.subObjectA.subObjectA, "subObjectA", o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA, "subObjectA", o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA, null);
            assertChangesContains(changes, o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA, "subObjectB", o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectB, null);
            assertChangesContains(changes, o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectB, "intValue", 555, 444);
            async.done();
        });

        o1.subObjectA = new ObservableObjectA();
        o1.subObjectA.subObjectA = new ObservableObjectA();
        o1.subObjectA.subObjectA.subObjectA = new ObservableObjectA();
        o1.subObjectA.subObjectA.subObjectA.subObjectA = new ObservableObjectA();
        o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA = new ObservableObjectA();
        o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA = new ObservableObjectA();
        o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectB = new ObservableObjectB();
        o1.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectA.subObjectB.intValue = 555;
    }

    function test_SubObject_With_Default(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.length);
            assertChangesContains(changes, o1.subObjectAWithDefault, "intValue", 555, 444);
            async.done();
        });

        o1.subObjectAWithDefault.intValue = 555;
    }
}