# Chapter2：拡散反射・鏡面反射の基礎（URP / Directional Light 1灯）

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

## 3. 法線の見方（Normal Visualize）

まず法線を色として表示すると理解が早いです。  
法線ベクトルは `[-1, 1]` の範囲なので、表示用に `[0, 1]` に変換します。

```hlsl
half3 n = normalize(IN.normalWS);
return half4(n * 0.5h + 0.5h, 1.0h);
```

- 赤成分: X方向法線
- 緑成分: Y方向法線
- 青成分: Z方向法線

これで「頂点法線がどう補間されているか」が見えます。

---

## 4. フラットシェーディング実装

フラットシェーディングは「面ごとに同じ法線」で計算する方式です。  
URPでは、フラグメント内で微分を使って面法線を再構築できます。

```hlsl
half3 dpdx = ddx(IN.positionWS);
half3 dpdy = ddy(IN.positionWS);
half3 faceN = normalize(cross(dpdy, dpdx));
```

この `faceN` で拡散反射を計算すると、ポリゴン面がくっきり見える描画になります。

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
