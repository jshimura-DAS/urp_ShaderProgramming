# Chapter5：テクスチャ発展（Metallic・AO・Emission・Alpha Clip）

この章は `URPシェーダープログラミングindex.md` の **Chapter 05**（テクスチャ発展）に対応します。  
Chapter4 の `PhongNormal04.shader` を出発点として、URP/Lit が使うマテリアル入力を **一つずつ** 追加します。

> この章ではテクスチャからマテリアル入力を作り、Phong ライティングへ反映します。Cook-Torrance による物理ベースの反射計算は Chapter6 で扱います。

---

## 1. この章でやること

1. Chapter4 のアルベド・ノーマル・Main Light・Additional Lights 対応を基準にする
2. Metallic／Smoothness を追加する
3. AO を追加する
4. Emission を追加する
5. Alpha Clip を追加する
6. 高さ・ディテール・Clear Coat を統合した `SurfaceInputs05.shader` を確認する

各段階のシェーダーは、直前のシェーダーへ **一つの機能だけ** を加えたものです。マテリアルを切り替えて差分を確認してください。

---

## 2. Chapter4 から引き継ぐ基準

`Assets/ShaderProgramming/Chapter4/PhongNormal04.shader` は、次をすでに実装しています。

- Base Map と Base Color によるアルベド
- Normal Map と TBN によるタンジェント空間法線
- Ambient、Main Light、Additional Lights の Phong ライティング

Chapter5 の各段階シェーダーは、この構造を維持します。新しい機能を使わない場合、直前の段階と同じ見た目になる中立値を設定します。

| 項目 | 中立値 | 結果 |
| :--- | :--- | :--- |
| Metallic | `0` | 拡散反射を減らさない |
| Smoothness | `0.5` | 中程度の Phong ハイライト |
| Occlusion | `1` | 光を減衰しない |
| Emission | `(0, 0, 0)` | 発光を加算しない |
| Alpha | `1` | Alpha Clip で破棄されない |

---

## 3. 数値マップのチャンネルとインポート設定

| マップ | チャンネル構造 | sRGB | 用途 |
| :--- | :--- | :---: | :--- |
| Base Map | RGB = Albedo、A = Alpha | オン | 拡散反射色・切り抜き形状 |
| Normal Map | RG/AG = XY 法線 | オフ、Normal map | 凹凸による明暗・ハイライト |
| Metallic Gloss Map | R = Metallic、A = Smoothness | オフ | 金属らしさ・ハイライトの鋭さ |
| Occlusion Map | G = AO | オフ | 遮蔽による暗さ |
| Emission Map | RGB = 発光色 | オン | 自己発光 |
| Parallax Map | R = 高さ | オフ | 視差による UV のずれ |
| Detail Mask | A = 適用量 | オフ | Detail Map の適用範囲 |
| Detail Albedo Map | RGB = 細かな色変化 | オン | 細かな汚れ・模様 |
| Detail Normal Map | RG/AG = XY 法線 | オフ、Normal map | 細かな凹凸 |
| Clear Coat Map | R = Mask、G = Smoothness | オフ | 上塗り層のハイライト |

色として見せる Base／Emission／Detail Albedo は **sRGB をオン**、計算に使う数値マップは **sRGB をオフ**にします。

---

## 4. 段階 1：Metallic と Smoothness

`Assets/ShaderProgramming/Chapter5/MetallicSmoothness05.shader` は、Chapter4 に `_MetallicGlossMap`、`_Metallic`、`_Smoothness` だけを加えます。

```text
MetallicGlossMap = (Metallic, unused, unused, Smoothness)
                  = (R,        G,      B,      A)
```

- **Metallic = 0**: 絶縁体。拡散反射を残し、鏡面反射色はほぼ白い
- **Metallic = 1**: 金属。拡散反射を減らし、アルベド色を鏡面反射色へ使う
- **Smoothness = 0**: ハイライトが広い
- **Smoothness = 1**: ハイライトが鋭い

Chapter5 は PBR 前の段階なので、値を Phong の拡散反射・鏡面反射へ近似的に対応させます。

データを読み込むコードは次の通りです。マップデータの追加とパラメータの追加、既存の_specColorと_Shinnessを削除します。


```hlsl
	Properties
	{
		_BaseMap ("Albedo Map", 2D) = "white" {}
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		[Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
		_NormalScale ("Normal Scale", Range(0,2)) = 1
		_MetallicGlossMap ("Metallic (R) Smoothness (A)", 2D) = "white" {}
		_Metallic ("Metallic", Range(0,1)) = 0
		_Smoothness ("Smoothness", Range(0,1)) = 0.5
		_Ambient ("Ambient", Color) = (0.05,0.05,0.05,1)
	}
```


SubShaderのPassに変更を加えます。





```hlsl
half4 metallicGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, IN.uv);
half metallic = metallicGloss.r * _Metallic;
half smoothness = metallicGloss.a * _Smoothness;

half3 diffuse = albedo * (1.0h - metallic) * radiance * NdotL;
half3 specularColor = lerp(0.04h.xxx, albedo, metallic);
half shininess = lerp(8.0h, 128.0h, smoothness);
```

`MetallicSmoothness05.shader` は Chapter4 と同じく Main Light と Additional Lights の両方にこの処理を適用します。

---

## 5. 段階 2：AO（Ambient Occlusion）

`Assets/ShaderProgramming/Chapter5/Occlusion05.shader` は、前段階に `_OcclusionMap` と `_OcclusionStrength` だけを加えます。URP/Lit と同じく Occlusion Map の **G チャンネル**を読みます。

```hlsl
half sampledOcclusion = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, IN.uv).g;
half occlusion = lerp(1.0h, sampledOcclusion, _OcclusionStrength);

half3 color = _Ambient.rgb * albedoSample.rgb * occlusion;
color += ShadePhong(GetMainLight(), albedoSample.rgb, metallic, smoothness, normalWS, V) * occlusion;
```

`_OcclusionStrength = 0` は AO を無効にし、`1` は画像の値をそのまま使います。この教材では変化を確認しやすくするため、環境光と直接光の両方に AO を掛けます。URP/Lit の PBR 実装では、主に間接光を減衰します。

---

## 6. 段階 3：Emission

`Assets/ShaderProgramming/Chapter5/Emission05.shader` は、AO 段階に `_EmissionMap` と `_EmissionColor` だけを加えます。

```hlsl
half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, IN.uv).rgb * _EmissionColor.rgb;
return half4(color + emission, albedoSample.a);
```

Emission はライトが当たらない場所にも加算されます。ネオン、ディスプレイ、魔法の紋様などに使用します。`_EmissionColor` を HDR カラーに設定し、Bloom を有効にすると光のにじみを確認できます。

> Emission はこのシェーダー単体で周囲を照らしません。周囲への光やベイクされた GI は別の機能です。

---

## 7. 段階 4：Alpha Clip

`Assets/ShaderProgramming/Chapter5/AlphaClip05.shader` は、Emission 段階に `_Cutoff` と `clip` だけを加えます。Base Map の A チャンネルを使って、しきい値未満のピクセルを描画しません。

```hlsl
half4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
clip(albedoSample.a - _Cutoff);
```

```text
Base Map A = 0.20    Cutoff = 0.50    → 描画しない
Base Map A = 0.80    Cutoff = 0.50    → 描画する
```

これは透明ブレンドではありません。葉、金網、穴の空いた板のように輪郭を切り抜く用途です。この章では UniversalForward パスの切り抜きを扱います。ShadowCaster パスに同じ clip を適用する処理は、シャドウを扱う章で追加します。

---

## 8. 発展：SurfaceInputs への統合

`Assets/ShaderProgramming/Chapter5/SurfaceInputs05.shader` は、これまで段階的に追加した入力を `SurfaceInputs` にまとめます。構造体にまとめること自体は見た目を変えず、テクスチャの読み取りとライティングを分離するための設計上の改善です。

```hlsl
struct SurfaceInputs
{
    half3 albedo;
    half metallic;
    half smoothness;
    half3 normalTS;
    half3 emission;
    half occlusion;
    half alpha;
    half clearCoatMask;
    half clearCoatSmoothness;
};
```

さらに、段階実装にはない次の発展マップを追加します。

| マップ | 実装する処理 | 見た目の変化 |
| :--- | :--- | :--- |
| Parallax Map | 視線のタンジェント空間成分に応じて UV をずらす | 模様に奥行きがあるように見える |
| Detail Mask / Albedo / Normal | マスク領域へ別 Tiling の色・法線を重ねる | 細かな傷、布目、汚れを加える |
| Clear Coat Map | 下地の上へ追加の鋭い Phong ハイライトを加える | ニス、車の塗装のような反射 |

### 8.1 高さマップと簡易パララックス

```hlsl
half height = SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, uv).r;
uv += viewDirTS.xy / max(viewDirTS.z, 0.1h) * ((height - 0.5h) * _Parallax);
```

これは 1 回だけ UV をずらす簡易方式です。シルエットは変わりません。高さマップを使わない場合は `0.5` のグレー画像を割り当てると UV のずれが 0 になります。

### 8.2 ディテールマップ

```hlsl
half detailMask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, uv).a;
half3 detailAlbedo = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUv).rgb;
surface.albedo *= lerp(1.0h.xxx, 2.0h * detailAlbedo * _DetailAlbedoMapScale - _DetailAlbedoMapScale + 1.0h, detailMask);
surface.normalTS = normalize(lerp(surface.normalTS, BlendNormalRNM(surface.normalTS, detailNormalTS), detailMask));
```

### 8.3 Clear Coat

```hlsl
half2 clearCoat = SAMPLE_TEXTURE2D(_ClearCoatMap, sampler_ClearCoatMap, uv).rg;
surface.clearCoatMask = clearCoat.r * _ClearCoatMask;
surface.clearCoatSmoothness = clearCoat.g * _ClearCoatSmoothness;
```

Clear Coat は追加の Phong ハイライトで近似しています。URP/Lit の実装は PBR の Fresnel・多重反射を考慮するため、数値結果は厳密には同一ではありません。

---

## 9. URP/Lit の SurfaceData との対応

| URP/Lit の入力・処理 | Chapter5 の対応 | 補足 |
| :--- | :--- | :--- |
| `SurfaceData.albedo` | `SurfaceInputs.albedo` | Base と Detail Albedo を合成 |
| `SurfaceData.normalTS` | `SurfaceInputs.normalTS` | Base / Detail Normal を合成 |
| `SurfaceData.metallic` / `smoothness` | 同名のフィールド | Phong の色と指数へ近似的に反映 |
| `SurfaceData.occlusion` | `SurfaceInputs.occlusion` | Chapter5 は直接光にも掛ける簡略化 |
| `SurfaceData.emission` | `SurfaceInputs.emission` | 最後に加算 |
| `SurfaceData.alpha` | `SurfaceInputs.alpha` | `clip` と出力 alpha に利用 |
| Clear Coat | 同名のフィールド | 追加 Phong ハイライトで近似 |
| Parallax / Detail | 初期化関数内で処理 | SurfaceData を作る前の前処理 |
| PBR BRDF / IBL / Shadow | Chapter6 以降 | Chapter5 の対象外 |

---

## 10. 確認課題

1. `MetallicSmoothness05.shader` の Metallic Gloss Map で、R を 0 と 1、A を 0 と 1 に塗り分ける
2. `Occlusion05.shader` で Occlusion Map の G に黒い溝を描き、`_OcclusionStrength` を 0〜1 に変える
3. `Emission05.shader` で Emission Map の一部を白くし、HDR の `_EmissionColor` を調整する
4. `AlphaClip05.shader` で Base Map の A に穴を描き、`_Cutoff` による切り抜きを確認する
5. `SurfaceInputs05.shader` で Detail Mask と Clear Coat Map を割り当て、段階シェーダーとの差分を観察する

---

## 11. まとめ

- Chapter4 の最終シェーダーを基準に、各マップを一つずつ追加した
- Metallic／Smoothness は拡散反射、鏡面反射色、ハイライトの鋭さを変える
- AO は遮蔽による暗さ、Emission は自己発光、Alpha Clip は輪郭の切り抜きを追加する
- `SurfaceInputs05.shader` は段階実装の入力を整理し、Parallax／Detail／Clear Coat まで統合する
- Chapter6 では同じ入力を PBR の Cook-Torrance BRDF と環境反射へ接続する
