// Copyright (c) 2015, bacondither
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer
//    in this position and unchanged.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

// Adaptive sharpen - version 2015-05-15 - (requires ps >= 3.0)
// Tuned for use post resize, EXPECTS FULL RANGE GAMMA LIGHT

// Compatibility #ifdefs needed for parameters
#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

// Parameter lines go here:
#pragma parameter CURVE_HEIGHT "AS Sharpness" 0.8 0.1 2.0 0.1
#ifdef PARAMETER_UNIFORM
// All parameter floats need to have COMPAT_PRECISION in front of them
uniform COMPAT_PRECISION float CURVE_HEIGHT;
#else
#define CURVE_HEIGHT 0.8
#endif

#define VIDEO_LEVEL_OUT 0.0

#define curve_height    CURVE_HEIGHT         // Main sharpening strength, POSITIVE VALUE ONLY!
                                             // 0.3 <-> 1.5 is a reasonable range of values

#define video_level_out VIDEO_LEVEL_OUT      // True to preserve BTB & WTW (minor summation error)
                                             // Normally it should be set to false

// Defined values under this row are "optimal" DO NOT CHANGE IF YOU DO NOT KNOW WHAT YOU ARE DOING!

#define curveslope      (curve_height*1.5)   // Sharpening curve slope, edge region
#define D_overshoot     0.016                // Max dark overshoot before max compression
#define D_comp_ratio    0.250                // Max compression ratio, dark overshoot (1/0.25=4x)
#define L_overshoot     0.004                // Max light overshoot before max compression
#define L_comp_ratio    0.167                // Max compression ratio, light overshoot (1/0.167=6x)
#define max_scale_lim   10.0                 // Abs change before max compression (1/10=�10%)

// Colour to greyscale, fast approx gamma
COMPAT_PRECISION float CtG(vec3 RGB) { return  sqrt( (1.0/3.0)*((RGB*RGB).r + (RGB*RGB).g + (RGB*RGB).b) ); }

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;
// out variables go here as COMPAT_VARYING whatever

vec4 _oPosition1; 
uniform mat4 MVPMatrix;
uniform int FrameDirection;
uniform int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

void main()
{
    gl_Position = MVPMatrix * VertexCoord;
    COL0 = COLOR;
    TEX0.xy = TexCoord.xy;
// Paste vertex contents here:

}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform int FrameDirection;
uniform int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;
// in variables go here as COMPAT_VARYING whatever

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy
#define texture(c, d) COMPAT_TEXTURE(c, d)
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutputSize vec4(OutputSize, 1.0 / OutputSize)

// delete all 'params.' or 'registers.' or whatever in the fragment

void main()
{
	vec2	tex	=	vTexCoord;
	
	float	px	=	SourceSize.z;
	float	py	=	SourceSize.w;

// Get points and saturate out of range values (BTB & WTW)
// [                c22               ]
// [           c24, c9,  c23          ]
// [      c21, c1,  c2,  c3, c18      ]
// [ c19, c10, c4,  c0,  c5, c11, c16 ]
// [      c20, c6,  c7,  c8, c17      ]
// [           c15, c12, c14          ]
// [                c13               ]
	vec3	 c19	=	clamp( texture(Source, vTexCoord + vec2(-3*px,   0)).rgb, 0.0, 1.0);
	vec3	 c21	=	clamp( texture(Source, vTexCoord + vec2(-2*px,  -py)).rgb, 0.0, 1.0);
	vec3	 c10	=	clamp( texture(Source, vTexCoord + vec2(-2*px,   0)).rgb, 0.0, 1.0);
	vec3	 c20	=	clamp( texture(Source, vTexCoord + vec2(-2*px,   py)).rgb, 0.0, 1.0);
	vec3	 c24	=	clamp( texture(Source, vTexCoord + vec2(  -px,-2*py)).rgb, 0.0, 1.0);
	vec3	 c1 	=	clamp( texture(Source, vTexCoord + vec2(  -px,  -py)).rgb, 0.0, 1.0);
	vec3	 c4 	=	clamp( texture(Source, vTexCoord + vec2(  -px,   0)).rgb, 0.0, 1.0);
	vec3	 c6 	=	clamp( texture(Source, vTexCoord + vec2(  -px,   py)).rgb, 0.0, 1.0);
	vec3	 c15	=	clamp( texture(Source, vTexCoord + vec2(  -px, 2*py)).rgb, 0.0, 1.0);
	vec3	 c22	=	clamp( texture(Source, vTexCoord + vec2(   0, -3*py)).rgb, 0.0, 1.0);
	vec3	 c9 	=	clamp( texture(Source, vTexCoord + vec2(   0, -2*py)).rgb, 0.0, 1.0);
	vec3	 c2 	=	clamp( texture(Source, vTexCoord + vec2(   0,   -py)).rgb, 0.0, 1.0);
	vec3	 c0 	=	clamp( texture(Source, vTexCoord).rgb, 0.0, 1.0);
	vec3	 c7 	=	clamp( texture(Source, vTexCoord + vec2(   0,    py)).rgb, 0.0, 1.0);
	vec3	 c12	=	clamp( texture(Source, vTexCoord + vec2(   0,  2*py)).rgb, 0.0, 1.0);
	vec3	 c13	=	clamp( texture(Source, vTexCoord + vec2(   0,  3*py)).rgb, 0.0, 1.0);
	vec3	 c23	=	clamp( texture(Source, vTexCoord + vec2(   px,-2*py)).rgb, 0.0, 1.0);
	vec3	 c3 	=	clamp( texture(Source, vTexCoord + vec2(   px,  -py)).rgb, 0.0, 1.0);
	vec3	 c5 	=	clamp( texture(Source, vTexCoord + vec2(   px,   0)).rgb, 0.0, 1.0);
	vec3	 c8 	=	clamp( texture(Source, vTexCoord + vec2(   px,   py)).rgb, 0.0, 1.0);
	vec3	 c14	=	clamp( texture(Source, vTexCoord + vec2(   px, 2*py)).rgb, 0.0, 1.0);
	vec3	 c18	=	clamp( texture(Source, vTexCoord + vec2( 2*px,  -py)).rgb, 0.0, 1.0);
	vec3	 c11	=	clamp( texture(Source, vTexCoord + vec2( 2*px,   0)).rgb, 0.0, 1.0);
	vec3	 c17	=	clamp( texture(Source, vTexCoord + vec2( 2*px,   py)).rgb, 0.0, 1.0);
	vec3	 c16	=	clamp( texture(Source, vTexCoord + vec2( 3*px,   0)).rgb, 0.0, 1.0 );
	
// Blur, gauss 3x3
	vec3	blur	=	(2*(c2 + c4 + c5 + c7) + (c1 + c3 + c6 +c8) + 4*c0)/16;
	float	blur_Y	=	(blur.r*(1.0/3.0) + blur.g*(1.0/3.0) + blur.b*(1.0/3.0));
	
// Edge detection
// Matrix, relative weights
// [           1          ]
// [       4,  4,  4      ]
// [   1,  4,  4,  4,  1  ]
// [       4,  4,  4      ]
// [           1          ]
	float	edge	=	length( abs(blur-c0) + abs(blur-c1) + abs(blur-c2) + abs(blur-c3)
					+	abs(blur-c4) + abs(blur-c5) + abs(blur-c6) + abs(blur-c7) + abs(blur-c8)
					+	0.25*(abs(blur-c9) + abs(blur-c10) + abs(blur-c11) + abs(blur-c12)) )*(1.0/3.0);

// Edge detect contrast compression, center = 0.5
	edge	*=	min((0.8+2.7*pow(2, (-7.4*blur_Y))), 3.2);
	
// RGB to greyscale
	float	c0_Y	=	CtG(c0);
	
	float	kernel[25]	=	{ c0_Y,  CtG(c1), CtG(c2), CtG(c3), CtG(c4), CtG(c5), CtG(c6), CtG(c7), CtG(c8),
							CtG(c9), CtG(c10), CtG(c11), CtG(c12), CtG(c13), CtG(c14), CtG(c15), CtG(c16),
							CtG(c17), CtG(c18), CtG(c19), CtG(c20), CtG(c21), CtG(c22), CtG(c23), CtG(c24) };
			
// Partial laplacian outer pixel weighting scheme
	float	mdiff_c0	=	0.03 + 4*( abs(kernel[0]-kernel[2]) + abs(kernel[0]-kernel[4])
						+	abs(kernel[0]-kernel[5]) + abs(kernel[0]-kernel[7])
						+	0.25*(abs(kernel[0]-kernel[1]) + abs(kernel[0]-kernel[3])
						+	abs(kernel[0]-kernel[6]) + abs(kernel[0]-kernel[8])) );
								  
	float	mdiff_c9	=	( abs(kernel[9]-kernel[2])   + abs(kernel[9]-kernel[24])
						+	abs(kernel[9]-kernel[23])  + abs(kernel[9]-kernel[22])
						+	0.5*(abs(kernel[9]-kernel[1]) + abs(kernel[9]-kernel[3])) );

	float	mdiff_c10	=	( abs(kernel[10]-kernel[20]) + abs(kernel[10]-kernel[19])
						+	abs(kernel[10]-kernel[21]) + abs(kernel[10]-kernel[4])
						+	0.5*(abs(kernel[10]-kernel[1]) + abs(kernel[10]-kernel[6])) );

	float	mdiff_c11	=	( abs(kernel[11]-kernel[17]) + abs(kernel[11]-kernel[5])
						+	abs(kernel[11]-kernel[18]) + abs(kernel[11]-kernel[16])
						+	0.5*(abs(kernel[11]-kernel[3]) + abs(kernel[11]-kernel[8])) );

	float	mdiff_c12	=	( abs(kernel[12]-kernel[13]) + abs(kernel[12]-kernel[15])
						+	abs(kernel[12]-kernel[7])  + abs(kernel[12]-kernel[14])
						+	0.5*(abs(kernel[12]-kernel[6]) + abs(kernel[12]-kernel[8])) );

	vec4	weights		=	vec4( (min((mdiff_c0/mdiff_c9), 2.0)), (min((mdiff_c0/mdiff_c10),2.0)),
							(min((mdiff_c0/mdiff_c11),2.0)), (min((mdiff_c0/mdiff_c12),2.0)) );
						  
// Negative laplace matrix
 // Matrix, relative weights, *Varying 0<->8
 // [          8*         ]
 // [      4,  1,  4      ]
 // [  8*, 1,      1,  8* ]
 // [      4,  1,  4      ]
 // [          8*         ]
	float	neg_laplace	=	( 0.25 * (kernel[2] + kernel[4] + kernel[5] + kernel[7])
						+	(kernel[1] + kernel[3] + kernel[6] + kernel[8])
						+	((kernel[9]*weights.x) + (kernel[10]*weights.y)
						+	(kernel[11]*weights.z) + (kernel[12]*weights.w)) )
						/	(5 + weights.x + weights.y + weights.z + weights.w);
						
 // Compute sharpening magnitude function, x = edge mag, y = laplace operator mag
	float	sharpen_val	=	0.01 + (curve_height/(curveslope*pow(edge, 3.5) + 0.5))
						-	(curve_height/(8192*pow((edge*2.2), 4.5) + 0.5));

 // Calculate sharpening diff and scale
	float	sharpdiff	=	(c0_Y - neg_laplace)*(sharpen_val*0.8);
	
// Calculate local near min & max, partial cocktail sort (No branching!)
	for	(int i = 0; i < 2; ++i)
	{
		for	(int i1 = 1+i; i1 < 25-i; ++i1)
		{
			float temp		=	kernel[i1-1];
			kernel[i1-1]	=	min(kernel[i1-1], kernel[i1]);
			kernel[i1]		=	max(temp, kernel[i1]);
		}

		for	(int i2 = 23-i; i2 > i; --i2)
		{
			float temp		=	kernel[i2-1];
			kernel[i2-1]	=	min(kernel[i2-1], kernel[i2]);
			kernel[i2]		=	max(temp, kernel[i2]);
		}
	}
	
	float	nmax		=	max(((kernel[23] + kernel[24])/2), c0_Y);
	float	nmin		=	min(((kernel[0]  + kernel[1])/2),  c0_Y);

// Calculate tanh scale factor, pos/neg
	float	nmax_scale	=	max((1/((nmax - c0_Y) + L_overshoot)), max_scale_lim);
	float	nmin_scale	=	max((1/((c0_Y - nmin) + D_overshoot)), max_scale_lim);

// Soft limit sharpening with tanh, mix to control maximum compression
	sharpdiff			=	mix( (tanh((max(sharpdiff, 0.0))*nmax_scale)/nmax_scale), (max(sharpdiff, 0.0)), L_comp_ratio )
						+	mix( (tanh((min(sharpdiff, 0.0))*nmin_scale)/nmin_scale), (min(sharpdiff, 0.0)), D_comp_ratio );

//	if	(video_level_out	==	1.0) { texture(Source, vTexCoord) + sharpdiff; }
   FragColor = vec4(c0.rgbb + sharpdiff);
} 
#endif