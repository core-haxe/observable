package cases.basic;

import utest.Test;
import utest.Assert;
import utest.Async;

import cases.AssertTools.assertChangesContains;

class TestBasic extends Test {
    function test_Nullable_Int(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "nullableIntValue", 111, null);
            async.done();
        });

        o1.nullableIntValue = 111;
    }

    function test_Nullable_Float(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "nullableFloatValue", 222.22, null);
            async.done();
        });

        o1.nullableFloatValue = 222.22;
    }

    function test_Nullable_Bool(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "nullableBoolValue", true, null);
            async.done();
        });

        o1.nullableBoolValue = true;
    }

    function test_Nullable_String(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "nullableStringValue", "bob", null);
            async.done();
        });

        o1.nullableStringValue = "bob";
    }

    function test_Int_With_Default(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "intValueWithDefault", 222, 111);
            async.done();
        });

        o1.intValueWithDefault = 222;
    }

    function test_Float_With_Default(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "floatValueWithDefault", 333.33, 222.22);
            async.done();
        });

        o1.floatValueWithDefault = 333.33;
    }

    function test_Bool_With_Default(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "boolValueWithDefault", false, true);
            async.done();
        });

        o1.boolValueWithDefault = false;
    }

    function test_String_With_Default(async:Async) {
        var o1 = new ObservableObjectA();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            assertChangesContains(changes, o1, "stringValueWithDefault", "bob", "tim");
            async.done();
        });

        o1.stringValueWithDefault = "bob";
    }
}