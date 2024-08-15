#ifndef QC_INTSCT
#define QC_INTSCT

#include "Assets/Qc_Rendering/Shaders/PrimitivesScene_Sampler.cginc"
#include "Assets/Qc_Rendering/Shaders/inc/IntersectOperations.cginc"
#include "Assets/Qc_Rendering/Shaders/inc/RayMathHelpers.cginc"

#define MATCH_RAY_TRACED_SUN_COEFFICIENT 0.5
#define MATCH_RAY_TRACED_SKY_COEFFICIENT 0.5
#define MATCH_RAY_TRACED_SUN_LIGH_GLOSS 0.2

uniform float _RayTraceDofDist;
uniform float _RayTraceDOF;
uniform sampler2D _RayTracing_SourceBuffer;
uniform float4 _RayTracing_SourceBuffer_ScreenFillAspect;
uniform float _RayTraceTransparency;
uniform float4 _RayTracing_TargetBuffer_ScreenFillAspect;


float3 opU(float3 d, float distance, float4 newMat, inout float4 currentMat, float type) 
{
	currentMat = d.y > distance ? newMat : currentMat;
	return d.y > distance ? float3(d.x, distance, type) : d; // if closer make new result
}

/*
float SampleBoxRotated(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal, in float3 boxSize) 
{
	rd = Rotate(rd, q);
	ro = Rotate(ro, q);

	float3 absRd = abs(rd) + 0.000001f;
	float3 signRd = rd / absRd;
	float3 m = signRd / (absRd);
	float3 n = m * ro;
	float3 k = abs(m) * boxSize;

	float3 t1 = -n - k;
	float3 t2 = -n + k;

	float tN = max(max(t1.x, t1.y), t1.z);
	float tF = min(min(t2.x, t2.y), t2.z);

	if (tN > tF || tF <= 0.0)
	{
		return MAX_DIST;
	}
	else 
	{
		if (tN >= distBound.x && tN <= distBound.y) 
		{
			normal = -signRd * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
			normal = Rotate(normal, float4(-q.x,-q.y,-q.z, q.w));
			return tN;
		}
		else if (tF >= distBound.x && tF <= distBound.y)
		{
			normal = -signRd * step(t2.xyz, t2.yzx) * step(t2.xyz, t2.zxy);
			normal = Rotate(normal, float4(-q.x, -q.y, -q.z, q.w));
			return tF;
		}
		else 
		{
			return MAX_DIST;
		}
	}
}
*/

#define IS_HIT_BOX(pos, size) IsHitBox(ro - pos.xyz, rd, size.xyz, d.xy, m)
#define IS_HIT_SPHERE(pos, radius) isHitSphere(ro - pos.xyz, rd, radius, d.xy)
#define IS_HIT_BOX_ROT(pos, rot, size) isHitBoxRot(ro - pos.xyz, rd, rot, size.xyz, d.xy)
#define IS_HIT_BOX_ROT_DEPTH(pos, rot, size) IsHitBoxRot_ModifyDepth(ro - pos.xyz, rd, rot, size.xyz, dTmp.xy)

#define IS_HIT_CAPSULE_ROT(pos, rot, size) isHitCapsuleRot(ro - pos.xyz, rd, rot, d.xy, size.y, size.x)

#define TRACE_BOX(posNmat, size,objmat) d = opU(d, iBox(ro - posNmat.xyz, rd, d.xy, normal, size.xyz, m), objmat, mat, posNmat.w)
#define TRACE_BOX_ROT(posNmat, rot, size,objmat) d = opU(d, iBoxRot(ro - posNmat.xyz, rd, rot, d.xy, normal, size.xyz), objmat, mat, posNmat.w)
#define TRACE_CAPSULE_ROT(posNmat, rot, size,objmat) d = opU(d, iCapsuleRot(ro - posNmat.xyz, rd, rot, d.xy, normal, size.y, size.x), objmat, mat, posNmat.w)

//float iCapsuleRot(in float3 ro, in float3 rd, in float4 q, in float2 distBound, inout float3 normal,
	//in float3 pa, in float3 pb, in float r) 


void WorldHit_Dynamic(float3 ro, in float3 rd, inout float3 d, inout float3 normal, inout float4 mat, in float3 m) 
{
	if (IS_HIT_BOX(DYNAMIC_PRIM_BoundPos, DYNAMIC_PRIM_BoundSize))
	{
		for (int dyI=0; dyI< DYNAMIC_PRIM_COUNT; dyI++)
			TRACE_CAPSULE_ROT(DYNAMIC_PRIM[dyI], DYNAMIC_PRIM_Rot[dyI], DYNAMIC_PRIM_Size[dyI], DYNAMIC_PRIM_Mat[dyI]);
	}
}

// Hit Box
bool isHit_bin_box_rot(float3 ro, in float3 rd, inout float3 d, float3 m)
{
	if (RayMarchCube_BinaryTree_Count.x<2)
		return false;

	int elementsToProcess[16]; // unlikely to ever be more

	elementsToProcess[0] = RayMarchCube_BinaryTree_PosNL[0].w;
	elementsToProcess[1] = RayMarchCube_BinaryTree_SizeNR[0].w;
	int freeSpace = 2;

	UNITY_BRANCH
	while (freeSpace >0) 
	{
		freeSpace--;
		int index = elementsToProcess[freeSpace];
		
		UNITY_BRANCH
		if (index <0)
		{
			// We got Leaf
			int boundIndex = -index - 1;

			float4 pos = RayMarchCube_BoundPos[boundIndex];
			float4 size = RayMarchCube_BoundSize[boundIndex];

			if (!IS_HIT_BOX(pos, size))
				continue;
			
			for (int rmcI = pos.w; rmcI < size.w; rmcI++)
			{
				float4 posNmat = RayMarchCube[rmcI];
				float type = posNmat.w;
				if (type < GLASS && IS_HIT_BOX_ROT(posNmat, RayMarchCube_Rot[rmcI], RayMarchCube_Size[rmcI]))
					return true;
			}
			continue;
		}  
		
		float4 bin_pos = RayMarchCube_BinaryTree_PosNL[index];
		float4 bin_size = RayMarchCube_BinaryTree_SizeNR[index];

		if (!IS_HIT_BOX(bin_pos, bin_size)) // This one is also a problem
			continue;

		elementsToProcess[freeSpace] = bin_pos.w;
		freeSpace++;

		elementsToProcess[freeSpace] = bin_size.w;
		freeSpace++;
	}

	return false;
}

bool isHit_bin_box_unrot(float3 ro, in float3 rd, inout float3 d, float3 m)
{
	if (RayMarchUnRot_BinaryTree_Count.x<2)
		return false;

	int elementsToProcess[16]; // unlikely to ever be more

	elementsToProcess[0] = RayMarchUnRot_BinaryTree_PosNL[0].w;
	elementsToProcess[1] = RayMarchUnRot_BinaryTree_SizeNR[0].w;
	int freeSpace = 2;

	while (freeSpace >0) 
	{
		int index = elementsToProcess[freeSpace-1];
		freeSpace--;

		if (index <0)
		{
			// We got Leaf
			int boundIndex = -index - 1;

			float4 pos = RayMarchUnRot_BoundPos[boundIndex];
			float4 size = RayMarchUnRot_BoundSize[boundIndex];

			if (!IS_HIT_BOX(pos, size))
				continue;
			
			for (int rmcuI = pos.w; rmcuI < size.w; rmcuI++)
			{
				float4 posNmat = RayMarchUnRot[rmcuI];
				float type = posNmat.w;
				if (type < GLASS && IS_HIT_BOX(posNmat, RayMarchUnRot_Size[rmcuI]))
					return true;
						
			}
			continue;
		}  
		
		float4 bin_pos = RayMarchUnRot_BinaryTree_PosNL[index];
		float4 bin_size = RayMarchUnRot_BinaryTree_SizeNR[index];

		if (!IS_HIT_BOX(bin_pos, bin_size)) // This one is also a problem
			continue;

		elementsToProcess[freeSpace] = bin_pos.w;
		freeSpace++;

		elementsToProcess[freeSpace] = bin_size.w;
		freeSpace++;
	}

	return false;
}



bool Raycast(float3 ro, in float3 rd, in float2 dist) {

	rd += 0.001; // rd * 0.01;

	float3 d = float3(dist, 0.);

	float3 m = sign(rd) / max(abs(rd), 0.00001);//1e-8);

	if (isHit_bin_box_rot(ro, rd, d, m))
		return true;

	if (isHit_bin_box_unrot(ro, rd, d, m))
		return true;

#if defined(RENDER_DYNAMICS)

	UNITY_BRANCH
	if (IS_HIT_BOX(DYNAMIC_PRIM_BoundPos, DYNAMIC_PRIM_BoundSize))
	{
		for (int dyI = 0; dyI < DYNAMIC_PRIM_COUNT; dyI++)
			if (IS_HIT_CAPSULE_ROT(DYNAMIC_PRIM[dyI], DYNAMIC_PRIM_Rot[dyI], DYNAMIC_PRIM_Size[dyI]))
				return true;
	}
#endif

	return false;
}

bool Raycast(float3 start, in float3 end)
{
	float3 dir = end.xyz - start;

	float distance = length(dir);

	float2 MIN_MAX = float2(0.0001, distance);

	return Raycast(start , normalize(dir), MIN_MAX);
}

bool RaycastStaticPhisics(float3 ro, in float3 rd, in float2 dist) {

	rd += 0.001; // rd * 0.01;

	float3 d = float3(dist, 0.);

	float3 m = sign(rd) / max(abs(rd), 0.0001);//1e-8);

	if (isHit_bin_box_rot(ro, rd, d, m))
		return true;

	if (isHit_bin_box_unrot(ro, rd, d, m))
		return true;

	return false;
}


// Render ray

void hit_bin_box_rot(float3 ro, in float3 rd, inout float3 d, inout float3 normal, inout float4 mat, float3 m) 
{
	if (RayMarchCube_BinaryTree_Count.x<2)
		return;

	int elementsToProcess[16]; // unlikely to ever be more

	elementsToProcess[0] = RayMarchCube_BinaryTree_PosNL[0].w;
	elementsToProcess[1] = RayMarchCube_BinaryTree_SizeNR[0].w;
	int freeSpace = 2;

	while (freeSpace >0) 
	{
		int index = elementsToProcess[freeSpace-1];
		freeSpace--;

		if (index <0)
		{
			// We got Leaf
			int boundIndex = -index - 1;

			float4 pos = RayMarchCube_BoundPos[boundIndex];
			float4 size = RayMarchCube_BoundSize[boundIndex];

			if (!IS_HIT_BOX(pos, size))
				continue;
			
			for (int rtbI = pos.w; rtbI < size.w; rtbI++)
				TRACE_BOX_ROT(RayMarchCube[rtbI], RayMarchCube_Rot[rtbI], RayMarchCube_Size[rtbI], RayMarchCube_Mat[rtbI]);
				
			continue;
		}  
		
		float4 bin_pos = RayMarchCube_BinaryTree_PosNL[index];
		float4 bin_size = RayMarchCube_BinaryTree_SizeNR[index];

		if (!IS_HIT_BOX(bin_pos, bin_size)) // This one is also a problem
			continue;

		elementsToProcess[freeSpace] = bin_pos.w;
		freeSpace++;

		elementsToProcess[freeSpace] = bin_size.w;
		freeSpace++;
	}

}

void hit_bin_box_unrot(float3 ro, in float3 rd, inout float3 d, inout float3 normal, inout float4 mat, float3 m) 
{
	if (RayMarchUnRot_BinaryTree_Count.x<2)
		return;

	int elementsToProcess[16]; // unlikely to ever be more

	elementsToProcess[0] = RayMarchUnRot_BinaryTree_PosNL[0].w;
	elementsToProcess[1] = RayMarchUnRot_BinaryTree_SizeNR[0].w;
	int freeSpace = 2;

	while (freeSpace >0) 
	{
		int index = elementsToProcess[freeSpace-1];
		freeSpace--;

		if (index <0)
		{
			// We got Leaf
			int boundIndex = -index - 1;

			float4 pos = RayMarchUnRot_BoundPos[boundIndex];
			float4 size = RayMarchUnRot_BoundSize[boundIndex];

			if (!IS_HIT_BOX(pos, size))
				continue;
			
			for (int rtbuI = pos.w; rtbuI < size.w; rtbuI++)
				TRACE_BOX(RayMarchUnRot[rtbuI], RayMarchUnRot_Size[rtbuI], RayMarchUnRot_Mat[rtbuI]);

			continue;
		}  
		
		float4 bin_pos = RayMarchUnRot_BinaryTree_PosNL[index];
		float4 bin_size = RayMarchUnRot_BinaryTree_SizeNR[index];

		if (!IS_HIT_BOX(bin_pos, bin_size)) // This one is also a problem
			continue;

		elementsToProcess[freeSpace] = bin_pos.w;
		freeSpace++;

		elementsToProcess[freeSpace] = bin_size.w;
		freeSpace++;
	}
}



float3 worldhit(float3 ro, in float3 rd, in float2 dist, out float3 normal, inout float4 mat) 
{
	ro += rd * 0.01;
	// d.z <= z causes to show sky   d.z is material
	float3 d = float3(dist, 0.);

	normal = -rd;

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	int boxHit = -1;

	float3 dTmp = d;

	hit_bin_box_rot(ro, rd, d, normal, mat, m);

	hit_bin_box_unrot(ro, rd, d, normal, mat, m);

	#if defined(RENDER_DYNAMICS)

	WorldHit_Dynamic(ro, rd, d, normal, mat, m);

	#endif

	return d;
}


float worldhitSubtractive(float3 ro, in float3 rd, in float2 dist) 
{
	float3 d = float3(dist, 0.);

	float3 m = sign(rd) / max(abs(rd), 1e-8);

	float distance = iBoxTrigger(ro - RayMarchSubtractiveCube_0.xyz, rd, d.xy, RayMarchSubtractiveCube_0_Size.xyz, m);
	distance = min(distance, iBoxTrigger(ro - RayMarchSubtractiveCube_1.xyz, rd, d.xy, RayMarchSubtractiveCube_1_Size.xyz, m));
	distance = min(distance, iBoxTrigger(ro - RayMarchSubtractiveCube_2.xyz, rd, d.xy, RayMarchSubtractiveCube_2_Size.xyz, m));

	return distance;
}

float SampleRayShadowAndAttenuation(float3 pos, float3 normal)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility == 0)
			return 0;

	float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);

	bool isHit = Raycast(pos + normal * 0.0001, _WorldSpaceLightPos0.xyz, MIN_MAX);

	return isHit ? 0 : smoothstep(0, 1, dot(normalize(_WorldSpaceLightPos0.xyz), normal));
}

float SampleRayShadow(float3 pos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	UNITY_BRANCH
	if (_qc_SunVisibility == 0){
			return 0;
			}
	else 
	{

		float2 MIN_MAX = float2(0.0001, MAX_DIST_EDGE);

		bool isHit = Raycast(pos, _WorldSpaceLightPos0.xyz, MIN_MAX);

		return isHit ? 0 : 1;
	}
}

float GetQcShadow(float3 worldPos)
{
	#if _qc_IGNORE_SKY
		return 0;
	#endif

	if (_qc_SunVisibility<0.01)
			return 0;

	return SampleRayShadow(worldPos); // * SampleSkyShadow(worldPos);
}



#endif