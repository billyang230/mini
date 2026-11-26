# 武將外觀算繪工具

關羽／呂布／趙雲外觀珠的角色圖是用這裡的程式「自己建 3D 模型 → 預先算繪」出來的原創圖（不是擷取別的伺服器）。

1. `node render.js full 0,1,2 idle,walk,attack,hurt front,back 2`：用無頭 Chromium（WebGL）算繪每一格（hero 0=關羽 1=呂布 2=趙雲）
2. `node arc.js`：算出攻擊刀光軌跡
3. `python3 build.py full atlas`：縮圖、描邊、加刀光、打包成 `assets/hero/<key>.png` 與格子座標 JSON（座標要貼回 `hero-costume.js` 的 `KCOS_DATA`）

改造型：`shader.glsl`（模型與顏色）、`pose.js`（動作）。
