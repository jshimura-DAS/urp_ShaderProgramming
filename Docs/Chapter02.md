# Chapter2：拡散反射の基礎（URP / Directional Light 単体）

この章は `index.md` の **Chapter 02**（ライティングの基礎）に対応します。鏡面反射は Chapter3 で扱います。  
前提として、**シーンには Directional Light を1つだけ**置いているものとします。

---

## 1. この章でやること

1. URPでの**ライト情報の取得方法**を理解する  
2. 法線（Normal）を可視化して、**頂点法線の見方**を掴む  
3. **フラットシェーディング**を実装する  
4. **グーロー（Gouraud）シェーディング**を拡散反射のみで実装する  
5. **フォン（Phong）シェーディング**を拡散反射のみで実装し、補間方法の違いを比較する

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

### 3.4 UnityがMeshに持つ法線情報の確認

UnityではMeshに頂点法線が含まれています。これは、各頂点ごとに法線ベクトルが定義されており、スムーズなシェーディングを行うために使用されます。そのため、基本的に法線は補完される仕組みがパイプラインに出来上がっており、法線情報を受け渡す方法にすると、グーローシェーディングが簡単に実装できます。
CPU側でMeshでnormalを確認するには、以下のようなスクリプトを使うと便利です。
```Csharp:Meshdumper.cs
// Meshの法線情報を確認する例
using UnityEngine;

public class MeshDumper : MonoBehaviour
{
    // ノーマル表示設定
    public bool showVertexNormals = true;
    public float normalLength = 0.1f;
    public Color normalColor = Color.blue;
    public float normalLineWidth = 0.01f;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        Mesh mesh = null;
        var mf = GetComponent<MeshFilter>();
        if (mf != null) mesh = mf.sharedMesh;
        else
        {
            var smr = GetComponent<SkinnedMeshRenderer>();
            if (smr != null) mesh = smr.sharedMesh;
        }

        if (mesh == null)
        {
            Debug.LogWarning("MeshDumper: No mesh found on this GameObject.");
            return;
        }

        var verts = mesh.vertices;
        Debug.Log($"Mesh '{mesh.name}' vertex count: {verts.Length}");
        for (int i = 0; i < verts.Length; i++)
        {
            Vector3 worldPos = transform.TransformPoint(verts[i]);
            Debug.Log($"[{i}] Local: {verts[i]}  World: {worldPos}");
        }

        // 頂点ごとのノーマルをLineRendererで表示
        if (showVertexNormals)
        {
            var normals = mesh.normals;
            if (normals == null || normals.Length != verts.Length)
            {
                Debug.LogWarning("MeshDumper: Mesh does not contain valid normals to display.");
                return;
            }

            // ノーマル表示用の親オブジェクト
            var parent = new GameObject($"{name}_VertexNormals");
            parent.transform.SetParent(transform, false);

            // 共有マテリアルを1つ作成して使い回す
            var lineMat = new Material(Shader.Find("Sprites/Default"));

            for (int i = 0; i < verts.Length; i++)
            {
                Vector3 worldPos = transform.TransformPoint(verts[i]);
                Vector3 worldNormal = transform.TransformDirection(normals[i]).normalized;

                var go = new GameObject($"Normal_{i}");
                go.transform.SetParent(parent.transform, false);
                var lr = go.AddComponent<LineRenderer>();
                lr.useWorldSpace = true;
                lr.positionCount = 2;
                lr.SetPosition(0, worldPos);
                lr.SetPosition(1, worldPos + worldNormal * normalLength);
                lr.startWidth = lr.endWidth = normalLineWidth;
                lr.material = lineMat;
                lr.startColor = lr.endColor = normalColor;
                // 不要な余分な機能をオフ
                lr.loop = false;
            }
        }
    }


}
```

---

## 4. フラットシェーディング実装

ここでは **フラットシェーディングだけ** を行う単体シェーダーとして実装します。  
頂点法線を使わず、ピクセル位置の微分から面法線を再構築します。Unityで一般的に扱うMeshには、頂点ごとの法線情報が含まれています。通常は、頂点シェーダーからフラグメントシェーダーへ渡された法線が、ラスタライズ時にピクセルごとに補間されます。
この実装では、補間された頂点法線を使用すると平面にならないため、利用しません。その代わりに、HLSLの画面空間微分命令である ddx / ddy を用いて、画面上でのワールド座標の変化量を取得します。2つの変化量の外積を取ることで、現在描画している三角形の面法線を再構築できます。

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

公式ドキュメントリンク一覧
Direct3D HLSL リファレンス (Microsoft Learn):
ddx 関数 ([HLSL Reference](https://learn.microsoft.com/ja-jp/windows/win32/direct3dhlsl/dx-graphics-hlsl-ddx))
ddy 関数 ([HLSL Reference](https://learn.microsoft.com/ja-jp/windows/win32/direct3dhlsl/dx-graphics-hlsl-ddy))
fwidth 関数 ([HLSL Reference](https://learn.microsoft.com/ja-jp/windows/win32/direct3dhlsl/dx-graphics-hlsl-fwidth))

`dpdx` と `dpdy` は、その三角形面上の接ベクトルです。

![法線可視化の実行例](./watermarked_img_15521748016248688758.jpg)

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

				half3 L = normalize(mainLight.direction);
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

## 5. グーロー / フォンの違い（拡散反射のみ）

この章では **拡散反射（Diffuse）だけ** を扱い、グーローとフォンの違いを「どこでライティングを計算するか」「何を補間するか」に絞って比較します。鏡面反射（Specular）とカメラ位置の扱いは Chapter3 で学びます。

### 5.1 Unityの頂点法線と補間

Unityの一般的なMeshには、各頂点の向きを表す法線が頂点属性として保存されています。自作シェーダーでは、`Attributes` の `normalOS : NORMAL` からこの頂点法線を受け取ります。

```hlsl
struct Attributes
{
	float3 normalOS : NORMAL;
};
```

頂点シェーダーから `Varyings` の `TEXCOORD` へ代入した値は、ラスタライザが三角形の内部でピクセルごとに自動補間します。

```hlsl
// vert: オブジェクト空間の頂点法線をワールド空間へ変換して渡す
OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);

// frag: 補間済みの法線は長さが変わるため normalize してから使う
half3 N = normalize(IN.normalWS);
```

**補間処理そのものは、グーローでもフォンでも自分で実装する必要はありません。** 違いは「補間する対象」です。

| 方式 | ライティング計算の場所 | 補間される値 | 特徴 |
| :--- | :--- | :--- | :--- |
| **グーロー（Gouraud）** | 頂点シェーダー | 計算済みの明るさ（色） | 計算回数が頂点数分で軽い。頂点が少ないと明暗の変化が粗くなる |
| **フォン（Phong）** | フラグメントシェーダー | 法線 | ピクセルごとに計算するため、明暗の変化が滑らか |

### 5.2 拡散反射の式（ランバート）

どちらの方式も、同じ式を使います。

```hlsl
half NdotL = saturate(dot(N, L));
half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
```

- `N` : 法線（表面の向き）
- `L` : 表面からライトへ向かう単位ベクトル。URPの `Light.direction` がそのまま使える（符号を反転しない）
- `saturate` : 裏側（`N·L < 0`）を 0 に切り捨てる

---

## 6. グーローシェーディング実装（Gouraud01.shader）

### 6.1 特徴

`vert` 関数で拡散反射を計算し、結果の色 `diffuse` を `Varyings` に格納します。ラスタライザが頂点間で色を補間し、`frag` 関数は補間済みの色をそのまま出力します。

### 6.2 実装

```shader
Shader "ShaderProgramming/Chapter2/Gouraud01"
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
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				// 頂点ごとに計算した拡散反射色をフラグメントへ補間して渡す
				half3 diffuse      : TEXCOORD0;
			};

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(positionWS);

				// 頂点ごとに拡散反射を計算する
				half3 N = normalize(TransformObjectToWorldNormal(IN.normalOS));
				Light mainLight = GetMainLight();
				half3 L = normalize(mainLight.direction);
				half NdotL = saturate(dot(N, L));
				OUT.diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				return half4(IN.diffuse, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

> このコードは `Assets/ShaderProgramming/Chapter2/Gouraud01.shader` として保存して使います。

---

## 7. フォンシェーディング実装（Phong01.shader）

### 7.1 特徴

`vert` 関数では法線をワールド空間へ変換して渡すだけです。ラスタライザが法線を補間し、`frag` 関数で **ピクセルごとに** 拡散反射を計算します。

### 7.2 実装

```shader
Shader "ShaderProgramming/Chapter2/Phong01"
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
				float3 normalOS   : NORMAL;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				half3 normalWS     : TEXCOORD0;
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
				Light mainLight = GetMainLight();
				// 補間された法線は長さが1ではないため正規化する
				half3 N = normalize(IN.normalWS);
				half3 L = normalize(mainLight.direction);
				half NdotL = saturate(dot(N, L));
				half3 diffuse = _BaseColor.rgb * mainLight.color * NdotL;
				return half4(diffuse, 1.0h);
			}
			ENDHLSL
		}
	}
}
```

> このコードは `Assets/ShaderProgramming/Chapter2/Phong01.shader` として保存して使います。

> 鏡面反射（ハイライト）を加えたフォンシェーディングは、カメラ位置が必要になるため **Chapter3 の `Phong03.shader`** で扱います。

---

## 8. 実習手順

1. `Assets/ShaderProgramming/Chapter2/` に、次のファイルがあることを確認する
   - `NormalVisualizer.shader`
   - `Flat.shader`
   - `Gouraud01.shader`
   - `Phong01.shader`
2. 各シェーダー用のマテリアルを1つずつ作成する
3. 比較用に同じメッシュ（Sphere など）を4つ用意し、それぞれのマテリアルを割り当てる
4. シーンには Directional Light を1つだけ置く
5. Gouraud01 と Phong01 のマテリアルで、`_BaseColor` を同じ値に設定する
6. Directional Light の向きを変え、各シェーダーの描画結果を比較する

---

## 9. 観察ポイント

- Flatでは面ごとの段差が見えるか
- Gouraudで、明暗の境界が頂点の並びに引きずられて粗く見えるか（頂点数の少ないメッシュで顕著）
- Phongで、明暗の境界が滑らかに動くか
- 法線デバッグ表示でモデルの法線方向が想定通りか
- ライトを真下に向けたとき、球の下半分が暗くなるか（`N·L < 0` で 0 になる）

---

## 10. まとめ

- URPでは `GetMainLight()` でメインライト情報を取得できる
- 法線理解には「色で可視化」が最短
- `Light.direction` は「表面からライトへ向かう方向」なので、そのまま `L` として使う
- Flat / Gouraud / Phong の差は「どこで法線とライティングを計算・補間するか」の差
- 鏡面反射とカメラ位置の扱いは Chapter3 で学ぶ
