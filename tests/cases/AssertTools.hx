package cases;

import observable.Changes;
import utest.Assert;
import observable.ChangeInfo;

class AssertTools {
    public static function assertChangesContains(changes:Changes, source:Any, field:String, newValue:Any, oldValue:Any) {
        var found = false;
        for (change in changes.items) {
            if (change.source == source && change.field == field && change.newValue == newValue && change.oldValue == oldValue) {
                found = true;
                break;
            }
        }
        if (!found) {
            Assert.fail('change not found (field: ${field}, newValue: ${newValue}, oldValue: ${oldValue})');
        } else {
            Assert.pass();
        }
    }

    public static function findChange(changes:Changes, source:Any, field:String, index:Int = 0) {
        var found = null;
        var foundIndex = 0;
        for (change in changes.items) {
            if (change.source == source && change.field == field) {
                if (index == foundIndex) {
                    found = change;
                    break;
                }
            }
            foundIndex++;
        }
        return found;
    }
}