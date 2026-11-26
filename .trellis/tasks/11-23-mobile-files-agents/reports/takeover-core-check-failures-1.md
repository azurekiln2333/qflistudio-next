# Core-check f434128 run 45157266417



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_failure_test.dart :: 端口抛错时关掉进度框并说明原因 (3063)


Test failed. See exception logs above.
The test description was: 端口抛错时关掉进度框并说明原因


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "开始同步": []" (used in a call to "tap()") could not find any
matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_failure_test.dart:101:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  端口抛错时关掉进度框并说明原因
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_failure_test.dart :: 传输失败后旧文件仍然可用 (3064)


TimeoutException after 0:10:00.000000: Test timed out after 10 minutes.
dart:isolate  _RawReceivePort._handleMessage



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_test.dart :: evict removes the least recently used copy (3100)


Expected: <1>
  Actual: <2>

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 477:18  expect
test/sync/device_sync_test.dart 476:7               main.<fn>.<fn>



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_dialog_test.dart :: the sync dialog writes the files after confirmation (3107)


Test failed. See exception logs above.
The test description was: the sync dialog writes the files after confirmation


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "从电脑同步这个项目": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_dialog_test.dart:148:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_dialog_test.dart line 148
The test description was:
  the sync dialog writes the files after confirmation
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_dialog_test.dart :: cancelling the prompt transfers nothing (3108)


Test failed. See exception logs above.
The test description was: cancelling the prompt transfers nothing


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following assertion was thrown running a test:
The finder "Found 0 widgets with text "取消": []" (used in a call to "tap()") could not find any
matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:2090:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1942:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1075:7)
#3      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/sync/device_sync_dialog_test.dart:191:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  cancelling the prompt transfers nothing
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/share/share_intake_test.dart :: 超过单文件上限的文件被跳过 (3809)


Expected: false
  Actual: <true>

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 477:18  expect
test/share/share_intake_test.dart 112:5             main.<fn>



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/share/share_intake_test.dart :: 文件名里的路径分隔符被清掉 (3810)


Expected: 'a_b_c.txt'
  Actual: 'b_c.txt'
   Which: is different.
          Expected: a_b_c.txt
            Actual: b_c.txt
                    ^
           Differ at offset 0

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 477:18  expect
test/share/share_intake_test.dart 117:5             main.<fn>



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/studio_session_index_test.dart :: 坏条目跳过，好条目照常出现 (3856)


Expected: ['good']
  Actual: ['', 'good']
   Which: at location [0] is '' instead of 'good'

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 477:18  expect
test/harness/studio_session_index_test.dart 111:5   main.<fn>



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/hub_status_dots_test.dart :: 颜色不随主题变 (4105)


Expected: Color:<Color(alpha: 1.0000, red: 0.8824, green: 0.8863, blue: 0.9098, colorSpace: ColorSpace.sRGB)>
  Actual: Color:<Color(alpha: 1.0000, red: 0.0980, green: 0.1098, blue: 0.1255, colorSpace: ColorSpace.sRGB)>
unknown 的描边在深浅主题下相同

package:matcher                                     expect
package:flutter_test/src/widget_tester.dart 477:18  expect
test/harness/hub_status_dots_test.dart 71:7         main.<fn>



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart :: 首屏先画快照，主机报上新列表后替换 (4110)


Test failed. See exception logs above.
The test description was: 首屏先画快照，主机报上新列表后替换


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "上次的会话": []>
   Which: means none were found but one was expected
快照先顶上

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart:143:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart line 143
The test description was:
  首屏先画快照，主机报上新列表后替换
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart :: 内置会话从索引读出来，不需要主机 (4111)


Test failed. See exception logs above.
The test description was: 内置会话从索引读出来，不需要主机


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "内置改登录": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart:173:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart line 173
The test description was:
  内置会话从索引读出来，不需要主机
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart :: 圆点不只靠颜色：带状态的文字标签 (4116)


Test failed. See exception logs above.
The test description was: 圆点不只靠颜色：带状态的文字标签


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: at least one matching candidate
  Actual: _ElementPredicateWidgetFinder:<Found 0 widgets with element matching predicate: []>
   Which: means none were found but some were expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart:294:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart line 294
The test description was:
  圆点不只靠颜色：带状态的文字标签
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_test.dart :: 刷新后读到新增的内置会话 (4117)



## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart :: 没有运行时可报时，内置会话保持 idle (4163)


Test failed. See exception logs above.
The test description was: 没有运行时可报时，内置会话保持 idle


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: [
            HarnessSessionStatus:HarnessSessionStatus.idle,
            HarnessSessionStatus:HarnessSessionStatus.idle
          ]
  Actual: []
   Which: at location [0] is [] which shorter than expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart:115:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart line 115
The test description was:
  没有运行时可报时，内置会话保持 idle
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart :: 运行时在跑时显示真状态 (4164)


Test failed. See exception logs above.
The test description was: 运行时在跑时显示真状态


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: Set:[
            HarnessSessionStatus:HarnessSessionStatus.working,
            HarnessSessionStatus:HarnessSessionStatus.blocked,
            HarnessSessionStatus:HarnessSessionStatus.done,
            HarnessSessionStatus:HarnessSessionStatus.idle
          ]
  Actual: Set:[]
   Which: does not contain HarnessSessionStatus:<HarnessSessionStatus.working>

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart:131:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart line 131
The test description was:
  运行时在跑时显示真状态
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart :: 运行时状态变了，列表跟着改，不重读磁盘 (4165)


Test failed. See exception logs above.
The test description was: 运行时状态变了，列表跟着改，不重读磁盘


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: [HarnessSessionStatus:HarnessSessionStatus.working]
  Actual: []
   Which: at location [0] is [] which shorter than expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart:146:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart line 146
The test description was:
  运行时状态变了，列表跟着改，不重读磁盘
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart :: 排队中也算运行中 (4166)


Test failed. See exception logs above.
The test description was: 排队中也算运行中


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: [HarnessSessionStatus:HarnessSessionStatus.working]
  Actual: []
   Which: at location [0] is [] which shorter than expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart:174:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart line 174
The test description was:
  排队中也算运行中
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart :: 运行时没见过的会话仍是 idle (4167)


Test failed. See exception logs above.
The test description was: 运行时没见过的会话仍是 idle


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: [
            HarnessSessionStatus:HarnessSessionStatus.working,
            HarnessSessionStatus:HarnessSessionStatus.idle
          ]
  Actual: []
   Which: at location [0] is [] which shorter than expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart:188:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart line 188
The test description was:
  运行时没见过的会话仍是 idle
════════════════════════════════════════════════════════════════════════════════════════════════════


## /home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart :: 内置会话行仍然按状态排序 (4168)


Test failed. See exception logs above.
The test description was: 内置会话行仍然按状态排序


══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: [
            HarnessSessionStatus:HarnessSessionStatus.blocked,
            HarnessSessionStatus:HarnessSessionStatus.idle,
            HarnessSessionStatus:HarnessSessionStatus.done
          ]
  Actual: []
   Which: at location [0] is [] which shorter than expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart:203:5)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1682:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///home/runner/work/qflistudio-core/qflistudio-core/qfli_studio_core/test/harness/home_agents_tab_live_status_test.dart line 203
The test description was:
  内置会话行仍然按状态排序
════════════════════════════════════════════════════════════════════════════════════════════════════