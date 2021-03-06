//
//  OpenGLView.m
//  HelloOpenGL
//
//  Created by KaiKai on 11-10-30.
//  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
//

#import <OpenGLES/es1/gl.h>
#import "OpenGLView.h"

@interface OpenGLView()

- (void)setupLayer;
- (void)setupContext;
- (void)setupRenderBuffer;
- (void)setupFrameBuffer;
- (void)render:(CADisplayLink *)displayLink;
- (void)setupVBOs;
- (void)setupDisplayLink;
//- (void)setupDepthBuffer;

- (void)loadTexture;

@end

@implementation OpenGLView

typedef struct
{
	float Position[3];
	float Color[4];
}
Vertex;

const Vertex Vertices[] = 
{
	{{1, -1, 0}, {1, 0, 0, 1}},
	{{1, 1, 0}, {0, 1, 0, 1}},
	{{-1, 1, 0}, {0, 0, 1, 1}},
	{{-1, -1, 0}, {0, 0, 0, 1}}
};

const GLubyte Indices[] = 
{
	0, 1, 2,
	2, 3, 0
};

//const Vertex Vertices[] = {
//    {{1, -1, 0}, {1, 0, 0, 1}},
//    {{1, 1, 0}, {1, 0, 0, 1}},
//    {{-1, 1, 0}, {0, 1, 0, 1}},
//    {{-1, -1, 0}, {0, 1, 0, 1}},
//    {{1, -1, -1}, {1, 0, 0, 1}},
//    {{1, 1, -1}, {1, 0, 0, 1}},
//    {{-1, 1, -1}, {0, 1, 0, 1}},
//    {{-1, -1, -1}, {0, 1, 0, 1}}
//};
//
//const GLubyte Indices[] = {
//    // Front
//    0, 1, 2,
//    2, 3, 0,
//    // Back
//    4, 6, 5,
//    4, 7, 6,
//    // Left
//    2, 7, 3,
//    7, 6, 2,
//    // Right
//    0, 4, 1,
//    4, 1, 5,
//    // Top
//    6, 2, 1, 
//    1, 6, 5,
//    // Bottom
//    0, 3, 7,
//    0, 7, 4    
//};

- (GLuint)compileShader:(NSString *)shaderName withType:(GLenum)shaderType
{
	NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"glsl"];
	NSError* error;
	NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
	if (!shaderString)
	{
		NSLog(@"Error loading shader: %@", error.localizedDescription);
		exit(3);
	}
	
	GLuint shaderHandle = glCreateShader(shaderType);
	
	const char * shaderStringUTF8 = [shaderString UTF8String];
	int shaderStringLength = [shaderString length];
	glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
	
	glCompileShader(shaderHandle);
	
	GLint compileSucess;
	glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSucess);
	if (compileSucess == GL_FALSE)
	{
		GLchar message[256];
		glGetShaderInfoLog(shaderHandle, sizeof(message), 0, &message[0]);
		NSString *messageString = [NSString stringWithUTF8String:message];
		NSLog(@"%@", messageString);
		exit(4);
	}
	
	return shaderHandle;
}

- (void)compileShaders
{
	GLuint vertexShader = [self compileShader:@"vertex" withType:GL_VERTEX_SHADER];
	GLuint fragmentShader = [self compileShader:@"fragment" withType:GL_FRAGMENT_SHADER];
	
	GLuint programHandle = glCreateProgram();
	glAttachShader(programHandle, vertexShader);
	glAttachShader(programHandle, fragmentShader);
	glLinkProgram(programHandle);
	
	GLint linkSucess;
	glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSucess);
	if (linkSucess == GL_FALSE)
	{
		GLchar messages[256];
		glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
		NSString* messageString = [NSString stringWithUTF8String:messages];
		NSLog(@"%@", messageString);
		exit(5);
	}
	
	glUseProgram(programHandle);
	
	_positionSlot = glGetAttribLocation(programHandle, "Position");
	_colorSlot = glGetAttribLocation(programHandle, "SourceColor");
	glEnableVertexAttribArray(_positionSlot);
	glEnableVertexAttribArray(_colorSlot);
}

- (void)setupVBOs
{
	GLuint vertexBuffer;
	glGenBuffers(1, &vertexBuffer);
	glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
	glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
	
	GLuint indexBuffer;
	glGenBuffers(1, &indexBuffer);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
}

- (void)setupDisplayLink
{
	CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
	[displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
//		GLint param1 = 0;
//		glGetIntegerv(GL_GREEN_BITS, &param1);
		
        [self setupLayer];
		[self setupContext];
//		[self setupDepthBuffer];
		[self setupRenderBuffer];
		[self setupFrameBuffer];
		
//		[self compileShaders];
//		[self setupVBOs];
		
		[self setupDisplayLink];
		
		[self loadTexture];
		
//		GLint param = 0;
//		glGetIntegerv(GL_GREEN_BITS, &param);
//		param = -1;
    }
    return self;
}

- (void)dealloc
{
	[EAGLContext setCurrentContext:nil];
	[_context release];
	_context = nil;
	
	[super dealloc];
}

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (void)setupLayer
{
	_eaglLayer = (CAEAGLLayer *)self.layer;
	_eaglLayer.opaque = YES;
}

- (void)setupContext
{
	EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES1;
	_context = [[EAGLContext alloc] initWithAPI:api];
	
	if (_context == nil)
	{
		NSLog(@"Failed to initialize OpenGLES 2.0 context");
		exit(1);
	}
	
	if (![EAGLContext setCurrentContext:_context])
	{
		NSLog(@"Failed to set current OpenGL context");
		exit(2);
	}
}

//- (void)setupDepthBuffer
//{
//	glGenRenderbuffers(1, &_depthRenderBuffer);
//	glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderBuffer);
//	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, self.frame.size.width, self.frame.size.height);
//}

- (void)setupRenderBuffer
{
	glGenRenderbuffers(1, &_colorRenderBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}

- (void)setupFrameBuffer
{
	GLuint frameBuffer;
	glGenFramebuffers(1, &frameBuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
	
//	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderBuffer);
}

- (void)render:(CADisplayLink *)displayLink
{
	glClearColor(0, 104.0/255.0, 55.0/255.0, 0.5);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
//	glEnable(GL_DEPTH_TEST);
	
	
	glViewport(0, 0, self.frame.size.width, self.frame.size.height);
	
//	glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
//	glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *)(sizeof(float) * 3));
	
//	glDrawElements(GL_TRIANGLES, sizeof(Indices) / sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
	
//	const GLfloat triangleVertices[] = {
//        0.3, -0.3, 0,                    // Triangle top centre
//        0.3, 0.3, 0,                  // bottom left
//        -0.3, 0.3, 0                    // bottom right
//		, -0.3, -0.3,0
//    };

	const GLfloat triangleVertices[] = {
       -1.0, 1.0, 0.0,
		-1.0, -1.0, 0.0,
		1.0, -1.0,0.0,
		1.0, 1.0, 0.0,
    };
	
	const GLfloat squareColors[] = 
	{
		1, 0, 0, 1,
		0, 1, 0, 1,
		0, 0, 1, 1,
		0, 0, 0, 1
	};
	
	const GLshort squareTextureCoords[] = {
        0, 0,       // top left
        0, 1,       // bottom left
        1, 1,       // bottom right
        1, 0,        // top right
    };
	
//	const GLshort squareTextureCoords[] = {
//        1, 0,
//		1, 1,
//		0, 1,
//		0, 0,
//    };
	
	glColor4f(0, 0, 0.8, 0.5);
	glVertexPointer(3, GL_FLOAT, 0, triangleVertices);
//	glVertexPointer(3, GL_FLOAT, sizeof(float) * 4, Vertices);
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glColorPointer(4, GL_FLOAT, 0, squareColors);
	
	
	glShadeModel(GL_SMOOTH);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
//	glRotatef(30, 0, 0, 1);
	glTranslatef(-0.4, 0, 0);
	rota = 0;
	if (rota >= 360)
	{
		rota -= 360;
	}
	glRotatef(rota, 0, 0, 1);
	
	glDrawArrays(GL_TRIANGLE_FAN, 0, 3);
	
	
	glColor4f(1, 1.5, 1.5, 1.0);
	glLoadIdentity();
	glTranslatef(0.5, 0, 0);
//	glRotatef(-rota, 0, 0, 1);
//	glEnableClientState(GL_COLOR_ARRAY);
	glTexCoordPointer(2, GL_SHORT, 0, squareTextureCoords);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
//	glDisableClientState(GL_COLOR_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	[_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)loadTexture
{
	UIImage* image = [UIImage imageNamed:@"017.jpg"];
	CGImageRef textureImage = image.CGImage;
	if (textureImage == nil)
	{
		NSLog(@"Failed to load texture image");
		return;
	}
	NSInteger texWidth = image.size.width;
	NSInteger texHeight = image.size.height;
	GLubyte* textureData = (GLubyte *)malloc(texWidth * texHeight * 4);
	
	CGContextRef textureContext = CGBitmapContextCreate(textureData, texWidth, texHeight, 8, texWidth * 4, CGImageGetColorSpace(textureImage), kCGImageAlphaPremultipliedLast);
	CGContextDrawImage(textureContext, CGRectMake(0, 0, texWidth, texHeight), textureImage);
	CGContextRelease(textureContext);
	
	glGenTextures(1, &textures[0]);
	glBindTexture(GL_TEXTURE_2D, textures[0]);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texWidth, texHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData);
	free(textureData);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glEnable(GL_TEXTURE_2D);
}

@end
