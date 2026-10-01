package cases.basic;

import observable.Changes;
import observable.ObservableArray;
import observable.ObservableDefaults;
import utest.Assert;
import utest.Async;
import utest.Test;

class TestComputed extends Test {
    public static var totalCountReads:Int = 0;
    public static var completedCountReads:Int = 0;

    function test_Direct_Fields() {
        withUngrouped(() -> {
            var model = new ComputedModel();
            var changes:Array<{oldValue:Int, newValue:Int}> = [];
            model.registerChangeListener(batch -> collectIntChanges(batch, "sum", changes));

            Assert.equals(3, model.sum);
            Assert.equals(6, model.doubleSum);
            model.a = 2;
            Assert.equals(4, model.sum);
            Assert.equals(8, model.doubleSum);
            model.b = 1;
            Assert.equals(3, model.sum);
            Assert.equals(6, model.doubleSum);
            Assert.equals(2, changes.length);
            Assert.equals(3, changes[0].oldValue);
            Assert.equals(4, changes[0].newValue);
            Assert.equals(4, changes[1].oldValue);
            Assert.equals(3, changes[1].newValue);
        });
    }

    function test_Array_Length_Ignores_Item_Changes() {
        withUngrouped(() -> {
            totalCountReads = 0;
            var model = new ComputedModel();
            var notifications = 0;
            model.registerChangeListener(batch -> {
                if (batch.contains("totalCount")) notifications++;
            });
            Assert.equals(1, totalCountReads); // initial cached value

            var worker = new ComputedWorker();
            model.workers.push(worker);
            Assert.equals(1, notifications);
            Assert.equals(2, totalCountReads);
            Assert.equals(1, model.totalCount);

            worker.progressCurrent = 5;
            Assert.equals(1, notifications);
            Assert.equals(3, totalCountReads);

            model.workers.sort((a, b) -> 0);
            Assert.equals(1, notifications);
            Assert.equals(4, totalCountReads); // sort reports an array change
        });
    }

    function test_Collection_Item_Changes_And_Replacement() {
        withUngrouped(() -> {
            var model = new ComputedModel();
            var changes:Array<{oldValue:Int, newValue:Int}> = [];
            model.registerChangeListener(batch -> collectIntChanges(batch, "completedCount", changes));
            var worker = new ComputedWorker();
            model.workers.push(worker);
            worker.progressCurrent = 5;
            Assert.equals(0, changes.length);

            worker.progressCurrent = 10;
            Assert.equals(1, model.completedCount);
            Assert.equals(1, changes.length);
            Assert.equals(0, changes[0].oldValue);
            Assert.equals(1, changes[0].newValue);

            var replacement = new ComputedWorker();
            model.workers = [replacement];
            Assert.equals(0, model.completedCount);
            Assert.equals(2, changes.length);
            worker.progressCurrent = 0; // detached from the replacement array
            Assert.equals(2, changes.length);
            replacement.progressMax = 0;
            Assert.equals(1, model.completedCount);
            Assert.equals(3, changes.length);
        });
    }

    function test_Unrelated_Item_Field_Does_Not_Recompute() {
        withUngrouped(() -> {
            completedCountReads = 0;
            var model = new ComputedModel();
            Assert.equals(1, completedCountReads);
            var worker = new ComputedWorker();
            model.workers.push(worker);
            Assert.equals(2, completedCountReads);
            worker.name = "renamed";
            Assert.equals(2, completedCountReads);
            worker.progressCurrent = 5;
            Assert.equals(3, completedCountReads);
        });
    }

    function test_Nested_Property() {
        withUngrouped(() -> {
            var model = new ComputedModel();
            var changes:Array<String> = [];
            model.registerChangeListener(batch -> {
                for (change in batch.items) if (change.field == "personName") changes.push(cast change.newValue);
            });
            var person = new ComputedPerson();
            person.name = "Ada";
            model.person = person;
            person.age = 10;
            person.name = "Grace";
            Assert.equals(2, changes.length);
            Assert.equals("Ada", changes[0]);
            Assert.equals("Grace", changes[1]);
        });
    }

    function test_Explicit_Dependencies_For_Helper() {
        withUngrouped(() -> {
            var model = new ComputedModel();
            var notifications = 0;
            model.registerChangeListener(batch -> {
                if (batch.contains("helperSum")) notifications++;
            });
            Assert.equals(3, model.helperSum);
            model.a = 4;
            Assert.equals(6, model.helperSum);
            Assert.equals(1, notifications);
        });
    }

    function test_Computed_In_Subclass() {
        withUngrouped(() -> {
            var model = new ComputedChild();
            var notifications = 0;
            model.registerChangeListener(batch -> {
                if (batch.contains("doubled")) notifications++;
            });
            Assert.equals(6, model.doubled);
            Assert.equals(4, model.combined);
            model.localValue = 4;
            Assert.equals(8, model.doubled);
            Assert.equals(5, model.combined);
            Assert.equals(1, notifications);
            Assert.equals(2, model.baseDouble);
            model.baseValue = 3;
            Assert.equals(6, model.baseDouble);
            Assert.equals(7, model.combined);
        });
    }

    function test_Grouped_Change_In_Same_Batch(async:Async) {
        var model = new ComputedModel();
        model.registerChangeListener(batch -> {
            Assert.isTrue(batch.contains("a"));
            Assert.isTrue(batch.contains("sum"));
            Assert.isTrue(batch.contains("doubleSum"));
            async.done();
        });
        model.a = 5;
    }

    function test_Computed_Notification_Forwarded_Through_Array() {
        withUngrouped(() -> {
            var model = new ComputedModel();
            var models:ObservableArray<ComputedModel> = [model];
            var notifications = 0;
            models.registerChangeListener(batch -> {
                if (batch.contains("sum")) notifications++;
            });
            model.a = 5;
            Assert.equals(1, notifications);
        });
    }

    private function collectIntChanges(batch:Changes, name:String, out:Array<{oldValue:Int, newValue:Int}>):Void {
        for (change in batch.items) {
            if (change.field == name) out.push({oldValue: cast change.oldValue, newValue: cast change.newValue});
        }
    }

    private function withUngrouped(run:Void->Void):Void {
        var original = ObservableDefaults.GroupChanges;
        ObservableDefaults.GroupChanges = false;
        try {
            run();
        } catch (error:Dynamic) {
            ObservableDefaults.GroupChanges = original;
            throw error;
        }
        ObservableDefaults.GroupChanges = original;
    }
}
