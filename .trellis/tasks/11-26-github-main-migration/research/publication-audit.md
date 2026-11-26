# 发布候选复审报告

审计时间：`2026-11-26T20:56:52.884624+00:00`。
模型：`gpt-6.1-sol`。

## 结论

当前候选通过邮箱字段与保全字节复审。
最终索引和可达历史尚未认证。
- 已核验 65 份 JSON 报告。
- 已核验 168 个脱敏字段。
- 字段值均为 `[redacted-email]`。
- 当前哈希全部匹配脱敏清单。
- JSON 只改了声明的邮箱字段。
- 未发现遗留的真实邮箱 JSON 字段。
- 许可署名和维护者署名保持不变。

## 旧报告修正原因

旧 68 条结论全部作废。
旧脚本按插入顺序读取批量对象。
解析循环却按排序后的路径分配内容。
脚本也未校验返回的对象 ID。
这导致 blob 内容与路径错配。
本轮逐路径读取当前文件。
每条记录绑定实际字节与 SHA-256。
JSON 字段只取自该文件的解析结果。
本轮未使用批量 `cat-file`。

回归路径：`.agents/skills/trellis-before-dev/SKILL.md`。
该文件是 Markdown，未发现邮箱。
旧 `workflow_runs` 字段归属已删除。
当前 SHA-256：`02a88bae9ee5c8d56e1cf278699dd713b6b081dd9fe919f66a9ada6040eb99e0`。

## 审计范围

- HEAD：`c5f4bc3afe9c81ba488fd3f544d43c3dac061512`。
- github/main：`c5f4bc3afe9c81ba488fd3f544d43c3dac061512`。
- 隔离候选：`5a86e410f3cd583a457b7a2b127769d4f84413b7`。
- 文件集来自 tracked 与非忽略 untracked。
- 命令为 `git ls-files -z --cached`。
- 另一命令为 `git ls-files -z --others --exclude-standard`。
- 路径集共 1787 项。
- 已读取 1698 份现存常规文件。
- 缺失的 tracked 路径共 87 项。
- 两份审计报告不参与自身扫描。
- 未递归扫描目录。
- 未读取忽略目录或私有备份。
- 文件字节通过第二次读取。
- 审计期间索引与引用保持一致。
- 清单摘要：`2a0bad4ba5effd3dbc4deffa78272f6399511791f19ef9f47242799fd0c6529c`。
完整路径、字节数和哈希见 JSON。

## 邮箱字段脱敏证据

清单路径：`.trellis/tasks/11-26-github-main-migration/research/report-redactions.json`。
清单 SHA-256：`27b4e1f45946b5477833d90de247be1c796b2e7e60a7f114e62ab88415c9b314`。
65 个路径均不在当前公开基线中。
56 份原件哈希与隔离提交完全一致。
另 9 份匹配隔离提交的 CRLF 字节。
这 9 份不属于内容错配。
旧新 JSON 仅声明字段不同。
未读取 `publication-hold` 内的原件。

| 实际文件 | 已核验的 JSONPath | 当前 SHA-256 |
|---|---|---|
| `.trellis/tasks/11-20-cloudterminal-import/reports/cloud/app-a4d1efd-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `89efe3aee2de893ab16de724c331b77fc9a964640045efaef68b7db702ec5acf` |
| `.trellis/tasks/11-20-cloudterminal-import/reports/cloud/core-72c0b09-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `1d6a897fec3b3943ad9f3dc5bc9f593a85a8698dbfb5d2d430d262342455033a` |
| `.trellis/tasks/11-20-cloudterminal-import/reports/cloud/tag2-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `cc116d2722c966b1e635a0915e8dcaa5c1c6dd67c56db899b16cfe6fcd44e52f` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-core-45243367753-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `27436a8714afa9b0da9ae4e690e8ce28a36b7f3b0c72b544f4e0ae58cf51b685` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-core-45250672504-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `b10b6f703f0c23ce62c013108fe506fd88c910b125ba7ea318e384b121b9bbc7` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-next-45224073234-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `f81293247e11544260b536ccf174d5747fbf0a1b96ebee6a145ca29626ba95e9` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-next-45224073234-attempt-2.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `12997499385484c4e016bc2569061e69ac9767dc89e92222a539a295f9c97dcd` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-next-45244494258-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `6085bf69322c74ea0169a671030d552009823a1cd4280bf1ab749d2e890b9e47` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-next-45261332689-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `5bbdf709e9172210da6e55e7eec663172d808531962cd026020f8d5155bc3d75` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-next-45263306245-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `5438a938c53f137a194947bfa56b0b4f8d8aa3a09a971b5cf0a0ab868e272b3b` |
| `.trellis/tasks/11-24-large-screen-workbench/reports/ci-qflistudio-next-45379444606-attempt-1.json` | `$.run.head_commit.author.email`<br>`$.run.head_commit.committer.email` | `189af0db47ba3b747d43f627a87edea9ba1d8a217e12f2dac7957ed79c04e90a` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/app-gate-status.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `8cbebd5a9495bd2ed09769e42e41a41144b21d03f7c397abdeead67e433f91bb` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/app-latest.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `e85669050abfd1f3e08c400d8d23a69a9e6aea155dfa556fb88654cfb4fd245c` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/app-new-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `df8fa1b787d35dd14333f75c91f4c241ce12db69f3597dfea741730be02f6c31` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/app-source-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `0537b10d5cb8be509fa37b0fe6b440929dbb97a405b80ff2fb67e5ee64fcadb1` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/core-final-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `63f98133880c689fd2cbb1c4696c732ee5fc5a835d9d42cd461268083f6656c7` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/core-new-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email`<br>`$.workflow_runs[2].head_commit.author.email`<br>`$.workflow_runs[2].head_commit.committer.email` | `2ae3512f42c709bb0121f0d30b133e0ac32d490928c7d4e694fd13cb7dd7d612` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/core-phase-current.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `f9d6d75f0ed0696d161e7933f9c05391e7ed23577a56e0d2d4ae48b02e18ce29` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/core-source-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `6309f4842afdec308447cc9044dad9a3b07d986cdb6e7ce7dcf03d35c8072c15` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/git2-app-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `7354276466cec5c8d2df7e746da8800be2ef2bdfd7ba8c4d7ab5b2c18ea6a84e` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/git2-core-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `bc2ef5c16fb408e02b7d1bbcbdc6cad147794b17f0ae1c8623793b7a0da4b0b7` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/git2-plugin-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `d63e82c46fded5167ff49aed35d8f8561b917851be3a13d1f188f842df3c8192` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-artifact-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email`<br>`$.workflow_runs[2].head_commit.author.email`<br>`$.workflow_runs[2].head_commit.committer.email` | `8a72bf5f4136ccf962adfeeb1f607a542fe966bffcc5ebf63c2309ff3ecab416` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-gate-status.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `608f68b2796245b27e67e3f312ad7c85616097b71d3f5bf7b31ec02feee2330d` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-new-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email`<br>`$.workflow_runs[2].head_commit.author.email`<br>`$.workflow_runs[2].head_commit.committer.email` | `8b7101c990d08407a628c0441e80f0eb5fe2a1fd77753302c80d84eb5482c2f1` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-old-run-final.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `6b01c0f006bd79840acceced084f634e31379676c56bcaf069bdd81cbbf11bc0` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-old-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `942069165669615144d3f39b4bcbe26f8ccae6d9be59b037e2852c038ee4cfa7` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-source-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `6152a56758c6dada3f12790aba48795f834039731cd5a2ac8525b457831e115f` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/plugin-source-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `5b72137a524d22a2ebe8aed1074f476db74e25c4c57e439169dfcd9dafeae93a` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/tag-candidate-start.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email`<br>`$.workflow_runs[2].head_commit.author.email`<br>`$.workflow_runs[2].head_commit.committer.email`<br>`$.workflow_runs[3].head_commit.author.email`<br>`$.workflow_runs[3].head_commit.committer.email`<br>`$.workflow_runs[4].head_commit.author.email`<br>`$.workflow_runs[4].head_commit.committer.email` | `3c79a2ab1f62e1d1cd2c847a864b7307653d9cce7a0cf79d50b8994d81e52edd` |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/tag2-final-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `957929521b5f9c6196f5366bce5190761a760422c1b12fc05864823bfef20c37` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-506-run-final.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `1514399808a109995a1ecef348c65396a72b3855a01079788464d04ebf378bac` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-506-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `19f119c84656867c2b20df7c55b3b4cd6fbb1c0054beaf5b5a941e31bb9e056b` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-tag-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `a4086afd40943e36059cc6a9ca28dd5c5b08b5677ca363fc08d69d5cf10dd9f6` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-tag-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `e78af44b8f4a6448cb757c14e93d0f1231f5ccda940f14d6dedc2d2b9b3a2d60` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-watch-44870753378-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `2bfa610bcdc222781f5edcc625f7c1324898d461bbb9051ddbd7465236b1ea9b` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-watch-core-c619f9ff-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `22f1a52324274e6732fcff196091dd318fc69c4ebda3f01908af56440889a563` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app-watch-plugin-697291a-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `099dd95555176a77a90d07c808f7004c83fedf069ed5839000d77b2cc2633472` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-run-after-digest.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `a5fa7fa13a2f654b7493983c75ea9a4762eb8ac4c6cb8bcfde86add946380690` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-run-finalcheck.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `fd1c4dd1bde0179fbf9566c12ab7842418d364d1b2b6ab3e4fec2faf45bd2841` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-run-latest.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `fd1c4dd1bde0179fbf9566c12ab7842418d364d1b2b6ab3e4fec2faf45bd2841` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-run-publishcheck.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `1514399808a109995a1ecef348c65396a72b3855a01079788464d04ebf378bac` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-run-watch2.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `fd1c4dd1bde0179fbf9566c12ab7842418d364d1b2b6ab3e4fec2faf45bd2841` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `fd1c4dd1bde0179fbf9566c12ab7842418d364d1b2b6ab3e4fec2faf45bd2841` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-tag-object-after-digest.json` | `$.tagger.email` | `a8606e5a1d9b47c53052963683901614429202f66988c3d4e762b82c1a97edc8` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/app506-J-tag-object.json` | `$.tagger.email` | `a8606e5a1d9b47c53052963683901614429202f66988c3d4e762b82c1a97edc8` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/core-final-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `3cd5568d71243881b086b95695765bdebeafcd014ff521697e5ba7cd38f4ed1c` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/core-release-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `0ba9ae02b926f07094b42a59e061fb7e1273596ad9482a79954eb4eb9cb4ebc4` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/native-source-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `00f7ee8026e78dcd97b2a349fecded41ea3df033453839c3bf89ae2af4703efa` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/plugin-final-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `313abc7ca5123b6e78aadf96f494b8077d65c525178ddf1a840c482662f954cf` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/plugin-host-fix-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `7da2829c46288d88993b0a9eb23abe8ff759aa0ba5bf8aeaa39ec17a444560ab` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/plugin-release-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `894fcb36c65e648aa94818062ac09d3040b8045a715dd2aebf19715668800080` |
| `.trellis/tasks/archive/2026-11/11-21-git-clone-parallel-progress/reports/plugin-release-runs.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `ad72412df29560b759dfb48b4e1fd06fd1188bc581d07f81993b81681aa00baf` |
| `.trellis/tasks/archive/2026-11/11-21-ios-files-project-storage/reports/app-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `f6f388c9673e554dd0d3c50588969bf25a666453eb234a25acc82ea6863e0165` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/app-monitor-git5-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `decbbf930c3bf4216a62923ca13659c36935d501ce82ef5a627dce93f0428dc6` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/app-monitor-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `7b47c7ffcf6eefd53f25ee8ed96f8a3e2b1065ad416baf42e2670b8e2aca47de` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/app-runs-git3.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `4bfe9e3975db57a14d564c01026f5ee970b74cf50adb1638b87700eda67caa95` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/app-runs-git4.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `ab7a57fd28be5553d509b2eaf71ad88af9795c961055419874433096cd725019` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/app-runs-git5.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email`<br>`$.workflow_runs[1].head_commit.author.email`<br>`$.workflow_runs[1].head_commit.committer.email` | `cafe37c307100aa901db0f1976048064aa81d8fda1c1fc035b6a5af6045c55c2` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/core-branch-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `488298096ebb2a613a076a876cb6c99372ae17e9523b137448078849dda449e4` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/core-monitor-git5-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `d43009c7f722ee27cfda6849fcaed398155bcdef4d26978f1094b73771fcf631` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/core-monitor-run.json` | `$.head_commit.author.email`<br>`$.head_commit.committer.email` | `cde69bb6dfb915516e6a9380205a726e53aa98c914abb7062c89dec523fad512` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/core-runs-branch.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `2131312b1c6cd9ef4a5c2ff856cbedcaf27e312403263ba937d4619e2a62dafb` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/core-runs-git5.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `679d703ef388ac6ae531d207550357263883747ee81a9068ad59bb820dd4aacb` |
| `.trellis/tasks/archive/2026-11/11-21-project-card-git-branch/reports/core-runs-keyboard.json` | `$.workflow_runs[0].head_commit.author.email`<br>`$.workflow_runs[0].head_commit.committer.email` | `8f9d4abd2f49a646cbf0d6886902592311868d472fc18271002b16d444b51034` |

## 可保留的匹配

下列匹配不是待脱敏的个人邮箱。
许可署名允许保留。
维护者署名允许保留。
测试样例不当作真实凭据。

| 实际路径 | 判定 |
|---|---|
| `.trellis/spec/backend/terminal-isolation.md` | systemd 实例单元名，不是邮箱。 |
| `.trellis/tasks/11-20-cloudterminal-import/research/source-baseline.json` | 图标倍率文件名或路径键，不是邮箱。 |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-remote-account/patches/remote-account-review.patch` | Git 测试样例，保留原补丁。 |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-remote-account/patches/remote-account-working-tree-exact.patch` | 维护者署名与 Git 测试样例，保留原补丁。 |
| `.trellis/tasks/archive/2026-11/11-15-terminal-bootstrap/design.md` | systemd 实例单元名，不是邮箱。 |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/native-d002bd3/android/licenses/LIBGIT2-LICENSE` | 公开许可与版权署名，原样保留。 |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/native-d002bd3/ios/licenses/LIBGIT2-LICENSE` | 公开许可与版权署名，原样保留。 |
| `.trellis/tasks/archive/2026-11/11-20-studio-git-integration/reports/native-d002bd3/ohos/licenses/LIBGIT2-LICENSE` | 公开许可与版权署名，原样保留。 |
| `assets/content/examples.json` | 教学代码、样例数据和预期输出。 |
| `assets/content/tutorials.json` | 教学代码、样例数据和预期输出。 |
| `companion/remote_agent/test/git-info.test.ts` | SSH 地址解析测试，不是私密凭据。 |
| `companion/remote_agent/test/setup.test.ts` | 无效地址测试样例，不是有效凭据。 |
| `docs/compliance/acceptance/server.md` | 验收请求样例，不是个人联系信息。 |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` | 图标倍率文件名或路径键，不是邮箱。 |
| `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` | 图标倍率文件名或路径键，不是邮箱。 |
| `scripts/compliance/smoke.test.mjs` | 无效地址测试样例，不是有效凭据。 |
| `tool/ci/package_linux.sh` | 公开包维护者署名，保持不变。 |

## 终端任务保全

- 当前目录含 107 份文件。
- 107 份文件均已逐路径读取。
- 其中 104 份有内容保全记录。
- 104 份均匹配发布哈希。
- 40 份源码均匹配原始哈希。
- 源码包括 36 份 Dart 文件。
- 另含 3 份补丁和 1 份 YAML。
- 其余 3 份为说明和审查清单。
- 不再按报告文件名整类隔离。
- 已恢复的摘要不等于原始抓取。
- 时间戳、计数和项目路径不是凭据。
保全通过不代表运行集成获准。

## 远程账户保全

- 已读取恢复目录的 14 份文件。
- 9 份源码载荷匹配原始哈希。
- 2 份补丁匹配原始哈希。
- 1 份历史检查器匹配原始哈希。
- 维护者署名和许可内容未改。
独立发布与运行验证阻塞仍然存在。
本轮不授权启用历史检查器。

## 最后新增的辅助脚本

- 新增 8 份文件均已按实际字节读取。
- 其中 6 份为历史源码辅助脚本。
- 6 份源码共 85,830 字节。
- 6 份源码哈希均匹配保全清单。
- 未发现邮箱或凭据形状命中。
- 另两份为 README 和 manifest。
- 历史项目路径不是凭据。
- 文件属于保全源码，不是生成产物。
- 本轮未执行这些脚本。
- 未来执行需复核路径与批准的工作流。
- 该目录的 `text` 属性已禁用。

| 辅助脚本 | 字节数 | SHA-256 |
|---|---:|---|
| `.trellis/tasks/11-26-github-main-migration/research/preserved-staging-tools/b/build_cumulative.py` | 28501 | `30db24064d443c0a2ef645f530ab179cee37ea29a89f76b97891df177156866e` |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-staging-tools/b/validate_cumulative.py` | 5343 | `e8a9583970a83d131acc86aad8f0afa78130492bfb4d5da8deb98525208e63c6` |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-staging-tools/b/verify_bundle.py` | 3202 | `52fc7d4ffbcdeb31c57c49d9b9cd1ea511698674d55a7bbc6625856f64c64312` |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-staging-tools/c/build_cumulative.py` | 24993 | `f28237e03738c3b0a3ba18d6b6470871ae7dec5d6e7aa99b98f7c05fee761be6` |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-staging-tools/c/verify_bundle.py` | 6346 | `ef9ce67fdc667022fe6dccb6f08ab5ab19cde3ade9d607811715f8f8374fa2be` |
| `.trellis/tasks/11-26-github-main-migration/research/preserved-staging-tools/d/build_cumulative.py` | 17445 | `f90f5a9eb40dcdeab6428ea63c382c77d98f62c6c9e8560568834d4536eca3c3` |

终端保全清单修正了一个标签。
`project-switch-baseline-20261023T150053Z/manifest.json`
现标为 `json-reserialization-with-equivalent-values`。
该 JSON 不再宣称原始字节完全一致。
当前发布哈希匹配保全记录。
104 份内容与前次审计的字节一致。
40 份源码仍匹配原始字节。
本轮未打开忽略目录中的私有原件。

## 历史风险与当前候选分开

- 先前列出的 4 份原件不在当前候选。
- 10 份 UI JSON 在工作树中缺失。
- 这 10 个路径已存在于公开基线。
- 它们不是本次迁移新增。
- 删除当前文件不会清除历史 blob。
- 隔离候选仍含脱敏前原件。
- 不得推送 `migration-pre-publication`。
- 不得用 `--all` 或镜像推送公开它。
- 不得通过标签间接公开它。
历史路径状态仅表示路径存在性。
本轮没有重做完整可达历史审计。

## 检查边界

- 仅发现一个令牌形状的测试样例。
- 位置为 `scripts/check-root-ci.test.mjs:176`。
- 该样例用于 CI 拒绝测试。
- 未将其认定为有效令牌。
- 三个保全目录的 `text` 属性已禁用。
- analyzer 配置已排除 `.trellis/**`。
- 本轮未运行 analyzer。
- 本轮未构建、测试、安装或启动 WSL。
- 本轮未执行 Git 写操作。
- 本轮只重写两份审计报告。
- 未扫描忽略目录。
- 未展示或保存邮箱值。
- 未把公共 ID 当作凭据。
- 未把项目路径当作凭据。
- 未按数字长度推定个人信息。
- 未笼统排除源码、reports 或 workspace。

模式扫描不能保证发现所有秘密。
二进制文件未接受视觉与嵌入元数据复审。
最终索引、提交历史与云端证据需另验。
