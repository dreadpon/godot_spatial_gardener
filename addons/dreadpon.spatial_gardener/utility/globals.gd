@tool


#-------------------------------------------------------------------------------
# A list of global consts with methods to work with them
# A mirror of some of GlobalScope enums
# Because they can't be accessed as "enum" and only as "const int"
# And I need "enums" to expose them to ProjectSettings
#-------------------------------------------------------------------------------


# Globally accessible parameters loaded from ProjectSettings
static var is_threaded_LOD_update: bool = false
static var use_precise_LOD_distances: bool = false
static var use_precise_camera_frustum: bool = false
static var force_readable_node_names: bool = false


# Convert index starting from "0" to an enum value, where first index is the first enum value
# E.g. for KeyboardKey, index of "0" would represent a value of "SPKEY | 0x01" or simply "16777217")
static func index_to_enum(index:int, enum_dict:Dictionary):
	return enum_dict.values()[index]


# The opposite of index_to_enum()
static func enum_to_index(enum_val:int, enum_dict:Dictionary):
	return enum_dict.values().find(enum_val)


# Access and format an error message
static func get_err_message(err_code):
	return str("[", err_code, "]: ", Error[err_code])




# Controls per how many units is density calculated
const PLANT_DENSITY_UNITS:int = 100

# A string to be used in tooltips/hints regarding plugin settings
const AS_IN_SETTINGS_STRING:String = "As specified in 'Project' -> 'Project Settings' -> 'Dreadpons Spatial Gardener'"




# KeyboardKey
# Taken from https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html
enum KeyboardKey {
	KEY_NONE = 0,
	KEY_SPECIAL = 4194304,
	KEY_ESCAPE = 4194305,
	KEY_TAB = 4194306,
	KEY_BACKTAB = 4194307,
	KEY_BACKSPACE = 4194308,
	KEY_ENTER = 4194309,
	KEY_KP_ENTER = 4194310,
	KEY_INSERT = 4194311,
	KEY_DELETE = 4194312,
	KEY_PAUSE = 4194313,
	KEY_PRINT = 4194314,
	KEY_SYSREQ = 4194315,
	KEY_CLEAR = 4194316,
	KEY_HOME = 4194317,
	KEY_END = 4194318,
	KEY_LEFT = 4194319,
	KEY_UP = 4194320,
	KEY_RIGHT = 4194321,
	KEY_DOWN = 4194322,
	KEY_PAGEUP = 4194323,
	KEY_PAGEDOWN = 4194324,
	KEY_SHIFT = 4194325,
	KEY_CTRL = 4194326,
	KEY_META = 4194327,
	KEY_ALT = 4194328,
	KEY_CAPSLOCK = 4194329,
	KEY_NUMLOCK = 4194330,
	KEY_SCROLLLOCK = 4194331,
	KEY_F1 = 4194332,
	KEY_F2 = 4194333,
	KEY_F3 = 4194334,
	KEY_F4 = 4194335,
	KEY_F5 = 4194336,
	KEY_F6 = 4194337,
	KEY_F7 = 4194338,
	KEY_F8 = 4194339,
	KEY_F9 = 4194340,
	KEY_F10 = 4194341,
	KEY_F11 = 4194342,
	KEY_F12 = 4194343,
	KEY_F13 = 4194344,
	KEY_F14 = 4194345,
	KEY_F15 = 4194346,
	KEY_F16 = 4194347,
	KEY_F17 = 4194348,
	KEY_F18 = 4194349,
	KEY_F19 = 4194350,
	KEY_F20 = 4194351,
	KEY_F21 = 4194352,
	KEY_F22 = 4194353,
	KEY_F23 = 4194354,
	KEY_F24 = 4194355,
	KEY_F25 = 4194356,
	KEY_F26 = 4194357,
	KEY_F27 = 4194358,
	KEY_F28 = 4194359,
	KEY_F29 = 4194360,
	KEY_F30 = 4194361,
	KEY_F31 = 4194362,
	KEY_F32 = 4194363,
	KEY_F33 = 4194364,
	KEY_F34 = 4194365,
	KEY_F35 = 4194366,
	KEY_KP_MULTIPLY = 4194433,
	KEY_KP_DIVIDE = 4194434,
	KEY_KP_SUBTRACT = 4194435,
	KEY_KP_PERIOD = 4194436,
	KEY_KP_ADD = 4194437,
	KEY_KP_0 = 4194438,
	KEY_KP_1 = 4194439,
	KEY_KP_2 = 4194440,
	KEY_KP_3 = 4194441,
	KEY_KP_4 = 4194442,
	KEY_KP_5 = 4194443,
	KEY_KP_6 = 4194444,
	KEY_KP_7 = 4194445,
	KEY_KP_8 = 4194446,
	KEY_KP_9 = 4194447,
	KEY_MENU = 4194370,
	KEY_HYPER = 4194371,
	KEY_HELP = 4194373,
	KEY_BACK = 4194376,
	KEY_FORWARD = 4194377,
	KEY_STOP = 4194378,
	KEY_REFRESH = 4194379,
	KEY_VOLUMEDOWN = 4194380,
	KEY_VOLUMEMUTE = 4194381,
	KEY_VOLUMEUP = 4194382,
	KEY_MEDIAPLAY = 4194388,
	KEY_MEDIASTOP = 4194389,
	KEY_MEDIAPREVIOUS = 4194390,
	KEY_MEDIANEXT = 4194391,
	KEY_MEDIARECORD = 4194392,
	KEY_HOMEPAGE = 4194393,
	KEY_FAVORITES = 4194394,
	KEY_SEARCH = 4194395,
	KEY_STANDBY = 4194396,
	KEY_OPENURL = 4194397,
	KEY_LAUNCHMAIL = 4194398,
	KEY_LAUNCHMEDIA = 4194399,
	KEY_LAUNCH0 = 4194400,
	KEY_LAUNCH1 = 4194401,
	KEY_LAUNCH2 = 4194402,
	KEY_LAUNCH3 = 4194403,
	KEY_LAUNCH4 = 4194404,
	KEY_LAUNCH5 = 4194405,
	KEY_LAUNCH6 = 4194406,
	KEY_LAUNCH7 = 4194407,
	KEY_LAUNCH8 = 4194408,
	KEY_LAUNCH9 = 4194409,
	KEY_LAUNCHA = 4194410,
	KEY_LAUNCHB = 4194411,
	KEY_LAUNCHC = 4194412,
	KEY_LAUNCHD = 4194413,
	KEY_LAUNCHE = 4194414,
	KEY_LAUNCHF = 4194415,
	KEY_UNKNOWN = 8388607,
	KEY_SPACE = 32,
	KEY_EXCLAM = 33,
	KEY_QUOTEDBL = 34,
	KEY_NUMBERSIGN = 35,
	KEY_DOLLAR = 36,
	KEY_PERCENT = 37,
	KEY_AMPERSAND = 38,
	KEY_APOSTROPHE = 39,
	KEY_PARENLEFT = 40,
	KEY_PARENRIGHT = 41,
	KEY_ASTERISK = 42,
	KEY_PLUS = 43,
	KEY_COMMA = 44,
	KEY_MINUS = 45,
	KEY_PERIOD = 46,
	KEY_SLASH = 47,
	KEY_0 = 48,
	KEY_1 = 49,
	KEY_2 = 50,
	KEY_3 = 51,
	KEY_4 = 52,
	KEY_5 = 53,
	KEY_6 = 54,
	KEY_7 = 55,
	KEY_8 = 56,
	KEY_9 = 57,
	KEY_COLON = 58,
	KEY_SEMICOLON = 59,
	KEY_LESS = 60,
	KEY_EQUAL = 61,
	KEY_GREATER = 62,
	KEY_QUESTION = 63,
	KEY_AT = 64,
	KEY_A = 65,
	KEY_B = 66,
	KEY_C = 67,
	KEY_D = 68,
	KEY_E = 69,
	KEY_F = 70,
	KEY_G = 71,
	KEY_H = 72,
	KEY_I = 73,
	KEY_J = 74,
	KEY_K = 75,
	KEY_L = 76,
	KEY_M = 77,
	KEY_N = 78,
	KEY_O = 79,
	KEY_P = 80,
	KEY_Q = 81,
	KEY_R = 82,
	KEY_S = 83,
	KEY_T = 84,
	KEY_U = 85,
	KEY_V = 86,
	KEY_W = 87,
	KEY_X = 88,
	KEY_Y = 89,
	KEY_Z = 90,
	KEY_BRACKETLEFT = 91,
	KEY_BACKSLASH = 92,
	KEY_BRACKETRIGHT = 93,
	KEY_ASCIICIRCUM = 94,
	KEY_UNDERSCORE = 95,
	KEY_QUOTELEFT = 96,
	KEY_BRACELEFT = 123,
	KEY_BAR = 124,
	KEY_BRACERIGHT = 125,
	KEY_ASCIITILDE = 126,
	KEY_YEN = 165,
	KEY_SECTION = 167,
	KEY_GLOBE = 4194416,
	KEY_KEYBOARD = 4194417,
	KEY_JIS_EISU = 4194418,
	KEY_JIS_KANA = 4194419
}

# KeyModifierMask
# Taken from https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html
enum {
	KEY_CODE_MASK = 8388607,
	KEY_MODIFIER_MASK = 532676608,
	KEY_MASK_CMD_OR_CTRL = 16777216,
	KEY_MASK_SHIFT = 33554432,
	KEY_MASK_ALT = 67108864,
	KEY_MASK_META = 134217728,
	KEY_MASK_CTRL = 268435456,
	KEY_MASK_KPAD = 536870912,
	KEY_MASK_GROUP_SWITCH = 1073741824
}

# MouseButton
# Taken from https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html
enum MouseButton {
	MOUSE_BUTTON_NONE = 0,
	MOUSE_BUTTON_LEFT = 1,
	MOUSE_BUTTON_RIGHT = 2,
	MOUSE_BUTTON_MIDDLE = 3,
	MOUSE_BUTTON_WHEEL_UP = 4,
	MOUSE_BUTTON_WHEEL_DOWN = 5,
	MOUSE_BUTTON_WHEEL_LEFT = 6,
	MOUSE_BUTTON_WHEEL_RIGHT = 7,
	MOUSE_BUTTON_XBUTTON1 = 8,
	MOUSE_BUTTON_XBUTTON2 = 9,
}

# MouseButtonMask
# Taken from https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html
enum MouseButtonMask {
	MOUSE_BUTTON_MASK_LEFT = (1 << (MOUSE_BUTTON_LEFT - 1)),
	MOUSE_BUTTON_MASK_RIGHT = (1 << (MOUSE_BUTTON_RIGHT - 1)),
	MOUSE_BUTTON_MASK_MIDDLE = (1 << (MOUSE_BUTTON_MIDDLE - 1)),
	MOUSE_BUTTON_MASK_XBUTTON1 = (1 << (MOUSE_BUTTON_XBUTTON1 - 1)),
	MOUSE_BUTTON_MASK_XBUTTON2 = (1 << (MOUSE_BUTTON_XBUTTON2 - 1))
}


# Error
# Taken from https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html
const Error = {
	OK: "OK",
	FAILED: "Generic error",
	ERR_UNAVAILABLE: "Unavailable error",
	ERR_UNCONFIGURED: "Unconfigured error",
	ERR_UNAUTHORIZED: "Unauthorized error",
	ERR_PARAMETER_RANGE_ERROR: "Parameter range error",
	ERR_OUT_OF_MEMORY: "Out of memory (OOM) error",
	ERR_FILE_NOT_FOUND: "File: Not found error",
	ERR_FILE_BAD_DRIVE: "File: Bad drive error",
	ERR_FILE_BAD_PATH: "File: Bad path error",
	ERR_FILE_NO_PERMISSION: "File: No permission error",
	ERR_FILE_ALREADY_IN_USE: "File: Already in use error",
	ERR_FILE_CANT_OPEN: "File: Can't open error",
	ERR_FILE_CANT_WRITE: "File: Can't write error",
	ERR_FILE_CANT_READ: "File: Can't read error",
	ERR_FILE_UNRECOGNIZED: "File: Unrecognized error",
	ERR_FILE_CORRUPT: "File: Corrupt error",
	ERR_FILE_MISSING_DEPENDENCIES: "File: Missing dependencies error",
	ERR_FILE_EOF: "File: End of file (EOF) error",
	ERR_CANT_OPEN: "Can't open error",
	ERR_CANT_CREATE: "Can't create error",
	ERR_QUERY_FAILED: "Query failed error",
	ERR_ALREADY_IN_USE: "Already in use error",
	ERR_LOCKED: "Locked error",
	ERR_TIMEOUT: "Timeout error",
	ERR_CANT_CONNECT: "Can't connect error",
	ERR_CANT_RESOLVE: "Can't resolve error",
	ERR_CONNECTION_ERROR: "Connection error",
	ERR_CANT_ACQUIRE_RESOURCE: "Can't acquire resource error",
	ERR_CANT_FORK: "Can't fork process error",
	ERR_INVALID_DATA: "Invalid data error",
	ERR_INVALID_PARAMETER: "Invalid parameter error",
	ERR_ALREADY_EXISTS: "Already exists error",
	ERR_DOES_NOT_EXIST: "Does not exist error",
	ERR_DATABASE_CANT_READ: "Database: Read error",
	ERR_DATABASE_CANT_WRITE: "Database: Write error",
	ERR_COMPILATION_FAILED: "Compilation failed error",
	ERR_METHOD_NOT_FOUND: "Method not found error",
	ERR_LINK_FAILED: "Linking failed error",
	ERR_SCRIPT_FAILED: "Script failed error",
	ERR_CYCLIC_LINK: "Cycling link (import cycle) error",
	ERR_INVALID_DECLARATION: "Invalid declaration error",
	ERR_DUPLICATE_SYMBOL: "Duplicate symbol error",
	ERR_PARSE_ERROR: "Parse error",
	ERR_BUSY: "Busy error",
	ERR_SKIP: "Skip error",
	ERR_HELP: "Help error",
	ERR_BUG: "Bug error",
	ERR_PRINTER_ON_FIRE: "Printer on fire error",
}
