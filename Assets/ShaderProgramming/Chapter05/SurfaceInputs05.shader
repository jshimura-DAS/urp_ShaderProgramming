Shader "ShaderProgramming/Chapter5/SurfaceInputs05"
{
	Properties
	{
		_BaseMap ("Albedo Map", 2D) = "white" {}
		_BaseColor ("Base Color", Color) = (1,1,1,1)
		_Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5
		[Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
		_BumpScale ("Normal Scale", Range(0,2)) = 1
		_MetallicGlossMap ("Metallic (R) Smoothness (A)", 2D) = "white" {}
		_Metallic ("Metallic", Range(0,1)) = 0
		_Smoothness ("Smoothness", Range(0,1)) = 0.5
		_OcclusionMap ("Occlusion (G)", 2D) = "white" {}
		_OcclusionStrength ("Occlusion Strength", Range(0,1)) = 1
		_EmissionMap ("Emission Map", 2D) = "black" {}
		_EmissionColor ("Emission Color", Color) = (0,0,0,1)
		_ParallaxMap ("Height Map (R)", 2D) = "gray" {}
		_Parallax ("Height Scale", Range(0,0.1)) = 0.005
		_DetailMask ("Detail Mask (A)", 2D) = "white" {}
		_DetailAlbedoMap ("Detail Albedo Map", 2D) = "gray" {}
		_DetailAlbedoMapScale ("Detail Albedo Scale", Range(0,2)) = 1
		[Normal] _DetailNormalMap ("Detail Normal Map", 2D) = "bump" {}
		_DetailNormalMapScale ("Detail Normal Scale", Range(0,2)) = 1
		_ClearCoatMap ("Clear Coat (R) Smoothness (G)", 2D) = "white" {}
		_ClearCoatMask ("Clear Coat Mask", Range(0,1)) = 0
		_ClearCoatSmoothness ("Clear Coat Smoothness", Range(0,1)) = 1
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

			TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
			TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
			TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
			TEXTURE2D(_OcclusionMap); SAMPLER(sampler_OcclusionMap);
			TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
			TEXTURE2D(_ParallaxMap); SAMPLER(sampler_ParallaxMap);
			TEXTURE2D(_DetailMask); SAMPLER(sampler_DetailMask);
			TEXTURE2D(_DetailAlbedoMap); SAMPLER(sampler_DetailAlbedoMap);
			TEXTURE2D(_DetailNormalMap); SAMPLER(sampler_DetailNormalMap);
			TEXTURE2D(_ClearCoatMap); SAMPLER(sampler_ClearCoatMap);

			CBUFFER_START(UnityPerMaterial)
				float4 _BaseMap_ST;
				float4 _DetailAlbedoMap_ST;
				half4 _BaseColor;
				half4 _EmissionColor;
				half4 _Ambient;
				half _Cutoff;
				half _BumpScale;
				half _Metallic;
				half _Smoothness;
				half _OcclusionStrength;
				half _Parallax;
				half _DetailAlbedoMapScale;
				half _DetailNormalMapScale;
				half _ClearCoatMask;
				half _ClearCoatSmoothness;
			CBUFFER_END

			struct Attributes
			{
				float4 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				float2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionHCS : SV_POSITION;
				float3 positionWS : TEXCOORD0;
				half3 normalWS : TEXCOORD1;
				half4 tangentWS : TEXCOORD2;
				float2 uv : TEXCOORD3;
			};

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

			Varyings vert(Attributes IN)
			{
				Varyings OUT;
				OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
				OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
				OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
				OUT.tangentWS = half4(TransformObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w * GetOddNegativeScale());
				OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
				return OUT;
			}

			SurfaceInputs InitializeSurfaceInputs(float2 baseUv, half3 viewDirTS)
			{
				SurfaceInputs surface;
				float2 uv = baseUv;
				half height = SAMPLE_TEXTURE2D(_ParallaxMap, sampler_ParallaxMap, uv).r;
				uv += viewDirTS.xy / max(viewDirTS.z, 0.1h) * ((height - 0.5h) * _Parallax);

				half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv) * _BaseColor;
				surface.alpha = albedoAlpha.a;
				clip(surface.alpha - _Cutoff);
				surface.albedo = albedoAlpha.rgb;
				half detailMask = SAMPLE_TEXTURE2D(_DetailMask, sampler_DetailMask, uv).a;
				float2 detailUv = uv * _DetailAlbedoMap_ST.xy + _DetailAlbedoMap_ST.zw;
				half3 detailAlbedo = SAMPLE_TEXTURE2D(_DetailAlbedoMap, sampler_DetailAlbedoMap, detailUv).rgb;
				surface.albedo *= lerp(1.0h.xxx, 2.0h * detailAlbedo * _DetailAlbedoMapScale - _DetailAlbedoMapScale + 1.0h, detailMask);

				half4 metallicGloss = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
				surface.metallic = metallicGloss.r * _Metallic;
				surface.smoothness = metallicGloss.a * _Smoothness;
				surface.normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uv), _BumpScale);
				half3 detailNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, detailUv), _DetailNormalMapScale);
				surface.normalTS = normalize(lerp(surface.normalTS, BlendNormalRNM(surface.normalTS, detailNormalTS), detailMask));
				surface.occlusion = lerp(1.0h, SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g, _OcclusionStrength);
				surface.emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;
				half2 clearCoat = SAMPLE_TEXTURE2D(_ClearCoatMap, sampler_ClearCoatMap, uv).rg;
				surface.clearCoatMask = clearCoat.r * _ClearCoatMask;
				surface.clearCoatSmoothness = clearCoat.g * _ClearCoatSmoothness;
				return surface;
			}

			half3 ShadePhong(Light light, SurfaceInputs surface, half3 N, half3 V)
			{
				half3 L = normalize(light.direction);
				half3 H = normalize(L + V);
				half NdotL = saturate(dot(N, L));
				half3 radiance = light.color * light.distanceAttenuation;
				half3 specularColor = lerp(0.04h.xxx, surface.albedo, surface.metallic);
				half shininess = lerp(8.0h, 128.0h, surface.smoothness);
				half3 diffuse = surface.albedo * (1.0h - surface.metallic) * radiance * NdotL;
				half3 specular = specularColor * radiance * pow(saturate(dot(N, H)), shininess) * step(0.0h, NdotL);
				half coatShininess = lerp(32.0h, 256.0h, surface.clearCoatSmoothness);
				half3 clearCoat = radiance * pow(saturate(dot(N, H)), coatShininess) * surface.clearCoatMask * step(0.0h, NdotL);
				return diffuse + specular + clearCoat;
			}

			half4 frag(Varyings IN) : SV_Target
			{
				half3 N = normalize(IN.normalWS);
				half3 T = normalize(IN.tangentWS.xyz);
				half3 B = cross(N, T) * IN.tangentWS.w;
				half3 V = normalize(GetCameraPositionWS() - IN.positionWS);
				half3 VTS = half3(dot(V, T), dot(V, B), dot(V, N));
				SurfaceInputs surface = InitializeSurfaceInputs(IN.uv, VTS);
				N = normalize(TransformTangentToWorld(surface.normalTS, half3x3(T, B, N)));

				half3 color = _Ambient.rgb * surface.albedo * surface.occlusion;
				color += ShadePhong(GetMainLight(), surface, N, V) * surface.occlusion;

				#if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
				InputData inputData = (InputData)0;
				inputData.positionWS = IN.positionWS;
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);

				uint count = GetAdditionalLightsCount();
				LIGHT_LOOP_BEGIN(count)
					color += ShadePhong(GetAdditionalLight(lightIndex, IN.positionWS), surface, N, V) * surface.occlusion;
				LIGHT_LOOP_END
				#endif

				return half4(color + surface.emission, surface.alpha);
			}
			ENDHLSL
		}
	}
}
