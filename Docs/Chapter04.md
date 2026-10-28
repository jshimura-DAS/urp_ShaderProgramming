# Chapter4：テクスチャ利用（アルベドマップ・法線マップ）

この章は `URPシェーダープログラミングindex.md` の **Chapter 04**（テクスチャ利用）に対応します。  
Chapter3 の Main Light / Additional Lights 対応 Phong シェーディングを土台に、**アルベドマップ**と**法線マップ**を使って物体表面の見た目を詳しくします。

---

## 1. この章でやること

1. 既存 GameObject が持つ **UV 座標**を Scene ビューで確認する
2. UV 座標とテクスチャ座標の関係を理解する
3. テクスチャデータの種類、色空間、インポート設定を整理する
4. アルベドマップを読み込み、Phong の拡散反射へ使う
5. ノーマルマップの RGB とタンジェント空間の関係を理解する
6. アルベド／ノーマルマップと Main Light／Additional Lights に対応した最終シェーダーを作る

---

## 2. UV 座標とは

### 2.1 3D の頂点と 2D の画像を対応付ける座標

メッシュの頂点位置は 3D 座標ですが、画像は 2D の格子です。  
**UV 座標**は、メッシュの各頂点を画像上のどこに対応付けるかを表す 2D 座標です。

```text
メッシュの頂点                    テクスチャ画像
(positionOS, uv)                   (u, v)

	   頂点 A  uv=(0, 1) ──────── 左上
	   頂点 B  uv=(1, 1) ──────── 右上
	   頂点 C  uv=(0, 0) ──────── 左下
	   頂点 D  uv=(1, 0) ──────── 右下
```

- `u` : 横方向の座標。通常は左が 0、右が 1
- `v` : 縦方向の座標。通常は下が 0、上が 1
- Unity の `Mesh.uv` は `Vector2[]` として格納される
- UV は頂点属性なので、シェーダーでは `TEXCOORD0` セマンティクスから取得する

UV は必ずしも 0〜1 に収まるとは限りません。1 を超える値、負の値、UV が重なった値も使えます。画像の繰り返し方は Texture Import Settings の **Wrap Mode**（Repeat / Clamp など）で決まります。

### 2.2 シェーダーでの UV の受け取り

```hlsl
struct Attributes
{
	float2 uv : TEXCOORD0;
};

struct Varyings
{
	float2 uv : TEXCOORD0;
};

Varyings vert(Attributes IN)
{
	Varyings OUT;
	OUT.uv = IN.uv;
	return OUT;
}
```

頂点間の UV はラスタライザが補間するため、フラグメントシェーダーでは各ピクセルに対応する UV を受け取れます。

---

## 3. GameObject の UV を Scene ビューで確認する

### 3.1 UvCoordinateVisualizer.cs

`Assets/ShaderProgramming/Chapter4/UvCoordinateVisualizer.cs` を、確認したい GameObject に追加します。  
`MeshFilter` または `SkinnedMeshRenderer` が持つ共有メッシュから頂点と UV を読み取り、Scene ビューに次を描画します。

- UV の `u` を赤、`v` を緑で表した頂点マーカー
- `頂点番号: (u, v)` のラベル
- 三角形の境界線

```csharp
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
public sealed class UvCoordinateVisualizer : MonoBehaviour
{
	[SerializeField] private bool showVertexLabels = true;
	[SerializeField] private bool showTriangleEdges = true;
	[SerializeField] private int maximumVertexCount = 128;
	[SerializeField] private float markerRadius = 0.015f;

	private Mesh _mesh;

	private void OnValidate()
	{
		maximumVertexCount = Mathf.Max(1, maximumVertexCount);
		markerRadius = Mathf.Max(0.001f, markerRadius);
		CacheMesh();
	}

	private void OnDrawGizmos()
	{
		if (!CacheMesh() || _mesh.uv == null || _mesh.uv.Length == 0)
		{
			return;
		}

		Vector3[] vertices = _mesh.vertices;
		Vector2[] uv = _mesh.uv;
		int vertexCount = Mathf.Min(Mathf.Min(vertices.Length, uv.Length), maximumVertexCount);

		for (int i = 0; i < vertexCount; i++)
		{
			Vector3 positionWS = transform.TransformPoint(vertices[i]);
			Color uvColor = new Color(uv[i].x, uv[i].y, 0.0f, 1.0f);
			Gizmos.color = uvColor;
			Gizmos.DrawSphere(positionWS, markerRadius);

#if UNITY_EDITOR
			if (showVertexLabels)
			{
				Handles.Label(positionWS, $"{i}: ({uv[i].x:F2}, {uv[i].y:F2})");
			}
#endif
		}

		if (!showTriangleEdges)
		{
			return;
		}

		Gizmos.color = Color.white;
		int[] triangles = _mesh.triangles;
		for (int i = 0; i + 2 < triangles.Length; i += 3)
		{
			int a = triangles[i];
			int b = triangles[i + 1];
			int c = triangles[i + 2];
			if (a >= vertexCount || b >= vertexCount || c >= vertexCount)
			{
				continue;
			}

			Vector3 positionA = transform.TransformPoint(vertices[a]);
			Vector3 positionB = transform.TransformPoint(vertices[b]);
			Vector3 positionC = transform.TransformPoint(vertices[c]);
			Gizmos.DrawLine(positionA, positionB);
			Gizmos.DrawLine(positionB, positionC);
			Gizmos.DrawLine(positionC, positionA);
		}
	}

	private bool CacheMesh()
	{
		if (_mesh != null)
		{
			return true;
		}

		MeshFilter meshFilter = GetComponent<MeshFilter>();
		if (meshFilter != null)
		{
			_mesh = meshFilter.sharedMesh;
		}

		if (_mesh == null)
		{
			SkinnedMeshRenderer skinnedMeshRenderer = GetComponent<SkinnedMeshRenderer>();
			if (skinnedMeshRenderer != null)
			{
				_mesh = skinnedMeshRenderer.sharedMesh;
			}
		}

		return _mesh != null;
	}
}
```

### 3.2 使い方と確認ポイント

1. Cube、Sphere、Plane などを選択する
2. Inspector から `UvCoordinateVisualizer` を追加する
3. **Scene ビュー**で頂点ラベルを確認する（Game ビューには表示されない）
4. `maximumVertexCount` を調整して、ラベルが多すぎないようにする

Cube では面ごとに画像を貼り分けるため、同じ位置に見える頂点でも UV が異なる場合があります。これは **UV シーム**です。法線マップでも UV シームに沿って接空間が分かれるため、モデル作成時に重要になります。

---

## 4. テクスチャデータを読む

### 4.1 テクスチャの宣言とサンプリング

URP の HLSL では、テクスチャ本体とサンプラーを別々に宣言します。

```hlsl
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
```

`SAMPLE_TEXTURE2D` は UV に対応する画素を読み、`half4` として返します。各成分は通常 0〜1 の範囲です。

```text
half4 color = (R, G, B, A)
			= (red, green, blue, alpha)
```

### 4.2 読み込めるデータの種類とフォーマット

テクスチャは「色専用」ではありません。RGBA の各チャンネルに任意の数値データを格納できます。

| 用途 | よく使うチャンネル | sRGB | シェーダーでの代表的な使い方 |
| :--- | :--- | :--- | :--- |
| アルベド／ベースカラー | RGB = 色、A = 透明度やマスク | オン | `sample.rgb` |
| ノーマルマップ | RGB = 法線方向 | オフ。Texture Type は Normal map | `UnpackNormalScale(sample, scale)` |
| メタリック・スムースネス | R = Metallic、A = Smoothness など | オフ | `sample.r`, `sample.a` |
| AO・マスク | R または RGB | オフ | `sample.r` |
| 高さ・粗さ | R | オフ | `sample.r` |
| HDR・環境データ | RGBA の広い値域 | 用途による | `float4` として読む |

**sRGB** は人間の視覚に合わせた色データの変換です。アルベドのように「見せる色」は sRGB をオンにします。  
一方、法線・メタリック・粗さ・マスクは「計算に使う数値」なので、sRGB をオフにします。数値テクスチャを sRGB のまま読むと、値が非線形に変換されて計算結果が崩れます。

### 4.3 データ形式と精度

Unity のインポート設定では、対象プラットフォームに合わせた圧縮形式が選ばれます。代表例は次のとおりです。

| 形式の例 | チャンネル | 特徴 |
| :--- | :--- | :--- |
| RGB(A) 8-bit | R/G/B/A 各 8 bit | 一般的なカラー画像。PNG などの入力で多い |
| BC1 / DXT1 | RGB | 低メモリ。アルファなしの色画像向け |
| BC3 / DXT5 | RGBA | アルファを含む色画像向け |
| BC5 | 2 チャンネル | ノーマルマップの X/Y 保存に適する |
| BC6H / 半精度浮動小数 | HDR RGB | 高輝度の環境マップなど |

GPU に送られる実際の圧縮形式はプラットフォームごとに異なります。教材ではまず、**どのチャンネルに何の値を入れ、シェーダーでどの成分を読むか**を明確にすることが重要です。

### 4.4 `_ST` による Tiling と Offset

2D Properties を宣言すると、Unity はプロパティごとに `<TextureName>_ST` を提供します。

```hlsl
float4 _BaseMap_ST;
float4 _NormalMap_ST;
```

各 `_ST` の内容は `(Tiling.x, Tiling.y, Offset.x, Offset.y)` です。  
`TRANSFORM_TEX` は指定したテクスチャの `_ST` を使い、UV へタイル数とオフセットを適用します。

```hlsl
uv = IN.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
```

#### 4.4.1 マップごとの個別設定を反映する

Inspector では `_BaseMap` と `_NormalMap` に、それぞれ別の **Tiling** と **Offset** を設定できます。個別設定を実際のサンプリングへ反映するには、各テクスチャ専用の UV を作ります。

```hlsl
// vert
OUT.baseUv = TRANSFORM_TEX(IN.uv, _BaseMap);
OUT.normalUv = TRANSFORM_TEX(IN.uv, _NormalMap);

// frag
half4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.baseUv) * _BaseColor;
half3 normalTS = UnpackNormalScale(
	SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.normalUv),
	_NormalScale);
```

`PhongNormal04.shader` はこの個別 UV 方式です。たとえば Base Map の Tiling を `(1, 1)`、Normal Map の Tiling を `(4, 4)` にすると、色模様は 1 回だけ貼られ、細かな凹凸だけが 4 回繰り返されます。

反対に、両方を同じ配置にしたい場合は、Normal Map にも `baseUv` を渡してサンプリングします。ただしその場合は `_NormalMap_ST` を使わないため、Inspector で変更した Normal Map 側の Tiling／Offset は反映されません。**Inspector に個別の設定欄を出す 2D プロパティは、個別の `TRANSFORM_TEX` と UV を用意する**ことが重要です。

---

## 5. アルベドマップを Phong シェーディングへ使う

### 5.1 アルベドとは

**アルベド**は物体固有の反射色です。この章では、アルベドマップをランバート拡散反射の色として使用します。

```hlsl
half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
half3 diffuse = albedo.rgb * radiance * NdotL;
```

- テクスチャの RGB が模様・色を決める
- `_BaseColor` はテクスチャ全体への色付け（Tint）
- 光量と `NdotL` によって明暗が決まる

### 5.2 段階実装（Albedo04.shader）

`Assets/ShaderProgramming/Chapter4/Albedo04.shader` は、アルベドマップと Main Light の Phong ライティングを組み合わせた段階用シェーダーです。

実装の中心は次の部分です。

```hlsl
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

CBUFFER_START(UnityPerMaterial)
	half4 _BaseColor;
	half4 _SpecColor;
	float4 _BaseMap_ST;
	half _Shininess;
CBUFFER_END

// vert
OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

// frag
half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
half3 diffuse = albedo.rgb * radiance * NdotL;
```

マテリアルに画像を割り当て、Tiling と Offset を変えると、画像が貼られる回数と開始位置が変化します。

---

## 6. ノーマルマップ

### 6.1 RGB に法線を入れる理由

法線は本来、各成分が -1〜1 の範囲を取る単位ベクトルです。しかし画像のチャンネルは通常 0〜1 で保存します。そのため、ノーマルマップでは次のように対応させます。

```text
法線成分 -1.0  → 色値 0.0
法線成分  0.0  → 色値 0.5
法線成分  1.0  → 色値 1.0

normal = color * 2 - 1
```

接空間で「平らな面を向く法線」は `(0, 0, 1)` なので、画像ではおおむね `(0.5, 0.5, 1.0)`、青紫色になります。

```text
Normal TS = (0, 0, 1)
Color     = (0.5, 0.5, 1.0)
```

URP では画像フォーマットや圧縮を考慮して `UnpackNormalScale` を使います。

```hlsl
half3 normalTS = UnpackNormalScale(
	SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.normalUv),
	_NormalScale);
```

### 6.2 タンジェント空間とは

ノーマルマップをワールド空間に直接保存すると、同じテクスチャを回転した別の面に再利用できません。  
そこで、各表面に固定された局所座標系である **タンジェント空間（Tangent Space）** に法線を保存します。

```text
T: Tangent   = UV の u が増える方向
B: Bitangent = UV の v が増える方向
N: Normal    = メッシュ本来の法線方向

			  N
			  ↑
			  |
			  +──→ T
			 /
			B
```

`T`, `B`, `N` が作る 3×3 行列を **TBN 行列**と呼びます。ノーマルマップから復元した `normalTS` を TBN 行列で変換すると、ライティング計算に使えるワールド空間法線になります。

```hlsl
half3 N = normalize(IN.normalWS);
half3 T = normalize(IN.tangentWS.xyz);
half3 B = cross(N, T) * IN.tangentWS.w;
half3 normalWS = normalize(TransformTangentToWorld(normalTS, half3x3(T, B, N)));
```

`IN.tangentWS.w` は、UV の反転（ミラー）を考慮して B の向きを正しくする符号です。自分で 0 や 1 を決めず、頂点属性の `tangentOS.w` と `GetOddNegativeScale()` を使って渡します。

### 6.3 ローカル座標・タンジェント空間・ワールド座標

| 座標空間 | 原点・向き | この章での用途 |
| :--- | :--- | :--- |
| オブジェクト空間（ローカル座標） | GameObject の原点基準 | 頂点位置、頂点法線、頂点タンジェントをMeshから読む |
| タンジェント空間 | 各頂点の T/B/N 基準 | ノーマルマップの RGB を法線として保存する |
| ワールド空間 | シーン全体の原点基準 | ライト、カメラ、最終的な法線を同じ空間で計算する |

ライティングで内積を取るベクトルは、必ず同じ座標空間にそろえます。この最終シェーダーでは、法線・ライト方向・視線方向をすべてワールド空間にそろえます。

### 6.4 Unity での画像読み込み設定

ノーマルマップ画像を Project ウィンドウで選択し、Inspector の Import Settings で次を設定します。

1. **Texture Type** を `Normal map` にする
2. **sRGB (Color Texture)** はオフであることを確認する
3. 必要なら **Create From Grayscale** を使い、高さ画像から法線マップを生成する
4. Apply を押す

`[Normal]` 属性を付けた `_NormalMap` プロパティには、Normal Map としてインポートされた画像を割り当てます。

---

## 7. 最終実装（PhongNormal04.shader）

`Assets/ShaderProgramming/Chapter4/PhongNormal04.shader` は次をすべて処理します。

- `_BaseMap` と `_BaseColor` からアルベドを作る
- `_NormalMap` からタンジェント空間法線を復元する
- TBN 行列でワールド空間法線へ変換する
- Main Light と Additional Lights の両方に同じ Phong 計算を適用する
- Point Light の距離減衰、Spot Light の距離・角度減衰を URP の `Light.distanceAttenuation` として使う

```shader
Shader "ShaderProgramming/Chapter4/PhongNormal04"
{
	Properties
	{
		_BaseMap ("Albedo Map", 2D) = "white" {}
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		[Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
		_NormalScale ("Normal Scale", Range(0,2)) = 1
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

			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURE2D(_NormalMap);
			SAMPLER(sampler_NormalMap);

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _SpecColor;
				half4 _Ambient;
				float4 _BaseMap_ST;
				float4 _NormalMap_ST;
				half _NormalScale;
				half _Shininess;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS   : NORMAL;
				float4 tangentOS  : TANGENT;
				float2 uv         : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS  : TEXCOORD0;
				half3 normalWS     : TEXCOORD1;
				half4 tangentWS    : TEXCOORD2;
				float2 baseUv      : TEXCOORD3;
				float2 normalUv    : TEXCOORD4;
			};

			half3 ShadePhong(Light light, half3 albedo, half3 N, half3 V)
			{
				half3 L = normalize(light.direction);
				half3 H = normalize(L + V);
				half NdotL = saturate(dot(N, L));
				half NdotH = saturate(dot(N, H));
				half3 radiance = light.color * light.distanceAttenuation;
				half3 diffuse = albedo * radiance * NdotL;
				half3 specular = _SpecColor.rgb * radiance * pow(NdotH, _Shininess) * step(0.0h, NdotL);
				return diffuse + specular;
			}

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				OUT.tangentWS = half4(TransformObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w * GetOddNegativeScale());
				OUT.baseUv = TRANSFORM_TEX(IN.uv, _BaseMap);
				OUT.normalUv = TRANSFORM_TEX(IN.uv, _NormalMap);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half4 albedoSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.baseUv) * _BaseColor;
				half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.normalUv), _NormalScale);

				half3 N = normalize(IN.normalWS);
				half3 T = normalize(IN.tangentWS.xyz);
				half3 B = cross(N, T) * IN.tangentWS.w;
				half3 normalWS = normalize(TransformTangentToWorld(normalTS, half3x3(T, B, N)));
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);

				half3 color = _Ambient.rgb * albedoSample.rgb;
				color += ShadePhong(GetMainLight(), albedoSample.rgb, normalWS, V);

				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					Light light = GetAdditionalLight(lightIndex, IN.positionWS);
					color += ShadePhong(light, albedoSample.rgb, normalWS, V);
				LIGHT_LOOP_END
				#endif

				return half4(color, albedoSample.a);
			}
			ENDHLSL
		}
	}
}
```

---

## 8. 実習手順

1. `Assets/ShaderProgramming/Chapter4/` に次のファイルがあることを確認する
   - `UvCoordinateVisualizer.cs`
   - `Albedo04.shader`
   - `PhongNormal04.shader`
2. Sphere または Cube に `UvCoordinateVisualizer` を追加し、Scene ビューで UV ラベルを確認する
3. PNG などのカラー画像を追加し、Texture Type を `Default`、sRGB をオンにしてアルベドとして使う
4. `Albedo04.shader` のマテリアルを作り、`Albedo Map` へ画像を割り当てる
5. ノーマルマップ画像を追加し、Texture Type を `Normal map` にして Apply する
6. `PhongNormal04.shader` のマテリアルを作り、Albedo Map と Normal Map の両方を割り当てる
7. Directional Light、Point Light、Spot Light を配置して、ライト位置・向き・Normal Scale を変えて観察する
8. Point / Spot が反映されない場合、URP Asset の **Additional Lights** を Per Pixel に設定する

---

## 9. 観察ポイントとトラブルシューティング

| 確認項目 | 期待する結果 |
| :--- | :--- |
| Albedo Map の Tiling | 数値を増やすと画像が繰り返される |
| Base Color | テクスチャ全体が指定色で色付く |
| Normal Scale | 0 で平坦、値を上げると凹凸の明暗が強くなる |
| Point Light | ライトへ近い部分が明るく、Range 外で暗くなる |
| Spot Light | 円錐の内部だけが照らされる |

| 症状 | 原因・対処 |
| :--- | :--- |
| テクスチャが表示されない | `_BaseMap` に画像を割り当てたか、UV を持つメッシュか確認 |
| 色が暗すぎる／不自然 | アルベド画像の sRGB 設定を確認 |
| 凹凸が逆に見える | ノーマルマップを Texture Type `Normal map` として再インポート。作成ツールの Y（緑）反転設定も確認 |
| ノーマルマップが効かない | メッシュに Tangent があるか、`_NormalScale` が 0 でないか確認 |
| Point / Spot が効かない | URP Asset の Additional Lights を Per Pixel に設定 |

---

## 10. まとめ

- UV は 3D メッシュと 2D テクスチャを対応付ける頂点属性
- `TEXTURE2D`、`SAMPLER`、`SAMPLE_TEXTURE2D` でテクスチャデータを読む
- アルベドは sRGB をオン、ノーマルやマスクなどの数値データは sRGB をオフにする
- ノーマルマップはタンジェント空間の法線を RGB に保存し、TBN 行列でワールド空間へ変換する
- `ShadePhong` を共通化すれば、Main Light と Additional Lights の両方へ同じアルベド・ノーマルマップ対応ライティングを適用できる
