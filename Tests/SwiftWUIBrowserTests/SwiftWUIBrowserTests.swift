import Testing
@testable import SwiftWUIBrowser
@testable import SwiftWUIState

@Suite("Browser Utilities")
struct BrowserUtilityTests {
    @Test("AppStorage default value")
    func appStorageDefault() {
        let storage = AppStorage(wrappedValue: "default", "test_key")
        #expect(storage.wrappedValue == "default")
    }

    @Test("AppStorage set and get")
    func appStorageSetGet() {
        let storage = AppStorage(wrappedValue: 0, "counter_key")
        storage.wrappedValue = 42
        #expect(storage.wrappedValue == 42)
    }

    @Test("AppStorage projected value binding")
    func appStorageBinding() {
        let storage = AppStorage(wrappedValue: "initial", "binding_key")
        let binding = storage.projectedValue
        binding.wrappedValue = "updated"
        #expect(storage.wrappedValue == "updated")
    }

    @Test("SessionStorage default value")
    func sessionStorageDefault() {
        let storage = SessionStorage(wrappedValue: true, "flag_key")
        #expect(storage.wrappedValue == true)
    }

    @Test("SessionStorage set and get")
    func sessionStorageSetGet() {
        let storage = SessionStorage(wrappedValue: 10, "session_counter")
        storage.wrappedValue = 25
        #expect(storage.wrappedValue == 25)
    }

    @Test("LocalizedStringCatalog basic lookup")
    func localizationBasicLookup() {
        var catalog = LocalizedStringCatalog()
        catalog.add(locale: "en", key: "hello", value: "Hello")
        catalog.add(locale: "ru", key: "hello", value: "Привет")

        #expect(catalog.localized("hello", locale: "en") == "Hello")
        #expect(catalog.localized("hello", locale: "ru") == "Привет")
    }

    @Test("LocalizedStringCatalog fallback to English")
    func localizationFallbackToEnglish() {
        var catalog = LocalizedStringCatalog()
        catalog.add(locale: "en", key: "hello", value: "Hello")

        #expect(catalog.localized("hello", locale: "fr") == "Hello")
    }

    @Test("LocalizedStringCatalog fallback to key")
    func localizationFallbackToKey() {
        let catalog = LocalizedStringCatalog()
        #expect(catalog.localized("missing_key", locale: "en") == "missing_key")
    }

    @Test("LocalizedStringCatalog base locale fallback")
    func localizationBaseLocaleFallback() {
        var catalog = LocalizedStringCatalog()
        catalog.add(locale: "en", key: "hello", value: "Hello")

        // "en-US" should fall back to "en"
        #expect(catalog.localized("hello", locale: "en-US") == "Hello")
    }

    @Test("LocalizedStringCatalog available locales")
    func localizationAvailableLocales() {
        var catalog = LocalizedStringCatalog()
        catalog.add(locale: "en", key: "hello", value: "Hello")
        catalog.add(locale: "ru", key: "hello", value: "Привет")
        catalog.add(locale: "de", key: "hello", value: "Hallo")

        #expect(catalog.availableLocales.count == 3)
        #expect(catalog.availableLocales.contains("en"))
        #expect(catalog.availableLocales.contains("ru"))
        #expect(catalog.availableLocales.contains("de"))
    }

    @Test("LocalizedStringCatalog batch add translations")
    func localizationBatchAdd() {
        var catalog = LocalizedStringCatalog()
        catalog.add(locale: "en", translations: [
            "hello": "Hello",
            "goodbye": "Goodbye",
        ])

        #expect(catalog.localized("hello", locale: "en") == "Hello")
        #expect(catalog.localized("goodbye", locale: "en") == "Goodbye")
    }

    @Test("ColorScheme enum values")
    func colorSchemeValues() {
        #expect(ColorScheme.light.rawValue == "light")
        #expect(ColorScheme.dark.rawValue == "dark")
    }

    @Test("ScreenSize compact threshold")
    func screenSizeCompact() {
        let media = MediaQueryState()
        media.screenWidth = 375
        #expect(media.screenSize == .compact)
    }

    @Test("ScreenSize regular threshold")
    func screenSizeRegular() {
        let media = MediaQueryState()
        media.screenWidth = 800
        #expect(media.screenSize == .regular)
    }

    @Test("ScreenSize expanded threshold")
    func screenSizeExpanded() {
        let media = MediaQueryState()
        media.screenWidth = 1440
        #expect(media.screenSize == .expanded)
    }

    @Test("ScreenSize boundary at 768")
    func screenSizeBoundary768() {
        let media = MediaQueryState()
        media.screenWidth = 768
        #expect(media.screenSize == .regular)
    }

    @Test("ScreenSize boundary at 1024")
    func screenSizeBoundary1024() {
        let media = MediaQueryState()
        media.screenWidth = 1024
        #expect(media.screenSize == .regular)
    }

    @Test("ScreenSize boundary just above 1024")
    func screenSizeBoundaryAbove1024() {
        let media = MediaQueryState()
        media.screenWidth = 1025
        #expect(media.screenSize == .expanded)
    }

    @Test("MediaQueryState default values")
    func mediaQueryDefaults() {
        let media = MediaQueryState()
        #expect(media.colorScheme == .light)
        #expect(media.screenWidth == 1024)
        #expect(media.screenHeight == 768)
        #expect(media.prefersReducedMotion == false)
    }

    @Test("GeolocationManager initial state")
    func geolocationInitialState() {
        let geo = GeolocationManager()
        #expect(geo.lastLocation == nil)
        #expect(geo.error == nil)
        #expect(geo.isLoading == false)
    }

    @Test("GeolocationManager requestLocation sets error in non-WASM")
    func geolocationRequestNonWasm() {
        let geo = GeolocationManager()
        geo.requestLocation()
        #expect(geo.error == "Geolocation is only available in WASM environment")
    }

    @Test("Coordinate initialization")
    func coordinateInit() {
        let coord = Coordinate(latitude: 55.7558, longitude: 37.6173, accuracy: 10.0)
        #expect(coord.latitude == 55.7558)
        #expect(coord.longitude == 37.6173)
        #expect(coord.accuracy == 10.0)
    }

    @Test("Coordinate without accuracy")
    func coordinateWithoutAccuracy() {
        let coord = Coordinate(latitude: 40.7128, longitude: -74.0060)
        #expect(coord.latitude == 40.7128)
        #expect(coord.longitude == -74.0060)
        #expect(coord.accuracy == nil)
    }

    @Test("ClipboardManager non-WASM stubs")
    func clipboardNonWasm() {
        // writeText should be a no-op
        ClipboardManager.writeText("test")

        // readText should return nil
        nonisolated(unsafe) var result: String? = "not nil"
        ClipboardManager.readText { text in
            result = text
        }
        #expect(result == nil)
    }

    @Test("EnvironmentValues colorScheme default")
    func environmentColorScheme() {
        let env = EnvironmentValues()
        #expect(env.colorScheme == .light)
    }

    @Test("EnvironmentValues screenSize default")
    func environmentScreenSize() {
        let env = EnvironmentValues()
        #expect(env.screenSize == .regular)
    }

    @Test("EnvironmentValues prefersReducedMotion default")
    func environmentReducedMotion() {
        let env = EnvironmentValues()
        #expect(env.prefersReducedMotion == false)
    }

    @Test("EnvironmentValues locale default")
    func environmentLocale() {
        let env = EnvironmentValues()
        // In non-WASM environment, locale defaults to "en"
        #expect(env.locale == "en")
    }

    @Test("EnvironmentValues colorScheme set and get")
    func environmentColorSchemeSetGet() {
        var env = EnvironmentValues()
        env.colorScheme = .dark
        #expect(env.colorScheme == .dark)
    }

    @Test("EnvironmentValues screenSize set and get")
    func environmentScreenSizeSetGet() {
        var env = EnvironmentValues()
        env.screenSize = .compact
        #expect(env.screenSize == .compact)
    }

    @Test("EnvironmentValues locale set and get")
    func environmentLocaleSetGet() {
        var env = EnvironmentValues()
        env.locale = "ru"
        #expect(env.locale == "ru")
    }
}
