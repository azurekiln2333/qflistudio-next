# core-check failures, loop 6, run 45025371682, core d045273632f6337a839fe0eb6aa1ea1b9c6d2133
- test/editor_cloud_open_lifecycle_test.dart :: late cloud open after editor disposal releases activity lease :: Test failed. See exception logs above.
    The test description was: late cloud open after editor disposal releases activity lease
    The following assertion was thrown running a test:
    A Timer is still pending even after the widget tree was disposed.
    'package:flutter_test/src/binding.dart':
    Failed assertion: line 2243 pos 12: '!timersPending'
