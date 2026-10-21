import ctypes

EGL_VENDOR = 0x3053

egl = ctypes.CDLL("libEGL.so.1")
egl.eglGetDisplay.restype = ctypes.c_void_p
egl.eglGetDisplay.argtypes = [ctypes.c_void_p]
egl.eglInitialize.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
egl.eglQueryString.restype = ctypes.c_char_p
egl.eglQueryString.argtypes = [ctypes.c_void_p, ctypes.c_int]

# libEGL only finds mesa through mesa's vendor file, so without it there is no display.
display = egl.eglGetDisplay(None)
assert display, "no EGL display"
assert egl.eglInitialize(display, None, None), hex(egl.eglGetError())
vendor = egl.eglQueryString(display, EGL_VENDOR).decode()
assert vendor == "Mesa Project", vendor
