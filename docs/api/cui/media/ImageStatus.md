# ImageStatus

```cangjie
public enum ImageStatus
```

| 状态 | 含义 |
|---|---|
| `Idle` | 尚未加载、缓存失效或纹理已释放。 |
| `Ready` | 主图已解析为可用纹理。 |
| `Failed` | 主图解码或上传失败，可读取 loadError；备用图不改变主图状态。 |
| `Closed` | 当前视图已 close。 |

状态查询不会触发 I/O；本版同步加载，没有动画或异步 Loading 状态。
