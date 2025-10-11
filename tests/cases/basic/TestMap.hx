package cases.basic;

import utest.Test;
import utest.Assert;
import utest.Async;

import cases.AssertTools.assertChangesContains;
import cases.AssertTools.findChange;

class TestMap extends Test {
    function test_Basic_Init(async:Async) {
        var o1 = new ObservableObjectC();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            var change = findChange(changes, o1, "basicMap");
            Assert.notNull(change);
            async.done();
        });

        o1.basicMap = ["bob" => "tim"];
    }

    /*
    function test_Empty_Init(async:Async) {
        var o1 = new ObservableObjectC();
        o1.registerChangeListener((changes) -> {
            Assert.equals(1, changes.items.length);
            var change = findChange(changes, o1, "basicMap");
            Assert.notNull(change);
            async.done();
        });

        o1.basicMap = [];
    }
    */    
}