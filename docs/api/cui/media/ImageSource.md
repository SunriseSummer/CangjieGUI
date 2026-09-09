# ImageSource

文件路径或编码字节的不可变来源。创建不加载、不分配 GPU 资源；相对路径依赖工作目录。内存构造复制输入一次，来源对象可重复使用；每次重新调用 memory 会创建不同的缓存身份。来源被视图持有，纹理缓存不额外保留编码字节。

```cangjie
public struct ImageSource
```

### init

创建文件来源，不执行 I/O；路径含 NUL 时抛出 `IllegalArgumentException`。

```cangjie
public init(path: String)
```

### memory

复制编码字节一次；跨重建复用同一来源可共享缓存。TGA 等无签名格式需要 `typeHint`，其他格式通常可省略。提示含 NUL 时抛出 `IllegalArgumentException`；空或损坏字节在加载时形成普通失败。

```cangjie
public static func memory(bytes: Array<UInt8>, typeHint!: String = ""): ImageSource
```

参见 [ImageView](ImageView.md) 和 [invalidateImage](functions.md#invalidateimage)。
