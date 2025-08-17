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
            Assert.equals(2, changes.length);
            var change = findChange(changes, o1, "normalArray", 0);
            Assert.notNull(change);
            var change = findChange(changes, o1, "normalArray", 1);
            Assert.notNull(change);
            async.done();
        });

        o1.normalArray = [];
        o1.normalArray.push(1);
    }
}