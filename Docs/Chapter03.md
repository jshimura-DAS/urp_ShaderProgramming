# Chapter3：ライティング発展（カメラ位置・ポイントライト・スポットライト）

この章は `index.md` の **Chapter 03**（ライティング発展）に対応します。  
Chapter2 で扱った拡散反射のみの Phong シェーダー（`Phong01.shader`）を土台に、**カメラ位置を意識した鏡面反射**を追加し、さらに**ポイントライト／スポットライト**への対応を学びます。

---

## 1. この章でやること

1. **カメラ情報の読み込み方法**の基本を理解する
2. シェーダーが受け取る**バッファ（CBUFFER）の構造**を整理する
3. カメラ位置を意識した `Phong03.shader` を実装する
4. **ポイントライト**に対応する
5. **スポットライト**に対応する
6. **ライトの種類を区別せず／区別して扱える最終シェーダー**を作る

---

## 2. カメラ情報の読み込み

### 2.1 なぜカメラが必要か

拡散反射（Diffuse）は「光の向き」と「法線」だけで決まります。  
一方、鏡面反射（Specular）は **見る位置によってハイライトの位置が変わる**ため、カメラ位置が必要です。

```text
 ライト ──▶ 面 ──▶ カメラ
			  ↑
		  ここでの視線ベクトル V が必要
```

視線ベクトル `V` は「**表面の位置 → カメラ位置**」の単位ベクトルです。

```hlsl
half3 V = normalize(cameraPositionWS - positionWS);
```

### 2.2 URPでのカメラ位置の取得方法

| 方法 | 内容 |
| :--- | :--- |
Unityが毎フレーム送ってくるワールド空間のカメラ位置（`float3`） |
| `GetCameraPositionWS()` | URPが用意しているラッパー関数。内部で同じ値を返す |

この章では、意図が読み取りやすい `GetCameraPositionWS()` を使います。

> `_WorldSpaceCameraPos` や `unity_MatrixVP` のような値は **Unityが自動で設定**します。  
> プロパティとして宣言したり、C#から渡したりする必要はありません。

### 2.3 注意点：ライト方向の向き

URPの `Light.direction` は「**サーフェスからライトへ向かう方向**」です。  
そのため `L` に使うときに**符号を反転する必要はありません**。

```hlsl
half3 L = normalize(light.direction);   // そのまま使う
```

> Chapter2 と同様に、`L` は `light.direction` をそのまま使い、符号を反転しません。

---

## 3. バッファ（CBUFFER）構造のサンプル

### 3.1 シェーダーに届くデータの種類

| 種類 | 例 | 設定する人 |
| :--- | :--- | :--- |
| マテリアル単位 | `_BaseColor`, `_SpecColor`, `_Shininess` | マテリアル（Properties） |
| オブジェクト単位 | `unity_ObjectToWorld` | Unity |
| カメラ／フレーム単位 | `_WorldSpaceCameraPos`, `unity_MatrixVP` | Unity |
| ライト単位 | `_MainLightPosition`, `_MainLightColor`, `_AdditionalLightsPosition` など | URP |

### 3.2 マテリアル用 CBUFFER の書き方

Chapter1 でも登場した `UnityPerMaterial` に、Properties と同じ名前・型の変数を並べます。

```hlsl
CBUFFER_START(UnityPerMaterial)
	half4 _BaseColor;
	half4 _SpecColor;
	half  _Shininess;
CBUFFER_END
```

ポイント:

- Properties に書いた名前と **完全に一致**させる
- 色は `half4`、スカラーは `half`
- 要素が増えたら **`float4` / `half4` 単位でまとめる** と GPU 側の詰め込み（16バイト境界）の無駄が減る
- URP の SRP Batcher は、この `UnityPerMaterial` が同一であることを条件に動作する

### 3.3 ライト情報のバッファ構造（イメージ）

URP は内部で、ライトの情報を次のような形で保持しています。

```text
Main Light
  _MainLightPosition   : float4  (xyz = 方向、w = 0)
  _MainLightColor      : half4   (rgb = 色×強度)

Additional Lights（配列／StructuredBuffer）
  position             : float4  (xyz = 位置または方向、w = 1:点光源・スポット / 0:平行光)
  color                : half4
  attenuation          : half4   (xy = 距離減衰用、zw = スポット角度減衰用)
  spotDirection        : half4   (xyz = スポットライトの向き)
```

重要なのは `position.w` です。URP は次の式で **ポイント／スポット／平行光を同じ計算**で扱っています。

```hlsl
float3 lightVector = lightPositionWS.xyz - positionWS * lightPositionWS.w;
```

- `w = 0`（平行光）→ `lightVector = 方向` となり、位置に依存しない
- `w = 1`（点光源／スポット）→ `lightVector = ライト位置 - 表面位置` となる

私たちが自分で書くときは、これを **`GetAdditionalLight()` が全部計算してくれた `Light` 構造体** として受け取ります。

```hlsl
struct Light
{
	half3 direction;            // 表面 → ライトの単位ベクトル
	half3 color;                // 色 × 強度
	float distanceAttenuation;  // 距離減衰 × （スポットなら）角度減衰
	half  shadowAttenuation;    // 影
	uint  layerMask;
};
```

---

## 4. カメラ位置を意識した Phong（Phong03.shader）

Chapter2 の Phong をベースに、次の点を変更します。

- 視線ベクトルを `GetCameraPositionWS()` で取得
- `Light.direction` の向きを URP の仕様どおりに使う
- `distanceAttenuation` を掛けておく（Directional では 1 なので影響なし）
- `NdotL` が 0 のとき（裏側）にハイライトが出ないように `step` を掛ける

`Assets/ShaderProgramming/Chapter3/Phong03.shader`

```shader
Shader "ShaderProgramming/Chapter3/Phong03"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half _Shininess;
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
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				Light mainLight = GetMainLight();

				half3 N = normalize(IN.normalWS);
				half3 L = normalize(mainLight.direction);
				// カメラ位置から視線ベクトルを作る（Phongの鏡面反射に必要）
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);
				half3 H = normalize(L + V);

				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));

				half3 radiance = mainLight.color * mainLight.distanceAttenuation;
				half3 diffuse = _BaseColor.rgb * radiance * NdotL;
				half3 specular = _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);

				return half4(diffuse + specular, 1.0h);
			}
			ENDHLSL
		}
	}
}
```
#### コード解説

##### ハーフベクトル `H`

```hlsl
half3 H = normalize(L + V);
```

`L` は表面からライトへ向かう単位ベクトル、`V` は表面からカメラへ向かう単位ベクトルです。  
この2つを加算して正規化した `H` は、**ライト方向と視線方向のちょうど中間を向くベクトル**で、ハーフベクトル（Half Vector）と呼ばれます。

鏡面反射が強く見えるのは、法線 `N` がこの中間方向 `H` に近いときです。その近さは次の内積で求めます。

```hlsl
half NdotH = saturate(dot(N, H));
```

`NdotH` が `1` に近いほど、法線とハーフベクトルが同じ向きを向いているため、ハイライトが強くなります。この計算方法は、反射ベクトルを使うPhong反射に対して、一般に **Blinn-Phong** と呼ばれます。

##### 鏡面反射の式

```hlsl
half3 specular = _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);
```

各項の役割は次のとおりです。

| 項 | 意味 |
| :--- | :--- |
| `_SpecColor.rgb` | ハイライトの色 |
| `radiance` | ライトの色・強度と距離減衰 |
| `pow(NdotH, _Shininess)` | ハイライトの形状。`_Shininess` が大きいほど、狭く鋭いハイライトになる |
| `step(0.0h, NdotL)` | ライトが表面の裏側にあるとき、鏡面反射を `0` にする |

`step(edge, x)` は、`x < edge` なら `0`、`x >= edge` なら `1` を返します。ここでは `NdotL` が負（ライトが法線の反対側）の場合に鏡面反射を消し、裏面に不自然なハイライトが出ることを防ぎます。

##### `saturate` の役割

```hlsl
half NdotL = saturate(dot(N, L));
half NdotH = saturate(dot(N, H));
```

`saturate(x)` は値を **`0` から `1` の範囲に丸める**関数です。上の式では内積の結果を明るさとして使うため、負の値を `0` にし、浮動小数点の誤差などで `1` を超えた値も `1` に制限します。

- `NdotL`：拡散反射の明るさ。ライトが表面の正面側にあるほど `1` に近づく
- `NdotH`：鏡面反射の強さ。法線がハーフベクトルに近いほど `1` に近づく


### 4.1 確認ポイント

- シーン内でカメラを動かすと、ハイライトの位置が動く
- Directional Light を回すと、ハイライトと明暗の境界が追従する
- `Shininess` を大きくするとハイライトが小さく鋭くなる

---

## 5. ポイントライトに対応する

### 5.1 Main Light と Additional Lights の関係

URP では **Directional Light がメインライト**として扱われるのが基本です。  
ポイントライトやスポットライトは、**Additional Lights（追加ライト）として別経路**で届きます。

| ライト | 届く経路 | 取得方法 |
| :--- | :--- | :--- |
| Directional Light（Main） | Main Light | `GetMainLight()` |
| Point Light | Additional Lights | `GetAdditionalLight(i, positionWS)` |
| Spot Light | Additional Lights | `GetAdditionalLight(i, positionWS)` |

> 「メインライトがポイントライトになっている場合」は、**`GetMainLight()` では位置依存の計算が行われません**。  
> Directional Light を1つ置いて Main Light とし、ポイントライトは追加ライトとして処理するのが URP の考え方です。  
> したがって、ポイントライトを扱うには **Additional Lights のループ処理**が必要です。

### 5.2 ポイントライトで変わる点

| 項目 | Directional | Point |
| :--- | :--- | :--- |
| ライト方向 `L` | 全面で同じ | **面ごとに異なる**（ライト位置 − 表面位置） |
| 距離減衰 | なし（1） | あり（距離が遠いほど暗い） |
| 必要な情報 | 方向 | 位置・範囲 |

`GetAdditionalLight()` は、これらを計算した **`Light`** を返してくれます。

```hlsl
Light light = GetAdditionalLight(lightIndex, IN.positionWS);
// light.direction           : 表面 → ライト（面ごとに異なる）
// light.distanceAttenuation : 距離による減衰（範囲外では0）
```

### 5.3 追加ライトのループ

```hlsl
uint count = GetAdditionalLightsCount();
LIGHT_LOOP_BEGIN(count)
	Light light = GetAdditionalLight(lightIndex, IN.positionWS);
	// ここでライティング計算
LIGHT_LOOP_END
```

`LIGHT_LOOP_BEGIN / END` は URP が用意しているマクロで、通常の Forward と Forward+ の両方に対応しています。  
また、追加ライトを有効にするためのキーワードを `#pragma` で宣言します。

```hlsl
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
#pragma multi_compile _ _FORWARD_PLUS
```

### 5.4 実装例（PhongPoint03.shader）

`Assets/ShaderProgramming/Chapter3/PhongPoint03.shader`

```shader
Shader "ShaderProgramming/Chapter3/PhongPoint03"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _FORWARD_PLUS

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half _Shininess;
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
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half3 N = normalize(IN.normalWS);
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);
				half3 color = 0;

				// ポイントライトはAdditional Lightsとして届く
				// ライトの位置を使って方向と距離減衰を計算済みのLightが返る
				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					Light light = GetAdditionalLight(lightIndex, IN.positionWS);

					half3 L = normalize(light.direction);
					half3 H = normalize(L + V);
					half NdotL = saturate(dot(N, L));
					half NdotH = saturate(dot(N, H));

					// distanceAttenuationに距離による暗くなり方が入っている
					half3 radiance = light.color * light.distanceAttenuation;
					color += _BaseColor.rgb * radiance * NdotL;
					color += _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);
				LIGHT_LOOP_END
				#endif

				return half4(color, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

> このシェーダーは **追加ライトだけ**を描画します。Directional Light の寄与は含まれません（最終版で統合します）。

### 5.5 確認ポイント

- Point Light を球やキューブの近くに置くと、近い部分だけが明るくなる
- Point Light を遠ざけると暗くなり、`Range` を超えると完全に光が届かなくなる
- カメラを動かすと、ライト位置に応じたハイライトが動く

> 追加ライトが反映されない場合は、URP Asset の **Lighting > Additional Lights** が `Per Pixel` になっているか確認してください。Forward+ の場合は Renderer 側の Rendering Path 設定を確認します。

---

## 6. スポットライトに対応する

### 6.1 スポットライトで変わる点

スポットライトは **ポイントライトに「円錐の範囲」が加わったもの**です。

| 項目 | Point | Spot |
| :--- | :--- | :--- |
| 光の方向 | 全方向 | 向きと角度（Spot Angle）で決まる円錐内のみ |
| 距離減衰 | あり | あり |
| 角度減衰 | なし | あり（円錐の縁に向かって暗くなる） |

### 6.2 コードの書き換えは必要か

URP の `GetAdditionalLight()` は、内部で次の計算をしています。

```hlsl
float attenuation = DistanceAttenuation(distanceSqr, distanceAndSpotAttenuation.xy)
				  * AngleAttenuation(spotDirection.xyz, lightDirection, distanceAndSpotAttenuation.zw);
```

つまり **スポットの角度減衰は `light.distanceAttenuation` にすでに含まれている**ため、ポイントライト用のコードがそのままスポットライトにも使えます。

- ポイントライト: `AngleAttenuation` が常に 1 になるようなデータが入る
- スポットライト: 円錐の外側で 0、内側に向かって 1 に近づく

### 6.3 実装例（PhongSpot03.shader）

円錐の形が分かるように、`_VisualizeCone` で減衰値そのものを表示できるようにします。

`Assets/ShaderProgramming/Chapter3/PhongSpot03.shader`

```shader
Shader "ShaderProgramming/Chapter3/PhongSpot03"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
		[Toggle] _VisualizeCone ("Visualize Cone (Spot Attenuation)", Float) = 0
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _FORWARD_PLUS

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half _Shininess;
				half _VisualizeCone;
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
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half3 N = normalize(IN.normalWS);
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);
				half3 color = 0;

				// スポットライトもAdditional Lightsとして届く
				// distanceAttenuationには「距離減衰 × 円錐の角度減衰」が掛け合わされている
				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					Light light = GetAdditionalLight(lightIndex, IN.positionWS);

					half3 L = normalize(light.direction);
					half3 H = normalize(L + V);
					half NdotL = saturate(dot(N, L));
					half NdotH = saturate(dot(N, H));

					half3 radiance = light.color * light.distanceAttenuation;
					color += _BaseColor.rgb * radiance * NdotL;
					color += _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);

					// 円錐の範囲を確認するためのデバッグ表示
					if (_VisualizeCone > 0.5h)
					{
						color = saturate(light.distanceAttenuation).xxx;
					}
				LIGHT_LOOP_END
				#endif

				return half4(color, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

### 6.4 確認ポイント

- Spot Light を物体に向けると、円形に照らされる
- `Spot Angle` を大きくすると円が広がり、`Inner Spot Angle` を大きくすると縁のぼかしが小さくなる
- `Visualize Cone` をオンにすると、円錐の形（減衰値）がグレースケールで見える

---

## 7. ライトの種類を考慮した最終シェーダー（PhongFinal03.shader）

### 7.1 「判別」の考え方

ここまでで、ライトは次のように届くことが分かりました。

| ライト | 経路 | `direction` | `distanceAttenuation` |
| :--- | :--- | :--- | :--- |
| Directional（Main） | `GetMainLight()` | 全面共通 | 1 |
| Point | Additional | 面ごとに変化 | 距離減衰 |
| Spot | Additional | 面ごとに変化 | 距離減衰 × 角度減衰 |

`Light` 構造体には「種類」を示すメンバはありません。  
その代わり、**種類の違いが `direction` と `distanceAttenuation` の値に自動的に反映されている**ため、**1つの計算関数で全種類を処理できます**。

これが、URP の構造の利点です。

- **Main Light と Additional Lights を別経路で取得する**（ここが「判別」にあたる）
- **1灯分のライティング計算は共通関数にまとめる**

### 7.2 実装

`Assets/ShaderProgramming/Chapter3/PhongFinal03.shader`

```shader
Shader "ShaderProgramming/Chapter3/PhongFinal03"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range(1,128)) = 32
		_Ambient ("Ambient", Color) = (0.05,0.05,0.05,1)
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

		Pass
		{
			Tags { "LightMode"="UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _FORWARD_PLUS

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half4 _Ambient;
				half _Shininess;
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
			};

			// 1灯分のPhong計算。ライトの種類によらず共通で使える
			half3 ShadePhong(Light light, half3 N, half3 V)
			{
				half3 L = normalize(light.direction);
				half3 H = normalize(L + V);
				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));

				// 距離減衰・スポットの角度減衰はdistanceAttenuationに含まれる
				// Directionalは1、Pointは距離減衰、Spotは距離減衰×角度減衰
				half3 radiance = light.color * light.distanceAttenuation;
				half3 diffuse = _BaseColor.rgb * radiance * NdotL;
				half3 specular = _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);
				return diffuse + specular;
			}

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half3 N = normalize(IN.normalWS);
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);

				// メインライト（通常はDirectional Light）
				half3 color = _Ambient.rgb * _BaseColor.rgb;
				color += ShadePhong(GetMainLight(), N, V);

				// 追加ライト（Point / Spot）
				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					Light light = GetAdditionalLight(lightIndex, IN.positionWS);
					color += ShadePhong(light, N, V);
				LIGHT_LOOP_END
				#endif

				return half4(color, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

### 7.3 ライトの種類を見分けたい場合

どうしても種類で処理を分けたい場合は、C# から種類を渡すのではなく、`Light` の値から推定します。  
ただし、距離減衰が小さいだけかスポット外なのかは区別できないため、**基本は共通計算に任せる**のが安全です。

---

## 8. 実習手順

1. `Assets/ShaderProgramming/Chapter3/` に 4 つのシェーダー（Phong03 / PhongPoint03 / PhongSpot03 / PhongFinal03）が存在することを確認する
2. 新しいシーン `Chapter3.unity` を作り、Sphere・Cube・Plane を配置する
3. シェーダーごとにマテリアルを作り、各オブジェクトに割り当てる
4. **Phong03**: Directional Light のみで、カメラを動かしてハイライトの動きを確認する
5. **PhongPoint03**: Directional Light を無効にし、Point Light を追加。距離・Range を変えて減衰を観察する
6. **PhongSpot03**: Spot Light を追加。Spot Angle と `Visualize Cone` を確認する
7. **PhongFinal03**: Directional + Point + Spot を同時に置き、すべてが合成されることを確認する
8. 追加ライト数を増やし、URP Asset の `Per Object Limit` や Forward+ の影響を観察する

### 8.1 トラブルシューティング

| 症状 | 原因・対処 |
| :--- | :--- |
| 追加ライトが反映されない | URP Asset の Additional Lights が `Disabled` / `Per Vertex` になっていないか確認 |
| 真っ黒に見える | `PhongPoint03` / `PhongSpot03` は追加ライトのみ。ライトの範囲内にオブジェクトがあるか確認 |
| ピンクになる | シェーダーのコンパイルエラー。Console を確認 |
| ハイライトが反対側に出る | `L` の符号を反転していないか確認（`light.direction` はそのまま使う） |

---

## 9. この章のまとめ

- 鏡面反射には **カメラ位置**が必要で、`GetCameraPositionWS()` で取得できる
- マテリアル用の値は `UnityPerMaterial` の CBUFFER に宣言する
- URP では Directional が **Main Light**、Point / Spot は **Additional Lights** として別経路で届く
- `Light` 構造体の `direction` と `distanceAttenuation` に、ライトの種類の差が反映されている
- 1灯分のライティングを関数にまとめれば、**Main + Additional を同じ計算で処理できる**
