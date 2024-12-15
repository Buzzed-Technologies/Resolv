import SwiftUI

enum CustomFont {
    static func playfairDisplay(size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Regular", size: size)
    }
    
    static func playfairDisplayBold(size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Bold", size: size)
    }
    
    static func playfairDisplayItalic(size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Italic", size: size)
    }
    
    static func registerFonts() {
        registerFont(bundle: .main, fontName: "PlayfairDisplay-Regular", fontExtension: "ttf")
        registerFont(bundle: .main, fontName: "PlayfairDisplay-Bold", fontExtension: "ttf")
        registerFont(bundle: .main, fontName: "PlayfairDisplay-Italic", fontExtension: "ttf")
    }
    
    private static func registerFont(bundle: Bundle, fontName: String, fontExtension: String) {
        guard let fontURL = bundle.url(forResource: fontName, withExtension: fontExtension),
              let fontDataProvider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("Couldn't create font from data")
            return
        }
        
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterGraphicsFont(font, &error)
    }
} 