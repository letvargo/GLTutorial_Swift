//
//  GLTutorialController.swift
//  GLTutorial_Swift
//
//  Created by doof nugget on 12/16/15.
//  Copyright © 2015 letvargo. All rights reserved.
//

import Cocoa
import CoreVideo.CVDisplayLink
import OpenGL.GL3

struct Vertex {
    let position: (x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat)
    let color: (r: GLfloat, g: GLfloat, b: GLfloat, a: GLfloat)
}

struct Vertices {
    let v1: Vertex
    let v2: Vertex
    let v3: Vertex
    let v4: Vertex
}

class GLTutorialController: NSObject {

    @IBOutlet var window: NSWindow!
    var view: NSOpenGLView!

    var displayLink: CVDisplayLink?
    
    var shaderProgram: GLuint!
    var vertexArrayObject: GLuint = 0
    var vertexBuffer: GLuint = 0

    var positionUniform: GLint!
    var colorAttribute: GLint = 0
    var positionAttribute: GLint = 0
    
    let displayCallback: CVDisplayLinkOutputCallback = { displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext in
        let controller = unsafeBitCast(displayLinkContext, GLTutorialController.self)
        controller.renderForTime(inOutputTime.memory)
        return kCVReturnSuccess
    }
    
    override func awakeFromNib() {
        createOpenGLView()
        createOpenGLResources()
        createDisplayLink()
    }
    
    func createOpenGLView() {
        let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] =
            [
                NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
                NSOpenGLPFAColorSize    , 24                           ,
                NSOpenGLPFAAlphaSize    , 8                            ,
                NSOpenGLPFADoubleBuffer ,
                NSOpenGLPFAAccelerated  ,
                NSOpenGLPFANoRecovery   ,
                0
                ].map { UInt32($0) }
                
        let pixelFormat = NSOpenGLPixelFormat(attributes: pixelFormatAttributes)
        
        guard let contentView = window.contentView
            , let openGLView = NSOpenGLView(frame: contentView.bounds, pixelFormat: pixelFormat) else { return }
        
        view = openGLView
        
        contentView.addSubview(view)
    }
    
    func createOpenGLResources() {
        view.openGLContext?.makeCurrentContext()
        loadShader()
        loadBufferData()
    }
    
    func createDisplayLink() {
        let displayID = CGMainDisplayID()
        let error = CVDisplayLinkCreateWithCGDisplay(displayID, &displayLink)
        
        guard let dLink = displayLink where kCVReturnSuccess == error else {
            NSLog("Display Link created with error: %d", error)
            displayLink = nil
            return
        }
        
        CVDisplayLinkSetOutputCallback(dLink, displayCallback, UnsafeMutablePointer<Void>(unsafeAddressOf(self)))
        CVDisplayLinkStart(dLink)
    }
    
    func loadShader() {
    
        guard let vShaderFile = NSBundle.mainBundle().pathForResource("Shader", ofType: "vsh")
            , let fShaderFile = NSBundle.mainBundle().pathForResource("Shader", ofType: "fsh") else { return }
        
        let vertexShader = compileShaderOfType(GLenum(GL_VERTEX_SHADER), file: vShaderFile)
        let fragmentShader = compileShaderOfType(GLenum(GL_FRAGMENT_SHADER), file: fShaderFile)
        
        guard vertexShader != 0 && fragmentShader != 0 else {
            print("Shader compilation failed.")
            return
        }
        
        shaderProgram = glCreateProgram()
        getError()
        
        glAttachShader(shaderProgram, vertexShader)
        getError()
        glAttachShader(shaderProgram, fragmentShader)
        getError()
        
        glBindFragDataLocation(shaderProgram, 0, "fragColor")
        
        linkProgram(shaderProgram)

        positionUniform = glGetUniformLocation(shaderProgram, "p");
        getError()

        if (positionUniform < 0) {
            print("Shader did not contain the 'p' uniform.")
        }
        
        colorAttribute = glGetAttribLocation(shaderProgram, "color")
        getError()

        if (colorAttribute < 0) {
            print("Shader did not contain the 'colour' attribute.")
        }
        
        positionAttribute = glGetAttribLocation(shaderProgram, "position")
        getError()

        if (positionAttribute < 0) {
            print("Shader did not contain the 'position' attribute.")
        }

        glDeleteShader(vertexShader)
        getError()
        glDeleteShader(fragmentShader)
        getError()
    }
    
    func compileShaderOfType(type: GLenum, file: String) -> GLuint {
    
        var shader: GLuint = 0
        
        do {
        
            var source = try NSString(contentsOfFile: file, encoding: NSASCIIStringEncoding).cStringUsingEncoding(NSASCIIStringEncoding)
            
            shader = glCreateShader(type)
            getError()
            glShaderSource(shader, 1, &source, nil)
            getError()
            glCompileShader(shader)
            getError()
            
//        #if defined(DEBUG)
//            GLint logLength;
//
//            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
//            GetError();
//            if (logLength > 0)
//            {
//                GLchar *log = malloc((size_t)logLength);
//                glGetShaderInfoLog(shader, logLength, &logLength, log);
//                GetError();
//                NSLog(@"Shader compilation failed with error:\n%s", log);
//                free(log);
//            }
//        #endif

            var status: GLint = 0
            glGetShaderiv(shader, UInt32(GL_COMPILE_STATUS), &status)
            
            getError()
            if (0 == status) {
                glDeleteShader(shader);
            getError()
                print("Shader compilation failed for file \(file)")
            }
            
        } catch {
            print("Failed to reader shader file.")
            print("\(error)")
        }
        return shader
    }
    
    func loadBufferData() {
        
        var vertexData = Vertices(
            v1: Vertex( position:   (x: -0.5, y: -0.5, z:  0.0, w:  1.0),
                        color:      (r:  1.0, g:  0.0, b:  0.0, a:  1.0)),
            v2: Vertex( position:   (x: -0.5, y:  0.5, z:  0.0, w:  1.0),
                        color:      (r:  0.0, g:  1.0, b:  0.0, a:  1.0)),
            v3: Vertex( position:   (x:  0.5, y:  0.5, z:  0.0, w:  1.0),
                        color:      (r:  0.0, g:  0.0, b:  1.0, a:  1.0)),
            v4: Vertex( position:   (x:  0.5, y: -0.5, z:  0.0, w:  1.0),
                        color:      (r:  1.0, g:  1.0, b:  1.0, a:  1.0)) )
        
        glGenVertexArrays(1, &vertexArrayObject)
        getError()
        glBindVertexArray(vertexArrayObject)
        getError()

        glGenBuffers(1, &vertexBuffer)
        getError()
        glBindBuffer(UInt32(GL_ARRAY_BUFFER), vertexBuffer);
        getError()
        glBufferData(UInt32(GL_ARRAY_BUFFER), 4 * sizeof(Vertex), &vertexData, UInt32(GL_STATIC_DRAW));
        getError()

        glEnableVertexAttribArray(GLuint(positionAttribute))
        getError()
        glEnableVertexAttribArray(GLuint(colorAttribute))
        getError()

        glVertexAttribPointer(GLuint(positionAttribute), 4, UInt32(GL_FLOAT), UInt8(GL_FALSE), GLsizei(sizeof(Vertex)), nil)
        getError()

        glVertexAttribPointer(GLuint(colorAttribute), 4, UInt32(GL_FLOAT), UInt8(GL_FALSE), GLsizei(sizeof(Vertex)), UnsafePointer<Void>(nil) + 16)
        
        getError()

    }
    
    func renderForTime(time: CVTimeStamp) {
    
        view.openGLContext?.makeCurrentContext()
        
        glClearColor(0.0, 0.0, 0.0, 1.0)
        getError()
        glClear(UInt32(GL_COLOR_BUFFER_BIT))
        getError()
        
        glUseProgram(shaderProgram);
        getError()

        let timeValue = GLfloat(time.videoTime) / GLfloat(time.videoTimeScale);
        let p: [GLfloat] = [ 0.5 * sinf(timeValue), 0.5 * cosf(timeValue) ]
        glUniform2fv(positionUniform, 1, p)
        getError()
        
        glDrawArrays(UInt32(GL_TRIANGLE_FAN), 0, 4)
        getError()
        
        view.openGLContext?.flushBuffer()
    }
    
    func linkProgram(program: GLuint) {
        glLinkProgram(program)
        getError()
        
//        #if defined(DEBUG)
//            GLint logLength;
//            
//            glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
//            GetError();
//            if (logLength > 0)
//            {
//                GLchar *log = malloc((size_t)logLength);
//                glGetProgramInfoLog(program, logLength, &logLength, log);
//                GetError();
//                NSLog(@"Shader program linking failed with error:\n%s", log);
//                free(log);
//            }
//        #endif
        
        var status: GLint = 0
        glGetProgramiv(program, UInt32(GL_LINK_STATUS), &status);
        getError()
        if (0 == status) {
            print("Failed to link shader program")
        }
    }


    func getError() {
        for (var error = Int32(glGetError()); error != GL_NO_ERROR; error = Int32(glGetError())) {
            switch error {
            case GL_INVALID_ENUM:
                NSLog( "\n%s\n\n", "GL_INVALID_ENUM")
                assert(false)
                
            case GL_INVALID_VALUE:
                NSLog("\n%s\n\n", "GL_INVALID_VALUE")
                assert(false)
                
            case GL_INVALID_OPERATION:
                NSLog( "\nGL_INVALID_OPERATION\n\n")
                assert(false)
                
            case GL_OUT_OF_MEMORY:
                NSLog( "\n%s\n\n", "GL_OUT_OF_MEMORY")
                assert(false)
                
            default:
                break
            }
        }
    }
}