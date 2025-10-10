package observable;

class Changes {
    public var items:Array<ChangeInfo<Any>> = [];

    public function new() {

    }

    public function contains(field:String) {
        for (change in this.items) {
            if (change.field == field) {
                return true;
            }
        }
        return false;
    }
}