# core-check failures, loop 5 (details), run 45023383633, core 79babb35e2ff5f9678abc7e13fefbf66250b3e91
- test/retained_editor_test.dart :: live editor survives Home, tools, content and restore :: Test failed. See exception logs above.
    The test description was: live editor survives Home, tools, content and restore
    The following StateError was thrown running a test:
    Bad state: No element
    #3      main.<anonymous closure> (test/retained_editor_test.dart:242:18)
- test/service_configuration_test.dart :: 旧云镜像保留为本地副本，官方缓存不复用旧服务器目录 :: 请先登录云端账号
    package:qfli_studio_core/services/cloud_sync_service.dart 111:15  CloudSyncService.open
    test/service_configuration_test.dart 46:44                        main.<fn>
- test/experience_test.dart :: 云端目录合并保留收藏，不重复追加已有项目 :: Bad state: No element
    test/experience_test.dart 89:44  main.<fn>
- test/editor_cloud_open_lifecycle_test.dart :: late cloud open after editor disposal releases activity lease :: Test failed. See exception logs above.
    The test description was: late cloud open after editor disposal releases activity lease
    The following assertion was thrown running a test:
    A Timer is still pending even after the widget tree was disposed.
    'package:flutter_test/src/binding.dart':
    Failed assertion: line 2243 pos 12: '!timersPending'
- test/harness_remote_host_test.dart :: Herdr panes on the paired computer replay snapshots and send keys :: Expected: contains 'sendKeys:w37:p14:up'
    Actual: ['refresh']
    Which: does not contain 'sendKeys:w37:p14:up'
    test/harness_remote_host_test.dart 756:7            main.<fn>
- test/project_card_cloud_actions_test.dart :: R3/R8 busy cloud operations cannot duplicate destructive actions :: Test failed. See exception logs above.
    The test description was: R3/R8 busy cloud operations cannot duplicate destructive actions
    The following assertion was thrown running a test:
    pumpAndSettle timed out
    #2      main.<anonymous closure> (test/project_card_cloud_actions_test.dart:151:7)
