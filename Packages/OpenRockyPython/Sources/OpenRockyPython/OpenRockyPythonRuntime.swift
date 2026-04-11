import Foundation
import Python

/// Result of executing a Python code snippet.
public struct PythonExecutionResult: Sendable {
    public let success: Bool
    public let output: String
    public let error: String
}

/// Manages an embedded CPython 3.13 interpreter on iOS.
///
/// Call ``initialize()`` once at app launch (after the stdlib has been installed
/// into the app bundle by the Xcode build-phase script).  Then use
/// ``execute(_:)`` to run arbitrary Python source strings.
public final class OpenRockyPythonRuntime: @unchecked Sendable {

    public static let shared = OpenRockyPythonRuntime()

    private var isInitialized = false
    private let queue = DispatchQueue(label: "com.rocky.python", qos: .userInitiated)

    private init() {}

    // MARK: - Public API

    /// Initialise the embedded Python interpreter.
    /// Must be called from the main thread before any ``execute`` call.
    public func initialize() -> Bool {
        guard !isInitialized else { return true }

        let bundle = Bundle.main
        guard let resourcePath = bundle.resourcePath else { return false }

        let pythonHome = (resourcePath as NSString).appendingPathComponent("python")
        let pythonLib = (pythonHome as NSString).appendingPathComponent("lib/python3.13")
        let libDynload = (pythonLib as NSString).appendingPathComponent("lib-dynload")

        // --- pre-config ---
        var preconfig = PyPreConfig()
        PyPreConfig_InitIsolatedConfig(&preconfig)
        preconfig.utf8_mode = 1

        var status = Py_PreInitialize(&preconfig)
        if PyStatus_Exception(status) != 0 {
            #if DEBUG
            print("[OpenRockyPython] Pre-init failed: \(String(cString: status.err_msg))")
            #endif
            return false
        }

        // --- config ---
        var config = PyConfig()
        PyConfig_InitIsolatedConfig(&config)
        config.buffered_stdio = 0
        config.write_bytecode = 0
        config.install_signal_handlers = 1

        // PYTHONHOME
        let wHome = Py_DecodeLocale(pythonHome, nil)
        let homePtr = UnsafeMutablePointer<PyConfig>.allocate(capacity: 1)
        homePtr.initialize(from: &config, count: 1)
        status = PyConfig_SetString(homePtr, &homePtr.pointee.home, wHome)
        config = homePtr.pointee
        homePtr.deallocate()
        PyMem_RawFree(wHome)
        if PyStatus_Exception(status) != 0 {
            #if DEBUG
            print("[OpenRockyPython] Set home failed: \(String(cString: status.err_msg))")
            #endif
            PyConfig_Clear(&config)
            return false
        }

        // Read defaults (sets up module_search_paths etc.)
        status = PyConfig_Read(&config)
        if PyStatus_Exception(status) != 0 {
            #if DEBUG
            print("[OpenRockyPython] Config read failed: \(String(cString: status.err_msg))")
            #endif
            PyConfig_Clear(&config)
            return false
        }

        // Append lib-dynload to module search paths
        let wDynload = Py_DecodeLocale(libDynload, nil)
        status = PyWideStringList_Append(&config.module_search_paths, wDynload)
        PyMem_RawFree(wDynload)
        if PyStatus_Exception(status) != 0 {
            #if DEBUG
            print("[OpenRockyPython] Append dynload path failed")
            #endif
            PyConfig_Clear(&config)
            return false
        }

        // --- initialize ---
        status = Py_InitializeFromConfig(&config)
        PyConfig_Clear(&config)
        if PyStatus_Exception(status) != 0 {
            #if DEBUG
            print("[OpenRockyPython] Init failed: \(String(cString: status.err_msg))")
            #endif
            return false
        }

        // Add site-packages to sys.path
        let sitePackages = (pythonLib as NSString).appendingPathComponent("site-packages")
        let addSiteScript = "import sys; sys.path.insert(0, '\(sitePackages)')"
        PyRun_SimpleString(addSiteScript)

        // Redirect stdout/stderr to capture buffers
        let redirectScript = """
        import sys, io
        class _OpenRockyIO(io.StringIO):
            pass
        sys.stdout = _OpenRockyIO()
        sys.stderr = _OpenRockyIO()
        """
        PyRun_SimpleString(redirectScript)

        isInitialized = true
        #if DEBUG
        print("[OpenRockyPython] Python 3.13 initialized successfully")
        #endif
        return true
    }

    /// Execute a Python source string and return captured stdout/stderr.
    public func execute(_ code: String) -> PythonExecutionResult {
        guard isInitialized else {
            return PythonExecutionResult(
                success: false,
                output: "",
                error: "Python interpreter not initialized"
            )
        }

        return queue.sync {
            // Reset capture buffers
            PyRun_SimpleString("""
            import sys
            sys.stdout.truncate(0)
            sys.stdout.seek(0)
            sys.stderr.truncate(0)
            sys.stderr.seek(0)
            """)

            let rc = PyRun_SimpleString(code)

            let stdout = readStream("stdout")
            let stderr = readStream("stderr")

            return PythonExecutionResult(
                success: rc == 0,
                output: stdout,
                error: stderr
            )
        }
    }

    /// Get Python version string.
    public func version() -> String? {
        guard isInitialized else { return nil }
        let result = execute("import sys; print(sys.version, end='')")
        return result.success ? result.output : nil
    }

    // MARK: - Private

    private func readStream(_ name: String) -> String {
        let script = """
        import sys
        _rocky_val = sys.\(name).getvalue()
        """
        PyRun_SimpleString(script)

        guard let mainModule = PyImport_AddModule("__main__"),
              let dict = PyModule_GetDict(mainModule),
              let val = PyDict_GetItemString(dict, "_rocky_val"),
              let cStr = PyUnicode_AsUTF8(val) else {
            return ""
        }
        return String(cString: cStr)
    }
}
