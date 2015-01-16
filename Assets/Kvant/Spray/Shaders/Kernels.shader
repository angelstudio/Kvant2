﻿Shader "Hidden/Kvant/Spray/Kernels"
{
    Properties
    {
        _MainTex        ("-", 2D)       = ""{}

        _EmitterPos     ("-", Vector)   = (100, 100, 100, 0)
        _EmitterSize    ("-", Vector)   = (100, 100, 100, 0)

        _Life           ("-", Float)    = 3
        _Randomness     ("-", Float)    = 0.5

        _Velocity       ("-", Vector)   = (0, 0, -10, 0)
        _Noise          ("-", Vector)   = (0.5, 5, 0, 0)
    }

    CGINCLUDE

    #include "UnityCG.cginc"
    #include "ClassicNoise3D.cginc"

    #define PI2 6.28318530718

    sampler2D _MainTex;

    float3 _EmitterPos;
    float3 _EmitterSize;

    float _Life;
    float _Randomness;

    float3 _Velocity;
    float2 _Noise;  // Density, Velocity

    // PRNG function.
    float nrand(float2 uv)
    {
        return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    }

    // Uniform random unit quaternion.
    // http://tog.acm.org/resources/GraphicsGems/gemsiii/urot.c
    float4 random_quaternion(float2 uv)
    {
        float r = nrand(uv);
        float r1 = sqrt(1.0 - r);
        float r2 = sqrt(r);

        float t1 = PI2 * nrand(uv + float2(1, 0));
        float t2 = PI2 * nrand(uv + float2(0, 1));

        return float4(sin(t1) * r1, cos(t1) * r1, sin(t2) * r2, cos(t2) * r2);
    }

    // Get a new particle.
    float4 new_particle_position(float2 uv)
    {
        uv += float2(_Time.x, 31.3824);

        float r1 = nrand(uv);
        float r2 = nrand(uv + float2(1, 0));
        float r3 = nrand(uv + float2(0, 1));
        float r4 = nrand(uv + float2(1, 1));

        float3 p = float3(r1, r2, r3) - float3(0.5);
        p = p * _EmitterSize + _EmitterPos;

        float l = _Life * (1.0 - r4 * _Randomness);

        return float4(p, l);
    }

    float4 new_particle_rotation(float2 uv)
    {
        return random_quaternion(uv + float2(_Time.x, 84.737));
    }

    // Position dependant noise function.
    float3 position_noise(float3 p, float salt)
    {
        p *= _Noise.x;
        salt *= 43.329;
        float x = cnoise(p + float3(10,  0, salt));
        float y = cnoise(p + float3( 0, 10, salt));
        float z = cnoise(p + float3(10, 10, salt)); 
        return float3(x, y, z);
    }

    // Kernel 0 - initialize position.
    float4 frag_init_position(v2f_img i) : SV_Target 
    {
        return new_particle_position(i.uv);
    }

    // Kernel 1 - initialize rotation.
    float4 frag_init_rotation(v2f_img i) : SV_Target 
    {
        return new_particle_rotation(i.uv);
    }

    // Kernel 2 - update position.
    float4 frag_update_position(v2f_img i) : SV_Target 
    {
        float d = unity_DeltaTime.x;
        float r = 1.0 - nrand(i.uv) * _Randomness;
        float4 p = tex2D(_MainTex, i.uv);
        if (p.w > 0)
        {
            p.xyz += (_Velocity * r + position_noise(p.xyz * 0.3 + _Time.y, 0) * 8) * d;
            p.w -= d;
            return p;
        }
        else
        {
            return new_particle_position(i.uv);
        }
    }

        float4 qmul(float4 q1, float4 q2)
        {
            return float4(
                q1.w * q2.xyz + q2.w * q1.xyz + cross(q1.xyz, q2.xyz),
                q1.w * q2.w - dot(q1.xyz, q2.xyz)
            );
        }

    // Kernel 3 - update rotation.
    float4 frag_update_rotation(v2f_img i) : SV_Target 
    {
        float d = unity_DeltaTime.x;
        float4 r = tex2D(_MainTex, i.uv);

        float uv = i.uv + float2(0, 31.3824);

        float x1 = nrand(uv);
        float x2 = nrand(uv + float2(1, 0));
        float x3 = nrand(uv + float2(0, 1));

        float3 v = normalize(float3(x1, x2, x3) - float3(0.5));

        r = qmul(r, float4(v * sin(1.8 * d), cos(1.8 * d)));

        return r;
    }

    ENDCG

    SubShader
    {
        Pass
        {
            Fog { Mode off }    
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_init_position
            ENDCG
        }
        Pass
        {
            Fog { Mode off }    
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_init_rotation
            ENDCG
        }
        Pass
        {
            Fog { Mode off }    
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_update_position
            ENDCG
        }
        Pass
        {
            Fog { Mode off }    
            CGPROGRAM
            #pragma target 3.0
            #pragma glsl
            #pragma vertex vert_img
            #pragma fragment frag_update_rotation
            ENDCG
        }
    }
}
