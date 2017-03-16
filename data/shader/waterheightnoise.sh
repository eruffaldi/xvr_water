[VERTEX SHADER]

varying vec4 texCoord; 
uniform float time;
uniform float offsety;
/// the plane is -1 -1 for filling all the viewport
/// xy is the texture coordinate, zw are free
void main(void)
{
   float tcoord = mod(time * 0.05,1.0);
   //texCoord = vec4(gl_MultiTexCoord0.s,gl_MultiTexCoord0.t,tcoord,1.0);
   texCoord = vec4(0.5 * (1.0 + 1.0 * gl_Vertex.x),0.5 * (1.0 + 1.0 * (gl_Vertex.y+offsety)),tcoord,1.0);
   gl_Position = vec4(gl_Vertex.x,gl_Vertex.y,0,1);
}

[FRAGMENT SHADER]
uniform float PixelDelta; // 1/size
uniform sampler3D NoiseTex;
uniform float time;

varying vec4 texCoord;

void main(void)
{   
   float tcoord = mod(time * 0.05,1.0);
   vec4 cc = texture3D(NoiseTex, texCoord.xyz);
   gl_FragColor = vec4(cc.x,cc.y,cc.z,1);
   //gl_FragColor = vec4(texCoord.x,texCoord.y,0,1);
}
