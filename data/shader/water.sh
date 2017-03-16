[VERTEX SHADER]

uniform float sz;

uniform vec3 viewPos;
uniform vec3 lightPos;

varying vec2 vTexCoord;
varying vec3 vViewVertex;
varying vec3 vLightVertex;
varying vec4 vVertexClip;
varying vec3 vNormal;		// eye coordinates normal
varying vec3 vTangent;
varying vec3 vBinormal;

//varying vec3 eyeLinear;
//varying vec2 textCoordRefl;

vec3 fnormal(void)
{
    return normalize(gl_NormalMatrix * gl_Normal);
}

void main(void)
{
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 norm = vec3(0.0, 1.0, 0.0);
    vec3 binormal = vec3(0.0, 0.0, 1.0);   
    
    
    vec4 pos = gl_Vertex;
 //   vViewVertex = viewPos-gl_Vertex.xyz;
	vViewVertex = vec3(normalize((gl_ModelViewMatrixInverse * vec4 (0.0, 0.0, 0.0, 1.0)) -  gl_Vertex));

    vLightVertex = lightPos - gl_Vertex.xyz;    
    vec4 sPos = gl_ModelViewProjectionMatrix * pos;
    gl_Position = sPos;
    vVertexClip = sPos;
    
    // Image-space
    vTexCoord.x = 0.5 * (1.0 + 1.0 * pos.x/sz);
    vTexCoord.y = 0.5 * (1.0 + 1.0 * pos.z/sz);

// O_O Non mischiate roba in eye space con roba in clip space.
// Qui c'è molta confusione. (Per favore fate partire la sigla del dotto Rosario)
// Per quale strana ragione viene fatta la supposizione che la normale è sulla X
// e che le tangenti e binormali si trovino con questa strana formula
// Considerando che loro la volevano in EYE space non è possibile fare supposizioni
// sulla normale. Inoltre le tangenti andrebbero calcolate in base alle UV.. e quindi
// questa roba in eye space non ha molto senso.
    vNormal = gl_Normal;//fnormal(); // eye space normal
    vec3 c1 = cross(vNormal, vec3(0.0, 0.0, 1.0)); 
    vec3 c2 = cross(vNormal, vec3(0.0, 1.0, 0.0)); 
    vTangent = normalize(length(c1)>length(c2) ? c1 : c2);
    vBinormal = cross(vTangent,vNormal);
}

[FRAGMENT SHADER]
uniform sampler2D refrTex;
uniform sampler2D reflTex;
uniform sampler2D heightTex;
uniform float fadeBias;
uniform float fadeExp;
uniform vec4 waterColor;
uniform vec4 humbraColor;
uniform float PixelDelta;
const float riflReflStrength = 0.03; //scostamento massimo della normale

varying vec2 vTexCoord;
varying vec3 vViewVertex;
varying vec4 vVertexClip;
varying vec3 vLightVertex;
varying vec3 vNormal;
varying vec3 vTangent;
varying vec3 vBinormal;

// Questa funzione non viene usata, viene fatta una approssimazione piu' semplice del coefficiente di Fresnel
// Al compilatore il compito di trascurarla. ;)
// Eliminatela se volete
float fresnel(in vec3 incom, in vec3 normal, in float index_internal)
{
	float eta = 1.0/index_internal;
	float cos_theta1 = dot(incom, normal);
	float cos_theta2 = sqrt(1.0 - ((eta * eta) * (1.0 - (cos_theta1 * cos_theta1))));
	
	// s polarized light
	float fresnel_rs = (cos_theta1 - index_internal * cos_theta2 ) / (cos_theta1 + index_internal * cos_theta2);
	// p polarized light
	float fresnel_rp = (index_internal * cos_theta1 - cos_theta2 ) / (index_internal * cos_theta1 + cos_theta2);
	
	return (fresnel_rs * fresnel_rs + fresnel_rp * fresnel_rp) * 0.5;
} 

void main(void)
{
	// make an array and set it from XVR!
	vec2 vTexCoords00 = vec2(-PixelDelta, -PixelDelta);
	vec2 vTexCoords01 = vec2( 0.0, -PixelDelta);
	vec2 vTexCoords02 = vec2( PixelDelta, -PixelDelta);
	vec2 vTexCoords10 = vec2(-PixelDelta, 0.0);
	vec2 vTexCoords12 = vec2( PixelDelta, 0.0);
	vec2 vTexCoords20 = vec2(-PixelDelta, PixelDelta);
	vec2 vTexCoords21 = vec2( 0.0, PixelDelta);
	vec2 vTexCoords22 = vec2( PixelDelta, PixelDelta);

	float s00 = texture2D(heightTex, vTexCoord+vTexCoords00).r;
	float s01 = texture2D(heightTex, vTexCoord+vTexCoords01).r;
	float s02 = texture2D(heightTex, vTexCoord+vTexCoords02).r;
	float s10 = texture2D(heightTex, vTexCoord+vTexCoords10).r;
	float s12 = texture2D(heightTex, vTexCoord+vTexCoords12).r;
	float s20 = texture2D(heightTex, vTexCoord+vTexCoords20).r;
	float s21 = texture2D(heightTex, vTexCoord+vTexCoords21).r;
	float s22 = texture2D(heightTex, vTexCoord+vTexCoords22).r;
	// float waterHeight = texture2D(heightTex, vTexCoord).r;

	//float wdepth = waterHeight.x;
	//  float invdepth = 1.0 - wdepth;

	// Slope in XY direction
	float sobelX = s00 + 2.0 * s10 + s20 - s02 - 2.0 * s12 - s22;
	float sobelY = s00 + 2.0 * s01 + s02 - s20 - 2.0 * s21 - s22;

	// Weight the slope in all channels, we use grayscale as height
	// Normal  is in Eye coordinates
	const float bumpFactor = 0.5;
	vec3 normal = normalize(vNormal + bumpFactor*(sobelX*vTangent+sobelY*vBinormal));

	vec3 vViewVertexN = normalize(vViewVertex);
	float invfres = dot(vViewVertexN, normal);
	float fres = 1.0 - invfres;
	//	float fres = fresnel(vViewVertexN, normal, 1.33);
	//	float invfres = 1.0 - fres;

	// Reflection of Water from the objects
	vec4 projCoord = ((vVertexClip / vVertexClip.w)+1.0)*0.5;
	vec2 riflreflCoord = clamp(projCoord.xy - riflReflStrength*vec2(sobelX, sobelY)/projCoord.z , 0.001, 0.999);
	vec3 humbrac= texture2D(reflTex, clamp(projCoord.xy, 0.001, 0.999)).rgb;
	float humbra = 0.11*humbrac.b+0.59*humbrac.g+0.3*humbrac.r;
	vec3 reflScene = texture2D(reflTex, riflreflCoord).rgb;
	vec3 refrScene = texture2D(refrTex, riflreflCoord).rgb;

	//vec3 color = mix(humbraColor.rgb,mix(waterColor.rgb,mix(refrScene, reflScene, clamp(fadeBias + pow(fres, fadeExp),0.0, 1.0)),waterColor.a),1.0-humbraColor.a*humbra);
	vec3 color = mix(waterColor.rgb,mix(refrScene, reflScene, clamp(fadeBias + pow(fres, fadeExp),0.0, 1.0)),waterColor.a);
	

	gl_FragColor = vec4(color, 1.0); 
}