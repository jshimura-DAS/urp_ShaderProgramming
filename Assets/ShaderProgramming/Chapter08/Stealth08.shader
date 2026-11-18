Shader "ShaderProgramming/Chapter8/Stealth08"
{
	Properties
	{
		_BaseColor ("Base Color", Color) = (0.2,0.3,0.4,1)
		_RimColor ("Rim Color", Color) = (0.6,0.9,1,1)
		_RimPower ("Rim Power", Range(0.5,8)) = 3
		_RimVisibility ("Rim Visibility", Range(0,1)) = 0.8
		_Visibility ("Visibility", Range(0,1)) = 1
	}

	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

		Pass
		{
			Tags { "LightMode"="UniversalForward" }
			Cull Back

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			CBUFFER_START(UnityPerMaterial)
				half4 _BaseColor;
				half4 _RimColor;
				half _RimPower;
				half _RimVisibility;
				half _Visibility;
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
				float3 normalWS    : TEXCOORD1;
				float4 screenPos   : TEXCOORD2;
			};

			static const float kBayer4x4[16] =
			{
				 0,  8,  2, 10,
				12,  4, 14,  6,
				 3, 11,  1,  9,
				15,  7, 13,  5
			};

			float DitherThreshold(float4 screenPos)
			{
				float2 pixel = screenPos.xy / screenPos.w * _ScreenParams.xy;
				uint2 p = uint2(pixel) & 3u;
				return (kBayer4x4[p.y * 4 + p.x] + 0.5) / 16.0;
			}

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
				return OUT;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half3 N = normalize(IN.normalWS);
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);

				// 縁ほど強くなるフレネル項
				half NdotV = saturate(dot(N, V));
				half fresnel = pow(1.0h - NdotV, _RimPower);

				// 表示量 = 本体の可視度 + 縁の可視度（0〜1 に丸める）
				half visibility = saturate(_Visibility + fresnel * _RimVisibility);

				// 表示量に応じて、ディザで部分的に描画する
				clip(visibility - DitherThreshold(IN.screenPos));

				// 本体は暗い色、縁は発光色として描く
				Light mainLight = GetMainLight();
				half NdotL = saturate(dot(N, mainLight.direction));
				half3 body = _BaseColor.rgb * (0.2h + 0.8h * NdotL * mainLight.color);
				half3 color = lerp(body, _RimColor.rgb, fresnel);

				return half4(color, 1.0h);
			}
			ENDHLSL
		}
	}
}