/*
 * Port 私有的 qstr 定义。
 *
 * MicroPython 生成 qstr 表时会把三个文件拼起来预处理：
 *     py/qstrdefs.h  +  本文件  +  扫描源码收集到的 Q(...)
 * 本文件就是给 port 手工塞额外 qstr 的地方，比如「源码里扫不到、但运行时
 * 要按名字查」的字符串。
 *
 * 我们一个都不需要，所以它是空的。但不能删——tool/build_embed.py 会把它
 * 当作路径参数传下去，缺文件的话那一步直接失败。
 * （上游 ports/minimal/qstrdefsport.h 也是空壳，同样原因。）
 */
