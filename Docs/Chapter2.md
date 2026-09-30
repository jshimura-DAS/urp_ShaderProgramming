# Chapter2：拡散反射・鏡面反射の基礎（URP / Directional Light 単体）

この章は `index.md` の **17週**（拡散反射、鏡面反射の基礎）に対応します。  
前提として、**シーンには Directional Light を1つだけ**置いているものとします。

---

## 1. この章でやること

1. URPでの**ライト情報の取得方法**を理解する  
2. 法線（Normal）を可視化して、**頂点法線の見方**を掴む  
3. **フラットシェーディング**を実装する  
4. **グーロー（Gouraud）シェーディング**を実装する  
5. **フォン（Phong）シェーディング**を実装する

---

## 2. URPでライト情報を取得する

### 2.1 Unityのメインライトについて
UnityのURPでは、ライティング計算の基準になる「代表ライト」を **メインライト（Main Light）** として扱います。

- **Directional Lightが1つだけ** の場合:
  - そのDirectional Lightがそのままメインライトになります。
- **ライトが複数ある** 場合:
  - URPは1つだけをメインライトとして選び、残りは「追加ライト（Additional Lights）」として別経路で扱います。
  - 一般に、太陽光として配置したDirectional Lightをメインライトとして使う構成が基本です。

実装上の重要点:

- `GetMainLight()` で取得できるのは **常に1灯分** の情報です。
- 追加ライトまで反映したい場合は、Additional Lights向けの処理（別ループ）を実装する必要があります。

このChapter2では、学習をシンプルにするため **Directional Light 1灯 = Main Lightのみ** を前提に進めます。


### 2.2 URPのHLSLでのライト情報取得

URPのHLSLでは、主に以下を使います。

- `#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"`
- `#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"`
- `Light mainLight = GetMainLight();`

`Light` 構造体の代表的なメンバ:

- `mainLight.direction` : ライト方向（ワールド空間）
- `mainLight.color` : ライト色
- `mainLight.distanceAttenuation` : 距離減衰（Directional Light は実質1）
- `mainLight.shadowAttenuation` : 影減衰（シャドウ有効時）

> Directional Light は「無限遠の平行光」なので、ポイントライトのような距離減衰は基本ありません。

---

## 3. 法線の向きを可視化してみる（Normal Visualize）

### 3.1 法線とは

**法線（Normal Vector）** は、ポリゴンの表面に対して垂直な方向を示す単位ベクトルです。ライティング計算では、この法線と光の方向の関係から「その面がどれだけ光を受けるか」を決定します。

- **頂点法線** : メッシュの各頂点に指定された法線。スムーズなシェーディングに使われる
- **面法線** : 三角形面そのものの向き。フラットシェーディングで使われる

### 3.2 法線を色で可視化する

法線を直接見えるようにするために、法線ベクトルを**RGB色に変換して画面に映します**。

法線ベクトルは `[-1, 1]` の範囲なので、表示用に `[0, 1]` に変換します：

```hlsl
half3 n = normalize(IN.normalWS);
return half4(n * 0.5h + 0.5h, 1.0h);
```

色の対応：

| 成分 | 意味 | 色例 |
| :--- | :--- | :--- |
| 赤（R） | X方向法線 | 赤系 ＝ 法線がX正方向（右向き） |
| 緑（G） | Y方向法線 | 緑系 ＝ 法線がY正方向（上向き） |
| 青（B） | Z方向法線 | 青系 ＝ 法線がZ正方向（奥向き） |

**結果として、複数の色が混ざった画面が見えます** — これは「頂点法線がピクセルごとにどう補間されているか」を表しています。この可視化により、後続の**フラット・グーロー・フォンシェーディングで何が起こっているか**をより直感的に理解できるようになります。

### 3.3 実装サンプル（NormalVisualizer.shader）

以下は法線をそのまま色で表示するシェーダーです。`Assets/ShaderProgramming/Chapter2/NormalVisualizer.shader` として保存して使います。

```shader
Shader "ShaderProgramming/Chapter2/NormalVisualizer"
{
	Properties
	{
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				half3  normalWS    : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				// 法線を [-1, 1] から [0, 1] へ変換
				half3 n = normalize(IN.normalWS);
				half3 visualNormal = n * 0.5h + 0.5h;

				return half4(visualNormal, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

> **使い方**:
> 1. このシェーダーをマテリアルに適用する
> 2. ゲーム画面に「虹色のグラデーション」が表示される
> 3. 色が均一な領域 ＝ 法線が一定（フラットな面）
> 4. 色が滑らかに変わる領域 ＝ 法線が補間されている（スムーズなシェーディング）

---

## 4. フラットシェーディング実装

ここでは **フラットシェーディングだけ** を行う単体シェーダーとして実装します。  
考え方は「頂点法線を使わず、ピクセル位置の微分から面法線を再構築する」です。

### 4.1 面法線の再構築を掘り下げる

以下の3行が中核です。

```hlsl
half3 dpdx = ddx(IN.positionWS);
half3 dpdy = ddy(IN.positionWS);
half3 faceN = normalize(cross(dpdy, dpdx));
```

それぞれの意味:

1. `IN.positionWS` は「現在ピクセルのワールド座標」
2. `ddx(IN.positionWS)` は「画面のx方向に1ピクセル進んだとき、座標がどれだけ変化するか」
3. `ddy(IN.positionWS)` は「画面のy方向に1ピクセル進んだとき、座標がどれだけ変化するか」

`dpdx` と `dpdy` は、その三角形面上の接ベクトルです。  
2本の接ベクトルの外積 `cross(dpdy, dpdx)` を取ると、面に垂直なベクトル（面法線）が得られます。

- `cross(a, b)` の結果は `a` と `b` の両方に直交
- 順序で向きが反転するため、`cross(dpdy, dpdx)` と `cross(dpdx, dpdy)` は逆向き
- 最後に `normalize` して単位法線にする

この方法を使うと、同じ三角形内ではほぼ同じ法線が得られるため、結果として「面ごとに一定の明るさ」になり、カクッとした見た目（フラット）になります。



### 4.2 単体実装サンプル（Flat.shader）

```shader
Shader "ShaderProgramming/Chapter2/Flat"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				Light mainLight = GetMainLight();

				half3 dpdx = ddx(IN.positionWS);
				half3 dpdy = ddy(IN.positionWS);
				half3 faceN = normalize(cross(dpdy, dpdx));

				half3 L = normalize(-mainLight.direction);
				half NdotL = saturate(dot(faceN, L));

				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				return half4(diffuse, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

> このコードは `Assets/ShaderProgramming/Chapter2/Flat.shader` として保存して使います。

---

## 5. グーロー / フォンの違い

- **グーロー（Gouraud）**: 頂点でライティング計算して、色を補間
- **フォン（Phong）**: ピクセルで法線を使ってライティング計算

一般的に:
- グーロー: 軽いがハイライトが粗い
- フォン: 重いが見た目が滑らか

---

## 6. 実装サンプル（1ファイルで切り替え）

以下は、法線表示 / フラット / グーロー / フォンを切り替え可能な最小サンプルです。

```shader
Shader "ShaderProgramming/Chapter2/LightingBasics"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
		[Enum(NormalDebug,0,Flat,1,Gouraud,2,Phong,3)] _Mode ("Mode", Float) = 3
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half _Shininess;
				half _Mode;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
				half3  normalWS    : TEXCOORD1;
				half3  gouraudLit  : TEXCOORD2;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

				// Gouraud用: 頂点でライティング
				Light mainLight = GetMainLight();
				half3 N = normalize(OUT.normalWS);
				half3 L = normalize(-mainLight.direction);
				half3 V = normalize(_WorldSpaceCameraPos.xyz - OUT.positionWS);
				half3 H = normalize(L + V);

				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));

				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				half3 spec = _SpecColor.rgb * pow(NdotH, _Shininess);
				OUT.gouraudLit = diffuse + spec;

				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				// 0: Normal Debug
				if (_Mode < 0.5h)
				{
					half3 n = normalize(IN.normalWS);
					return half4(n * 0.5h + 0.5h, 1.0h);
				}

				Light mainLight = GetMainLight();
				half3 lightColor = mainLight.color;

				// 1: Flat
				if (_Mode < 1.5h)
				{
					half3 dpdx = ddx(IN.positionWS);
					half3 dpdy = ddy(IN.positionWS);
					half3 faceN = normalize(cross(dpdy, dpdx));
					half3 L = normalize(-mainLight.direction);

					half NdotL = saturate(dot(faceN, L));
					half3 col = _BaseColor.rgb * lightColor * NdotL;
					return half4(col, 1.0h);
				}

				// 2: Gouraud
				if (_Mode < 2.5h)
				{
					return half4(IN.gouraudLit, 1.0h);
				}

				// 3: Phong
				{
					half3 N = normalize(IN.normalWS);
					half3 L = normalize(-mainLight.direction);
					half3 V = normalize(_WorldSpaceCameraPos.xyz - IN.positionWS);
					half3 H = normalize(L + V);

					half NdotL = saturate(dot(N, L));
					half NdotH = saturate(dot(N, H));

					half3 diffuse = _BaseColor.rgb * lightColor * NdotL;
					half3 spec = _SpecColor.rgb * pow(NdotH, _Shininess);

					return half4(diffuse + spec, 1.0h);
				}
			}
			ENDHLSL
		}
	}
}
```

---

## 7. 実習手順

1. `Assets/ShaderProgramming/Chapter2/` を作成
2. 上記シェーダーを `LightingBasics.shader` として保存
3. マテリアルを作成してシェーダーを割り当て
4. シーンには Directional Light を1つだけ置く
5. `_Mode` を切り替えて比較
   - `NormalDebug`
   - `Flat`
   - `Gouraud`
   - `Phong`

---

## 8. 観察ポイント

- Flatでは面ごとの段差が見えるか
- Gouraudでハイライトが頂点依存で粗く見えるか
- Phongでハイライトが滑らかに動くか
- 法線デバッグ表示でモデルの法線方向が想定通りか

---

## 9. まとめ

- URPでは `GetMainLight()` でメインライト情報を取得できる
- 法線理解には「色で可視化」が最短
- Flat / Gouraud / Phong の差は「どこで何を補間するか」の差
- この章は次のシャドウイング実装の土台になる
