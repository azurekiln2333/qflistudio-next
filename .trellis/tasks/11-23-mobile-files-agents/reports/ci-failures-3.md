# core-check failures, loop 3, run 45136693596, core 606810bd7d5a359851305f4573b4f1460137e0ea
- test/external_agent_files_test.dart :: read 与 write 走协调通道 :: 文件不是 UTF-8 文本，工具拒绝读取或覆盖
    package:qfli_studio_core/vibe_coding/vibe_tools.dart 531:7   VibeProjectFiles._decodeText
    package:qfli_studio_core/vibe_coding/vibe_tools.dart 517:18  VibeProjectFiles.read
- test/editor_harness_session_target_test.dart :: 内置 Agent 的会话不进 hub，直接选中会话 id :: Test failed. See exception logs above.
    The test description was: 内置 Agent 的会话不进 hub，直接选中会话 id
    The following assertion was thrown running a test:
    A Timer is still pending even after the widget tree was disposed.
    'package:flutter_test/src/binding.dart':
    Failed assertion: line 2243 pos 12: '!timersPending'
- test/harness_remote_device_test.dart :: harnessDeviceOf finds the device host :: Expected: '工作台'
    Actual: <null>
    Which: not an <Instance of 'String'>
    test/harness_remote_device_test.dart 293:5          main.<fn>
- test/harness_remote_device_test.dart :: an old agent that sends no device fields falls back to platform :: Expected: HarnessDeviceOs:<HarnessDeviceOs.windows>
    Actual: HarnessDeviceOs:<HarnessDeviceOs.unknown>
    platform 兜底
    test/harness_remote_device_test.dart 250:7          main.<fn>
- test/harness_remote_device_test.dart :: a missing os falls back to the platform value :: Expected: HarnessDeviceOs:<HarnessDeviceOs.macos>
    Actual: HarnessDeviceOs:<HarnessDeviceOs.unknown>
    test/harness_remote_device_test.dart 229:5          main.<fn>
- test/harness_remote_device_test.dart :: os other falls back to the platform value :: Expected: HarnessDeviceOs:<HarnessDeviceOs.windows>
    Actual: HarnessDeviceOs:<HarnessDeviceOs.unknown>
    win32
    test/harness_remote_device_test.dart 219:7          main.<fn>
- test/harness_remote_device_test.dart :: os maps the three reported short names :: Expected: HarnessDeviceOs:<HarnessDeviceOs.windows>
    Actual: HarnessDeviceOs:<HarnessDeviceOs.unknown>
    windows
    test/harness_remote_device_test.dart 204:7          main.<fn>
- test/harness_remote_device_test.dart :: a missing hostName falls back to host :: Expected: 'DESKTOP-7'
    Actual: <null>
    Which: not an <Instance of 'String'>
    test/harness_remote_device_test.dart 193:5          main.<fn>
- test/harness_remote_device_test.dart :: reported device fields reach the host unchanged :: Expected: '工作台'
    Actual: <null>
    Which: not an <Instance of 'String'>
    test/harness_remote_device_test.dart 182:5          main.<fn>
- test/external_explorer_menu_test.dart :: 外部根条目不提供删除 :: Test failed. See exception logs above.
    The test description was: 外部根条目不提供删除
    The following assertion was thrown running a test:
    The finder "Found 0 widgets with text "note.md": []" (used in a call to "longPress()") could not
    find any matching widgets.
    #3      main.<anonymous closure> (test/external_explorer_menu_test.dart:119:18)
