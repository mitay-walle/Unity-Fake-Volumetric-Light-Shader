Shader "Particles/Additive Facing Fade" {
Properties {
    _TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
    _MainTex ("Particle Texture", 2D) = "white" {}
    _Fade ("Fade Factor", Range(0.01,100.0)) = 8.0
    _InvFade ("Soft Particles Factor", Range(0.01,3.0)) = 1.0
	[Toggle(DEBUG)] _Debug ("Debug", Float) = 0.0
}

Category {
    Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
    Blend SrcAlpha One
    ColorMask RGB
    Cull Back Lighting Off ZWrite Off

    SubShader {
        Pass {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_particles
            #pragma multi_compile_fog
            #pragma shader_feature DEBUG
			
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            fixed4 _TintColor;

            struct appdata_t {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                
#ifdef SOFTPARTICLES_ON
                float4 projPos : TEXCOORD2;
#endif
				
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _MainTex_ST;
			fixed _Debug;
            float _Fade;

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				
                o.vertex = UnityObjectToClipPos(v.vertex);

                           
                float3 worldNorm = UnityObjectToWorldNormal(v.normal);
                float3 viewDir = mul((float3x3)unity_CameraToWorld, float3(0,0,1));
           
                o.color = v.color;
				#ifdef DEBUG
				o.color.rgb = dot(worldNorm,-viewDir);//viewDir * 0.5 + 0.5;//worldNorm * 0.5 + 0.5;
				#endif
				o.color.a *= pow(dot(worldNorm,-viewDir),_Fade) * _Fade;
				
								
#ifdef SOFTPARTICLES_ON
                o.projPos = ComputeScreenPos (o.vertex);
                COMPUTE_EYEDEPTH(o.projPos.z);
#endif
				
                o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float _InvFade;

            fixed4 frag (v2f i) : SV_Target
            {
#ifdef SOFTPARTICLES_ON
                float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
                float partZ = i.projPos.z;
                float fade = saturate (_InvFade * (sceneZ-partZ));
                i.color.a *= fade;
#endif

                fixed4 col = 2.0f * i.color * _TintColor * tex2D(_MainTex, i.texcoord);
                col.a = saturate(col.a); // alpha should not have double-brightness applied to it, but we can't fix that legacy behavior without breaking everyone's effects, so instead clamp the output to get sensible HDR behavior (case 967476)

                UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0,0,0,0)); // fog towards black due to our blend mode
				#ifdef DEBUG
				col = i.color;
				#endif
                return col;
            }
            ENDCG
        }
    }
}
}
