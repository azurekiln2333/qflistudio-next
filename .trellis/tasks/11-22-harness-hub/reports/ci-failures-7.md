# core-check failures, loop 7, run 45031879854, core efa49c15e0640ba9fd3c36dab15acadf8689955d
- test/editor_cloud_open_lifecycle_test.dart :: asynchronous open failure is consumed without an activity lease :: Test failed. See exception logs above.
    The test description was: asynchronous open failure is consumed without an activity lease
    The following assertion was thrown running a test:
    A Timer is still pending even after the widget tree was disposed.
    'package:flutter_test/src/binding.dart':
    Failed assertion: line 2243 pos 12: '!timersPending'
