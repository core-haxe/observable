package;

import utest.ui.Report;
import utest.Runner;
import cases.*;
import cases.basic.*;
import utest.ui.common.HeaderDisplayMode;

class TestAll {
    public static var databaseBackend:String = null;

    public static function main() {
        var runner = new Runner();

        addBasicCases(runner);

        Report.create(runner, SuccessResultsDisplayMode.AlwaysShowSuccessResults, HeaderDisplayMode.NeverShowHeader);
        runner.run();
    }

    private static function addBasicCases(runner:Runner) {
        runner.addCase(new cases.basic.TestBasic());
        runner.addCase(new cases.basic.TestSubObject());
        runner.addCase(new cases.basic.TestArray());
        runner.addCase(new cases.basic.TestMap());
    }
}