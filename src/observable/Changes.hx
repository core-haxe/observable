package observable;

class Changes {
    public function new() {
    }

    private var _items:Array<ChangeInfo<Any>> = [];
    public var items(get, set):Array<ChangeInfo<Any>>;
    private function get_items():Array<ChangeInfo<Any>> {
        return _items;
    }
    private function set_items(value:Array<ChangeInfo<Any>>):Array<ChangeInfo<Any>> {
        _items = value;
        buildItemsMap();
        return value;
    }

    private var _itemsMap:Map<String, Array<ChangeInfo<Any>>> = [];
    private function buildItemsMap() {
        _itemsMap.clear();
        for (item in _items) {
            var list = _itemsMap.get(item.field);
            if (list == null) {
                list = [];
                _itemsMap.set(item.field, list);
            }
            list.push(item);
        }
    }


    public function contains(field:String) {
        return _itemsMap.exists(field);
    }
}