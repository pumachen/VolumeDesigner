#version 330

#include "../common/common.glsl"
#include "../common/uvtile.glsl"

in vec3 iFS_PointWS;
in vec4 iFS_PointCS;

out vec4 ocolor0;

uniform mat4 worldMatrix;
uniform mat4 viewInverseMatrix;
uniform mat4 projectionMatrix;
uniform sampler2D volumeMap;
uniform int VolumeRes;
uniform float Tiling;
uniform vec3 Offset;
uniform int MarchingSteps;
uniform int ShadowSteps;
uniform float Density;
uniform float ShadowDensity;

uniform vec3 ambientColor;
uniform vec3 Lamp0Pos;
uniform vec3 Lamp0Color;
uniform float Lamp0Intensity;

struct Ray
{
	vec3 origin;
	vec3 dir;
};

Ray RayGen(vec2 screenUV)
{
	Ray ray;
	ray.origin = viewInverseMatrix[3].xyz;
	vec4 farVS = inverse(projectionMatrix) * vec4(screenUV, 1.0f, 1.0f);
	farVS /= farVS.w;
	ray.dir = normalize((viewInverseMatrix * vec4(farVS.xyz, 1)).xyz - ray.origin);
	return ray;
}

vec2 CubeIntersect(vec3 ro, vec3 rd)
{
	vec3 boxSize = vec3(50);
	vec3 m = 1.0 / rd;
	vec3 n = m * ro;
	vec3 k = abs(m) * boxSize;
	vec3 t1 = -n-k;
	vec3 t2 = -n+k;
	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);
	return vec2(tN, tF);
}

vec3 CubeIntersectNear(Ray ray)
{
	mat4 inverseWorldMatrix = inverse(worldMatrix);
	vec3 ro = (inverseWorldMatrix * vec4(ray.origin, 1)).xyz - vec3(0, 50, 0);
	vec3 rd = normalize((inverseWorldMatrix * vec4(ray.dir, 0)).xyz);
	vec2 t = CubeIntersect(ro, rd);
	vec3 p = ro + rd * min(t.x, t.y) + vec3(0, 50, 0);
	return (worldMatrix * vec4(p, 1)).xyz;
}

vec3 CubeIntersectFar(Ray ray)
{
	mat4 inverseWorldMatrix = inverse(worldMatrix);
	vec3 ro = (inverseWorldMatrix * vec4(ray.origin, 1)).xyz - vec3(0, 50, 0);
	vec3 rd = normalize((inverseWorldMatrix * vec4(ray.dir, 0)).xyz);
	vec2 t = CubeIntersect(ro, rd);
	vec3 p = ro + rd * max(t.x, t.y) + vec3(0, 50, 0);
	return (worldMatrix * vec4(p, 1)).xyz;
}

vec2 EncodeUVW(vec3 uvw)
{
	uvw = fract((uvw * VolumeRes + 0.5) / VolumeRes);
	int countX = int(pow(2, int(floor(log2(float(VolumeRes)) / 2.0))));
	int countY = VolumeRes / countX;
	vec2 uv = uvw.xy;
	vec2 cellSize = 1.0 / vec2(countX, countY);
	uv *= cellSize;
	int idx = int(uvw.z * VolumeRes);
	int x = idx % countX;
	int y = idx / countX;
	y = countY - y - 1;
	uv += cellSize * vec2(x,y);
	uv = fract(uv);
	return uv;
}

vec4 SampleVolume(vec3 uvw)
{
	uvw = uvw * Tiling * 0.01 + vec3(0.5, 0, 0.5) + Offset;
	return texture(volumeMap, EncodeUVW(uvw));
}

float SampleDensity(vec3 uvw)
{
	return SampleVolume(uvw).r;
}

void main()
{
	vec2 screenUV = iFS_PointCS.xy / iFS_PointCS.w;
	Ray ray = RayGen(screenUV);
	vec3 back = iFS_PointWS;
	vec3 front = CubeIntersectNear(ray);
	
	float dt = 1.0 / MarchingSteps;
	float jitter = 0;
	float transmittance = 1;
	vec3 lightEnergy = vec3(0);

	for(int i = 0; i < MarchingSteps; ++i)
	{
		float t = clamp((i + jitter) * dt, 0, 1);
		vec3 sp = mix(front, back, t);
		float density = SampleDensity(sp) * Density * dt * distance(front, back) * 0.01;
		if(density > 0)
		{
			vec3 p = sp;
			float shadowDist = 0;
			//vec3 lightDir = normalize(Lamp0Pos - p);
			vec3 lightDir = normalize(Lamp0Pos);
			vec3 shadowStart = p;
			Ray shadowRay;
			shadowRay.origin = shadowStart;
			shadowRay.dir = lightDir;
			vec3 shadowEnd = CubeIntersectFar(shadowRay);
			for(int s = 0; s < ShadowSteps; ++s)
			{
				p = mix(shadowStart, shadowEnd, float(s) / ShadowSteps);
				shadowDist += SampleDensity(p) * distance(shadowStart, shadowEnd) / ShadowSteps;
			}
			vec3 absorbedLight = exp(-shadowDist * ShadowDensity) * vec3(density);
			lightEnergy += absorbedLight * transmittance;
			transmittance *= 1 - density;
		}
	}
	lightEnergy += ambientColor;
	ocolor0 = vec4(lightEnergy, 1 - transmittance);
}
