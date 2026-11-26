#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <commctrl.h>
#include <stdint.h>
#include "gdextension_interface.h"

static GDExtensionInterfaceGetProcAddress api;
static GDExtensionClassLibraryPtr library;
static GDExtensionTypeFromVariantConstructorFunc read_int;
static GDExtensionVariantFromTypeConstructorFunc write_int;
static GDExtensionInterfaceVariantGetType variant_type;
static HHOOK menu_mouse_hook;
static HWND watched_menu;
static bool clicked_outside;

static LRESULT CALLBACK watch_menu_mouse(int code, WPARAM message, LPARAM data) {
    if (code == HC_ACTION && message == WM_LBUTTONDOWN) {
        RECT bounds;
        const auto *event = reinterpret_cast<const MSLLHOOKSTRUCT *>(data);
        if (GetWindowRect(watched_menu, &bounds) && !PtInRect(&bounds, event->pt))
            clicked_outside = true;
    }
    return CallNextHookEx(menu_mouse_hook, code, message, data);
}

static void stop_menu_watch() {
    if (menu_mouse_hook) UnhookWindowsHookEx(menu_mouse_hook);
    menu_mouse_hook = nullptr;
    watched_menu = nullptr;
    clicked_outside = false;
}

static LONG_PTR tool_window_style(LONG_PTR style) {
    return (style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW;
}

static LRESULT CALLBACK keep_tool_window(HWND window, UINT message, WPARAM wparam, LPARAM lparam,
                                        UINT_PTR id, DWORD_PTR) {
    if (message == WM_STYLECHANGING && static_cast<int>(wparam) == GWL_EXSTYLE) {
        // Godot recalculates the main window style from its flags on every focus-mode change.
        auto *styles = reinterpret_cast<STYLESTRUCT *>(lparam);
        styles->styleNew = static_cast<DWORD>(tool_window_style(styles->styleNew));
    } else if (message == WM_NCDESTROY) {
        RemoveWindowSubclass(window, keep_tool_window, id);
    }
    return DefSubclassProc(window, message, wparam, lparam);
}

// Static-only interface: all handles must belong to this process.
static int64_t operate(int64_t handle, int64_t command, int64_t value) {
    HWND window = reinterpret_cast<HWND>(handle);
    DWORD process = 0;
    if (!IsWindow(window)) return 0;
    GetWindowThreadProcessId(window, &process);
    if (process != GetCurrentProcessId()) return 0;
    if (command == 0) {
        if (!SetWindowSubclass(window, keep_tool_window, 1, 0)) return 0;
        LONG_PTR style = GetWindowLongPtrW(window, GWL_EXSTYLE);
        LONG_PTR tool_style = tool_window_style(style);
        if (style != tool_style) {
            bool visible = IsWindowVisible(window);
            if (visible) ShowWindow(window, SW_HIDE);
            SetWindowLongPtrW(window, GWL_EXSTYLE, tool_style);
            SetWindowPos(window, nullptr, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
            if (visible) ShowWindow(window, SW_SHOWNOACTIVATE);
        }
        style = GetWindowLongPtrW(window, GWL_EXSTYLE);
        return style == tool_window_style(style);
    }
    if (command == 1) {
        ShowWindow(window, value ? SW_SHOWNOACTIVATE : SW_HIDE);
        return !!IsWindowVisible(window) == !!value;
    }
    if (command == 2) return GetWindowLongPtrW(window, GWL_EXSTYLE);
    if (command == 3) return !!IsWindowVisible(window);
    if (command == 4) {
        HWND foreground = GetForegroundWindow();
        DWORD owner = 0;
        GetWindowThreadProcessId(foreground, &owner);
        return owner != process ? reinterpret_cast<int64_t>(foreground) : 0;
    }
    if (command == 5) {
        SetForegroundWindow(window);
        return GetForegroundWindow() == window;
    }
    if (command == 6) {
        HWND foreground = GetForegroundWindow();
        DWORD owner = 0;
        GetWindowThreadProcessId(foreground, &owner);
        HWND previous = reinterpret_cast<HWND>(value);
        return owner == process && IsWindow(previous) && SetForegroundWindow(previous);
    }
    if (command == 7 && value > 0 && value < 256)
        return (GetAsyncKeyState(static_cast<int>(value)) & 0x8000) != 0;
    if (command == 8 && value >= 32 && value <= 0xffff) {
        SHORT key = VkKeyScanW(static_cast<WCHAR>(value));
        return key == -1 ? 0 : LOBYTE(key);
    }
    if (command == 9) {
        stop_menu_watch();
        if (!value) return 1;
        HWND menu = reinterpret_cast<HWND>(value);
        DWORD menu_process = 0;
        GetWindowThreadProcessId(menu, &menu_process);
        if (menu_process != process) return 0;
        HMODULE module = nullptr;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                          reinterpret_cast<LPCWSTR>(&watch_menu_mouse), &module);
        watched_menu = menu;
        menu_mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, watch_menu_mouse, module, 0);
        return menu_mouse_hook != nullptr;
    }
    if (command == 10) return clicked_outside;
    return 0;
}

static void call(void *, GDExtensionClassInstancePtr, const GDExtensionConstVariantPtr *args,
                 GDExtensionInt count, GDExtensionVariantPtr result, GDExtensionCallError *error) {
    int64_t values[3] = {};
    error->error = GDEXTENSION_CALL_OK;
    if (count != 3) {
        error->error = count < 3 ? GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS : GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        error->expected = 3;
    } else {
        for (int i = 0; i < 3; ++i) {
            if (variant_type(args[i]) != GDEXTENSION_VARIANT_TYPE_INT) {
                error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
                error->argument = i;
                error->expected = GDEXTENSION_VARIANT_TYPE_INT;
                break;
            }
            read_int(&values[i], const_cast<void *>(args[i]));
        }
    }
    int64_t answer = error->error == GDEXTENSION_CALL_OK ? operate(values[0], values[1], values[2]) : 0;
    write_int(result, &answer);
}

static void ptrcall(void *, GDExtensionClassInstancePtr, const GDExtensionConstTypePtr *args, GDExtensionTypePtr result) {
    *static_cast<int64_t *>(result) = operate(*static_cast<const int64_t *>(args[0]),
                                            *static_cast<const int64_t *>(args[1]),
                                            *static_cast<const int64_t *>(args[2]));
}

static void free_instance(void *, GDExtensionClassInstancePtr) {}

static void initialize(void *, GDExtensionInitializationLevel level) {
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    auto name_new = reinterpret_cast<GDExtensionInterfaceStringNameNewWithUtf8Chars>(api("string_name_new_with_utf8_chars"));
    auto destructor = reinterpret_cast<GDExtensionInterfaceVariantGetPtrDestructor>(api("variant_get_ptr_destructor"))(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
    auto register_class = reinterpret_cast<GDExtensionInterfaceClassdbRegisterExtensionClass4>(api("classdb_register_extension_class4"));
    auto register_method = reinterpret_cast<GDExtensionInterfaceClassdbRegisterExtensionClassMethod>(api("classdb_register_extension_class_method"));
    uint64_t names[7] = {};
    uint64_t empty_string = 0;
    reinterpret_cast<GDExtensionInterfaceStringNewWithUtf8Chars>(api("string_new_with_utf8_chars"))(&empty_string, "");
    const char *texts[] = {"RigPopWindows", "RefCounted", "operate", "handle", "command", "value", ""};
    for (int i = 0; i < 7; ++i) name_new(&names[i], texts[i]);
    GDExtensionClassCreationInfo4 info = {};
    info.is_abstract = true;
    info.is_exposed = true;
    info.is_runtime = true;
    info.free_instance_func = free_instance;
    register_class(library, &names[0], &names[1], &info);
    GDExtensionPropertyInfo arguments[3] = {};
    GDExtensionClassMethodArgumentMetadata metadata[3] = {};
    for (int i = 0; i < 3; ++i) {
        arguments[i].type = GDEXTENSION_VARIANT_TYPE_INT;
        arguments[i].name = &names[3 + i];
        arguments[i].class_name = &names[6];
        arguments[i].hint_string = &empty_string;
        arguments[i].usage = 6;
    }
    GDExtensionPropertyInfo returns = {};
    returns.type = GDEXTENSION_VARIANT_TYPE_INT;
    returns.name = &names[6];
    returns.class_name = &names[6];
    returns.hint_string = &empty_string;
    returns.usage = 6;
    GDExtensionClassMethodInfo method = {};
    method.name = &names[2];
    method.call_func = call;
    method.ptrcall_func = ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL | GDEXTENSION_METHOD_FLAG_STATIC;
    method.has_return_value = true;
    method.return_value_info = &returns;
    method.argument_count = 3;
    method.arguments_info = arguments;
    method.arguments_metadata = metadata;
    register_method(library, &names[0], &method);
    for (int i = 0; i < 7; ++i) destructor(&names[i]);
    reinterpret_cast<GDExtensionInterfaceVariantGetPtrDestructor>(api("variant_get_ptr_destructor"))(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}

static void deinitialize(void *, GDExtensionInitializationLevel level) {
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    stop_menu_watch();
    uint64_t name = 0;
    reinterpret_cast<GDExtensionInterfaceStringNameNewWithUtf8Chars>(api("string_name_new_with_utf8_chars"))(&name, "RigPopWindows");
    reinterpret_cast<GDExtensionInterfaceClassdbUnregisterExtensionClass>(api("classdb_unregister_extension_class"))(library, &name);
    reinterpret_cast<GDExtensionInterfaceVariantGetPtrDestructor>(api("variant_get_ptr_destructor"))(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&name);
}

extern "C" __declspec(dllexport) GDExtensionBool rigpop_windows_init(
    GDExtensionInterfaceGetProcAddress get_proc, GDExtensionClassLibraryPtr supplied_library,
    GDExtensionInitialization *initialization) {
    api = get_proc;
    library = supplied_library;
    variant_type = reinterpret_cast<GDExtensionInterfaceVariantGetType>(api("variant_get_type"));
    read_int = reinterpret_cast<GDExtensionInterfaceGetVariantToTypeConstructor>(api("get_variant_to_type_constructor"))(GDEXTENSION_VARIANT_TYPE_INT);
    write_int = reinterpret_cast<GDExtensionInterfaceGetVariantFromTypeConstructor>(api("get_variant_from_type_constructor"))(GDEXTENSION_VARIANT_TYPE_INT);
    initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    initialization->initialize = initialize;
    initialization->deinitialize = deinitialize;
    return true;
}
