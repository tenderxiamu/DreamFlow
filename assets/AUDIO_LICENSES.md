# DreamFlow 音景资产授权清单

所有音景均来自 Pixabay（https://pixabay.com/sound-effects/），适用
**Pixabay Content License**：可免费商用、无需署名、允许分发于应用内。
来源页面与直链均可在 pixabay.com 检索确认。

| 文件 | 内容 | 用途 | 来源直链 | 许可 |
|---|---|---|---|---|
| tide_low.mp3 | 低频潮汐 | C 屏主音景（设计稿「低频潮汐 × 远海雨声」） | https://cdn.pixabay.com/audio/2022/06/07/audio_b9bd4170e4.mp3 | Pixabay Content License |
| rain_far.mp3 | 远处雨声 | C 层次音景（叠层） | https://cdn.pixabay.com/audio/2022/05/13/audio_257112ce99.mp3 | Pixabay Content License |
| white_noise.mp3 | 白噪音 | C 屏可选音景 | https://cdn.pixabay.com/audio/2022/03/12/audio_b4f7e5a4ff.mp3 | Pixabay Content License |
| forest.mp3 | 森林夜境 | C 屏可选音景 | https://cdn.pixabay.com/audio/2022/03/10/audio_4dedf5bf94.mp3 | Pixabay Content License |

## 循环播放说明

- 播放采用 just_audio `LoopMode.one`（单曲循环）。
- 潮汐/雨声类环境音本身首尾衔接平缓，循环点感知弱；如后续发现明显接缝，
  再引入首尾交叉淡化处理（需要 ffmpeg 或原生 gapless 方案，M6 打包前复查）。

## 二期扩展原则

仅收录以下许可之一，并逐条登记于本表：CC0 / Pixabay Content License /
OFL（字体）/ 明确标注可商用的作者授权。禁止使用仅限个人使用的素材。
