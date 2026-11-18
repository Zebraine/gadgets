# lz77

一个用 Zig 实现的最小 LZ77 编解码示例。程序从标准输入读取一行文本，依次输出：

1. 哈希链匹配后的 token 序列；
2. 按位打包后的字节（十六进制，每行一个）；
3. 解码得到的 token 序列；
4. 还原出的原始文本。

## 模块

| 文件 | 职责 |
| --- | --- |
| `src/bit_stream.zig` | `BitReader` / `BitWriter`，以 MSB-first 顺序读写任意长度的位 |
| `src/token_stream.zig` | `Token` / `Match` 类型与 `TokenStream`（分词、还原、位流编解码） |
| `src/hashchain.zig` | `HashChain`（哈希链最长匹配，生成匹配 token） |
| `src/root.zig` | 库入口，导出模块与匹配长度常量 |
| `src/main.zig` | 命令行演示入口 |

## 编码格式

每个 token 以 1 bit 类型标记开头：

- 字面量：`0` + 8 bit 字节；
- 匹配：`1` + 16 bit distance + 8 bit `length - 3`。

位流按字节从高位到低位填充。

## 构建与运行

需要 Zig 0.17.1。

```sh
zig build
printf 'abracadabra abracadabra\n' | zig build run
zig build test
```

也可以直接运行构建产物：

```sh
./zig-out/bin/lz77 < input.txt
```

输入以第一个换行符为界（需要结尾换行），换行符本身不参与编码。
