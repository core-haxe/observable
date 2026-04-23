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
        _itemsMap = null;
        _fieldList = null;
        _itemsMapBuilt = false;
        return value;
    }

    private var _itemsMap:Map<String, Array<ChangeInfo<Any>>> = [];
    private var _fieldList:Array<String> = [];
    private var _itemsMapBuilt:Bool = false;
    private function buildItemsMap() {
        if (_itemsMapBuilt) {
            return;
        }

        _itemsMap = [];
        _fieldList = [];
        
        for (item in _items) {
            var list = _itemsMap.get(item.field);
            if (list == null) {
                list = [];
                _itemsMap.set(item.field, list);
            }
            list.push(item);
            if (!_fieldList.contains(item.field)) {
                _fieldList.push(item.field);
            }
        }

        _itemsMapBuilt = true;
    }

    public var fieldList(get, never):Array<String>;
    private function get_fieldList():Array<String> {
        buildItemsMap();
        return _fieldList;
    }

    public function contains(field:String) {
        buildItemsMap();
        return _itemsMap.exists(field);
    }
}