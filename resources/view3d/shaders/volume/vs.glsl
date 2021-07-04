#version 330

in vec4 iVS_Position;

out vec3 iFS_PointWS;
out vec4 iFS_PointCS;

uniform mat4 worldMatrix;
uniform mat4 worldViewProjMatrix;

void main()
{
	gl_Position = worldViewProjMatrix * iVS_Position;
	iFS_PointWS = (worldMatrix * iVS_Position).xyz;
	iFS_PointCS = gl_Position;
}
